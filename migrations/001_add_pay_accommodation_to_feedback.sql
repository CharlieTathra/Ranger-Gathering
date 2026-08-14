-- Add pay_accommodation column to feedback table
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS pay_accommodation text;
