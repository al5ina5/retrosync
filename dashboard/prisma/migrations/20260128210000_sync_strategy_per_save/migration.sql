-- Add syncStrategy to Save: "shared" (one version for all) or "per_device" (each device has its own, all backed up)
ALTER TABLE "Save" ADD COLUMN "syncStrategy" TEXT NOT NULL DEFAULT 'shared';

-- Remove per-location sync; sync is now per-save only (handles both sync_mode and legacy syncEnabled)
ALTER TABLE "SaveLocation" DROP COLUMN IF EXISTS "syncMode";
ALTER TABLE "SaveLocation" DROP COLUMN IF EXISTS "syncEnabled";
