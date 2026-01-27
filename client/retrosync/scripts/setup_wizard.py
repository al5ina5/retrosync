"""
Setup wizard for RetroSync client
"""
import sys
import time
from pathlib import Path

from ..config import Config
from ..api_client import APIClient
from ..detect import auto_configure
from ..ui import DeviceUI


def run_setup(config_dir: str = None):
    """
    Run the setup wizard

    Args:
        config_dir: Optional custom config directory
    """
    config = Config(config_dir)
    ui = DeviceUI()

    ui.clear_screen()
    ui.print_header("RetroSync Setup Wizard")
    print()
    print("Welcome to RetroSync!")
    print()
    print("This wizard will help you set up your device for")
    print("automatic save file syncing.")
    print()
    input("Press Enter to continue...")

    # Auto-detect device configuration
    print()
    print("Detecting device configuration...")
    auto_config = auto_configure()

    device_type = auto_config["device_type"]
    device_name = auto_config["device_name"]
    watch_paths = auto_config["watch_paths"]

    print(f"Detected: {device_name} ({device_type})")
    print()

    # Show detected watch paths
    if watch_paths:
        print("Found the following save file locations:")
        for path in watch_paths:
            print(f"  - {path}")
        print()
    else:
        print("No save file locations were automatically detected.")
        print("You'll need to add them manually later.")
        print()

    # Ask if user wants to customize
    if ui.prompt_yes_no("Use these settings?", default=True):
        pass
    else:
        # Allow customization
        device_name = ui.prompt_input("Enter device name") or device_name

        if ui.prompt_yes_no("Add custom watch paths?", default=False):
            while True:
                path = ui.prompt_input("Enter path (or blank to finish)")
                if not path:
                    break
                if Path(path).exists():
                    watch_paths.append(path)
                    print(f"Added: {path}")
                else:
                    print(f"Warning: Path does not exist: {path}")

    # Get API URL
    print()
    api_url = ui.prompt_input("Enter API URL [http://localhost:3000]")
    if not api_url:
        api_url = "http://localhost:3000"

    # Pairing process
    print()
    ui.print_header("Device Pairing")
    print()
    print("You have two options to pair this device:")
    print()
    print("1. Generate pairing code on this device (recommended)")
    print("2. Enter pairing code from web dashboard")
    print()

    choice = ui.show_menu(
        "Pairing Method",
        [
            "Generate code on this device",
            "Enter code from web dashboard",
        ]
    )

    api_client = APIClient(api_url)

    if choice == 0:
        # Generate pairing code on device
        pairing_code = _generate_and_wait_for_pairing(
            ui, api_client, device_name, device_type
        )
    else:
        # Enter pairing code
        pairing_code = _enter_pairing_code(ui)

    if not pairing_code:
        print()
        print("Setup cancelled.")
        return

    # Pair device
    print()
    print("Pairing device...")

    try:
        result = api_client.pair_device(pairing_code, device_name, device_type)

        device_id = result["device"]["id"]
        api_key = result["apiKey"]
        s3_config = result["s3Config"]
        user_id = result["userId"]

        # Save configuration
        config.update({
            "device_id": device_id,
            "device_name": device_name,
            "device_type": device_type,
            "api_url": api_url,
            "api_key": api_key,
            "s3_config": s3_config,
            "watch_paths": watch_paths,
            "user_id": user_id,  # This should come from the API
        })

        ui.show_success(
            f"Device paired successfully!\n\n"
            f"Device: {device_name}\n"
            f"Device ID: {device_id}\n\n"
            f"You can now start the RetroSync daemon:\n"
            f"  retrosync start"
        )

        print()
        input("Press Enter to exit...")

    except Exception as e:
        ui.show_error(f"Failed to pair device: {e}")
        print()
        input("Press Enter to exit...")


def _generate_and_wait_for_pairing(
    ui: DeviceUI,
    api_client: APIClient,
    device_name: str,
    device_type: str
) -> str:
    """
    Generate pairing code and wait for user to pair via web dashboard

    Note: This requires API endpoints that we haven't implemented yet
    for device-initiated pairing. For now, we'll use the manual entry method.

    Args:
        ui: Device UI
        api_client: API client
        device_name: Device name
        device_type: Device type

    Returns:
        Pairing code
    """
    # For MVP, we'll use manual entry
    # In the future, implement device-initiated pairing
    print()
    print("Note: Device-initiated pairing requires additional API support.")
    print("Please use the web dashboard to generate a pairing code.")
    print()
    return _enter_pairing_code(ui)


def _enter_pairing_code(ui: DeviceUI) -> str:
    """
    Prompt user to enter pairing code

    Args:
        ui: Device UI

    Returns:
        Pairing code
    """
    print()
    print("To get a pairing code:")
    print("1. Open the web dashboard in your browser")
    print("2. Login or create an account")
    print("3. Click 'Add Device' to generate a pairing code")
    print()

    while True:
        code = ui.prompt_input("Enter 6-digit pairing code (or 'q' to quit)")

        if code.lower() == "q":
            return ""

        if len(code) == 6 and code.isdigit():
            return code

        print("Invalid code. Please enter a 6-digit number.")


if __name__ == "__main__":
    run_setup()
