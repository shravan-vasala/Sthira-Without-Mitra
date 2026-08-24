void main() {
  var frames = {
    'idle1': '''
........................
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

    'idle2': '''
........................
........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBKBBBBBBBS..
.....SBBBBBBKWWKBBBBBS..
.....SBBBBBBKWKBBBBBBB..
.....SBBBBAABBBBEEEBS...
.....SBBBBBBBBBBEEEEEBS.
....SSBBBBBBBBBBEEEEEBS.
...SBBTSSBBBBBBBEEEEEBS.
...SBBB..SSBBBBBBEEBBS..
....SS....SBBBBBBBBBS...
..........SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBBB..BBBBBBS
........SBBBBBS..SBBBBBS
.......SSBBSSS....SSBBSS
........SSSS........SSSS''',

    'blink': '''
........................
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

    'walk1': '''
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
........SBBBBSS...SBBBBS
.......SSBBSS.....SBBBBS
........SSSS.....SSBSSS.
........................''',

    'walk2': '''
........................
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

    'walk3': '''
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
...SBB....SBBBBBBBBBS...
....SS....SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBBB..BBBBBBS
........SBBBBBS...SBBBBS
.......SSBBSSS....SSBBSS
........SSSS.......SSSS.
........................''',

    'walk4': '''
........................
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
....SBB..SSBBBBBBBEBBS..
...SSB....SBBBBBBBBBS...
....SS....SBBBBBBBBBS..S
.........SBBBBBBBBBBBS.S
.........SBBBBBBBBBBBBSS
........SSBBBBBBBBBBBBSS
........SBBBBB..SBBBBBBS
........SBBBBBS.SBBBBSS.
.......SSBBSSS...SSBBSS.
........SSSS......SSSS..''',

    'happy2': '''
........................
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
........................''',
    
    'sleep1': '''
........................
........................
.........LLLLLL.........
.......LLBBBBBBLL.......
......LBBBBBBBBBBLL.....
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBS...
.....LBBBBBBBBBBBBBBBS..
.....SBBBBBBBBBBBBBBBS..
.....SBBBBBBBKBBEEEBS...
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
........SBBBBBB..SBBBBBS
........SBBBBS..SSBBBBS.
.......SSBBS....SSBBS...
........SSSS....SSSS....''',
  };

  frames.forEach((name, frame) {
    var lines = frame.split('\n');
    if (lines.length != 24) {
      print('\ has ' + lines.length.toString() + ' lines!');
    }
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].length != 24) {
        print('\, line \ has ' + lines[i].length.toString() + ' chars: ' + lines[i]);
      }
    }
  });
  print('Done checking.');
}
