# ii-lacuna

A modular dotfile + system bootstrap framework.

## Structure
- dots/          → base configs
- dots-extra/    → optional configs
- sdata/         → command modules
## ⚠️ Compatibility Warning
Please **do not manually copy** parts of this framework (such as the `quickshell` directory) into other installations (including `ii-vynx`). 

This framework is modular and interdependent; `quickshell` relies on specific global states, scripts, and `sdata/` modules present only in a full `ii-lacuna` installation. Manual copying will lead to broken features and make it impossible for you to receive future updates through the built-in `pull-updates.sh` script. Always use the provided setup and update tools to ensure your system remains stable and compatible.

