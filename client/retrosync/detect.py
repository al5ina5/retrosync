"""
OS and device detection for RetroSync
"""
import os
import platform
from pathlib import Path
from typing import Tuple, List


def detect_os() -> str:
    """
    Detect operating system and device type

    Returns:
        Device type: 'rg35xx', 'miyoo_flip', 'windows', 'mac', 'linux', or 'other'
    """
    system = platform.system().lower()

    # Check for muOS (Anbernic RG35XX+)
    if os.path.exists("/mnt/mmc/MUOS"):
        return "rg35xx"

    # Check for Spruce OS (Miyoo Flip)
    if os.path.exists("/mnt/SDCARD/Saves"):
        return "miyoo_flip"

    # Standard desktop OS
    if system == "windows":
        return "windows"
    elif system == "darwin":
        return "mac"
    elif system == "linux":
        return "linux"

    return "other"


def get_default_save_paths(device_type: str) -> List[str]:
    """
    Get default save file paths for the detected device

    Args:
        device_type: Device type from detect_os()

    Returns:
        List of paths to watch for save files
    """
    home = Path.home()
    paths = []

    if device_type == "rg35xx":
        # muOS save paths
        paths.extend([
            "/mnt/mmc/MUOS/save",
            "/mnt/mmc/MUOS/saves",
        ])

    elif device_type == "miyoo_flip":
        # Spruce OS save paths
        paths.extend([
            "/mnt/SDCARD/Saves",
            "/mnt/SDCARD/RetroArch/.retroarch/saves",
        ])

    elif device_type == "windows":
        # Windows RetroArch and emulator paths
        appdata = Path(os.environ.get("APPDATA", home / "AppData/Roaming"))
        paths.extend([
            str(appdata / "RetroArch" / "saves"),
            str(home / "Documents" / "RetroArch" / "saves"),
        ])

    elif device_type == "mac":
        # macOS RetroArch and emulator paths
        paths.extend([
            str(home / "Library" / "Application Support" / "RetroArch" / "saves"),
            str(home / "Documents" / "RetroArch" / "saves"),
        ])

    elif device_type == "linux":
        # Linux RetroArch and emulator paths
        paths.extend([
            str(home / ".config" / "retroarch" / "saves"),
            str(home / ".local" / "share" / "retroarch" / "saves"),
        ])

    # Filter to only existing paths
    return [p for p in paths if os.path.exists(p)]


def get_device_name(device_type: str) -> str:
    """
    Get a friendly device name

    Args:
        device_type: Device type from detect_os()

    Returns:
        Friendly device name
    """
    hostname = platform.node() or "Unknown"

    name_map = {
        "rg35xx": f"Anbernic RG35XX+ ({hostname})",
        "miyoo_flip": f"Miyoo Flip ({hostname})",
        "windows": f"Windows PC ({hostname})",
        "mac": f"Mac ({hostname})",
        "linux": f"Linux ({hostname})",
        "other": f"Device ({hostname})",
    }

    return name_map.get(device_type, f"Device ({hostname})")


def detect_emulator_from_path(file_path: str) -> Tuple[str, str]:
    """
    Detect emulator type and game ID from file path

    Args:
        file_path: Full path to save file

    Returns:
        Tuple of (emulator_type, game_identifier)
    """
    path = Path(file_path)
    filename = path.stem
    parent = path.parent.name

    # Common save file extensions and their emulators
    ext_map = {
        ".srm": "retroarch",
        ".sav": "retroarch",
        ".state": "retroarch",
        ".st": "retroarch",
        ".eep": "retroarch",
        ".fla": "retroarch",
        ".mpk": "retroarch",
        ".rtc": "retroarch",
    }

    emulator = ext_map.get(path.suffix.lower(), "unknown")

    # Try to extract game name
    # For RetroArch: typically game_name.srm
    # For standalone emulators: might be in subdirectory
    game_id = filename

    return emulator, game_id


def auto_configure() -> dict:
    """
    Auto-detect device and configure default settings

    Returns:
        Dictionary with detected configuration
    """
    device_type = detect_os()
    device_name = get_device_name(device_type)
    watch_paths = get_default_save_paths(device_type)

    return {
        "device_type": device_type,
        "device_name": device_name,
        "watch_paths": watch_paths,
    }
