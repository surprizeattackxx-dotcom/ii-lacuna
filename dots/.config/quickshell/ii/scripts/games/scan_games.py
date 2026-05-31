#!/usr/bin/env python3
import json, os, re
from pathlib import Path

HOME = Path.home()

NON_GAME_APPIDS = {
    '7', '1070560', '1161040', '1391110', '1493710', '1628350',
    '1826330', '2180100', '228980', '4183110', '431960', '4628710',
}

NON_GAME_NAMES = ('Proton', 'Steam Linux Runtime', 'Steamworks')
LAUNCHER_NAMES = {'Steam', 'Lutris', 'Heroic Games Launcher', 'Goverlay',
    'ProtonUp-Qt', 'RetroArch', 'ES-DE', 'Bolt', 'SLSsteam', 'SLSsteam (Native)'}

ICON_THEME_ROOTS = [
    HOME / '.local' / 'share' / 'icons',
    Path('/usr/share/icons'),
]
ICON_SIZE_PREF = ['scalable', '512x512', '256x256', '192x192', '128x128', '96x96', '64x64', '48x48']

def resolve_icon(name):
    if not name:
        return None
    if name.startswith('/'):
        return name if Path(name).exists() else None
    flat_dirs = [Path('/usr/share/pixmaps'), HOME / '.local' / 'share' / 'pixmaps',
                 HOME / '.local' / 'share' / 'icons' / 'emudeck']
    for d in flat_dirs:
        if not d.exists():
            continue
        for e in ('.png', '.svg', '.xpm'):
            p = d / (name + e)
            if p.exists():
                return str(p)
        for child in d.iterdir():
            if child.is_file() and child.stem.lower() == name.lower() and child.suffix.lower() in ('.png', '.svg', '.xpm'):
                return str(child)
    for root in ICON_THEME_ROOTS:
        if not root.exists():
            continue
        for theme in ['hicolor', 'Papirus', 'Papirus-Dark', 'breeze', 'Adwaita']:
            base = root / theme
            if not base.exists():
                continue
            for size in ICON_SIZE_PREF:
                for e in ('.svg', '.png'):
                    p = base / size / 'apps' / (name + e)
                    if p.exists():
                        return str(p)
    return None

ESDE_THEME = Path('/usr/share/es-de/themes/slate-es-de')

def esde_logo(sysname):
    p = ESDE_THEME / sysname / 'images' / 'logo.svg'
    return str(p) if p.exists() else None

# rom-mimetype icon (substring) -> ES-DE system folder; ordered, specific first
ROM_ICON_SYSTEMS = [
    ('gba', 'gba'), ('gameboy-color', 'gbc'), ('gbc', 'gbc'),
    ('snes', 'snes'), ('nintendo-ds', 'nds'), ('3ds', 'n3ds'),
    ('n64', 'n64'), ('wii-u', 'wiiu'), ('wii', 'wii'), ('gamecube', 'gc'),
    ('psp', 'psp'), ('ps3', 'ps3'), ('genesis', 'genesis'),
    ('megadrive', 'megadrive'), ('master-system', 'mastersystem'),
    ('nes', 'nes'), ('gameboy', 'gb'), ('gb-rom', 'gb'),
]

def rom_icon_to_system(icon):
    if not icon:
        return None
    low = icon.lower()
    for key, sysname in ROM_ICON_SYSTEMS:
        if key in low:
            return sysname
    return None

def is_game(name, appid):
    if appid in NON_GAME_APPIDS:
        return False
    for p in NON_GAME_NAMES:
        if name.startswith(p):
            return False
    return True

def find_steam_libraries():
    libs = [str(HOME / '.steam' / 'steam')]
    vdf = HOME / '.steam' / 'steam' / 'steamapps' / 'libraryfolders.vdf'
    if vdf.exists():
        for m in re.finditer(r'"path"\s+"([^"]+)"', vdf.read_text('utf-8', errors='replace')):
            p = Path(m.group(1).replace('\\\\', '/'))
            if p.exists() and str(p) not in libs:
                libs.append(str(p))
    return libs

