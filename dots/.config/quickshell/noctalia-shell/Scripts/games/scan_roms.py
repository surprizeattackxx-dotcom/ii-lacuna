#!/usr/bin/env python3
import json, os, sys, glob, hashlib
from pathlib import Path

HOME = Path.home()
CONFIG = HOME / '.local' / 'state' / 'quickshell' / 'user' / 'game_roms.json'
LAUNCHERS = HOME / 'Emulation' / 'tools' / 'launchers'
RA_CORES = HOME / '.var' / 'app' / 'org.libretro.RetroArch' / 'config' / 'retroarch' / 'cores'
ART_CACHE = HOME / '.cache' / 'quickshell' / 'romart'

# folder name (lowercased) -> (display name, launch spec)
#   launch spec: ("ra", core)  -> RetroArch with a libretro core
#                ("std", launcher)  -> standalone EmuDeck launcher script
SYSTEMS = {
    'nes':         ('Nintendo NES',        ('ra', 'mesen')),
    'famicom':     ('Famicom',             ('ra', 'mesen')),
    'fc':          ('Famicom',             ('ra', 'mesen')),
    'snes':        ('Super Nintendo',      ('ra', 'snes9x')),
    'sfc':         ('Super Famicom',       ('ra', 'snes9x')),
    'n64':         ('Nintendo 64',         ('ra', 'mupen64plus_next')),
    'gb':          ('Game Boy',            ('ra', 'gambatte')),
    'gbc':         ('Game Boy Color',      ('ra', 'gambatte')),
    'gba':         ('Game Boy Advance',    ('ra', 'mgba')),
    'nds':         ('Nintendo DS',         ('std', 'melonds')),
    'n3ds':        ('Nintendo 3DS',        ('std', 'azahar')),
    '3ds':         ('Nintendo 3DS',        ('std', 'azahar')),
    'gc':          ('GameCube',            ('std', 'dolphin-emu')),
    'gamecube':    ('GameCube',            ('std', 'dolphin-emu')),
    'wii':         ('Nintendo Wii',        ('std', 'dolphin-emu')),
    'wiiu':        ('Wii U',               ('std', 'cemu')),
    'switch':      ('Nintendo Switch',     ('std', 'ryujinx')),
    'genesis':     ('Sega Genesis',        ('ra', 'genesis_plus_gx')),
    'megadrive':   ('Sega Mega Drive',     ('ra', 'genesis_plus_gx')),
    'md':          ('Sega Mega Drive',     ('ra', 'genesis_plus_gx')),
    'mastersystem':('Sega Master System',  ('ra', 'genesis_plus_gx')),
    'ms':          ('Sega Master System',  ('ra', 'genesis_plus_gx')),
    'gamegear':    ('Sega Game Gear',      ('ra', 'genesis_plus_gx')),
    'gg':          ('Sega Game Gear',      ('ra', 'genesis_plus_gx')),
    'saturn':      ('Sega Saturn',         ('ra', 'mednafen_saturn')),
    'dreamcast':   ('Sega Dreamcast',      ('ra', 'flycast')),
    'psx':         ('PlayStation',         ('std', 'duckstation')),
    'ps1':         ('PlayStation',         ('std', 'duckstation')),
    'ps2':         ('PlayStation 2',       ('std', 'pcsx2-qt')),
    'ps3':         ('PlayStation 3',       ('std', 'rpcs3')),
    'psp':         ('PSP',                 ('std', 'ppsspp')),
    'psvita':      ('PS Vita',             ('std', 'vita3k')),
    'vita':        ('PS Vita',             ('std', 'vita3k')),
    'pcengine':    ('PC Engine',           ('ra', 'mednafen_pce')),
    'pce':         ('PC Engine',           ('ra', 'mednafen_pce')),
    'neogeo':      ('Neo Geo',             ('ra', 'fbneo')),
    'ngp':         ('Neo Geo Pocket',      ('ra', 'mednafen_ngp')),
    'msx':         ('MSX',                 ('ra', 'bluemsx')),
    'xbox':        ('Xbox',                ('std', 'xemu-emu')),
    'xbox360':     ('Xbox 360',            ('std', 'xenia')),
    'ps4':         ('PlayStation 4',       ('std', 'shadps4')),
    'scummvm':     ('ScummVM',             ('std', 'scummvm')),
}

ESDE_THEME = Path('/usr/share/es-de/themes/slate-es-de')
ESDE_ALIASES = {
    'fc': 'famicom', 'sfc': 'snes', 'md': 'megadrive', 'ms': 'mastersystem',
    'gg': 'gamegear', 'pce': 'pcengine', 'ps1': 'psx', 'vita': 'psvita',
    '3ds': 'n3ds',
}

ROM_EXTS = {
    '.nes', '.sfc', '.smc', '.fig', '.swc', '.n64', '.z64', '.v64', '.gb', '.gbc',
    '.gba', '.nds', '.3ds', '.cia', '.iso', '.cso', '.chd', '.cue', '.bin', '.gdi',
    '.rvz', '.wbfs', '.wad', '.nsp', '.xci', '.md', '.gen', '.smd', '.sms', '.gg',
    '.pce', '.zip', '.7z', '.pbp', '.elf', '.ngp', '.ngc', '.vpk', '.cdi', '.m3u',
    '.rom', '.col', '.int', '.a26', '.a78', '.lnx', '.vec', '.ws', '.wsc', '.dsk',
}
IGNORE_NAMES = {'metadata.txt', 'systeminfo.txt', 'gamelist.xml', 'media'}

# systems where each game is a folder, not a single file
# key -> (marker subdir, relative path to the bootable file, relative icon path)
FOLDER_SYSTEMS = {
    'ps3': ('PS3_GAME', 'PS3_GAME/USRDIR/EBOOT.BIN', 'PS3_GAME/ICON0.PNG'),
}


