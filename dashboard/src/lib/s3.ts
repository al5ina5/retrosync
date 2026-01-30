import { S3 } from "aws-sdk";

const rawEndpoint =
  process.env.S3_ENDPOINT || process.env.MINIO_ENDPOINT || "http://localhost:9000";
const endpointUrl = rawEndpoint.startsWith("http") ? rawEndpoint : `http://${rawEndpoint}`;
const useSsl = endpointUrl.startsWith("https://");

const accessKeyId =
  process.env.S3_ACCESS_KEY_ID ||
  process.env.MINIO_ROOT_USER ||
  (process.env.NODE_ENV !== "production"
    ? "minioadmin"
    : (() => {
      throw new Error("S3_ACCESS_KEY_ID must be set in production");
    })());

const secretAccessKey =
  process.env.S3_SECRET_ACCESS_KEY ||
  process.env.MINIO_ROOT_PASSWORD ||
  (process.env.NODE_ENV !== "production"
    ? "minioadmin"
    : (() => {
      throw new Error("S3_SECRET_ACCESS_KEY must be set in production");
    })());

const s3Config = {
  endpoint: endpointUrl,
  s3ForcePathStyle: true,
  signatureVersion: "v4",
  sslEnabled: useSsl,
  accessKeyId,
  secretAccessKey,
  region: process.env.AWS_REGION || "us-east-1",
};

export const s3Client = new S3(s3Config);

export const BUCKET_NAME =
  process.env.S3_BUCKET || process.env.MINIO_BUCKET || "retrosync-saves";

export async function uploadFile(
  key: string,
  body: Buffer | string,
  contentType?: string
): Promise<S3.ManagedUpload.SendData> {
  return s3Client
    .upload({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: body,
      ContentType: contentType || "application/octet-stream",
    })
    .promise();
}

export async function downloadFile(key: string): Promise<Buffer> {
  const data = await s3Client.getObject({ Bucket: BUCKET_NAME, Key: key }).promise();
  return data.Body as Buffer;
}

export async function listFiles(prefix: string): Promise<S3.ObjectList> {
  const data = await s3Client.listObjectsV2({ Bucket: BUCKET_NAME, Prefix: prefix }).promise();
  return data.Contents || [];
}

export async function deleteFile(key: string): Promise<void> {
  await s3Client.deleteObject({ Bucket: BUCKET_NAME, Key: key }).promise();
}

export function getPresignedUrl(key: string, expiresIn: number = 3600): string {
  return s3Client.getSignedUrl("getObject", {
    Bucket: BUCKET_NAME,
    Key: key,
    Expires: expiresIn,
  });
}

export function getPresignedUploadUrl(key: string, expiresIn: number = 3600): string {
  return s3Client.getSignedUrl("putObject", {
    Bucket: BUCKET_NAME,
    Key: key,
    Expires: expiresIn,
  });
}

export async function fileExists(key: string): Promise<boolean> {
  try {
    await s3Client.headObject({ Bucket: BUCKET_NAME, Key: key }).promise();
    return true;
  } catch {
    return false;
  }
}

export async function getFileMetadata(key: string): Promise<S3.HeadObjectOutput | null> {
  try {
    return await s3Client.headObject({ Bucket: BUCKET_NAME, Key: key }).promise();
  } catch {
    return null;
  }
}
