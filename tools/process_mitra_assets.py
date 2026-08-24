import os
import sys
import argparse
from pathlib import Path

# Note: In a production environment, you might use 'rembg' (U2NET) or an advanced alpha matting library
# to cleanly extract backgrounds from generated art without haloing.
# Since the Canoncial Master asset is already locked and we are explicitly instructed NOT to 
# run background removal on it, this script serves as the pipeline for future generated assets.

try:
    from PIL import Image, ImageOps
except ImportError:
    print("Error: PIL is not installed. Run `pip install Pillow`")
    sys.exit(1)

def process_asset(input_path, output_path, remove_bg=False, target_size=None):
    """
    Process an asset to be canonical production-ready.
    - remove_bg: Stubbed/optional background removal logic.
    - target_size: Optional tuple (width, height) to resize while preserving aspect ratio.
    """
    print(f"Processing: {input_path}")
    
    if not os.path.exists(input_path):
        print(f"Error: {input_path} does not exist.")
        return False

    try:
        img = Image.open(input_path).convert("RGBA")
    except Exception as e:
        print(f"Error opening image: {e}")
        return False

    if remove_bg:
        print("  -> Extracting background (Placeholder for advanced alpha matting pipeline)")
        # Future: implement rembg or custom matting here to remove solid background colors.
        # This is strictly bypassed for the canonical master image.

    # 1. Clean Bounding Box (Removing excessive transparent padding)
    print("  -> Cropping to bounding box")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    # 2. Consistent Base Alignment (Grounding)
    # We add 2px of transparent padding at the bottom to ensure the soft shadow/footing 
    # doesn't clip directly at the frame edge in Flutter renderers.
    print("  -> Applying baseline padding")
    new_width = img.width + 10
    new_height = img.height + 10
    
    padded_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    # Paste centered horizontally, but bottom-aligned with a small 2px margin at the bottom
    paste_x = (new_width - img.width) // 2
    paste_y = new_height - img.height - 2
    padded_img.paste(img, (paste_x, paste_y))

    # 3. Optional Resize
    if target_size:
        print(f"  -> Resizing to {target_size}")
        # Use high-quality downsampling
        padded_img.thumbnail(target_size, Image.Resampling.LANCZOS)

    # 4. Export WebP/PNG
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    
    try:
        if output_path.lower().endswith(".webp"):
            padded_img.save(output_path, "WEBP", quality=95, method=6)
        else:
            padded_img.save(output_path, "PNG", optimize=True)
        print(f"  [SUCCESS] Saved to {output_path}")
        return True
    except Exception as e:
        print(f"Error saving image: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Mitra Asset Processing Pipeline")
    parser.add_argument("--input", required=True, help="Path to input image")
    parser.add_argument("--output", required=True, help="Path to output image (.png or .webp)")
    parser.add_argument("--extract-bg", action="store_true", help="Run background extraction (DO NOT use on Canonical Master)")
    parser.add_argument("--size", type=int, help="Optional max resolution size (e.g. 1024)")
    
    args = parser.parse_args()
    
    target_size = (args.size, args.size) if args.size else None
    process_asset(args.input, args.output, args.extract_bg, target_size)

if __name__ == "__main__":
    main()
