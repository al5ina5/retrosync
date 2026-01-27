"""
On-device UI for RetroSync
"""
import sys
from typing import Optional


class DeviceUI:
    """Simple text-based UI for handheld devices"""

    @staticmethod
    def clear_screen():
        """Clear the screen"""
        print("\033[2J\033[H", end="")

    @staticmethod
    def print_header(title: str):
        """Print a header"""
        width = 50
        print("=" * width)
        print(title.center(width))
        print("=" * width)

    @staticmethod
    def show_pairing_screen(code: str, api_url: str):
        """
        Display pairing code screen

        Args:
            code: 6-digit pairing code
            api_url: API URL for web dashboard
        """
        DeviceUI.clear_screen()
        DeviceUI.print_header("RetroSync - Device Pairing")
        print()
        print("To connect this device to RetroSync:")
        print()
        print("1. Open your web browser and go to:")
        print(f"   {api_url}")
        print()
        print("2. Login or create an account")
        print()
        print("3. Click 'Add Device' and enter this code:")
        print()
        print("   " + "┌" + "─" * 10 + "┐")
        print(f"   │  {code}  │")
        print("   " + "└" + "─" * 10 + "┘")
        print()
        print("This code expires in 15 minutes.")
        print()
        print("Waiting for pairing...")
        print()

    @staticmethod
    def show_status(
        device_name: str,
        status: str,
        last_sync: Optional[str] = None,
        files_synced: int = 0,
    ):
        """
        Display device status

        Args:
            device_name: Name of the device
            status: Current status (e.g., "Running", "Paused", "Error")
            last_sync: Timestamp of last sync
            files_synced: Number of files synced
        """
        DeviceUI.clear_screen()
        DeviceUI.print_header("RetroSync")
        print()
        print(f"Device: {device_name}")
        print(f"Status: {status}")
        print()
        if last_sync:
            print(f"Last Sync: {last_sync}")
        print(f"Files Synced: {files_synced}")
        print()
        print("Press Ctrl+C to stop")
        print()

    @staticmethod
    def show_error(error_msg: str):
        """
        Display error message

        Args:
            error_msg: Error message to display
        """
        DeviceUI.clear_screen()
        DeviceUI.print_header("RetroSync - Error")
        print()
        print("ERROR:")
        print(error_msg)
        print()
        print("Press any key to exit...")
        print()

    @staticmethod
    def show_success(message: str):
        """
        Display success message

        Args:
            message: Success message to display
        """
        DeviceUI.clear_screen()
        DeviceUI.print_header("RetroSync - Success")
        print()
        print(message)
        print()

    @staticmethod
    def prompt_input(prompt: str) -> str:
        """
        Prompt for user input

        Args:
            prompt: Prompt message

        Returns:
            User input
        """
        return input(f"{prompt}: ").strip()

    @staticmethod
    def prompt_yes_no(prompt: str, default: bool = True) -> bool:
        """
        Prompt for yes/no input

        Args:
            prompt: Prompt message
            default: Default value if user just presses Enter

        Returns:
            True for yes, False for no
        """
        default_str = "Y/n" if default else "y/N"
        response = input(f"{prompt} [{default_str}]: ").strip().lower()

        if not response:
            return default

        return response in ["y", "yes"]

    @staticmethod
    def show_menu(title: str, options: list) -> int:
        """
        Display a menu and get user selection

        Args:
            title: Menu title
            options: List of menu options

        Returns:
            Selected option index (0-based)
        """
        DeviceUI.clear_screen()
        DeviceUI.print_header(title)
        print()

        for i, option in enumerate(options, 1):
            print(f"{i}. {option}")

        print()

        while True:
            try:
                choice = int(input("Enter your choice: "))
                if 1 <= choice <= len(options):
                    return choice - 1
                else:
                    print("Invalid choice. Please try again.")
            except ValueError:
                print("Invalid input. Please enter a number.")

    @staticmethod
    def show_watch_paths(paths: list):
        """
        Display list of paths being watched

        Args:
            paths: List of paths
        """
        print()
        print("Watching for save files in:")
        if not paths:
            print("  (no paths configured)")
        else:
            for path in paths:
                print(f"  - {path}")
        print()
