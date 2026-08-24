from PIL import Image, ImageDraw
import os

# Grab the variables from gen_frames.py
import gen_frames

colors = {
    '.': (0, 0, 0, 0),        # Transparent
    'D': (60, 42, 60, 255),   # Deep Plum/Brown (Outline)
    'I': (245, 240, 230, 255),# Warm Ivory/Cream (Body)
    'P': (250, 210, 200, 255),# Soft Peach (Ears)
    'A': (255, 180, 170, 255),# Peach (Cheeks)
    'K': (20, 20, 20, 255),   # Black (Eyes)
    'W': (255, 255, 255, 255) # White (Eye sparkles)
}

color_silhouette = {
    '.':(0,0,0,0),
    'D':(40,40,40,255),
    'I':(40,40,40,255),
    'P':(40,40,40,255),
    'A':(40,40,40,255),
    'K':(40,40,40,255),
    'W':(40,40,40,255),
}

def render_sprite(frame_string, filename, scale=1, outline_only=False):
    lines = [line.strip() for line in frame_string.split('\n') if line.strip()]
    if not lines:
        return
        
    width = len(lines[0])
    height = len(lines)
    
    img = Image.new('RGBA', (width * scale, height * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    colormap = color_silhouette if outline_only else colors
    
    for y, row in enumerate(lines):
        for x, char in enumerate(row):
            if char in colormap:
                c = colormap[char]
                if c[3] > 0:
                    d.rectangle(
                        [x*scale, y*scale, (x+1)*scale - 1, (y+1)*scale - 1],
                        fill=c
                    )
                    
    img.save(filename)

poses = ['idle', 'walk1', 'sniff', 'lift', 'sit']

if not os.path.exists('renders'):
    os.makedirs('renders')

for pose in poses:
    frame_data = gen_frames.frame_exports.get(pose, gen_frames.idle)
    
    # Full Color
    render_sprite(frame_data, f'renders/{pose}_48.png', scale=1)
    render_sprite(frame_data, f'renders/{pose}_80.png', scale=80//48)
    render_sprite(frame_data, f'renders/{pose}_160.png', scale=160//48)
    
    # Silhouette (Elephant Shape Test)
    render_sprite(frame_data, f'renders/{pose}_160_silhouette.png', scale=160//48, outline_only=True)

print("Rendered PNGs for validation")
