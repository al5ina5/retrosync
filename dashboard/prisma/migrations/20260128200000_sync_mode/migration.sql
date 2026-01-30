-- Add syncMode column (sync | upload_only | disabled)
ALTER TABLE "SaveLocation" ADD COLUMN IF NOT EXISTS "syncMode" TEXT NOT NULL DEFAULT 'sync';

-- Migrate existing syncEnabled if column exists (legacy schema)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SaveLocation' AND column_name = 'syncEnabled'
  ) THEN
    UPDATE "SaveLocation" SET "syncMode" = CASE WHEN "syncEnabled" = true THEN 'sync' ELSE 'disabled' END;
    ALTER TABLE "SaveLocation" DROP COLUMN "syncEnabled";
  END IF;
END $$;
