"""
File watcher for monitoring save file changes
"""
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileSystemEvent
from pathlib import Path
from typing import Callable, List
import logging
import time

logger = logging.getLogger(__name__)


class SaveFileHandler(FileSystemEventHandler):
    """Handler for save file changes"""

    # Common save file extensions
    SAVE_EXTENSIONS = {
        ".srm",  # SNES/Genesis saves
        ".sav",  # General save files
        ".state",  # Save states
        ".st",  # Save states (alternative)
        ".eep",  # EEPROM saves
        ".fla",  # Flash saves
        ".mpk",  # N64 controller pak
        ".rtc",  # Real-time clock saves
        ".dss",  # DeSmuME save states
        ".dsv",  # DeSmuME saves
        ".sps",  # PCSX2 save states
        ".gci",  # GameCube saves
        ".raw",  # Memory card raw
    }

    def __init__(self, on_change: Callable[[str], None]):
        """
        Initialize save file handler

        Args:
            on_change: Callback function called when a save file changes
        """
        super().__init__()
        self.on_change = on_change
        self.debounce_time = 2  # seconds
        self.last_modified = {}

    def _is_save_file(self, path: str) -> bool:
        """Check if file is a save file based on extension"""
        return Path(path).suffix.lower() in self.SAVE_EXTENSIONS

    def _should_process(self, path: str) -> bool:
        """Check if file should be processed (debounce)"""
        now = time.time()
        last_time = self.last_modified.get(path, 0)

        if now - last_time < self.debounce_time:
            return False

        self.last_modified[path] = now
        return True

    def on_modified(self, event: FileSystemEvent):
        """Handle file modification"""
        if event.is_directory:
            return

        path = event.src_path

        if self._is_save_file(path) and self._should_process(path):
            logger.info(f"Save file modified: {path}")
            try:
                self.on_change(path)
            except Exception as e:
                logger.error(f"Error processing file change: {e}")

    def on_created(self, event: FileSystemEvent):
        """Handle file creation"""
        if event.is_directory:
            return

        path = event.src_path

        if self._is_save_file(path):
            logger.info(f"Save file created: {path}")
            # Wait a moment for file to be written completely
            time.sleep(0.5)
            try:
                self.on_change(path)
            except Exception as e:
                logger.error(f"Error processing file creation: {e}")


class FileWatcher:
    """File system watcher for save files"""

    def __init__(self, on_change: Callable[[str], None]):
        """
        Initialize file watcher

        Args:
            on_change: Callback function called when a save file changes
        """
        self.on_change = on_change
        self.observer = Observer()
        self.watched_paths = set()
        self.handler = SaveFileHandler(on_change)

    def add_path(self, path: str):
        """
        Add a path to watch

        Args:
            path: Path to watch for save file changes
        """
        if path in self.watched_paths:
            logger.debug(f"Path already being watched: {path}")
            return

        if not Path(path).exists():
            logger.warning(f"Path does not exist: {path}")
            return

        try:
            self.observer.schedule(self.handler, path, recursive=True)
            self.watched_paths.add(path)
            logger.info(f"Now watching: {path}")
        except Exception as e:
            logger.error(f"Failed to watch path {path}: {e}")

    def remove_path(self, path: str):
        """
        Remove a path from watch list

        Args:
            path: Path to stop watching
        """
        if path not in self.watched_paths:
            return

        # Note: watchdog doesn't have a direct way to unschedule a specific path
        # In practice, you would need to stop and restart the observer
        self.watched_paths.discard(path)
        logger.info(f"Stopped watching: {path}")

    def start(self):
        """Start watching for file changes"""
        if not self.watched_paths:
            logger.warning("No paths to watch")
            return

        self.observer.start()
        logger.info(f"File watcher started, watching {len(self.watched_paths)} paths")

    def stop(self):
        """Stop watching for file changes"""
        self.observer.stop()
        self.observer.join()
        logger.info("File watcher stopped")

    def is_running(self) -> bool:
        """Check if watcher is running"""
        return self.observer.is_alive()
