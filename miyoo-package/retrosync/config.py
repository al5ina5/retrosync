"""
Configuration management for RetroSync client
"""
import json
import os
from pathlib import Path
from typing import Optional, Dict, Any


class Config:
    """Manages RetroSync configuration"""

    def __init__(self, config_dir: Optional[str] = None):
        if config_dir:
            self.config_dir = Path(config_dir)
        else:
            self.config_dir = Path.home() / ".retrosync"

        self.config_file = self.config_dir / "config.json"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.data = self._load()

    def _load(self) -> Dict[str, Any]:
        """Load configuration from file"""
        if self.config_file.exists():
            with open(self.config_file, "r") as f:
                return json.load(f)
        return {}

    def save(self):
        """Save configuration to file"""
        with open(self.config_file, "w") as f:
            json.dump(self.data, f, indent=2)

    def get(self, key: str, default: Any = None) -> Any:
        """Get a configuration value"""
        return self.data.get(key, default)

    def set(self, key: str, value: Any):
        """Set a configuration value"""
        self.data[key] = value
        self.save()

    def update(self, data: Dict[str, Any]):
        """Update multiple configuration values"""
        self.data.update(data)
        self.save()

    @property
    def is_configured(self) -> bool:
        """Check if client is configured"""
        return all(
            [
                self.get("device_id"),
                self.get("api_key"),
                self.get("s3_config"),
            ]
        )

    @property
    def device_id(self) -> Optional[str]:
        """Get device ID"""
        return self.get("device_id")

    @property
    def device_name(self) -> Optional[str]:
        """Get device name"""
        return self.get("device_name")

    @property
    def api_key(self) -> Optional[str]:
        """Get API key"""
        return self.get("api_key")

    @property
    def api_url(self) -> str:
        """Get API URL"""
        return self.get("api_url", "http://localhost:3000")

    @property
    def s3_config(self) -> Optional[Dict[str, str]]:
        """Get S3 configuration"""
        return self.get("s3_config")

    @property
    def watch_paths(self) -> list:
        """Get list of paths to watch"""
        return self.get("watch_paths", [])

    def add_watch_path(self, path: str):
        """Add a path to watch"""
        paths = self.watch_paths
        if path not in paths:
            paths.append(path)
            self.set("watch_paths", paths)

    def remove_watch_path(self, path: str):
        """Remove a path from watch list"""
        paths = self.watch_paths
        if path in paths:
            paths.remove(path)
            self.set("watch_paths", paths)
