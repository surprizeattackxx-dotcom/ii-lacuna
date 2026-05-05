# ii-lacuna

A modular dotfile + system bootstrap framework.

## Structure
- dots/          → base configs
- dots-extra/    → optional configs
- sdata/         → command modules
## Syncing Manual Copies
If you have manually copied the `quickshell` directory instead of using the full installation framework, you can keep it up-to-date with this repository by running:

```bash
./scripts/sync-quickshell.sh
```

By default, this assumes your local quickshell directory is located at `~/.config/quickshell`. If it is located elsewhere, provide the path as an argument:

```bash
./scripts/sync-quickshell.sh /path/to/your/quickshell
```

