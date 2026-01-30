/**
 * One-off migration: Make saveKey extension-agnostic (strip .sav/.srm).
 * - Updates all Save records so saveKey has no .sav/.srm.
 * - Merges duplicate Saves that collapse to the same key (e.g. X.sav and X.srm → one Save).
 * Run from dashboard dir: node scripts/migrate-save-keys-no-extension.js
 */
try {
  require('dotenv').config({ path: require('path').join(__dirname, '../.env') })
} catch (_) { }

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

function stripBatteryExtension(key) {
  if (!key || typeof key !== 'string') return key
  if (key.endsWith('.srm')) return key.slice(0, -4)
  if (key.endsWith('.sav')) return key.slice(0, -4)
  return key
}

async function main() {
  const saves = await prisma.save.findMany({
    include: {
      _count: { select: { locations: true, versions: true } },
    },
  })

  // Group by (userId, stripBatteryExtension(saveKey))
  const groups = new Map()
  for (const save of saves) {
    const newKey = stripBatteryExtension(save.saveKey)
    const groupKey = `${save.userId}\t${newKey}`
    if (!groups.has(groupKey)) groups.set(groupKey, [])
    groups.get(groupKey).push(save)
  }

  let updated = 0
  let merged = 0
  let deleted = 0

  for (const [, group] of groups) {
    const newSaveKey = stripBatteryExtension(group[0].saveKey)
    const newDisplayName = newSaveKey

    if (group.length === 1) {
      const save = group[0]
      if (save.saveKey !== newSaveKey || save.displayName !== newDisplayName) {
        await prisma.save.update({
          where: { id: save.id },
          data: { saveKey: newSaveKey, displayName: newDisplayName },
        })
        updated++
        console.log(`Updated: ${save.saveKey} -> ${newSaveKey}`)
      }
      continue
    }

    // Merge: keep the one with most locations (then most versions), then first by id
    group.sort((a, b) => {
      const locA = a._count.locations
      const locB = b._count.locations
      if (locB !== locA) return locB - locA
      const verA = a._count.versions
      const verB = b._count.versions
      if (verB !== verA) return verB - verA
      return a.id.localeCompare(b.id)
    })
    const keep = group[0]
    const toMerge = group.slice(1)

    const keepLocations = await prisma.saveLocation.findMany({
      where: { saveId: keep.id },
      select: { deviceId: true, localPath: true },
    })
    const keepLocKey = (loc) => `${loc.deviceId}\t${loc.localPath}`
    const keepLocSet = new Set(keepLocations.map(keepLocKey))

    for (const other of toMerge) {
      const otherLocations = await prisma.saveLocation.findMany({
        where: { saveId: other.id },
      })
      for (const loc of otherLocations) {
        if (keepLocSet.has(keepLocKey(loc))) {
          await prisma.saveLocation.delete({ where: { id: loc.id } })
        } else {
          await prisma.saveLocation.update({
            where: { id: loc.id },
            data: { saveId: keep.id },
          })
          keepLocSet.add(keepLocKey(loc))
        }
      }
      await prisma.saveVersion.updateMany({
        where: { saveId: other.id },
        data: { saveId: keep.id },
      })
      await prisma.syncLog.updateMany({
        where: { saveId: other.id },
        data: { saveId: keep.id },
      })
      await prisma.save.delete({ where: { id: other.id } })
      deleted++
      console.log(`Merged ${other.saveKey} into ${keep.saveKey}, deleted Save ${other.id}`)
    }

    await prisma.save.update({
      where: { id: keep.id },
      data: { saveKey: newSaveKey, displayName: newDisplayName },
    })
    updated++
    merged++
    console.log(`Kept save ${keep.id} as saveKey="${newSaveKey}" (${group.length} merged)`)
  }

  console.log(`\nDone. Updated: ${updated}, merged groups: ${merged}, deleted Saves: ${deleted}`)
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