def parse_acf(path):
    t = path.read_text('utf-8', errors='replace')
    a = re.search(r'"appid"\s+"(\d+)"', t)
    n = re.search(r'"name"\s+"([^"]*)"', t)
    s = re.search(r'"SizeOnDisk"\s+"(\d+)"', t)
    if not (a and n):
        return None
    return {'appId': a.group(1), 'name': n.group(1),
            'size': int(s.group(1)) if s else 0}

def steam_art_path(appid):
    steam_root = HOME / '.steam' / 'steam'
    lib_dirs = [steam_root] + [Path(p) for p in find_steam_libraries() if p != str(steam_root)]
    seen = set()

    for lib in lib_dirs:
        libcache = lib / 'appcache' / 'librarycache' / appid
        if not libcache.exists():
            continue

        # old format: directly in the appid dir
        for p in [libcache / 'library_600x900.jpg', libcache / 'library_600x900.png',
                   libcache / 'library_capsule.jpg', libcache / 'library_capsule.png']:
            if p.exists() and str(p) not in seen:
                seen.add(str(p))
                return str(p)

        # new format: hash subdirectories with capsule images
        for sub in sorted(libcache.iterdir()):
            if not sub.is_dir():
                continue
            for name in ['library_capsule.jpg', 'library_capsule.png',
                          'library_600x900.jpg', 'library_600x900.png']:
                p = sub / name
                if p.exists() and str(p) not in seen:
                    seen.add(str(p))
                    return str(p)

    # userdata grid art (custom images)
    grid_dir = steam_root / 'userdata'
    if grid_dir.exists():
        for ud in sorted(grid_dir.iterdir()):
            if not ud.is_dir():
                continue
            for p in [ud / 'config' / 'grid' / f'{appid}p.png',
                       ud / 'config' / 'grid' / f'{appid}.jpg',
                       ud / 'config' / 'grid' / f'{appid}.png']:
                if p.exists() and str(p) not in seen:
                    seen.add(str(p))
                    return str(p)

    return None

def steam_hero_path(appid):
    steam_root = HOME / '.steam' / 'steam'
    lib_dirs = [steam_root] + [Path(p) for p in find_steam_libraries() if p != str(steam_root)]
    for lib in lib_dirs:
        libcache = lib / 'appcache' / 'librarycache' / appid
        if not libcache.exists():
            continue
        for p in [libcache / 'library_hero_blur.jpg', libcache / 'library_hero.jpg', libcache / 'library_hero.png']:
            if p.exists():
                return str(p)
        for sub in sorted(libcache.iterdir()):
            if not sub.is_dir():
                continue
            for name in ['library_hero_blur.jpg', 'library_hero.jpg', 'library_hero.png']:
                p = sub / name
                if p.exists():
                    return str(p)
    return None

def load_steam_playtime():
    out = {}
    udir = HOME / '.steam' / 'steam' / 'userdata'
    if not udir.exists():
        return out
    try:
        import vdf
    except Exception:
        return out
    for ud in udir.iterdir():
        cfg = ud / 'config' / 'localconfig.vdf'
        if not cfg.exists():
            continue
        try:
            d = vdf.load(open(cfg, encoding='utf-8', errors='replace'))
            apps = d.get('UserLocalConfigStore', {}).get('Software', {}).get('Valve', {}).get('Steam', {}).get('apps', {})
            for appid, info in apps.items():
                if not isinstance(info, dict):
                    continue
                lp = int(info.get('LastPlayed', 0) or 0)
                pt = int(info.get('Playtime', 0) or 0)
                if lp or pt:
                    prev = out.get(appid, (0, 0))
                    out[appid] = (max(prev[0], lp), max(prev[1], pt))
        except Exception:
            continue
    return out

STEAM_PLAYTIME = load_steam_playtime()

