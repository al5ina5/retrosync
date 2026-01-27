"""
S3 client for RetroSync file storage
"""
import boto3
from botocore.exceptions import ClientError
from pathlib import Path
from typing import Optional, List, Dict, Any
import logging
import hashlib
import json
from datetime import datetime

logger = logging.getLogger(__name__)


class S3Client:
    """Client for S3-compatible storage (MinIO)"""

    def __init__(self, config: Dict[str, str], user_id: str, device_id: str):
        """
        Initialize S3 client

        Args:
            config: S3 configuration with endpoint, accessKeyId, secretAccessKey, bucket
            user_id: User ID for organizing files
            device_id: Device ID for organizing files
        """
        self.config = config
        self.user_id = user_id
        self.device_id = device_id
        self.bucket = config["bucket"]

        self.client = boto3.client(
            "s3",
            endpoint_url=config["endpoint"],
            aws_access_key_id=config["accessKeyId"],
            aws_secret_access_key=config["secretAccessKey"],
        )

    def _get_s3_key(self, emulator: str, game_id: str, filename: str) -> str:
        """
        Generate S3 key for file

        Format: {user_id}/{device_id}/{emulator}/{game_id}/{filename}
        """
        return f"{self.user_id}/{self.device_id}/{emulator}/{game_id}/{filename}"

    def _get_metadata_key(self, emulator: str, game_id: str) -> str:
        """
        Generate S3 key for metadata file

        Format: {user_id}/{device_id}/{emulator}/{game_id}/metadata.json
        """
        return self._get_s3_key(emulator, game_id, "metadata.json")

    def upload_file(
        self,
        local_path: str,
        emulator: str,
        game_id: str,
        filename: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Upload a file to S3

        Args:
            local_path: Path to local file
            emulator: Emulator type
            game_id: Game identifier
            filename: Optional custom filename (default: use local filename)

        Returns:
            Upload metadata
        """
        path = Path(local_path)

        if not path.exists():
            raise FileNotFoundError(f"File not found: {local_path}")

        if not filename:
            filename = path.name

        # Calculate file hash
        file_hash = self._calculate_hash(local_path)
        file_size = path.stat().st_size

        # Generate S3 key
        s3_key = self._get_s3_key(emulator, game_id, filename)

        try:
            # Upload file
            self.client.upload_file(
                local_path,
                self.bucket,
                s3_key,
                ExtraArgs={"Metadata": {"hash": file_hash}},
            )

            # Update metadata
            metadata = {
                "filename": filename,
                "emulator": emulator,
                "game_id": game_id,
                "device_id": self.device_id,
                "file_size": file_size,
                "hash": file_hash,
                "uploaded_at": datetime.utcnow().isoformat(),
            }

            metadata_key = self._get_metadata_key(emulator, game_id)
            self.client.put_object(
                Bucket=self.bucket,
                Key=metadata_key,
                Body=json.dumps(metadata),
                ContentType="application/json",
            )

            logger.info(f"Uploaded {filename} to {s3_key}")

            return {
                "s3_key": s3_key,
                "file_size": file_size,
                "hash": file_hash,
            }

        except ClientError as e:
            logger.error(f"Failed to upload {filename}: {e}")
            raise

    def download_file(
        self, emulator: str, game_id: str, filename: str, local_path: str
    ) -> Dict[str, Any]:
        """
        Download a file from S3

        Args:
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename to download
            local_path: Local path to save file

        Returns:
            Download metadata
        """
        s3_key = self._get_s3_key(emulator, game_id, filename)

        try:
            # Create parent directory if it doesn't exist
            Path(local_path).parent.mkdir(parents=True, exist_ok=True)

            # Download file
            self.client.download_file(self.bucket, s3_key, local_path)

            # Get file metadata
            response = self.client.head_object(Bucket=self.bucket, Key=s3_key)

            logger.info(f"Downloaded {filename} from {s3_key}")

            return {
                "s3_key": s3_key,
                "file_size": response["ContentLength"],
                "last_modified": response["LastModified"],
            }

        except ClientError as e:
            if e.response["Error"]["Code"] == "404":
                logger.error(f"File not found: {s3_key}")
            else:
                logger.error(f"Failed to download {filename}: {e}")
            raise

    def list_files(
        self, emulator: Optional[str] = None, game_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        List files in S3

        Args:
            emulator: Filter by emulator type
            game_id: Filter by game identifier

        Returns:
            List of file metadata
        """
        prefix = f"{self.user_id}/"

        if emulator and game_id:
            prefix += f"{self.device_id}/{emulator}/{game_id}/"
        elif emulator:
            prefix += f"{self.device_id}/{emulator}/"

        try:
            response = self.client.list_objects_v2(
                Bucket=self.bucket, Prefix=prefix
            )

            files = []
            for obj in response.get("Contents", []):
                # Skip metadata files
                if obj["Key"].endswith("metadata.json"):
                    continue

                files.append({
                    "key": obj["Key"],
                    "size": obj["Size"],
                    "last_modified": obj["LastModified"],
                })

            return files

        except ClientError as e:
            logger.error(f"Failed to list files: {e}")
            raise

    def file_exists(self, emulator: str, game_id: str, filename: str) -> bool:
        """
        Check if a file exists in S3

        Args:
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename to check

        Returns:
            True if file exists, False otherwise
        """
        s3_key = self._get_s3_key(emulator, game_id, filename)

        try:
            self.client.head_object(Bucket=self.bucket, Key=s3_key)
            return True
        except ClientError:
            return False

    def get_file_metadata(
        self, emulator: str, game_id: str, filename: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get metadata for a file

        Args:
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename

        Returns:
            File metadata or None if not found
        """
        s3_key = self._get_s3_key(emulator, game_id, filename)

        try:
            response = self.client.head_object(Bucket=self.bucket, Key=s3_key)

            return {
                "size": response["ContentLength"],
                "last_modified": response["LastModified"],
                "hash": response.get("Metadata", {}).get("hash"),
            }

        except ClientError:
            return None

    def _calculate_hash(self, file_path: str) -> str:
        """Calculate SHA256 hash of a file"""
        sha256_hash = hashlib.sha256()

        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)

        return sha256_hash.hexdigest()

    def should_upload(self, local_path: str, emulator: str, game_id: str) -> bool:
        """
        Check if a file should be uploaded (has changed)

        Args:
            local_path: Path to local file
            emulator: Emulator type
            game_id: Game identifier

        Returns:
            True if file should be uploaded, False otherwise
        """
        if not Path(local_path).exists():
            return False

        filename = Path(local_path).name
        remote_metadata = self.get_file_metadata(emulator, game_id, filename)

        if not remote_metadata:
            # File doesn't exist remotely, should upload
            return True

        # Compare file hashes
        local_hash = self._calculate_hash(local_path)
        remote_hash = remote_metadata.get("hash")

        return local_hash != remote_hash
