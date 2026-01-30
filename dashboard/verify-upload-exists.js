// Verify that the Minish Cap upload actually exists in S3
// Run: cd dashboard && node verify-upload-exists.js

const { PrismaClient } = require('@prisma/client')
const { S3 } = require('aws-sdk')
const prisma = new PrismaClient()

// Use same S3 config as the project
const rawEndpoint =
  process.env.S3_ENDPOINT || process.env.MINIO_ENDPOINT || 'http://localhost:9000'
const endpointUrl = rawEndpoint.startsWith('http') ? rawEndpoint : `http://${rawEndpoint}`
const useSsl = endpointUrl.startsWith('https://')

const accessKeyId =
  process.env.S3_ACCESS_KEY_ID ||
  process.env.MINIO_ROOT_USER ||
  (process.env.NODE_ENV !== 'production' ? 'minioadmin' : process.env.AWS_ACCESS_KEY_ID)

const secretAccessKey =
  process.env.S3_SECRET_ACCESS_KEY ||
  process.env.MINIO_ROOT_PASSWORD ||
  (process.env.NODE_ENV !== 'production' ? 'minioadmin' : process.env.AWS_SECRET_ACCESS_KEY)

const s3Client = new S3({
  endpoint: endpointUrl,
  s3ForcePathStyle: true,
  signatureVersion: 'v4',
  sslEnabled: useSsl,
  accessKeyId,
  secretAccessKey,
  region: process.env.AWS_REGION || 'us-east-1',
})

const BUCKET_NAME =
  process.env.S3_BUCKET || process.env.MINIO_BUCKET || process.env.AWS_S3_BUCKET_NAME || 'retrosync-saves'

async function verifyUpload() {
  console.log('=== Verifying Minish Cap Upload in S3 ===\n')

  if (!BUCKET_NAME) {
    console.error('ERROR: AWS_S3_BUCKET_NAME not set')
    process.exit(1)
  }

  // Find the save and the specific version we're looking for
  const expectedMtime = 1769644264 // Unix timestamp in seconds
  const expectedMtimeMs = expectedMtime * 1000

  const save = await prisma.save.findFirst({
    where: {
      saveKey: { contains: 'Minish Cap' },
    },
    include: {
      versions: {
        where: {
          localModifiedAt: {
            gte: new Date(expectedMtimeMs - 5000), // Within 5 seconds
            lte: new Date(expectedMtimeMs + 5000),
          },
        },
        include: {
          device: {
            select: { id: true, name: true },
          },
        },
        orderBy: { uploadedAt: 'desc' },
      },
    },
  })

  if (!save) {
    console.log('No save found matching Minish Cap')
    await prisma.$disconnect()
    return
  }

  console.log(`Found save: "${save.saveKey}"`)
  console.log(`Save ID: ${save.id}\n`)

  console.log(`Versions matching expected mtime (${expectedMtime}):`)
  console.log(`Found ${save.versions.length} version(s)\n`)

  for (const version of save.versions) {
    const localMs = version.localModifiedAt.getTime()
    const diff = Math.abs(localMs - expectedMtimeMs)
    const isMatch = diff < 5000

    console.log(`\n=== Version: ${version.id} ===`)
    console.log(`Device: ${version.device.name}`)
    console.log(`Local Modified: ${version.localModifiedAt.toISOString()} (${localMs}ms)`)
    console.log(`Uploaded: ${version.uploadedAt.toISOString()}`)
    console.log(`Size: ${version.byteSize} bytes`)
    console.log(`Hash: ${version.contentHash}`)
    console.log(`Storage Key: ${version.storageKey}`)
    console.log(`Match: ${isMatch ? '✅ YES' : '❌ NO'} (diff: ${diff}ms)`)

    // Check if file exists in S3
    try {
      const headResult = await s3Client
        .headObject({
          Bucket: BUCKET_NAME,
          Key: version.storageKey,
        })
        .promise()

      console.log(`\n✅ S3 File EXISTS:`)
      console.log(`   Size: ${headResult.ContentLength} bytes`)
      console.log(`   Last Modified: ${headResult.LastModified}`)
      console.log(`   ETag: ${headResult.ETag}`)

      // Verify size matches
      if (headResult.ContentLength === version.byteSize) {
        console.log(`   ✅ Size matches database (${version.byteSize} bytes)`)
      } else {
        console.log(
          `   ❌ Size MISMATCH: DB=${version.byteSize}, S3=${headResult.ContentLength}`
        )
      }

      // Download and verify hash if it's the version we're looking for
      if (isMatch) {
        console.log(`\n📥 Downloading file to verify content...`)
        const getResult = await s3Client
          .getObject({
            Bucket: BUCKET_NAME,
            Key: version.storageKey,
          })
          .promise()

        const fileBuffer = getResult.Body

        console.log(`   Downloaded: ${fileBuffer.length} bytes`)

        // Calculate hash
        const crypto = require('crypto')
        const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex')

        console.log(`   Calculated Hash: ${hash}`)
        console.log(`   Database Hash:   ${version.contentHash}`)

        if (hash === version.contentHash) {
          console.log(`   ✅ Hash MATCHES - file content is correct!`)
        } else {
          console.log(`   ❌ Hash MISMATCH - file content may be corrupted!`)
        }
      }
    } catch (error) {
      if (error.code === 'NotFound' || error.code === 'NoSuchKey') {
        console.log(`\n❌ S3 File DOES NOT EXIST!`)
        console.log(`   The database says it was uploaded, but the file is missing from S3.`)
        console.log(`   Error code: ${error.code}`)
      } else {
        console.log(`\n❌ Error checking S3: ${error.message}`)
        console.log(`   Error code: ${error.code}`)
        console.log(`   ${error}`)
      }
    }
  }

  // Also check the sync logs
  console.log(`\n\n=== Checking Sync Logs ===`)
  const logs = await prisma.syncLog.findMany({
    where: {
      saveId: save.id,
      action: 'upload',
      createdAt: {
        gte: new Date('2026-01-28T23:52:00Z'),
      },
    },
    include: {
      device: {
        select: { id: true, name: true },
      },
      saveVersion: {
        select: { id: true, localModifiedAt: true, storageKey: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  })

  console.log(`Found ${logs.length} upload log(s):\n`)
  logs.forEach((log) => {
    console.log(`${log.createdAt.toISOString()}:`)
    console.log(`  Device: ${log.device.name}`)
    console.log(`  Status: ${log.status}`)
    console.log(`  File: ${log.filePath}`)
    if (log.saveVersion) {
      const localMs = log.saveVersion.localModifiedAt.getTime()
      const diff = Math.abs(localMs - expectedMtimeMs)
      console.log(`  Version: ${log.saveVersion.id}`)
      console.log(`  Local Modified: ${log.saveVersion.localModifiedAt.toISOString()}`)
      console.log(`  Storage Key: ${log.saveVersion.storageKey}`)
      console.log(`  Match: ${diff < 5000 ? '✅ YES' : '❌ NO'}`)
    }
    if (log.errorMsg) {
      console.log(`  Error: ${log.errorMsg}`)
    }
  })

  await prisma.$disconnect()
}

verifyUpload().catch((e) => {
  console.error('Error:', e)
  process.exit(1)
})
