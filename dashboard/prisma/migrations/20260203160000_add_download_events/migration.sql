-- Add DownloadEvent table for dashboard download rate limiting

DROP TABLE IF EXISTS "DownloadEvent";

CREATE TABLE "DownloadEvent" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "saveId" UUID,
    "saveVersionId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DownloadEvent_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "DownloadEvent_userId_idx" ON "DownloadEvent"("userId");
CREATE INDEX "DownloadEvent_createdAt_idx" ON "DownloadEvent"("createdAt");
CREATE INDEX "DownloadEvent_saveId_idx" ON "DownloadEvent"("saveId");
CREATE INDEX "DownloadEvent_saveVersionId_idx" ON "DownloadEvent"("saveVersionId");

ALTER TABLE "DownloadEvent"
ADD CONSTRAINT "DownloadEvent_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "DownloadEvent"
ADD CONSTRAINT "DownloadEvent_saveId_fkey"
FOREIGN KEY ("saveId") REFERENCES "Save"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "DownloadEvent"
ADD CONSTRAINT "DownloadEvent_saveVersionId_fkey"
FOREIGN KEY ("saveVersionId") REFERENCES "SaveVersion"("id") ON DELETE SET NULL ON UPDATE CASCADE;
