"""
API client for RetroSync backend
"""
import requests
from typing import Optional, Dict, Any, List
import logging

logger = logging.getLogger(__name__)


class APIClient:
    """Client for RetroSync API"""

    def __init__(self, api_url: str, api_key: Optional[str] = None):
        self.api_url = api_url.rstrip("/")
        self.api_key = api_key
        self.session = requests.Session()

        if api_key:
            self.session.headers.update({"X-API-Key": api_key})

    def _make_request(
        self, method: str, endpoint: str, **kwargs
    ) -> Dict[str, Any]:
        """Make HTTP request to API"""
        url = f"{self.api_url}{endpoint}"

        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"API request failed: {e}")
            raise

    def pair_device(
        self, code: str, device_name: str, device_type: str
    ) -> Dict[str, Any]:
        """
        Pair device using pairing code

        Args:
            code: 6-digit pairing code
            device_name: Name of the device
            device_type: Type of device (rg35xx, miyoo_flip, etc.)

        Returns:
            Device credentials including API key and S3 config
        """
        response = self._make_request(
            "POST",
            "/api/devices/pair",
            json={
                "code": code,
                "deviceName": device_name,
                "deviceType": device_type,
            },
        )

        if not response.get("success"):
            raise Exception(response.get("error", "Pairing failed"))

        return response["data"]

    def heartbeat(self) -> Dict[str, Any]:
        """
        Send heartbeat to server

        Returns:
            Heartbeat response
        """
        response = self._make_request("POST", "/api/sync/heartbeat")

        if not response.get("success"):
            raise Exception(response.get("error", "Heartbeat failed"))

        return response["data"]

    def list_files(
        self, emulator: Optional[str] = None, game: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        List available save files

        Args:
            emulator: Filter by emulator type
            game: Filter by game identifier

        Returns:
            List of file metadata
        """
        params = {}
        if emulator:
            params["emulator"] = emulator
        if game:
            params["game"] = game

        response = self._make_request("GET", "/api/sync/files", params=params)

        if not response.get("success"):
            raise Exception(response.get("error", "Failed to list files"))

        return response["data"]["files"]

    def log_sync_event(
        self,
        action: str,
        file_path: str,
        file_size: Optional[int] = None,
        status: str = "success",
        error_msg: Optional[str] = None,
        metadata: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Log a sync event

        Args:
            action: Action type (upload, download, delete, conflict)
            file_path: Path to the file
            file_size: Size of the file in bytes
            status: Status of the sync (success, failed, pending)
            error_msg: Error message if failed
            metadata: Additional metadata as JSON string

        Returns:
            Log entry confirmation
        """
        response = self._make_request(
            "POST",
            "/api/sync/log",
            json={
                "action": action,
                "filePath": file_path,
                "fileSize": file_size,
                "status": status,
                "errorMsg": error_msg,
                "metadata": metadata,
            },
        )

        if not response.get("success"):
            raise Exception(response.get("error", "Failed to log sync event"))

        return response["data"]

    def get_sync_logs(
        self, device_id: Optional[str] = None, limit: int = 50, offset: int = 0
    ) -> Dict[str, Any]:
        """
        Get sync logs

        Args:
            device_id: Filter by device ID
            limit: Maximum number of logs to return
            offset: Offset for pagination

        Returns:
            Sync logs and pagination info
        """
        params = {"limit": limit, "offset": offset}
        if device_id:
            params["deviceId"] = device_id

        response = self._make_request("GET", "/api/sync/log", params=params)

        if not response.get("success"):
            raise Exception(response.get("error", "Failed to get sync logs"))

        return response["data"]
