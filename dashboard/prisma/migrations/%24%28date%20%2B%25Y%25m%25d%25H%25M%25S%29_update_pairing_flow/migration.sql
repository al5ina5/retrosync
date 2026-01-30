-- AlterTable: Update PairingCode model
-- Make userId nullable, remove deviceIdentifier, add deviceType

-- Step 1: Create new table with updated schema
CREATE TABLE "PairingCode_new" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "code" TEXT NOT NULL,
    "userId" TEXT,
    "expiresAt" DATETIME NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "usedAt" DATETIME,
    "deviceId" TEXT,
    "deviceType" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PairingCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- Step 2: Copy data from old table (preserve existing data)
INSERT INTO "PairingCode_new" ("id", "code", "userId", "expiresAt", "used", "usedAt", "deviceId", "createdAt")
SELECT "id", "code", 
       CASE WHEN "userId" = '' THEN NULL ELSE "userId" END,
       "expiresAt", "used", "usedAt", "deviceId", "createdAt"
FROM "PairingCode";

-- Step 3: Drop old table
DROP TABLE "PairingCode";

-- Step 4: Rename new table
ALTER TABLE "PairingCode_new" RENAME TO "PairingCode";

-- Step 5: Create indexes
CREATE UNIQUE INDEX "PairingCode_code_key" ON "PairingCode"("code");
CREATE INDEX "PairingCode_userId_idx" ON "PairingCode"("userId");
