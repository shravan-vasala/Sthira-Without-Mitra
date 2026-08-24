import math

def generate_frame(state):
    w, h = 48, 48
    grid = [['.' for _ in range(w)] for _ in range(h)]
    
    def fill_ellipse(cx, cy, rx, ry, char_fill, char_outline=None):
        for y in range(h):
            for x in range(w):
                dx = (x - cx) / rx
                dy = (y - cy) / ry
                dist = dx*dx + dy*dy
                if dist <= 1.0:
                    if char_outline and dist > 0.70:
                        if grid[y][x] == '.': # only draw outline if nothing else is above it
                            grid[y][x] = char_outline
                    else:
                        grid[y][x] = char_fill

    def fill_circle(cx, cy, r, char_fill, char_outline=None):
        fill_ellipse(cx, cy, r, r, char_fill, char_outline)

    def line(x0, y0, x1, y1, char):
        length = int(math.hypot(x1 - x0, y1 - y0) * 1.5)
        for i in range(length + 1):
            t = i / max(1, length)
            x = int(x0 + t * (x1 - x0))
            y = int(y0 + t * (y1 - y0))
            if 0 <= x < w and 0 <= y < h:
                grid[y][x] = char

    # Base offsets
    head_y = 0
    head_x = 0
    body_y = 0
    ear_dx = 0
    ear_rot = 0
    eyes_style = 'normal'
    trunk_style = 'normal'
    leg_style = 'stand'
    
    # State mapping overrides
    if state == 'idle1':
        trunk_style = 'curl_small'
    elif state == 'idle2':
        trunk_style = 'curl_sway'
    elif state == 'blink':
        eyes_style = 'blink'
        trunk_style = 'curl_small'
    elif state == 'curious':
        head_x = 1
        head_y = 1
        ear_rot = -2 # tilt ear up
        eyes_style = 'curious'
        trunk_style = 'point_forward'
    elif state.startswith('happy'):
        ear_rot = -1 
        if state == 'happy2':
            body_y = -1
            head_y = -2
            ear_dx = 1
        eyes_style = 'happy'
        trunk_style = 'curl_up'
    elif state.startswith('excited'):
        ear_rot = -2 
        if state == 'excited1':
            body_y = -1
            head_y = -1
            leg_style = 'stand'
        else:
            body_y = -2
            head_y = -3
            ear_dx = 2
            leg_style = 'stand'
        eyes_style = 'happy'
        trunk_style = 'lift_high'
    elif state.startswith('celebrating'):
        ear_rot = -2 
        if state == 'celebrating1':
            body_y = -1
            head_y = -1
            leg_style = 'jump'
        else:
            body_y = -3
            head_y = -4
            ear_dx = 2
            leg_style = 'jump'
        eyes_style = 'happy'
        trunk_style = 'lift_high'
    elif state == 'proud':
        body_y = -1
        head_y = -2
        eyes_style = 'proud'
        trunk_style = 'curl_in'
    elif state.startswith('tired'):
        body_y = 1
        head_y = 2
        ear_rot = 1 
        eyes_style = 'tired'
        trunk_style = 'hang'
        if state == 'tired2': body_y = 2
    elif state.startswith('sleepy'):
        body_y = 1
        head_y = 3
        ear_rot = 2
        eyes_style = 'sleepy'
        trunk_style = 'hang'
        if state == 'sleepy2': head_y = 4
    elif state.startswith('sleep'):
        body_y = 2
        head_y = 4
        ear_rot = 3
        eyes_style = 'blink'
        trunk_style = 'curl_in'
        if state == 'sleep2': body_y = 1; head_y = 5;
    elif state.startswith('eat'):
        trunk_style = 'hold_food'
        if state == 'eat2': 
            head_y = 1
            trunk_style = 'eat_food'
            eyes_style = 'happy'
    elif state.startswith('encouraging'):
        eyes_style = 'happy'  # Gentle eye contact
        if state == 'encouraging1':
            trunk_style = 'wave_left'
        else:
            trunk_style = 'wave_right'
    elif state.startswith('drink'):
        trunk_style = 'hold_drink'
        if state == 'drink2':
            head_y = 1
            trunk_style = 'drink_water'
            eyes_style = 'happy'
    elif state.startswith('workout'):
        # Squat animation instead of dumbbell
        if state == 'workout1':
            body_y = 0
            head_y = 0
            trunk_style = 'curl_up'
            eyes_style = 'happy'
            leg_style = 'stand'
        if state == 'workout2':
            body_y = 2
            head_y = 2
            ear_rot = -1
            trunk_style = 'lift_high'
            eyes_style = 'proud'
            leg_style = 'squat'
    elif state.startswith('greeting'):
        trunk_style = 'wave_left'
        eyes_style = 'happy'
        if state == 'greeting2':
            trunk_style = 'wave_right'
    elif state.startswith('walk'):
        if state in ['walk1', 'walk3']:
            body_y = -1
            head_y = -1
            trunk_style = 'curl_sway'
        if state == 'walk1': leg_style = 'walk1'
        elif state == 'walk2': leg_style = 'walk2'
        elif state == 'walk3': leg_style = 'walk3'
        elif state == 'walk4': leg_style = 'walk4'

    # DRAWING SYSTEM #

    # 1. Tiny Tail (Back layer)
    # A small angled line extending from lower rear body
    if 'tail' not in state:
        tx, ty = 14, 38 + body_y
        line(tx, ty, tx - 3, ty + 2, 'T')

    # 2. Right Ear (Back layer)
    # Larger, softer ears. Center moves with head. rx=9, ry=11
    re_x = 36 - ear_dx + head_x
    re_y = 20 + head_y + ear_rot
    fill_ellipse(re_x, re_y, 9, 11, 'P', 'D')
    
    # 3. Left Ear (Back layer)
    le_y = 20 + head_y
    if state == 'curious': le_y += 1
    if state.startswith('tired'): le_y += 1
    if state.startswith('sleep'): le_y += 2
    if state.startswith('happy'): le_y -= 1
    if state.startswith('excited'): le_y -= 2
    fill_ellipse(12 + ear_dx + (head_x//2), le_y, 9, 11, 'P', 'D')

    # 4. Compact Body
    brx, bry = 9, 9
    if state == 'proud':
        brx = 8
        bry = 10
    fill_ellipse(24, 34 + body_y, brx, bry, 'I', 'T')

    # 5. Feet
    if leg_style == 'walk1':
        fill_circle(19, 43, 2, 'T', 'D')
        fill_circle(29, 42, 2, 'T', 'D')
    elif leg_style == 'walk2':
        fill_circle(20, 42, 2, 'T', 'D')
        fill_circle(28, 43, 2, 'T', 'D')
    elif leg_style == 'walk3':
        fill_circle(18, 43, 2, 'T', 'D')
        fill_circle(30, 42, 2, 'T', 'D')
    elif leg_style == 'walk4':
        fill_circle(19, 42, 2, 'T', 'D')
        fill_circle(29, 43, 2, 'T', 'D')
    elif leg_style == 'jump':
        fill_circle(19, 41+body_y, 2, 'T', 'D')
        fill_circle(29, 41+body_y, 2, 'T', 'D')
    elif leg_style == 'squat':
        fill_circle(17, 43, 2, 'T', 'D')
        fill_circle(31, 43, 2, 'T', 'D')
    else:
        # Default standing
        fy = 43 + (1 if 'tired' in state or 'sleep' in state else 0)
        if state == 'proud': fy -= 1
        fill_circle(19, fy, 2, 'T', 'D')
        fill_circle(29, fy, 2, 'T', 'D')

    # 6. Oversized Head
    fill_ellipse(24 + head_x, 19 + head_y, 13, 10, 'I', 'T')

    # 7. Subtle Peach Cheeks
    if 'sleep' not in state:
        fill_ellipse(16 + head_x, 21 + head_y, 2, 1, 'A')
        fill_ellipse(32 + head_x, 21 + head_y, 2, 1, 'A')

    # 8. Eyes mapping
    base_y = head_y
    base_x = head_x

    if eyes_style == 'blink':
        line(17+base_x, 19+base_y, 19+base_x, 19+base_y, 'K') 
        line(29+base_x, 19+base_y, 31+base_x, 19+base_y, 'K')
    elif eyes_style == 'tired':
        line(17+base_x, 19+base_y, 19+base_x, 19+base_y, 'K') 
        line(29+base_x, 19+base_y, 31+base_x, 19+base_y, 'K')
        grid[20+base_y][18+base_x] = 'K'
        grid[20+base_y][30+base_x] = 'K'
    elif eyes_style == 'sleepy':
        line(17+base_x, 20+base_y, 19+base_x, 20+base_y, 'K') 
        line(29+base_x, 20+base_y, 31+base_x, 20+base_y, 'K')
    elif eyes_style == 'happy':
        # Arcs ^ ^
        grid[19+base_y][17+base_x] = 'K'
        grid[18+base_y][18+base_x] = 'K'
        grid[19+base_y][19+base_x] = 'K'
        
        grid[19+base_y][29+base_x] = 'K'
        grid[18+base_y][30+base_x] = 'K'
        grid[19+base_y][31+base_x] = 'K'
    elif eyes_style == 'proud':
        # Slight squint / confident
        line(17+base_x, 18+base_y, 19+base_x, 19+base_y, 'K')
        line(29+base_x, 19+base_y, 31+base_x, 18+base_y, 'K')
        grid[20+base_y][18+base_x] = 'K'
        grid[20+base_y][30+base_x] = 'K'
    elif eyes_style == 'curious':
        grid[19+base_y][19+base_x] = 'K'
        grid[20+base_y][19+base_x] = 'K'
        grid[19+base_y][20+base_x] = 'W'
        grid[20+base_y][20+base_x] = 'K'
        
        grid[19+base_y][30+base_x] = 'K'
        grid[20+base_y][30+base_x] = 'K'
        grid[19+base_y][31+base_x] = 'W'
        grid[20+base_y][31+base_x] = 'K'
    else:
        # Normal Expressive Eyes
        grid[18+base_y][18+base_x] = 'K'
        grid[19+base_y][18+base_x] = 'K'
        grid[18+base_y][19+base_x] = 'W' 
        grid[19+base_y][19+base_x] = 'K'
        
        grid[18+base_y][29+base_x] = 'K'
        grid[19+base_y][29+base_x] = 'K'
        grid[18+base_y][30+base_x] = 'W'
        grid[19+base_y][30+base_x] = 'K'

    # 9. Short Curled Trunk
    # Trunk attaches slightly lower due to oversized head
    trunk_h = 6
    if trunk_style == 'hang' or trunk_style == 'curl_in' or trunk_style == 'curl_small': trunk_h = 4
    if trunk_style.startswith('lift'): trunk_h = 3
    if trunk_style == 'curl_up': trunk_h = 5
    if trunk_style == 'point_forward': trunk_h = 4
    
    for ty in range(trunk_h):
        y = 23 + head_y + ty
        tx_offset = 0
        if trunk_style == 'curl_sway': tx_offset = int(math.sin(ty * 0.4) * 1.0)
        elif trunk_style == 'curl_small': tx_offset = int(math.sin(ty * 0.6) * 1.0)
        elif trunk_style == 'curl': tx_offset = int(math.sin(ty * 0.6) * 1.5)
        elif trunk_style == 'curl_up': tx_offset = int(math.sin(ty * 0.7) * 2.0)
        elif trunk_style == 'hang': tx_offset = 0
        elif trunk_style == 'curl_in': tx_offset = -int(math.sin(ty * 0.8) * 1.0)
        elif trunk_style == 'point_forward': tx_offset = int(ty * 0.8)
        elif trunk_style == 'wave_left': tx_offset = -int(ty * 1.2)
        elif trunk_style == 'wave_right': tx_offset = int(ty * 1.2)
        
        x = 24 + head_x + tx_offset
        for tx in range(-1, 2):
            if 0 <= y < h and 0 <= x+tx < w:
                if tx == 0:
                    grid[y][x+tx] = 'I'
                else:
                    grid[y][x+tx] = 'T'
                    
    # Extensions for trunk wrapping or lifting
    if trunk_style.startswith('lift') or trunk_style == 'curl_up':
        # Curve UPWARD
        ly = 23 + head_y + trunk_h
        lx = 24 + head_x
        if trunk_style == 'curl_up': lx += 1
        grid[ly][lx] = 'I'; grid[ly][lx-1] = 'T'; grid[ly][lx+1] = 'T'
        grid[ly-1][lx+2] = 'I'; grid[ly-1][lx+1] = 'T'; grid[ly-1][lx+3] = 'T'
        if trunk_style == 'lift_high':
            grid[ly-2][lx+3] = 'I'; grid[ly-2][lx+2] = 'T'; grid[ly-2][lx+4] = 'T'

    if trunk_style == 'hold_food' or trunk_style == 'eat_food':
        fy = 23 + head_y + 5
        fx = 24 + head_x + int(math.sin(5 * 0.4) * 1.0)
        if trunk_style == 'eat_food':
           fy = 23 + head_y + 2
           fx = 24 + head_x
        fill_ellipse(fx, fy+2, 1, 1, 'F')
        
    if trunk_style == 'hold_drink' or trunk_style == 'drink_water':
        by = 23 + head_y + 5
        bx = 24 + head_x + int(math.sin(5 * 0.4) * 1.0)
        if trunk_style == 'drink_water':
           by = 23 + head_y + 2
           bx = 24 + head_x
        fill_ellipse(bx, by+2, 1, 1, 'B')

    rs = '    \'\'\'\n' + '\n'.join(''.join(r) for r in grid) + '\'\'\','
    return rs

print('// ignore_for_file: unused_element')
print('part of \'mitra_sprite.dart\';')
print('// GENERATED PIXEL ART FRAMES 48x48')
print('List<String> _parseFrame(String raw) => raw.replaceAll(\'\\n\', \'\').split(\'\');\n')

frames = [
    'idle1', 'idle2', 'blink', 'curious',
    'happy1', 'happy2', 
    'excited1', 'excited2',
    'proud', 
    'tired1', 'tired2', 
    'sleepy1', 'sleepy2', 'sleep1', 'sleep2',
    'eat1', 'eat2',
    'drink1', 'drink2',
    'workout1', 'workout2',
    'encouraging1', 'encouraging2',
    'celebrating1', 'celebrating2',
    'greeting1', 'greeting2',
    'walk1', 'walk2', 'walk3', 'walk4'
]

for f in frames:
    print(f'final _{f} = _parseFrame(')
    print(generate_frame(f))
    print(');')
    print('')
