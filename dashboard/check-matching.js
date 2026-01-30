// Quick diagnostic script to check save matching and timestamps
// Run: cd dashboard && node check-matching.js

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

async function checkMatching() {
  console.log('=== Checking Save Matching & Timestamps ===\n')

  // Get all Saves with their versions and locations
  const saves = await prisma.save.findMany({
    include: {
      versions: {
        include: {
          device: {
            select: { id: true, name: true, deviceType: true }
          }
        },
        orderBy: { uploadedAt: 'desc' }
      },
      locations: {
        include: {
          device: {
            select: { id: true, name: true, deviceType: true }
          }
        }
      }
    },
    orderBy: { updatedAt: 'desc' }
  })

  console.log(`Total Saves: ${saves.length}\n`)

  // Check for saves that appear on multiple devices (good matching)
  const multiDeviceSaves = saves.filter(s => s.locations.length > 1)
  console.log(`Saves on multiple devices (matched correctly): ${multiDeviceSaves.length}`)

  if (multiDeviceSaves.length > 0) {
    console.log('\n--- Multi-device saves (GOOD - matched correctly) ---')
    multiDeviceSaves.forEach(save => {
      console.log(`\nSave: "${save.saveKey}" (${save.displayName})`)
      console.log(`  Save ID: ${save.id}`)
      console.log(`  Locations (${save.locations.length} devices):`)
      save.locations.forEach(loc => {
        console.log(`    - ${loc.device.name} (${loc.device.deviceType}): ${loc.localPath}`)
      })
      console.log(`  Versions (${save.versions.length} total):`)
      save.versions.forEach(v => {
        const localMs = v.localModifiedAt.getTime()
        const uploadMs = v.uploadedAt.getTime()
        const diff = uploadMs - localMs
        console.log(`    - ${v.device.name}: localModifiedAt=${v.localModifiedAt.toISOString()} (${localMs}ms), uploadedAt=${v.uploadedAt.toISOString()} (${uploadMs}ms), diff=${diff}ms`)
      })
    })
  }

  // Check for saves with only one device (not matched yet)
  const singleDeviceSaves = saves.filter(s => s.locations.length === 1)
  console.log(`\n\nSaves on single device only: ${singleDeviceSaves.length}`)

  // Check if any single-device saves have the same filename (potential matches)
  const filenameMap = new Map()
  singleDeviceSaves.forEach(save => {
    const key = save.saveKey.toLowerCase()
    if (!filenameMap.has(key)) {
      filenameMap.set(key, [])
    }
    filenameMap.get(key).push(save)
  })

  const potentialMatches = Array.from(filenameMap.entries()).filter(([_, saves]) => saves.length > 1)
  if (potentialMatches.length > 0) {
    console.log(`\n⚠️  Potential matches (same filename, different Save entities): ${potentialMatches.length}`)
    potentialMatches.slice(0, 5).forEach(([filename, saveList]) => {
      console.log(`\n  "${filename}":`)
      saveList.forEach(s => {
        const loc = s.locations[0]
        console.log(`    - Save ID ${s.id} on ${loc.device.name} (${loc.localPath})`)
      })
    })
    if (potentialMatches.length > 5) {
      console.log(`  ... and ${potentialMatches.length - 5} more`)
    }
  }

  // Check timestamp accuracy
  console.log('\n\n=== Timestamp Analysis ===')
  const allVersions = saves.flatMap(s => s.versions)
  const withLocalMtime = allVersions.filter(v => {
    const localMs = v.localModifiedAt.getTime()
    const uploadMs = v.uploadedAt.getTime()
    // If localModifiedAt is very close to uploadedAt (within 5 seconds), it might be a fallback
    return Math.abs(uploadMs - localMs) > 5000
  })
  console.log(`Versions with distinct localModifiedAt (not just upload time): ${withLocalMtime.length}/${allVersions.length}`)

  if (withLocalMtime.length < allVersions.length) {
    const fallbackCount = allVersions.length - withLocalMtime.length
    console.log(`⚠️  ${fallbackCount} versions using uploadedAt as localModifiedAt (client may not be sending mtime)`)
  }

  // Show some examples
  console.log('\n--- Sample Versions (first 10) ---')
  allVersions.slice(0, 10).forEach(v => {
    const localMs = v.localModifiedAt.getTime()
    const uploadMs = v.uploadedAt.getTime()
    const diff = uploadMs - localMs
    const saveName = v.save ? v.save.displayName : 'Unknown'
    console.log(`${v.device.name}: ${saveName}`)
    console.log(`  localModifiedAt: ${v.localModifiedAt.toISOString()} (${localMs}ms)`)
    console.log(`  uploadedAt: ${v.uploadedAt.toISOString()} (${uploadMs}ms)`)
    console.log(`  diff: ${diff}ms (${diff > 5000 ? '✅ distinct' : '⚠️  too close, might be fallback'})`)
    console.log(`  size: ${v.byteSize} bytes, hash: ${v.contentHash.substring(0, 16)}...`)
    console.log('')
  })

  await prisma.$disconnect()
}

checkMatching().catch(console.error)
