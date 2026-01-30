-- AlterTable: Update PairingCode model
-- Make userId nullable, remove deviceIdentifier, add deviceType
-- Use TEXT for userId to match existing data; FK added separately if needed

-- Step 1: Create new table (no FK inline - production DB may have type mismatches)
CREATE TABLE "PairingCode_new" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "code" TEXT NOT NULL,
    "userId" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "usedAt" TIMESTAMP(3),
    "deviceId" TEXT,
    "deviceType" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Step 2: Copy data from old table (preserve existing data)
INSERT INTO "PairingCode_new" ("id", "code", "userId", "expiresAt", "used", "usedAt", "deviceId", "createdAt")
SELECT "id", "code",
       NULLIF(TRIM(COALESCE("userId"::text, '')), ''),
       "expiresAt", "used", "usedAt", "deviceId", "createdAt"
FROM "PairingCode";

-- Step 3: Drop old table
DROP TABLE "PairingCode";

-- Step 4: Rename new table
ALTER TABLE "PairingCode_new" RENAME TO "PairingCode";

-- Step 5: Create indexes
CREATE UNIQUE INDEX "PairingCode_code_key" ON "PairingCode"("code");
CREATE INDEX "PairingCode_userId_idx" ON "PairingCode"("userId");
