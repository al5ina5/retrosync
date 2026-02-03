-- CreateTable
CREATE TABLE "DeviceScanPath" (
    "id" TEXT NOT NULL,
    "deviceId" UUID NOT NULL,
    "path" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'device',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DeviceScanPath_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "DeviceScanPath_deviceId_path_kind_key" ON "DeviceScanPath"("deviceId", "path", "kind");

-- CreateIndex
CREATE INDEX "DeviceScanPath_deviceId_idx" ON "DeviceScanPath"("deviceId");

-- CreateIndex
CREATE INDEX "DeviceScanPath_kind_idx" ON "DeviceScanPath"("kind");

-- AddForeignKey
ALTER TABLE "DeviceScanPath" ADD CONSTRAINT "DeviceScanPath_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE CASCADE ON UPDATE CASCADE;
