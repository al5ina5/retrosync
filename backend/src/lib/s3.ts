import { S3 } from 'aws-sdk'

const s3Config = {
  endpoint: process.env.MINIO_ENDPOINT || 'http://localhost:9000',
  accessKeyId: process.env.MINIO_ROOT_USER || 'minioadmin',
  secretAccessKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin',
  s3ForcePathStyle: true,
  signatureVersion: 'v4',
}

export const s3Client = new S3(s3Config)

export const BUCKET_NAME = process.env.MINIO_BUCKET || 'retrosync-saves'

/**
 * Upload a file to S3
 */
export async function uploadFile(
  key: string,
  body: Buffer | string,
  contentType?: string
): Promise<S3.ManagedUpload.SendData> {
  const params: S3.PutObjectRequest = {
    Bucket: BUCKET_NAME,
    Key: key,
    Body: body,
    ContentType: contentType || 'application/octet-stream',
  }

  return s3Client.upload(params).promise()
}

/**
 * Download a file from S3
 */
export async function downloadFile(key: string): Promise<Buffer> {
  const params: S3.GetObjectRequest = {
    Bucket: BUCKET_NAME,
    Key: key,
  }

  const data = await s3Client.getObject(params).promise()
  return data.Body as Buffer
}

/**
 * List files in S3 with a prefix
 */
export async function listFiles(prefix: string): Promise<S3.ObjectList> {
  const params: S3.ListObjectsV2Request = {
    Bucket: BUCKET_NAME,
    Prefix: prefix,
  }

  const data = await s3Client.listObjectsV2(params).promise()
  return data.Contents || []
}

/**
 * Delete a file from S3
 */
export async function deleteFile(key: string): Promise<void> {
  const params: S3.DeleteObjectRequest = {
    Bucket: BUCKET_NAME,
    Key: key,
  }

  await s3Client.deleteObject(params).promise()
}

/**
 * Get a presigned URL for downloading
 */
export function getPresignedUrl(key: string, expiresIn: number = 3600): string {
  const params = {
    Bucket: BUCKET_NAME,
    Key: key,
    Expires: expiresIn,
  }

  return s3Client.getSignedUrl('getObject', params)
}

/**
 * Get a presigned URL for uploading
 */
export function getPresignedUploadUrl(key: string, expiresIn: number = 3600): string {
  const params = {
    Bucket: BUCKET_NAME,
    Key: key,
    Expires: expiresIn,
  }

  return s3Client.getSignedUrl('putObject', params)
}

/**
 * Check if a file exists in S3
 */
export async function fileExists(key: string): Promise<boolean> {
  try {
    const params: S3.HeadObjectRequest = {
      Bucket: BUCKET_NAME,
      Key: key,
    }
    await s3Client.headObject(params).promise()
    return true
  } catch (error) {
    return false
  }
}

/**
 * Get file metadata
 */
export async function getFileMetadata(key: string): Promise<S3.HeadObjectOutput | null> {
  try {
    const params: S3.HeadObjectRequest = {
      Bucket: BUCKET_NAME,
      Key: key,
    }
    return await s3Client.headObject(params).promise()
  } catch (error) {
    return null
  }
}
