import os
from PIL import Image

def process_mitra_assets():
    source_dir = r"C:\Users\sande\OneDrive\Desktop\trufit-another\trufit-bodamma-another-copy\tmp_design\Mitra_reference\Mitra"
    target_dir = r"C:\Users\sande\OneDrive\Desktop\trufit-another\trufit-bodamma-another-copy\assets\mitra"

    os.makedirs(target_dir, exist_ok=True)

    max_size = 600

    # Specifically rename mappings for clean flutter use
    mappings = {
        'Mitra-Master.png': 'mitra_idle.png',
        'Mitra-Curious.png': 'mitra_curious.png',
        'Mitra-Walk-A.png': 'mitra_walk_a.png',
        'Mitra-Walk-b.png': 'mitra_walk_b.png',
        'Mitra-Walk-c.png': 'mitra_walk_c.png',
        'Mitra-Walk-D.png': 'mitra_walk_d.png',
        'Mitra-Sitting.png': 'mitra_sit.png',
        'Mitra-Running.png': 'mitra_run.png',
        'Mitra-Sleeping.png': 'mitra_sleep.png',
        'Mitra-Sunflower-happy.png': 'mitra_happy.png',
        'Mitra-Dancing.png': 'mitra_dance.png',
        'sunflower.png': 'sunflower_full.png'
    }

    for src_name, dst_name in mappings.items():
        src_path = os.path.join(source_dir, src_name)
        dst_path = os.path.join(target_dir, dst_name)
        
        if not os.path.exists(src_path):
            print(f"Skipping {src_name}, not found.")
            continue

        try:
            with Image.open(src_path) as img:
                # Maintain alpha channel
                if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
                    img = img.convert('RGBA')
                else:
                    img = img.convert('RGBA') # force rgba anyway

                width, height = img.size
                if width > max_size or height > max_size:
                    img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
                
                img.save(dst_path, "PNG", optimize=True)
                print(f"Processed {src_name} -> {dst_name} ({img.size[0]}x{img.size[1]})")
        except Exception as e:
            print(f"Failed {src_name}: {e}")

if __name__ == '__main__':
    process_mitra_assets()
