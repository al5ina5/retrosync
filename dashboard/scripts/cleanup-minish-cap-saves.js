/**
 * One-off: Remove all Minish Cap saves EXCEPT the one that has 3 paths (locations).
 * Run from dashboard dir: node scripts/cleanup-minish-cap-saves.js
 * Requires DATABASE_URL in environment (e.g. export from .env or: node -r dotenv/config scripts/cleanup-minish-cap-saves.js with dotenv installed).
 */
try {
  require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
} catch (_) { }

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Find all saves whose displayName or saveKey contains "Minish" (case-insensitive)
  const allSaves = await prisma.save.findMany({
    where: {
      OR: [
        { displayName: { contains: 'Minish', mode: 'insensitive' } },
        { saveKey: { contains: 'Minish', mode: 'insensitive' } },
      ],
    },
    include: {
      locations: true,
      _count: { select: { versions: true, locations: true } },
    },
    orderBy: { updatedAt: 'desc' },
  });

  if (allSaves.length === 0) {
    console.log('No Minish Cap saves found.');
    return;
  }

  console.log(`Found ${allSaves.length} Minish Cap save(s):`);
  allSaves.forEach((s, i) => {
    console.log(
      `  ${i + 1}. id=${s.id} saveKey="${s.saveKey}" locations=${s._count.locations} versions=${s._count.versions}`
    );
  });

  // Keep the one with exactly 3 paths (locations); if none has 3, keep the one with the most locations
  const keep =
    allSaves.find((s) => s._count.locations === 3) ??
    allSaves.reduce((a, b) => (a._count.locations >= b._count.locations ? a : b));
  const toDelete = allSaves.filter((s) => s.id !== keep.id);

  if (toDelete.length === 0) {
    console.log('Nothing to delete. Single Minish Cap save kept.');
    return;
  }

  console.log(`\nKeeping save id=${keep.id} (${keep._count.locations} locations)`);
  console.log(`Deleting ${toDelete.length} other Minish Cap save(s): ${toDelete.map((s) => s.id).join(', ')}`);

  const idsToDelete = toDelete.map((s) => s.id);

  // Unlink or delete SyncLogs that reference these saves (FK has no cascade)
  const unlinked = await prisma.syncLog.updateMany({
    where: { saveId: { in: idsToDelete } },
    data: { saveId: null, saveVersionId: null },
  });
  if (unlinked.count > 0) {
    console.log(`Unlinked ${unlinked.count} SyncLog(s) from deleted saves.`);
  }

  // Delete saves (cascade will remove SaveVersion and SaveLocation)
  for (const id of idsToDelete) {
    await prisma.saveVersion.deleteMany({ where: { saveId: id } });
    await prisma.saveLocation.deleteMany({ where: { saveId: id } });
    await prisma.save.delete({ where: { id } });
    console.log(`Deleted save ${id}`);
  }

  console.log('Done. Only the save with 3 paths remains.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
