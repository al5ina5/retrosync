// Check if Minish Cap save was uploaded successfully
// Run: cd dashboard && node check-minish-upload.js

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

async function checkMinishUpload() {
  console.log('=== Checking Minish Cap Upload ===\n')

  // The mtime from the log: 1769644264 (Unix timestamp in seconds)
  // Convert to Date
  const expectedMtime = new Date(1769644264 * 1000)
  console.log(`Expected mtime: ${expectedMtime.toISOString()} (${1769644264}s)\n`)

  // Find saves with "Minish Cap" in the name
  const saves = await prisma.save.findMany({
    where: {
      OR: [
        { saveKey: { contains: 'Minish Cap' } },
        { displayName: { contains: 'Minish Cap' } },
      ],
    },
    include: {
      versions: {
        orderBy: { uploadedAt: 'desc' },
        include: {
          device: {
            select: { id: true, name: true, deviceType: true },
          },
        },
      },
      locations: {
        include: {
          device: {
            select: { id: true, name: true, deviceType: true },
          },
        },
      },
      syncLogs: {
        where: {
          action: 'upload',
          createdAt: {
            gte: new Date('2026-01-28T23:52:00Z'), // Around the upload time
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
      },
    },
  })

  console.log(`Found ${saves.length} save(s) matching "Minish Cap"\n`)

  for (const save of saves) {
    console.log(`\n=== Save: "${save.saveKey}" ===`)
    console.log(`Display Name: ${save.displayName}`)
    console.log(`Save ID: ${save.id}`)
    console.log(`Created: ${save.createdAt.toISOString()}`)
    console.log(`Updated: ${save.updatedAt.toISOString()}`)

    console.log(`\nLocations (${save.locations.length}):`)
    save.locations.forEach((loc) => {
      console.log(`  - ${loc.device.name}: ${loc.localPath}`)
      console.log(`    Sync Enabled: ${loc.syncEnabled}`)
    })

    console.log(`\nVersions (${save.versions.length}):`)
    save.versions.forEach((v, idx) => {
      const localMs = v.localModifiedAt.getTime()
      const uploadMs = v.uploadedAt.getTime()
      const expectedMs = expectedMtime.getTime()
      const diff = Math.abs(localMs - expectedMs)
      const isMatch = diff < 5000 // Within 5 seconds

      console.log(`  [${idx + 1}] ${v.device.name}:`)
      console.log(`    Local Modified: ${v.localModifiedAt.toISOString()} (${localMs}ms)`)
      console.log(`    Uploaded: ${v.uploadedAt.toISOString()} (${uploadMs}ms)`)
      console.log(`    Size: ${v.byteSize} bytes`)
      console.log(`    Hash: ${v.contentHash.substring(0, 16)}...`)
      console.log(`    Expected mtime: ${expectedMtime.toISOString()} (${expectedMs}ms)`)
      console.log(`    Match: ${isMatch ? '✅ YES' : '❌ NO'} (diff: ${diff}ms)`)
      console.log(`    Storage Key: ${v.storageKey}`)
    })

    console.log(`\nRecent Upload Logs (${save.syncLogs.length}):`)
    save.syncLogs.forEach((log) => {
      console.log(`  - ${log.createdAt.toISOString()}: ${log.status} - ${log.filePath}`)
      if (log.errorMsg) {
        console.log(`    Error: ${log.errorMsg}`)
      }
      if (log.saveVersionId) {
        console.log(`    Version ID: ${log.saveVersionId}`)
      }
    })
  }

  // Also check sync logs directly
  console.log(`\n\n=== Checking Sync Logs Directly ===`)
  const recentLogs = await prisma.syncLog.findMany({
    where: {
      filePath: {
        contains: 'Minish Cap',
      },
      createdAt: {
        gte: new Date('2026-01-28T23:52:00Z'),
      },
    },
    include: {
      device: {
        select: { id: true, name: true },
      },
      save: {
        select: { id: true, saveKey: true },
      },
      saveVersion: {
        select: { id: true, localModifiedAt: true, uploadedAt: true },
      },
    },
    orderBy: { createdAt: 'desc' },
    take: 20,
  })

  console.log(`Found ${recentLogs.length} recent sync log entries\n`)
  recentLogs.forEach((log) => {
    console.log(`\n${log.createdAt.toISOString()}:`)
    console.log(`  Device: ${log.device.name}`)
    console.log(`  File: ${log.filePath}`)
    console.log(`  Action: ${log.action}`)
    console.log(`  Status: ${log.status}`)
    if (log.save) {
      console.log(`  Save: ${log.save.saveKey}`)
    }
    if (log.saveVersion) {
      const localMs = log.saveVersion.localModifiedAt.getTime()
      const expectedMs = expectedMtime.getTime()
      console.log(`  Version Local Modified: ${log.saveVersion.localModifiedAt.toISOString()} (${localMs}ms)`)
      console.log(`  Match: ${Math.abs(localMs - expectedMs) < 5000 ? '✅ YES' : '❌ NO'}`)
    }
    if (log.errorMsg) {
      console.log(`  Error: ${log.errorMsg}`)
    }
  })

  await prisma.$disconnect()
}

checkMinishUpload().catch((e) => {
  console.error('Error:', e)
  process.exit(1)
})
