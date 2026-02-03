-- Ensure deviceIdentifier column exists (idempotent; safe if migration 20260128180000 was marked applied but not run)
ALTER TABLE "PairingCode" ADD COLUMN IF NOT EXISTS "deviceIdentifier" TEXT;

CREATE INDEX IF NOT EXISTS "PairingCode_deviceIdentifier_idx" ON "PairingCode"("deviceIdentifier");
