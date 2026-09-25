// Ngarringilanha Ranger Gathering — send one notification to every ranger
// who has turned them on.
//
// The push is sent with NO payload. That is deliberate: a payload has to be
// encrypted to each subscriber's own key (aes128gcm), which is a lot of
// fragile crypto to carry for a message that is the same for everybody. With
// no payload the phone is simply told "something is waiting", and the service
// worker reads the newest row of push_messages to find out what to show. The
// wording can then be changed with one INSERT instead of an app release.
//
// Deploy:  supabase functions deploy send-push
// Secrets: VAPID_PUBLIC_KEY, VAPID_PRIVATE_JWK, VAPID_SUBJECT, PUSH_SEND_TOKEN

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const b64url = (b: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(b)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const b64urlStr = (s: string) => b64url(new TextEncoder().encode(s));

/** A VAPID JWT proves to the push service that this really is our server. */
async function vapidAuth(audience: string) {
  const jwk = JSON.parse(Deno.env.get("VAPID_PRIVATE_JWK")!);
  const key = await crypto.subtle.importKey(
    "jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const header = b64urlStr(JSON.stringify({ typ: "JWT", alg: "ES256" }));
  const claims = b64urlStr(JSON.stringify({
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + 12 * 60 * 60,
    sub: Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.com",
  }));
  // WebCrypto returns ECDSA as raw r||s, which is exactly what JWS ES256 wants.
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `vapid t=${header}.${claims}.${b64url(sig)}, k=${Deno.env.get("VAPID_PUBLIC_KEY")}`;
}

Deno.serve(async (req) => {
  // Without this check the URL alone would let anyone notify 200 rangers.
  const token = Deno.env.get("PUSH_SEND_TOKEN");
  if (!token || req.headers.get("x-push-token") !== token) {
    return new Response("Not authorised", { status: 401 });
  }

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: subs, error } = await sb
    .from("push_subscriptions").select("endpoint");
  if (error) return new Response(error.message, { status: 500 });
  if (!subs?.length) {
    return Response.json({ sent: 0, failed: 0, removed: 0, note: "nobody has turned notifications on yet" });
  }

  let sent = 0, failed = 0;
  const expired: string[] = [];

  // Sequential on purpose. 200 subscribers is nothing, and hammering the push
  // services in parallel is how you get rate-limited.
  for (const { endpoint } of subs) {
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: await vapidAuth(new URL(endpoint).origin),
          TTL: "86400",           // hold it for a day if the phone is off
          Urgency: "normal",
          "Content-Length": "0",
        },
      });
      if (res.status === 404 || res.status === 410) expired.push(endpoint);
      else if (res.ok) sent++;
      else failed++;
    } catch {
      failed++;
    }
  }

  // A 404/410 means that phone uninstalled the app or cleared its data.
  // Dropping them keeps the next send fast and the count honest.
  if (expired.length) {
    await sb.from("push_subscriptions").delete().in("endpoint", expired);
  }

  return Response.json({ sent, failed, removed: expired.length });
});