def load_config():
    try:
        return json.loads(CONFIG.read_text('utf-8'))
    except Exception:
        return {}


def rom_dirs():
    cfg = load_config()
    dirs = [Path(d) for d in cfg.get('romDirs', []) if d]
    dirs = [d for d in dirs if d.exists()]
    if dirs:
        return dirs
    # autodetect: mounted drives and home, no hardcoded single path
    found = []
    for pat in ['/mnt/*/Games', '/mnt/*/Emulation/roms', '/run/media/*/*/Games',
                str(HOME / 'Emulation' / 'roms'), str(HOME / 'Games' / 'ROMs')]:
        for p in glob.glob(pat):
            pp = Path(p)
            if pp.is_dir():
                found.append(pp)
    return found


def sysinfo(folder_name):
    key = folder_name.lower()
    return SYSTEMS.get(key)


def system_logo(key):
    name = ESDE_ALIASES.get(key, key)
    p = ESDE_THEME / name / 'images' / 'logo.svg'
    return str(p) if p.exists() else None


def is_rom(path):
    if path.name in IGNORE_NAMES:
        return False
    if path.suffix.lower() not in ROM_EXTS:
        return False
    return path.is_file()


def folder_games(d, key):
    marker = FOLDER_SYSTEMS[key][0]
    out = []
    for sub in sorted(d.iterdir()):
        if sub.is_dir() and not sub.name.startswith('.') and (sub / marker).is_dir():
            out.append(sub)
    return out


def count_roms(d, key=None):
    if key in FOLDER_SYSTEMS:
        return len(folder_games(d, key))
    n = 0
    for root, _, files in os.walk(d):
        for f in files:
            if Path(f).suffix.lower() in ROM_EXTS and f not in IGNORE_NAMES:
                n += 1
    return n


def launch_command(spec, rom_path):
    rp = str(rom_path).replace('"', '\\"')
    kind, what = spec
    if kind == 'std':
        return f'bash "{LAUNCHERS}/{what}.sh" "{rp}"'
    core = f'{RA_CORES}/{what}_libretro.so'
    return f'bash "{LAUNCHERS}/retroarch.sh" -L "{core}" "{rp}"'


def art_for(rom_path):
    h = hashlib.md5(str(rom_path).encode('utf-8')).hexdigest()
    art = ART_CACHE / f'{h}.png'
    gen = (f'mkdir -p "{ART_CACHE}"; [ -f "{art}" ] || '
           f'rp-stub -s 320 "{rom_path}" "{art}" >/dev/null 2>&1 || true')
    return str(art), gen


def clean_label(stem):
    # strip region/dump tags in parens/brackets
    out, depth = [], 0
    for ch in stem:
        if ch in '([':
            depth += 1
        elif ch in ')]':
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    name = ''.join(out).strip().rstrip('-').strip()
    return name or stem


def clean_name(path):
    return clean_label(path.stem)


def list_systems():
    out = []
    for root in rom_dirs():
        for d in sorted(root.iterdir()) if root.exists() else []:
            if not d.is_dir():
                continue
            info = sysinfo(d.name)
            if not info:
                continue
            cnt = count_roms(d, d.name.lower())
            if cnt == 0:
                continue
            out.append({
                'system': d.name.lower(),
                'name': info[0],
                'count': cnt,
                'dir': str(d),
                'logo': system_logo(d.name.lower()),
            })
    # merge duplicate systems across roots
    merged = {}
    for s in out:
        k = s['name']
        if k in merged:
            merged[k]['count'] += s['count']
            merged[k]['dirs'].append(s['dir'])
        else:
            merged[k] = {'system': s['system'], 'name': s['name'],
                         'count': s['count'], 'dirs': [s['dir']],
                         'logo': s['logo']}
    return sorted(merged.values(), key=lambda x: -x['count'])


def folder_game_entries(dp, key, spec):
    marker, boot_rel, icon_rel = FOLDER_SYSTEMS[key]
    out = []
    for sub in folder_games(dp, key):
        boot = sub / boot_rel
        if not boot.exists():
            cand = list(sub.glob(f'{marker}/USRDIR/EBOOT.BIN'))
            if not cand:
                continue
            boot = cand[0]
        icon = sub / icon_rel
        if icon.exists():
            art, artgen = str(icon), ''
        else:
            art, artgen = art_for(boot)
        out.append({
            'name': clean_label(sub.name),
            'path': str(boot),
            'launch': launch_command(spec, boot),
            'art': art,
            'artGen': artgen,
        })
    return out


def list_roms(dirs):
    spec = None
    games = []
    seen = set()
    for d in dirs:
        dp = Path(d)
        if not dp.exists():
            continue
        key = dp.name.lower()
        if spec is None:
            info = sysinfo(dp.name)
            spec = info[1] if info else ('ra', 'mgba')
        if key in FOLDER_SYSTEMS:
            games.extend(folder_game_entries(dp, key, spec))
            continue
        for root, _, files in os.walk(dp):
            for f in sorted(files):
                p = Path(root) / f
                if not is_rom(p):
                    continue
                name = clean_name(p)
                key = name.lower()
                if key in seen:
                    continue
                seen.add(key)
                art, artgen = art_for(p)
                games.append({
                    'name': name,
                    'path': str(p),
                    'launch': launch_command(spec, p),
                    'art': art,
                    'artGen': artgen,
                })
    games.sort(key=lambda x: x['name'].lower())
    return games


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--roms':
        print(json.dumps(list_roms(sys.argv[2:]), indent=2))
    else:
        print(json.dumps(list_systems(), indent=2))
