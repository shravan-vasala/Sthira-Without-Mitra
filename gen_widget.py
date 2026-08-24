import os

frames = {
    'icon': '''........................
........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBKBBBBBBBS..
.....SBBBBBBKWWKBBBBBS..
.....SBBBBBBKWKBBEEEBS..
.....SBBBBAABBBBEEEEEBS.
.....SBBBBBBBBBBEEEEEBS.
....SSBBBBBBBBBBEEEEEBS.
...SBBTSSBBBBBBBEEEEBBS.
...SBBB..SSBBBBBBBEBBS..
....SS....SBBBBBBBBBS...
..........SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBBB..BBBBBBS
........SBBBBBS..SBBBBBS
.......SSBBSSS....SSBBSS
........SSSS........SSSS''',

    'active': '''........................
........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBBS..
.....SBBBBBBKKKKBBBBBS..
.....SBBBBBBBBBBBEEEBS..
.....SBBBBAABBBBEEEEEBS.
.....SBBBBBBBBBBEEEEEBS.
....SSBBBBBBBBBBEEEEEBS.
...SBBTSSBBBBBBBEEEEBBS.
...SBBB..SSBBBBBBBEBBS..
....SS....SBBBBBBBBBS...
..........SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBBB..BBBBBBS
........SBBBBBS..SBBBBBS
.......SSBBSSS....SSBBSS
........SSSS........SSSS''',

    'walking': '''........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBKBBBBBBBS..
.....SBBBBBBKWWKBBBBBS..
.....SBBBBBBKWKBBEEEBS..
.....SBBBBAABBBBEEEEEBS.
.....SBBBBBBBBBBEEEEEBS.
....SSBBBBBBBBBBEEEEEBS.
...SBBTSSBBBBBBBEEEEBBS.
...SBBB..SSBBBBBBBEBBS..
....SS....SBBBBBBBBBS...
..........SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBBB..BBBBBBS
........SBBBBSS...SBBBBS
.......SSBBSS.....SBBBBS
........SSSS.....SSBSSS.
........................''',

    'encouraging': '''........................
........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBKBBBBBBBS..
.....SBBBBBBKWWKBBBBBS..
.....SBBBBBBKWKBBEEEBS..
.....SBBBBAABBBBEEEEEBS.
.....SBBBBBBBBBBEEEEEBS.
....SSBBBBBBBBBBEEEEEBS.
...SBBTSSBBBBBBBEEEEBBS.
....SBBB.SSBBBBBBBEBBS..
....SS....SBBBBBBBBBS...
..........SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBB...SBBBBBS
........SBBBBBS..SBBBBBS
.......SSBBSSS....SSBBSS
........SSSS........SSSS''',

    'celebrate': '''........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....SBBBBBBBBBBBBBBS...
....SBBBBBBBKBBBBBBBS...
....SBBBBBBKWWKBBBBBS...
....SBBBBBBKWKBBEEEBS...
...SSBBBBBBAABBBBEEEEEBS
.....SBBBBBBBBBBBEEEEEBS
......SSBBBBBBBBBEEEEEBS
.......SBBTSSBBBBEEEEBBS
.......SBBB..SBBBBBEBBS.
......SS......SBBBBBBBS.
..............SBBBBBBBS.
.............SBBBBBBBBBS
.............SBBBBBBBBBS
............SSBBBBBBBBBS
............SBBBBBB..BBS
............SBBBBBS..BBS
...........SSBBSSS...SSS
............SSSS........
........................
........................'''
}

colors = {
  'B': '#E29B65', # primary
  'S': '#C57A42', # primaryDark
  'L': '#EDBA94', # primaryLight
  'E': '#FFB6C1', # Soft Peach
  'W': '#FFFFFF', # White
  'K': '#1E293B', # Charcoal
  'A': '#F4A3A8', # Warm Peach Cheek
  'T': '#FDF5E6'  # Tusk bud
}

target_dir = r"android\app\src\main\res\drawable"

for name, frame_str in frames.items():
    paths = {c: [] for c in colors}
    lines = frame_str.split('\n')
    for y, line in enumerate(lines):
        line = line.strip()
        for x, char in enumerate(line):
            if char in paths:
                # Add a 1x1 block path
                paths[char].append(f"M {x} {y} h 1 v 1 h -1 v -1 Z")
    
    xml = ['<?xml version="1.0" encoding="utf-8"?>']
    xml.append('<vector xmlns:android="http://schemas.android.com/apk/res/android"\n    android:width="24dp"\n    android:height="24dp"\n    android:viewportWidth="24"\n    android:viewportHeight="24">')
    
    for c, blocks in paths.items():
        if blocks:
            path_data = " ".join(blocks)
            xml.append(f'  <path android:fillColor="{colors[c]}" android:pathData="{path_data}" />')
            
    xml.append('</vector>')
    
    file_path = os.path.join(target_dir, f"mitra_widget_{name}.xml")
    with open(file_path, "w") as f:
        f.write("\n".join(xml))

print("XML generated successfully.")
