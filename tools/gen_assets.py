#!/usr/bin/env python3
"""Generate all art + audio + 100 procedurally-built Tiled levels for Trap Runner.

Outputs:
  assets/images/tileset.png      - 32px tileset (loaded by flame_tiled via Flame.images)
  assets/tiles/level_NNN.tmx     - 100 levels (embedded tileset)
  assets/audio/*.wav             - SFX + music loop
  lib/data/level_data.dart       - generated level catalogue (titles + hints)

Solvability is guaranteed by construction: the critical path is a left->right
chain of platforms whose gaps are <= MAX_GAP tiles and whose climbs are
<= MAX_UP tiles, both within the player's jump reach. Hazards (patrolling
spikes, crushers, gate-walls) are layered on top and always have a passable
window, so every level is beatable.
"""
import os, struct, math, wave, random

ROOT = "/Users/amshashankk/StudioProjects/trap_runner"
TILES = os.path.join(ROOT, "assets", "tiles")
IMAGES = os.path.join(ROOT, "assets", "images")
AUDIO = os.path.join(ROOT, "assets", "audio")
DART = os.path.join(ROOT, "lib", "data", "level_data.dart")
for d in (TILES, IMAGES, AUDIO):
    os.makedirs(d, exist_ok=True)

TS = 32
W, H = 30, 17
LEVEL_COUNT = 100

# Jump reach (mirrors lib/game/config.dart). Keep these conservative.
MAX_GAP = 4   # horizontal tiles the player can clear
MAX_UP = 3    # vertical tiles the player can climb in one jump

# --------------------------------------------------------------------------
# Tileset image (gid = index+1).
# --------------------------------------------------------------------------
from PIL import Image, ImageDraw

COLS = 4
TILE_DEFS = ["grass_top", "dirt", "stone_top", "stone_body",
             "wood", "brick", "grass_only", "ledge"]
