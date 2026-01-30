#!/usr/bin/env node
/**
 * Test script to verify download sync readiness
 *
 * Usage (Neon Postgres, no local db file):
 *   DATABASE_URL="postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require" node test-download-sync.js
 */

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

async function testDownloadSyncReadiness() {
  console.log('=== Download Sync Readiness Test ===\n')

  // 1. Check devices
  const devices = await prisma.device.findMany({ take: 10 })
  console.log(`✓ Found ${devices.length} device(s)`)

  if (devices.length < 1) {
    console.log('⚠️  No devices found. Pair at least one device first.')
    await prisma.$disconnect()
    return
  }

  // 2. Check saves with locations
  for (const device of devices.slice(0, 2)) {
    console.log(`\n--- Device: ${device.name} (${device.deviceType}) ---`)

    const locations = await prisma.saveLocation.findMany({
      where: { deviceId: device.id },
      include: {
        save: {
          include: {
            versions: {
              orderBy: [{ uploadedAt: 'desc' }],
              take: 1,
            },
          },
        },
      },
      take: 5,
    })

    console.log(`  ✓ Found ${locations.length} save location(s) mapped to this device`)

    if (locations.length === 0) {
      console.log('  ⚠️  No saves mapped to this device. Upload some saves first.')
      continue
    }

    // Check a few saves
    for (const loc of locations.slice(0, 3)) {
      const latest = loc.save.versions[0]
      if (!latest) {
        console.log(`  ⚠️  Save "${loc.save.displayName}" has no versions`)
        continue
      }

      const localMs = latest.localModifiedAt.getTime()
      const uploadMs = latest.uploadedAt.getTime()
      const diff = Math.abs(uploadMs - localMs)
      const hasRealMtime = diff > 5000

      console.log(`  ✓ "${loc.save.displayName}"`)
      console.log(`    - Path: ${loc.localPath}`)
      console.log(`    - Latest version: ${hasRealMtime ? 'REAL MTIME' : 'FALLBACK'}`)
      console.log(`    - Timestamp: ${latest.localModifiedAt.toISOString()}`)
      console.log(`    - Size: ${latest.byteSize} bytes`)
    }
  }

  // 3. Check cross-device matching
  console.log('\n--- Cross-Device Matching ---')
  const allSaves = await prisma.save.findMany({
    include: {
      locations: {
        include: { device: { select: { name: true, deviceType: true } } },
      },
      versions: {
        include: { device: { select: { name: true } } },
        take: 1,
      },
    },
    take: 10,
  })

  let multiDeviceSaves = 0
  for (const save of allSaves) {
    if (save.locations.length > 1) {
      multiDeviceSaves++
      if (multiDeviceSaves <= 3) {
        console.log(`  ✓ "${save.displayName}" mapped to ${save.locations.length} device(s):`)
        for (const loc of save.locations) {
          console.log(`    - ${loc.device.name} (${loc.device.deviceType}): ${loc.localPath}`)
        }
      }
    }
  }

  if (multiDeviceSaves > 0) {
    console.log(`  ✓ Found ${multiDeviceSaves} save(s) mapped to multiple devices`)
  } else {
    console.log('  ℹ️  No saves yet mapped to multiple devices (this is OK for initial testing)')
  }

  console.log('\n=== Test Summary ===')
  console.log('✓ Database structure looks good')
  console.log('✓ Ready for download sync testing')
  console.log('\nNext steps:')
  console.log('1. On Device A: Upload a save file')
  console.log('2. On Device B: Press "d" (keyboard) or "Y" (gamepad) to download')
  console.log('3. Verify: File is downloaded to Device B\'s correct path')
  console.log('4. Check logs for: "download: GET" or "download: SKIP" messages')

  await prisma.$disconnect()
}

testDownloadSyncReadiness().catch((err) => {
  console.error('Error:', err)
  process.exit(1)
})
