-- Add syncStrategy to Save: "shared" (one version for all) or "per_device" (each device has its own, all backed up)
ALTER TABLE "Save" ADD COLUMN IF NOT EXISTS "syncStrategy" TEXT NOT NULL DEFAULT 'shared';

-- Remove legacy syncEnabled only (syncMode stays - per-location sync setting)
ALTER TABLE "SaveLocation" DROP COLUMN IF EXISTS "syncEnabled";
