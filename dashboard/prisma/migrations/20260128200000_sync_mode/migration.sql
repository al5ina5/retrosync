-- Add syncMode column (sync | upload_only | disabled)
ALTER TABLE "SaveLocation" ADD COLUMN "syncMode" TEXT NOT NULL DEFAULT 'sync';

-- Migrate existing syncEnabled: true -> 'sync', false -> 'disabled'
UPDATE "SaveLocation" SET "syncMode" = CASE WHEN "syncEnabled" = true THEN 'sync' ELSE 'disabled' END;

-- Drop old column
ALTER TABLE "SaveLocation" DROP COLUMN "syncEnabled";
