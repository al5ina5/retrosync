"""
RetroSync daemon - main client process
"""
import sys
import time
import logging
import signal
from datetime import datetime
from typing import Optional

from .config import Config
from .api_client import APIClient
from .s3_client import S3Client
from .sync_engine import SyncEngine
from .watcher import FileWatcher
from .ui import DeviceUI

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)


class RetroSyncDaemon:
    """Main daemon process for RetroSync client"""

    def __init__(self, config_dir: Optional[str] = None):
        """
        Initialize daemon

        Args:
            config_dir: Optional custom config directory
        """
        self.config = Config(config_dir)
        self.running = False
        self.api_client: Optional[APIClient] = None
        self.s3_client: Optional[S3Client] = None
        self.sync_engine: Optional[SyncEngine] = None
        self.watcher: Optional[FileWatcher] = None
        self.files_synced = 0

        # Set up signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info("Received shutdown signal")
        self.stop()

    def initialize(self) -> bool:
        """
        Initialize daemon with configuration

        Returns:
            True if initialization successful, False otherwise
        """
        if not self.config.is_configured:
            logger.error("Client is not configured. Run setup first.")
            return False

        try:
            # Initialize API client
            self.api_client = APIClient(
                self.config.api_url,
                self.config.api_key,
            )

            # Initialize S3 client
            s3_config = self.config.s3_config
            if not s3_config:
                logger.error("S3 configuration not found")
                return False

            # Get user ID from device ID (stored during pairing)
            user_id = self.config.get("user_id")
            if not user_id:
                logger.error("User ID not found in configuration")
                return False

            self.s3_client = S3Client(
                s3_config,
                user_id,
                self.config.device_id,
            )

            # Initialize sync engine
            self.sync_engine = SyncEngine(
                self.s3_client,
                self.api_client,
                self.config.device_id,
                self.config.watch_paths,
            )

            # Initialize file watcher
            self.watcher = FileWatcher(self._on_file_change)

            # Add watch paths
            for path in self.config.watch_paths:
                self.watcher.add_path(path)

            logger.info("Daemon initialized successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to initialize daemon: {e}")
            return False

    def _on_file_change(self, file_path: str):
        """
        Handle file change event

        Args:
            file_path: Path to changed file
        """
        logger.info(f"File changed: {file_path}")

        if self.sync_engine:
            if self.sync_engine.upload_file(file_path):
                self.files_synced += 1

    def start(self):
        """Start the daemon"""
        if not self.initialize():
            logger.error("Failed to start daemon")
            return

        self.running = True
        logger.info("RetroSync daemon starting...")

        # Show status
        DeviceUI.show_status(
            device_name=self.config.device_name or "Unknown Device",
            status="Starting...",
            files_synced=self.files_synced,
        )

        # Perform initial sync
        if self.sync_engine:
            logger.info("Performing initial sync...")
            self.sync_engine.initial_sync()

        # Start file watcher
        if self.watcher:
            self.watcher.start()

        # Main loop
        last_heartbeat = 0
        last_sync_from_cloud = 0
        heartbeat_interval = 60  # 1 minute
        sync_interval = 300  # 5 minutes

        try:
            while self.running:
                now = time.time()

                # Send heartbeat
                if now - last_heartbeat >= heartbeat_interval:
                    try:
                        if self.api_client:
                            self.api_client.heartbeat()
                        last_heartbeat = now
                    except Exception as e:
                        logger.error(f"Heartbeat failed: {e}")

                # Sync from cloud
                if now - last_sync_from_cloud >= sync_interval:
                    try:
                        if self.sync_engine:
                            self.sync_engine.sync_from_cloud()
                        last_sync_from_cloud = now
                    except Exception as e:
                        logger.error(f"Sync from cloud failed: {e}")

                # Update status display
                DeviceUI.show_status(
                    device_name=self.config.device_name or "Unknown Device",
                    status="Running",
                    last_sync=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    files_synced=self.files_synced,
                )

                # Sleep for a bit
                time.sleep(5)

        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
        finally:
            self.stop()

    def stop(self):
        """Stop the daemon"""
        if not self.running:
            return

        logger.info("Stopping RetroSync daemon...")
        self.running = False

        # Stop file watcher
        if self.watcher and self.watcher.is_running():
            self.watcher.stop()

        logger.info("RetroSync daemon stopped")
        sys.exit(0)


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="RetroSync daemon")
    parser.add_argument(
        "--config-dir",
        help="Custom configuration directory",
        default=None,
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=["start", "setup", "status"],
        default="start",
        help="Command to run",
    )

    args = parser.parse_args()

    if args.command == "setup":
        from .scripts.setup_wizard import run_setup
        run_setup(args.config_dir)
    elif args.command == "status":
        config = Config(args.config_dir)
        if config.is_configured:
            print(f"Device: {config.device_name}")
            print(f"Device ID: {config.device_id}")
            print(f"API URL: {config.api_url}")
            print(f"Watch Paths: {', '.join(config.watch_paths)}")
        else:
            print("Client is not configured. Run 'retrosync setup' first.")
    else:
        daemon = RetroSyncDaemon(args.config_dir)
        daemon.start()


if __name__ == "__main__":
    main()