ROWS = (len(TILE_DEFS) + COLS - 1) // COLS
img = Image.new("RGBA", (COLS * TS, ROWS * TS), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def rect(x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def draw_tile(i, name):
    x, y = (i % COLS) * TS, (i // COLS) * TS
    if name == "grass_top":
        rect(x, y, TS, TS, (108, 78, 52))
        rect(x, y, TS, 8, (86, 170, 72))
        rect(x, y + 8, TS, 2, (60, 120, 50))
        for gx in range(x + 2, x + TS, 6):
            rect(gx, y, 2, 5, (120, 200, 96))
    elif name == "dirt":
        rect(x, y, TS, TS, (108, 78, 52))
        for px in range(x + 4, x + TS, 9):
            rect(px, y + 10, 3, 3, (90, 62, 40))
            rect(px + 4, y + 22, 3, 3, (90, 62, 40))
    elif name == "stone_top":
        rect(x, y, TS, TS, (96, 100, 110)); rect(x, y, TS, 6, (140, 146, 158))
    elif name == "stone_body":
        rect(x, y, TS, TS, (96, 100, 110))
        rect(x, y + 15, TS, 2, (70, 74, 84)); rect(x + 15, y, 2, TS, (70, 74, 84))
    elif name == "wood":
        rect(x, y, TS, TS, (150, 104, 56)); rect(x, y, TS, 5, (176, 128, 74))
        rect(x, y + TS - 4, TS, 4, (120, 82, 44))
    elif name == "brick":
        rect(x, y, TS, TS, (150, 70, 60))
        for by in range(y, y + TS, 8):
            rect(x, by, TS, 1, (110, 48, 42))
    elif name == "grass_only":
        rect(x, y, TS, TS, (86, 170, 72)); rect(x, y + TS - 4, TS, 4, (60, 120, 50))
    elif name == "ledge":
        rect(x, y, TS, 10, (108, 78, 52)); rect(x, y, TS, 8, (86, 170, 72))


for i, n in enumerate(TILE_DEFS):
    draw_tile(i, n)
img.save(os.path.join(IMAGES, "tileset.png"))
print("tileset.png", img.size)


# --------------------------------------------------------------------------
# Level generation.
# --------------------------------------------------------------------------
def gen_level(idx):
    """Return (grid, objects). idx is 1-based."""
    rng = random.Random(7000 + idx)
    diff = (idx - 1) / (LEVEL_COUNT - 1)  # 0..1

    grid = [['.'] * W for _ in range(H)]
    objs = []  # each: {name,x,y,w,h,props}

    def solid(c, r):
        if 0 <= r < H and 0 <= c < W:
            grid[r][c] = '#'

    def segment(c0, c1, y, ground):
        for c in range(c0, c1 + 1):
            solid(c, y)
            if ground:
                for r in range(y + 1, H):
                    solid(c, r)
            else:
                solid(c, y + 1)  # 2-thick floating platform

    def add(name, c, r, wt=1, ht=1, **props):
        objs.append({'name': name, 'x': c * TS, 'y': r * TS,
                     'w': wt * TS, 'h': ht * TS, 'props': props})

    # Difficulty-scaled counts.
    maxgap = 2 + int(round(diff * (MAX_GAP - 2)))      # 2..4
    n_spikes = 1 + int(diff * 6)                        # 1..7
    n_crush = int(diff * 4)                             # 0..4
    n_gates = (1 if idx > 10 else 0) + int(diff * 2)    # 0..3
    n_movers = (1 if idx > 18 else 0) + int(diff * 1)   # 0..2
    n_walls = (1 if idx > 20 else 0) + int(diff * 1)    # 0..2 random walls

    # --- build the critical path of platform segments ---
    segs = []
    y = rng.randint(11, 13)
    seglen = rng.randint(3, 5)
    segment(0, seglen - 1, y, ground=True)
    segs.append([0, seglen - 1, y])
    add('spawn', 1, y - 1)
    x = seglen
    guard = 0
    while x < W - 5 and guard < 50:
        guard += 1
        climbing = rng.random() < 0.45
        if climbing:
            up = rng.randint(1, min(MAX_UP, max(1, y - 3)))
            ny = y - up
            gap = rng.randint(0, 2)  # smaller gap while climbing (reachable)
        else:
            ny = max(3, min(14, y + rng.randint(-1, 3)))
            gap = rng.randint(0, maxgap)
        nx = x + gap
        ground = ny >= 12
        # ground segments are longer so they can host gate-walls / random walls
        seglen = rng.randint(4, 8) if ground else rng.randint(2, 5)
        if nx + seglen > W - 1:
            seglen = (W - 1) - nx
        if seglen < 2:
            break
        segment(nx, nx + seglen - 1, ny, ground=ground)
        segs.append([nx, nx + seglen - 1, ny])
        x = nx + seglen
        y = ny
    if len(segs) < 2:
        segment(W - 5, W - 2, y, ground=True)
        segs.append([W - 5, W - 2, y])

    # exit on the last segment
    ec0, ec1, ey = segs[-1]
    add('exit', ec1, ey - 1)

    exit_seg = len(segs) - 1
    mid = list(range(1, exit_seg))  # segments eligible for hazards

    # --- patrolling spikes on segment tops ---
    for _ in range(n_spikes):
        if not mid:
            break
        si = rng.choice(mid)
        c0, c1, sy = segs[si]
        if c1 - c0 < 1:
            continue
        patrol = min(c1 - c0, 1 + int(diff * 3))
        add('spikes', c0, sy - 1, patrol=('int', patrol),
            phase=('float', round(rng.random(), 2)))

    # --- crushers above segments ---
    for _ in range(n_crush):
        if not mid:
            break
        si = rng.choice(mid)
        c0, c1, sy = segs[si]
        col = rng.randint(c0, c1)
        top = max(1, sy - 4)
        rng_tiles = sy - 1 - top
        if rng_tiles < 2:
            continue
        add('crusher', col, top, range=('int', rng_tiles),
            phase=('float', round(rng.random(), 2)))

    # --- gate-walls: split a long ground segment with a wall you must wait out ---
    used = set()
    gates_done = 0
    order = mid[:]
    rng.shuffle(order)
    for si in order:
        if gates_done >= n_gates:
            break
        c0, c1, sy = segs[si]
        if (c1 - c0) >= 5 and sy >= 11:  # long ground segment only
            gcol = (c0 + c1) // 2
            wall_h = 4 + int(diff)  # 4..5 tall -> taller than a jump
            for r in range(sy - 1, sy - 1 - wall_h, -1):
                add('gate', gcol, r)
            used.add(si)
            gates_done += 1

    # --- random walls: move/break a few times then settle open ---
    walls_done = 0
    for si in order:
        if walls_done >= n_walls:
            break
        if si in used:
            continue
        c0, c1, sy = segs[si]
        if (c1 - c0) >= 4 and sy >= 11:
            wcol = min(c0 + 2, c1)
            wh = 4
            add('wall', wcol, sy - wh, ht=wh,
                seed=('int', idx * 131 + wcol * 17 + sy))
            used.add(si)
            walls_done += 1

    # --- movers: a moving platform over a (jumpable) gap, for variety ---
    movers_done = 0
    for si in range(len(segs) - 1):
        if movers_done >= n_movers:
            break
        c0, c1, sy = segs[si]
        nc0, nc1, ny = segs[si + 1]
        gap = nc0 - c1 - 1
        if gap >= 2 and sy == ny and rng.random() < 0.6:
            axis = 'h' if rng.random() < 0.7 else 'v'
            add('mover', c1 + 1, sy, axis=('string', axis),
                range=('int', max(2, gap + 1)))
            movers_done += 1

    return grid, objs


def build_tmx(grid, objects):
    GRASS, DIRT = 1, 2
    data = []
    for y in range(H):
        for x in range(W):
            if grid[y][x] == '#':
                above = grid[y - 1][x] if y > 0 else '.'
                data.append(GRASS if above != '#' else DIRT)
            else:
                data.append(0)
    csv = ",".join(str(v) for v in data)

    oid = 1
    parts = []
    for o in objects:
        props = o['props']
        p = ""
        if props:
            p = "<properties>" + "".join(
                f'<property name="{k}" type="{t}" value="{v}"/>'
                for k, (t, v) in props.items()) + "</properties>"
        parts.append(
            f'<object id="{oid}" name="{o["name"]}" type="{o["name"]}" '
            f'x="{o["x"]}" y="{o["y"]}" width="{o["w"]}" height="{o["h"]}">{p}</object>')
        oid += 1

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="{W}" height="{H}" tilewidth="{TS}" tileheight="{TS}" infinite="0" nextlayerid="3" nextobjectid="{oid}">
 <tileset firstgid="1" name="tiles" tilewidth="{TS}" tileheight="{TS}" tilecount="{len(TILE_DEFS)}" columns="{COLS}">
  <image source="tileset.png" width="{COLS*TS}" height="{ROWS*TS}"/>
 </tileset>
 <layer id="1" name="Ground" width="{W}" height="{H}">
  <data encoding="csv">
{csv}
</data>
 </layer>
 <objectgroup id="2" name="Objects">
  {"".join(parts)}
 </objectgroup>
</map>
'''


# --------------------------------------------------------------------------
# Titles + hints for the catalogue.
# --------------------------------------------------------------------------
ADJ = ["First", "Quiet", "Narrow", "Broken", "Rising", "Hollow", "Bitter",
       "Cold", "Twin", "Sharp", "Hidden", "Silent", "Crooked", "Falling",
       "Iron", "Ashen", "Restless", "Gilded", "Sunken", "Final"]
NOUN = ["Steps", "Ledge", "Drop", "Gauntlet", "Crossing", "Climb", "Pit",
        "Span", "Run", "Gap", "Tangle", "Spire", "Hollow", "Reach", "Maze",
        "Descent", "Vault", "Gate", "Trap", "Room"]


def title(idx):
    rng = random.Random(99 + idx)
    if idx == 1:
        return "First Steps"
    if idx == LEVEL_COUNT:
        return "The Trap Room"
    return f"{rng.choice(ADJ)} {rng.choice(NOUN)}"


def hint(idx):
    if idx <= 15:
        return "Reach the green door. Time your jumps."
    if idx <= 40:
        return "Watch the traps' rhythm before you commit."
    if idx <= 70:
        return "Gates open and close — wait for your window."
    return "Everything moves. Read it, then run."


for i in range(1, LEVEL_COUNT + 1):
    grid, objs = gen_level(i)
    with open(os.path.join(TILES, f"level_{i:03d}.tmx"), "w") as f:
        f.write(build_tmx(grid, objs))
print(f"wrote {LEVEL_COUNT} levels")

with open(DART, "w") as f:
    f.write("// GENERATED by tools/gen_assets.py — do not edit by hand.\n")
    f.write("/// Static catalogue of procedurally-generated levels.\n")
    f.write("class LevelData {\n")
    f.write("  const LevelData(this.index, this.title, this.file, this.hint);\n\n")
    f.write("  final int index; // 0-based\n")
    f.write("  final String title;\n")
    f.write("  final String file;\n")
    f.write("  final String hint;\n\n")
    f.write("  int get number => index + 1;\n}\n\n")
    f.write("const List<LevelData> kLevels = [\n")
    for i in range(1, LEVEL_COUNT + 1):
        t = title(i).replace("'", "\\'")
        h = hint(i).replace("'", "\\'")
        f.write(f"  LevelData({i-1}, '{t}', 'level_{i:03d}.tmx', '{h}'),\n")
    f.write("];\n\n")
    f.write("int get kLevelCount => kLevels.length;\n")
print(f"wrote {DART}")


# --------------------------------------------------------------------------
# Audio (procedural 16-bit mono WAVs).
# --------------------------------------------------------------------------
RATE = 22050


def write_wav(name, samples):
    with wave.open(os.path.join(AUDIO, name), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def square(freq, t):
    return 1.0 if (t * freq) % 1.0 < 0.5 else -1.0


def tone(freq, dur, vol=0.5):
    n = int(RATE * dur)
    return [square(freq, i / RATE) * vol * (1 - i / n) for i in range(n)]


def sweep(f0, f1, dur, vol=0.5):
    n = int(RATE * dur); out = []; phase = 0.0
    for i in range(n):
        frac = i / n; f = f0 + (f1 - f0) * frac; phase += f / RATE
        out.append((1.0 if phase % 1.0 < 0.5 else -1.0) * vol * (1 - frac))
    return out


# Shared SFX
write_wav("land.wav", tone(140, 0.08, 0.4))
write_wav("click.wav", tone(660, 0.05, 0.35))

# Per-character SFX: jump / die / fall / win, each with a distinct voice.
# (index here must match kCharacters in lib/data/characters.dart)
CHAR_SFX = [
    dict(mult=1.00, scale=[523, 659, 784, 1047]),  # 0 Blip  (yellow)
    dict(mult=0.80, scale=[392, 494, 587, 784]),   # 1 Vox   (green, lower)
    dict(mult=1.28, scale=[659, 784, 988, 1319]),  # 2 Pixel (cyan, higher)
    dict(mult=1.06, scale=[466, 587, 698, 932]),   # 3 Zap   (pink, offbeat)
]
for ci, c in enumerate(CHAR_SFX):
    m = c['mult']
    write_wav(f"c{ci}_jump.wav", sweep(420 * m, 760 * m, 0.14, 0.45))
    write_wav(f"c{ci}_die.wav", sweep(500 * m, 90 * m, 0.42, 0.5))
    write_wav(f"c{ci}_fall.wav", sweep(720 * m, 120 * m, 0.6, 0.42))
    win = []
    for fr in c['scale']:
        win += tone(fr, 0.12, 0.45)
    write_wav(f"c{ci}_win.wav", win)

notes = {"C3": 130.81, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00,
         "C4": 261.63, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00,
         "C5": 523.25, "E5": 659.25, "-": 0.0}
melody = ["E4", "G4", "C5", "G4", "A4", "C5", "E5", "C5",
          "F4", "A4", "C5", "A4", "G4", "E4", "C4", "-"]
bass = ["C3", "C3", "G3", "G3", "A3", "A3", "F3", "F3",
        "F3", "F3", "C3", "C3", "G3", "G3", "C3", "C3"]
beat = 0.25
music = []
for i in range(len(melody)):
    mf = notes[melody[i]]; bf = notes[bass[i % len(bass)]]
    n = int(RATE * beat)
    for k in range(n):
        t = k / RATE
        env = min(1.0, (n - k) / (n * 0.3)) * 0.9
        lead = square(mf, t) * 0.18 if mf > 0 else 0.0
        b = square(bf, t) * 0.12 if bf > 0 else 0.0
        music.append((lead + b) * env)
write_wav("music.wav", music)
print("audio written\nDONE")