def enrich_steam(g):
    appid = g['appId']
    lp, pt = STEAM_PLAYTIME.get(appid, (0, 0))
    g['lastPlayed'] = lp
    g['playMinutes'] = pt
    g['hero'] = steam_hero_path(appid)
    g['storeUrl'] = f'https://store.steampowered.com/app/{appid}'
    g.setdefault('size', 0)
    return g

def find_steam_games():
    games, seen = [], set()
    for lib in find_steam_libraries():
        for m in sorted((Path(lib) / 'steamapps').glob('appmanifest_*.acf')):
            g = parse_acf(m)
            if g and g['appId'] not in seen and is_game(g['name'], g['appId']):
                seen.add(g['appId'])
                g['art'] = steam_art_path(g['appId'])
                g['platform'] = 'steam'
                g['installed'] = True
                g['launch'] = f'steam steam://rungameid/{g["appId"]}'
                enrich_steam(g)
                games.append(g)
    return games, seen

def load_steam_appinfo():
    try:
        from steam.utils.appcache import parse_appinfo
    except Exception:
        return {}
    path = HOME / '.steam' / 'steam' / 'appcache' / 'appinfo.vdf'
    if not path.exists():
        return {}
    out = {}
    try:
        _, apps = parse_appinfo(open(path, 'rb'), mapper=dict)
        for app in apps:
            common = (app.get('data', {}).get('appinfo', {}) or {}).get('common', {})
            if not common:
                continue
            out[str(app['appid'])] = {
                'name': common.get('name', ''),
                'type': str(common.get('type', '')).lower(),
            }
    except Exception:
        return {}
    return out

def steam_owned_appids():
    ids = set()
    cache = HOME / '.steam' / 'steam' / 'appcache' / 'librarycache'
    if cache.exists():
        for d in cache.iterdir():
            if d.is_dir() and d.name.isdigit():
                ids.add(d.name)
    return ids

def find_steam_uninstalled(installed_ids):
    appinfo = load_steam_appinfo()
    if not appinfo:
        return []
    games = []
    for appid in steam_owned_appids():
        if appid in installed_ids:
            continue
        info = appinfo.get(appid)
        if not info or info['type'] != 'game' or not info['name']:
            continue
        if not is_game(info['name'], appid):
            continue
        art = steam_art_path(appid)
        if not art:
            continue
        g = {
            'appId': appid, 'name': info['name'], 'art': art,
            'platform': 'steam', 'installed': False,
            'launch': f'steam steam://rungameid/{appid}',
        }
        enrich_steam(g)
        games.append(g)
    return games

def heroic_installed_ids():
    ids = set()
    legendary = HOME / '.config' / 'heroic' / 'legendaryConfig' / 'legendary' / 'installed.json'
    for f, key in [(legendary, None),
                   (HOME / '.config' / 'heroic' / 'gog_store' / 'installed.json', 'installed'),
                   (HOME / '.config' / 'heroic' / 'nile_config' / 'installed.json', None)]:
        if not f.exists():
            continue
        try:
            data = json.loads(f.read_text('utf-8', errors='replace'))
        except Exception:
            continue
        if isinstance(data, dict):
            entries = data.get(key) if key else data
            ids.update(entries.keys() if isinstance(entries, dict) else
                       (e.get('app_name') or e.get('id') for e in (entries or [])))
        elif isinstance(data, list):
            ids.update(e.get('app_name') or e.get('id') for e in data)
    return {i for i in ids if i}

