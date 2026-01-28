-- AlterTable
ALTER TABLE "PairingCode" ADD COLUMN "deviceIdentifier" TEXT;

-- CreateIndex
CREATE INDEX "PairingCode_deviceIdentifier_idx" ON "PairingCode"("deviceIdentifier");
