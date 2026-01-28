#!/usr/bin/env node

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const saves = await prisma.save.findMany({
    where: { displayName: { contains: 'Secret of Mana (USA).srm' } },
    include: {
      locations: { include: { device: true } },
      versions: {
        include: { device: true },
        orderBy: { uploadedAt: 'desc' },
        take: 10,
      },
    },
  });

  console.log('Found saves:', saves.length);
  for (const save of saves) {
    console.log('\\n=== Save ===');
    console.log('id:', save.id);
    console.log('saveKey:', save.saveKey);
    console.log('displayName:', save.displayName);
    console.log('Locations:');
    for (const loc of save.locations) {
      console.log(
        ' - device:',
        loc.device.name,
        'type:',
        loc.device.deviceType,
        'path:',
        loc.localPath,
        'syncEnabled:',
        loc.syncEnabled
      );
    }
    console.log('Latest versions:');
    for (const v of save.versions) {
      console.log(
        ' - device:',
        v.device.name,
        'uploadedAt:',
        v.uploadedAt.toISOString(),
        'localModifiedAt:',
        v.localModifiedAt.toISOString(),
        'hash:',
        v.contentHash.substring(0, 16) + '...'
      );
    }
  }

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

