"""
Sync engine for uploading and downloading save files
"""
from pathlib import Path
from typing import Optional, Dict, Any
import logging
import time
from datetime import datetime

from .s3_client import S3Client
from .api_client import APIClient
from .detect import detect_emulator_from_path

logger = logging.getLogger(__name__)


class SyncEngine:
    """Handles file synchronization between local and cloud"""

    def __init__(
        self,
        s3_client: S3Client,
        api_client: APIClient,
        device_id: str,
        watch_paths: list,
    ):
        """
        Initialize sync engine

        Args:
            s3_client: S3 client for file operations
            api_client: API client for logging
            device_id: Device ID
            watch_paths: List of paths being watched
        """
        self.s3_client = s3_client
        self.api_client = api_client
        self.device_id = device_id
        self.watch_paths = watch_paths
        self.last_sync_time = {}

    def upload_file(self, file_path: str) -> bool:
        """
        Upload a save file to cloud

        Args:
            file_path: Path to the file to upload

        Returns:
            True if upload successful, False otherwise
        """
        try:
            path = Path(file_path)

            if not path.exists():
                logger.warning(f"File does not exist: {file_path}")
                return False

            # Detect emulator and game from path
            emulator, game_id = detect_emulator_from_path(file_path)

            logger.info(f"Uploading {path.name} (emulator: {emulator}, game: {game_id})")

            # Check if file should be uploaded (has changed)
            if not self.s3_client.should_upload(file_path, emulator, game_id):
                logger.info(f"File {path.name} hasn't changed, skipping upload")
                return True

            # Upload file
            upload_result = self.s3_client.upload_file(
                file_path, emulator, game_id
            )

            # Log sync event
            self.api_client.log_sync_event(
                action="upload",
                file_path=file_path,
                file_size=upload_result["file_size"],
                status="success",
            )

            logger.info(f"Successfully uploaded {path.name}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload {file_path}: {e}")

            # Log failure
            try:
                self.api_client.log_sync_event(
                    action="upload",
                    file_path=file_path,
                    status="failed",
                    error_msg=str(e),
                )
            except Exception as log_error:
                logger.error(f"Failed to log upload failure: {log_error}")

            return False

    def download_file(
        self, emulator: str, game_id: str, filename: str, local_path: str
    ) -> bool:
        """
        Download a save file from cloud

        Args:
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename to download
            local_path: Local path to save file

        Returns:
            True if download successful, False otherwise
        """
        try:
            logger.info(f"Downloading {filename} (emulator: {emulator}, game: {game_id})")

            # Check if local file exists and compare
            path = Path(local_path)
            if path.exists():
                # Get remote metadata
                remote_metadata = self.s3_client.get_file_metadata(
                    emulator, game_id, filename
                )

                if remote_metadata:
                    # Compare modification times
                    local_mtime = datetime.fromtimestamp(path.stat().st_mtime)
                    remote_mtime = remote_metadata["last_modified"].replace(tzinfo=None)

                    if local_mtime >= remote_mtime:
                        logger.info(f"Local file {filename} is up to date, skipping download")
                        return True

                    # Backup local file before overwriting
                    backup_path = path.with_suffix(path.suffix + ".backup")
                    path.rename(backup_path)
                    logger.info(f"Backed up local file to {backup_path}")

            # Download file
            download_result = self.s3_client.download_file(
                emulator, game_id, filename, local_path
            )

            # Log sync event
            self.api_client.log_sync_event(
                action="download",
                file_path=local_path,
                file_size=download_result["file_size"],
                status="success",
            )

            logger.info(f"Successfully downloaded {filename}")
            return True

        except Exception as e:
            logger.error(f"Failed to download {filename}: {e}")

            # Log failure
            try:
                self.api_client.log_sync_event(
                    action="download",
                    file_path=local_path,
                    status="failed",
                    error_msg=str(e),
                )
            except Exception as log_error:
                logger.error(f"Failed to log download failure: {log_error}")

            return False

    def sync_from_cloud(self):
        """
        Download newer files from cloud

        Checks for files in cloud that are newer than local copies
        and downloads them.
        """
        try:
            logger.info("Checking for updates from cloud...")

            # List all files in cloud
            files = self.s3_client.list_files()

            downloads = 0
            for file_info in files:
                key = file_info["key"]
                parts = key.split("/")

                if len(parts) < 5:
                    continue

                # Parse S3 key: user_id/device_id/emulator/game_id/filename
                user_id, cloud_device_id, emulator, game_id, filename = parts[:5]

                # Skip files from this device
                if cloud_device_id == self.device_id:
                    continue

                # Find matching local path
                local_path = self._find_local_path(emulator, game_id, filename)

                if local_path:
                    if self.download_file(emulator, game_id, filename, local_path):
                        downloads += 1

            if downloads > 0:
                logger.info(f"Downloaded {downloads} files from cloud")
            else:
                logger.info("No updates found in cloud")

        except Exception as e:
            logger.error(f"Failed to sync from cloud: {e}")

    def _find_local_path(
        self, emulator: str, game_id: str, filename: str
    ) -> Optional[str]:
        """
        Find local path for a file based on emulator and game

        Args:
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename

        Returns:
            Local path or None if not found
        """
        # Search in watch paths for matching file structure
        for watch_path in self.watch_paths:
            path = Path(watch_path)

            # Try direct match
            target = path / filename
            if target.parent.exists():
                return str(target)

            # Try with game subdirectory
            target = path / game_id / filename
            if target.parent.exists():
                return str(target)

        # Default to first watch path
        if self.watch_paths:
            return str(Path(self.watch_paths[0]) / filename)

        return None

    def handle_conflict(
        self, local_path: str, emulator: str, game_id: str, filename: str
    ):
        """
        Handle sync conflict (last-write-wins)

        Args:
            local_path: Path to local file
            emulator: Emulator type
            game_id: Game identifier
            filename: Filename
        """
        try:
            path = Path(local_path)

            if not path.exists():
                return

            # Get remote metadata
            remote_metadata = self.s3_client.get_file_metadata(
                emulator, game_id, filename
            )

            if not remote_metadata:
                # No remote file, upload local
                self.upload_file(local_path)
                return

            # Compare modification times
            local_mtime = datetime.fromtimestamp(path.stat().st_mtime)
            remote_mtime = remote_metadata["last_modified"].replace(tzinfo=None)

            if local_mtime > remote_mtime:
                # Local is newer, upload
                logger.info(f"Conflict: Local file is newer, uploading {filename}")
                self.upload_file(local_path)
            else:
                # Remote is newer, download
                logger.info(f"Conflict: Remote file is newer, downloading {filename}")
                self.download_file(emulator, game_id, filename, local_path)

            # Log conflict
            self.api_client.log_sync_event(
                action="conflict",
                file_path=local_path,
                status="success",
                metadata=f"Resolved using last-write-wins (local: {local_mtime}, remote: {remote_mtime})",
            )

        except Exception as e:
            logger.error(f"Failed to handle conflict for {filename}: {e}")

    def initial_sync(self):
        """
        Perform initial sync of all existing save files

        Scans watch paths for existing save files and uploads them
        """
        try:
            logger.info("Performing initial sync...")

            uploads = 0
            for watch_path in self.watch_paths:
                path = Path(watch_path)

                if not path.exists():
                    continue

                # Find all save files recursively
                for file_path in path.rglob("*"):
                    if file_path.is_file() and self._is_save_file(str(file_path)):
                        if self.upload_file(str(file_path)):
                            uploads += 1

            logger.info(f"Initial sync complete: uploaded {uploads} files")

        except Exception as e:
            logger.error(f"Failed to perform initial sync: {e}")

    def _is_save_file(self, file_path: str) -> bool:
        """Check if file is a save file based on extension"""
        SAVE_EXTENSIONS = {
            ".srm", ".sav", ".state", ".st", ".eep", ".fla",
            ".mpk", ".rtc", ".dss", ".dsv", ".sps", ".gci", ".raw",
        }
        return Path(file_path).suffix.lower() in SAVE_EXTENSIONS
