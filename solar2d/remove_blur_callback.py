#!/usr/bin/env python3
"""
Solar2D HTML5 Build - Post-Build Patcher
1. Removes the blur callback registration to prevent HTML5 builds from freezing when user clicks outside of the app.
2. Removes the alert() from printErr to prevent blocking popups on non-fatal WASM errors.
"""

import zipfile
import os
import sys
import shutil
import re
from pathlib import Path

line_length = 60

def remove_blur_callback(js_content):
    """
    Remove the blur callback registration from _emscripten_set_blur_callback function.
    Handles both old and new Solar2D versions (handling the old version is probably not needed).
    """
    # Pattern 1: Old version with JSEvents.registerFocusEventCallback
    pattern_old = r'(function _emscripten_set_blur_callback\([^)]*\)\{)JSEvents\.registerFocusEventCallback\([^)]*\);(return 0\})'

    # Pattern 2: New version with registerFocusEventCallback (no JSEvents prefix)
    pattern_new = r'(function _emscripten_set_blur_callback_on_thread\([^)]*\)\{)registerFocusEventCallback\([^)]*\);(return 0\})'

    modified_content = re.sub(pattern_old, r'\1\2', js_content)

    if modified_content != js_content:
        print("Successfully removed blur callback registration (old Solar2D format)")
        return modified_content, True

    modified_content = re.sub(pattern_new, r'\1\2', js_content)

    if modified_content != js_content:
        print("Successfully removed blur callback registration (new Solar2D format)")
        return modified_content, True

    print("Warning: Could not find the expected function pattern.")
    print("This file may already be modified or have a different structure.")
    return js_content, False


def process_bin_file(bin_path):
    """
    Process the .bin file (zip archive):
    1. Extract it
    2. Modify the .js file (same name as .bin)
    3. Re-zip it
    """
    bin_path = Path(bin_path)

    if not bin_path.exists():
        print(f"Error: File '{bin_path}' not found!")
        return False

    print(f"Processing: {bin_path}")

    temp_dir = bin_path.parent / f"{bin_path.stem}_temp"
    backup_path = bin_path.parent / f"{bin_path.name}.backup"

    try:
        print(f"Creating backup: {backup_path.name}")
        shutil.copy2(bin_path, backup_path)

        # .bin is a zip archive containing the JS app and WASM module
        print("Extracting files...")
        with zipfile.ZipFile(bin_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Find the .js file (same name as .bin file)
        js_filename = bin_path.stem + ".js"
        js_file = temp_dir / js_filename

        if not js_file.exists():
            print(f"Error: {js_filename} not found in the archive!")
            print("Looking for any .js files in the archive...")
            js_files = list(temp_dir.glob("*.js"))
            if js_files:
                print(f"Found: {[f.name for f in js_files]}")
                print(f"Expected: {js_filename}")
            return False

        print(f"Found: {js_file.name}")

        with open(js_file, 'r', encoding='utf-8') as f:
            js_content = f.read()

        print("Modifying blur callback function...")
        modified_content, was_modified = remove_blur_callback(js_content)

        if not was_modified:
            print("No modifications made. The file may already be modified.")
            user_input = input("Continue anyway? (y/n): ").strip().lower()
            if user_input != 'y':
                return False

        with open(js_file, 'w', encoding='utf-8') as f:
            f.write(modified_content)

        # Repack the archive with the patched JS file
        print("Re-creating archive...")
        with zipfile.ZipFile(bin_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(temp_dir)
                    zip_ref.write(file_path, arcname)

        print(f"Successfully processed {bin_path.name}")
        print(f"Backup saved as {backup_path.name} (kept for safety)")
        return True

    except Exception as e:
        print(f"Error: {e}")
        return False

    finally:
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
            print("Cleaned up temporary files")


def patch_index_html(bin_dir):
    """
    Patch bin/index.html to remove alert() from printErr.
    The Solar2D-generated printErr calls alert() for any error containing 'ERROR',
    which blocks the UI thread and can cause cascading WASM crashes.
    """
    index_path = bin_dir / "index.html"

    if not index_path.exists():
        print(f"Warning: {index_path} not found, skipping printErr patch")
        return False

    with open(index_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the alert() call from printErr, keeping the console.error
    pattern = r'''if\(\s*typeof\(text\)\s*===\s*"string"\s*&&\s*text\.toUpperCase\(\)\.indexOf\("ERROR"\)\s*>=\s*0\)\s*alert\(text\);'''

    modified = re.sub(pattern, '// alert removed: blocking alert() on errors causes WASM crashes and freezes the UI', content)

    if modified != content:
        with open(index_path, 'w', encoding='utf-8') as f:
            f.write(modified)
        print("Removed alert() from printErr in index.html")
        return True
    else:
        print("Note: printErr alert pattern not found in index.html (may already be patched)")
        return False


def find_bin_in_folder():
    """
    Auto-detect .bin file in the 'bin' folder relative to this script.
    Returns the path if exactly one .bin file is found, otherwise None.
    """
    script_dir = Path(__file__).parent
    bin_dir = script_dir / "bin"

    if not bin_dir.exists():
        return None

    bin_files = list(bin_dir.glob("*.bin"))

    if len(bin_files) == 0:
        print(f"Error: No .bin files found in '{bin_dir}'")
        return None
    elif len(bin_files) > 1:
        print(f"Error: Multiple .bin files found in '{bin_dir}':")
        for f in bin_files:
            print(f"  - {f.name}")
        print("Please specify which file to process.")
        return None

    return bin_files[0]


def main():
    print("=" * line_length)
    print("Solar2D HTML5 - Post-Build Patcher")
    print("Patches blur callback + printErr alert")
    print("=" * line_length)
    print()

    bin_path = None

    if len(sys.argv) > 1:
        bin_path = sys.argv[1]
    else:
        user_input = input("Enter the path to your .bin file (or press Enter to auto-detect): ").strip()

        if user_input:
            bin_path = user_input
        else:
            print("Auto-detecting .bin file in 'bin' folder...")
            bin_path = find_bin_in_folder()
            if not bin_path:
                return
            print(f"Found: {bin_path}")

    # Clean up the path (handle VS Code/PowerShell drag-and-drop artifacts)
    if isinstance(bin_path, str):
        # VS Code adds "& '" at the beginning when drag-dropping
        if bin_path.startswith("& '") or bin_path.startswith('& "'):
            bin_path = bin_path[2:].strip()

        # Remove quotes if present (from drag and drop)
        bin_path = bin_path.strip('"').strip("'")

    if not bin_path:
        print("Error: No file path provided!")
        return

    bin_success = process_bin_file(bin_path)

    print()
    print("-" * line_length)
    print("Patching index.html...")
    bin_dir = Path(bin_path).parent
    html_success = patch_index_html(bin_dir)

    print()
    print("=" * line_length)

    if bin_success and html_success:
        print("SUCCESS! Your HTML5 build has been modified.")
        print("- Blur callback removed (no freeze on click outside)")
        print("- printErr alert removed (no blocking popups on errors)")
        print()
        print("Note: A .backup file has been kept for safety.")
        print("You can delete it once you've confirmed it works.")
    elif bin_success:
        print("Blur callback removed successfully.")
        print("Note: index.html printErr patch was skipped (see above).")
    else:
        print("Process completed with warnings or errors.")
        print("Please check the messages above.")

    print("=" * line_length)
    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()