#!/usr/bin/env python3
import sys, os, json, re, signal, subprocess, argparse
from pathlib import Path

HOME = Path.home()
HEROIC = HOME / '.config' / 'heroic'
BIN = Path('/opt/Heroic/resources/app.asar.unpacked/build/bin/x64/linux')

def steam_roots():
    return [HOME / '.steam' / 'steam',
            HOME / '.local' / 'share' / 'Steam',
            HOME / '.var' / 'app' / 'com.valvesoftware.Steam' / 'data' / 'Steam']

def list_runners():
    out, seen = [], set()
    def add(name, binp, typ):
        binp = Path(binp)
        if name in seen or not binp.exists():
            return
        seen.add(name)
        out.append({'name': name, 'bin': str(binp), 'type': typ})

    compat = [r / 'compatibilitytools.d' for r in steam_roots()] + [Path('/usr/share/steam/compatibilitytools.d')]
    for d in compat:
        if d.is_dir():
            for sub in sorted(d.iterdir()):
                if (sub / 'proton').exists():
                    add(sub.name, sub / 'proton', 'proton')
    for r in steam_roots():
        common = r / 'steamapps' / 'common'
        if common.is_dir():
            for sub in sorted(common.glob('Proton*')):
                if (sub / 'proton').exists():
                    add(sub.name, sub / 'proton', 'proton')
    for typ, exe in (('proton', 'proton'), ('wine', 'bin/wine')):
        d = HEROIC / 'tools' / typ
        if d.is_dir():
            for sub in sorted(d.iterdir()):
                cand = sub / exe
                if cand.exists():
                    add(sub.name, cand, typ)
    add('System Wine', '/usr/bin/wine', 'wine')
    return out

def defaults():
    path = HOME / 'Games' / 'Heroic'
    wine = None
    cfg = HEROIC / 'config.json'
    try:
        d = json.loads(cfg.read_text('utf-8', errors='replace')).get('defaultSettings', {})
        path = Path(d.get('defaultInstallPath') or path)
        wine = d.get('wineVersion')
    except Exception:
        pass
    return str(path), wine

def write_game_config(app, base_path, wine):
    cfgdir = HEROIC / 'GamesConfig'
    cfgdir.mkdir(parents=True, exist_ok=True)
    prefix = str(Path(base_path) / 'Prefixes' / 'shared')
    settings = {
        'autoInstallDxvk': True, 'autoInstallDxvkNvapi': True, 'autoInstallVkd3d': True,
        'preferSystemLibs': False, 'enableEsync': True, 'enableMsync': False, 'enableFsync': True,
        'wineVersion': wine, 'winePrefix': prefix,
    }
    (cfgdir / f'{app}.json').write_text(
        json.dumps({app: settings, 'version': 'v0', 'explicit': True}, indent=2))

def write_state(state_file, state, app_id, name, progress, status):
    tmp = state_file.with_suffix('.tmp')
    tmp.write_text(json.dumps({
        'active': state == 'running', 'state': state, 'pid': os.getpid(),
        'appId': app_id, 'name': name, 'progress': progress, 'status': status,
    }))
    tmp.replace(state_file)

def install(app, app_id, name, base_path, wine, state_file):
    state_file = Path(state_file)
    state_file.parent.mkdir(parents=True, exist_ok=True)
    write_game_config(app, base_path, wine)
    env = dict(os.environ,
               LEGENDARY_CONFIG_PATH=str(HEROIC / 'legendaryConfig' / 'legendary'))
    cmd = [str(BIN / 'legendary'), '-y', 'install', app, '--base-path', base_path]
    write_state(state_file, 'running', app_id, name, 0.0, 'Preparing…')

    def on_term(*_):
        write_state(state_file, 'error', app_id, name, 0.0, 'Cancelled')
        sys.exit(143)
    signal.signal(signal.SIGTERM, on_term)

    progress = 0.0
    try:
        proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in proc.stdout:
            m = re.search(r'Progress:\s*([0-9]+\.?[0-9]*)%', line)
            if m:
                progress = float(m.group(1))
                write_state(state_file, 'running', app_id, name, progress,
                            f'Downloading… {round(progress)}%')
            elif 'Verifying' in line:
                write_state(state_file, 'running', app_id, name, progress, 'Verifying…')
        code = proc.wait()
        if code == 0:
            write_state(state_file, 'done', app_id, name, 100.0, 'Installed')
        else:
            write_state(state_file, 'error', app_id, name, progress, 'Failed')
    except Exception as e:
        write_state(state_file, 'error', app_id, name, progress, f'Failed: {e}')

def check_stale(state_file):
    state_file = Path(state_file)
    try:
        d = json.loads(state_file.read_text())
    except Exception:
        return
    if not d.get('active'):
        return
    pid = d.get('pid')
    alive = False
    if pid:
        try:
            os.kill(pid, 0)
            alive = True
        except OSError:
            alive = False
    if not alive:
        d['active'] = False
        d['state'] = 'error'
        d['status'] = 'Interrupted'
        state_file.write_text(json.dumps(d))

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='cmd', required=True)
    sub.add_parser('list-runners')
    ip = sub.add_parser('install')
    ip.add_argument('--app', required=True)
    ip.add_argument('--app-id', required=True)
    ip.add_argument('--name', required=True)
    ip.add_argument('--base-path', required=True)
    ip.add_argument('--state-file', required=True)
    ip.add_argument('--wine-name', required=True)
    ip.add_argument('--wine-bin', required=True)
    ip.add_argument('--wine-type', required=True)
    cp = sub.add_parser('check-stale')
    cp.add_argument('--state-file', required=True)
    a = p.parse_args()
    if a.cmd == 'list-runners':
        dp, dw = defaults()
        print(json.dumps({'runners': list_runners(), 'defaultPath': dp, 'defaultWine': dw}))
    elif a.cmd == 'check-stale':
        check_stale(a.state_file)
    else:
        install(a.app, a.app_id, a.name, a.base_path,
                {'name': a.wine_name, 'bin': a.wine_bin, 'type': a.wine_type}, a.state_file)

if __name__ == '__main__':
    main()