def find_heroic_games():
    games = []
    installed_ids = heroic_installed_ids()
    cache = HOME / '.config' / 'heroic' / 'store_cache'
    sources = ['legendary_library.json', 'gog_library.json', 'nile_library.json']
    for src in sources:
        path = cache / src
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text('utf-8', errors='replace'))
        except Exception:
            continue
        if isinstance(data, dict):
            entries = data.get('library') or data.get('games') or []
        else:
            entries = data
        for g in entries:
            title = g.get('title')
            app_name = g.get('app_name')
            if not title or not app_name:
                continue
            if 'redistributable' in title.lower() or g.get('is_dlc'):
                continue
            runner = g.get('runner', 'legendary')
            art = g.get('art_square') or g.get('art_cover') or None
            hero = g.get('art_background') or g.get('art_cover') or None
            store = (g.get('extra') or {}).get('storeUrl') or None
            try:
                size = int((g.get('install') or {}).get('install_size') or 0)
            except (ValueError, TypeError):
                size = 0
            games.append({
                'appId': f'heroic_{app_name}', 'name': title, 'art': art,
                'platform': 'heroic', 'installed': bool(g.get('is_installed')) or app_name in installed_ids,
                'launch': f'xdg-open "heroic://launch/{runner}/{app_name}"',
                'lastPlayed': 0, 'playMinutes': 0, 'hero': hero, 'storeUrl': store,
                'size': size, 'runner': runner, 'appName': app_name,
            })
    return games

def find_appimages():
    games = []
    for d in [HOME / 'Applications', HOME / 'Games']:
        if not d.exists():
            continue
        for f in d.iterdir():
            if f.name.lower().endswith('.appimage') and f.is_file():
                hid = hash(str(f)) & 0xffffffff
                icon = (resolve_icon(f.stem) or resolve_icon(f.stem.lower())
                        or resolve_icon(f.stem.split('-')[0])
                        or resolve_icon(f.stem.split('-')[0].lower())
                        or resolve_icon(f.stem.split('_')[0].lower()))
                games.append({
                    'name': f.stem, 'appId': f'appimg_{hid}', 'platform': 'appimage',
                    'art': icon, 'iconArt': bool(icon), 'installed': True, 'launch': f'"{f}"',
                    'lastPlayed': 0, 'playMinutes': 0, 'hero': None, 'storeUrl': None,
                    'size': 0,
                })
    return games

def find_native_games(steam_names):
    games, seen_ids = [], set()
    game_cats = {'Game', 'Arcade', 'Action', 'Adventure', 'Simulation', 'Strategy', 'RolePlaying', 'Emulator'}
    for d in [HOME / '.local' / 'share' / 'applications', Path('/usr/share/applications')]:
        if not d.exists():
            continue
        for f in d.iterdir():
            if f.suffix != '.desktop':
                continue
            text = f.read_text('utf-8', errors='replace')
            cm = re.search(r'^Categories=(.+)$', text, re.MULTILINE)
            if not cm or not set(cm.group(1).split(';')) & game_cats:
                continue
            nm = re.search(r'^Name=(.+)$', text, re.MULTILINE)
            if not nm:
                continue
            name = nm.group(1)
            if name in steam_names or name in LAUNCHER_NAMES:
                continue
            em = re.search(r'^Exec=(.+)$', text, re.MULTILINE)
            im = re.search(r'^Icon=(.+)$', text, re.MULTILINE)
            icon_name = im.group(1).strip() if im else None
            rom_sys = rom_icon_to_system(icon_name)
            icon = esde_logo(rom_sys) if rom_sys else resolve_icon(icon_name)
            id = f'native_{f.stem}'
            if id in seen_ids:
                continue
            seen_ids.add(id)
            games.append({
                'name': name, 'appId': id, 'platform': 'native',
                'art': icon, 'iconArt': bool(icon), 'installed': True,
                'launch': f'gtk-launch {f.stem}',
                'lastPlayed': 0, 'playMinutes': 0, 'hero': None, 'storeUrl': None,
                'size': 0,
            })
    return games

steam_games, steam_installed_ids = find_steam_games()
steam_names = {g['name'] for g in steam_games}
games = (steam_games + find_steam_uninstalled(steam_installed_ids)
         + find_heroic_games() + find_appimages() + find_native_games(steam_names))
print(json.dumps(games, indent=2))
