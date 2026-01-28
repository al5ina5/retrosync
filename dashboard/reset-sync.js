#!/usr/bin/env node

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('=== RetroSync reset: starting ===');

  // 1) Wipe sync logs first (they depend on versions/saves)
  const deletedLogs = await prisma.syncLog.deleteMany({});
  console.log('Deleted SyncLog rows:', deletedLogs.count);

  // 2) Wipe save versions
  const deletedVersions = await prisma.saveVersion.deleteMany({});
  console.log('Deleted SaveVersion rows:', deletedVersions.count);

  // 3) Wipe save locations
  const deletedLocations = await prisma.saveLocation.deleteMany({});
  console.log('Deleted SaveLocation rows:', deletedLocations.count);

  // 4) Wipe logical saves
  const deletedSaves = await prisma.save.deleteMany({});
  console.log('Deleted Save rows:', deletedSaves.count);

  // 5) Optionally clear lastSyncAt on devices so the dashboard reflects fresh state
  const updatedDevices = await prisma.device.updateMany({
    data: { lastSyncAt: null },
  });
  console.log('Cleared lastSyncAt on devices:', updatedDevices.count);

  console.log('=== RetroSync reset: done ===');
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('Reset failed:', err);
  prisma
    .$disconnect()
    .catch(() => { })
    .finally(() => process.exit(1));
});

