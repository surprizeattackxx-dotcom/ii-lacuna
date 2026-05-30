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
    return {'appId': a.group(1), 'name': n.group(1)} if a and n else None

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
        games.append({
            'appId': appid, 'name': info['name'], 'art': art,
            'platform': 'steam', 'installed': False,
            'launch': f'steam steam://rungameid/{appid}',
        })
    return games

def find_heroic_games():
    games = []
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
            games.append({
                'appId': f'heroic_{app_name}', 'name': title, 'art': art,
                'platform': 'heroic', 'installed': bool(g.get('is_installed')),
                'launch': f'xdg-open "heroic://launch/{runner}/{app_name}"',
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
                games.append({
                    'name': f.stem, 'appId': f'appimg_{hid}', 'platform': 'appimage',
                    'art': None, 'installed': True, 'launch': f'"{f}"',
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
            id = f'native_{f.stem}'
            if id in seen_ids:
                continue
            seen_ids.add(id)
            games.append({
                'name': name, 'appId': id, 'platform': 'native',
                'art': None, 'installed': True, 'launch': f'gtk-launch {f.stem}',
            })
    return games

steam_games, steam_installed_ids = find_steam_games()
steam_names = {g['name'] for g in steam_games}
games = (steam_games + find_steam_uninstalled(steam_installed_ids)
         + find_heroic_games() + find_appimages() + find_native_games(steam_names))
print(json.dumps(games, indent=2))
