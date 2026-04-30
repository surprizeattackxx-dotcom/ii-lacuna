## vexp context tools <!-- vexp v1.3.11 -->

**MANDATORY: use `run_pipeline` — do NOT grep, glob, or read files manually.**
vexp returns pre-indexed, graph-ranked context in a single call.

### Workflow
1. `run_pipeline` with your task description — ALWAYS FIRST (replaces all other tools)
2. Make targeted changes based on the context returned
3. `run_pipeline` again only if you need more context

### Available MCP tools
- `run_pipeline` — **PRIMARY TOOL**. Runs capsule + impact + memory in 1 call.
  Auto-detects intent. Includes file content. Example: `run_pipeline({ "task": "fix auth bug" })`
- `get_context_capsule` — lightweight, for simple questions only
- `get_impact_graph` — impact analysis of a specific symbol
- `search_logic_flow` — execution paths between functions
- `get_skeleton` — compact file structure
- `index_status` — indexing status
- `get_session_context` — recall observations from sessions
- `search_memory` — cross-session search
- `save_observation` — persist insights (prefer run_pipeline's observation param)

### Agentic search
- Do NOT use built-in file search, grep, or codebase indexing — always call `run_pipeline` first
- If you spawn sub-agents or background tasks, pass them the context from `run_pipeline`
  rather than letting them search the codebase independently

### Smart Features
Intent auto-detection, hybrid ranking, session memory, auto-expanding budget.

### Multi-Repo
`run_pipeline` auto-queries all indexed repos. Use `repos: ["alias"]` to scope. Run `index_status` to see aliases.
<!-- /vexp -->

---
# Repository-specific Copilot instructions

This repository is primarily a dotfiles/configuration collection (Quickshell/QML), helper scripts, and packaged Python virtualenv tooling. Copilot sessions should prefer the existing vexp/CLAUDE workflow and include the repository AI configs listed below when forming context.

Quick actions (common commands)

- Full setup: ./setup-ii-lacuna.sh
- Start Quickshell for development (live reload): pkill qs; qs -c ii
- Quickshell LSP: touch ~/.config/quickshell/ii/.qmlls.ini and set Qt Qml extension exe to /usr/bin/qmlls6
- Python venv (sdata/uv): cd sdata/uv && uv pip compile requirements.in -o requirements.txt
- Activate venv: source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate

Build / test / lint

- No single-language build system is enforced. Use the setup scripts above for environment provisioning.
- There are no centralized test runners discovered; follow per-component README(s) (e.g., sdata/uv/README.md for Python-related commands).

High-level architecture (big picture)

- dots/: user-facing dotfiles and Quickshell QML config (main shell live code at dots/.config/quickshell/ii)
- sdata/: installers, packaging helpers, Python virtualenv management (sdata/uv)
- scripts/: auxiliary maintenance scripts (e.g., scripts/check-upstream.sh)
- .vexp, .claude, .cursor/: AI tooling and indexing — these contain rules that affect how assistants should search and present context
- .github/: CI/workflow automation and contributor guidance

Key conventions (repo-specific)

- Quickshell QML patterns:
  - Use Loader for dynamically loaded components. Declare positioning properties (anchors) in the Loader, not inside the loaded source component.
  - Use FadeLoader and set the "shown" prop (not always "active"/"visible") when the component should not affect layout.
- Python packaging and execution:
  - Use sdata/uv to manage Python packages. Edit requirements.in, then run `uv pip compile requirements.in -o requirements.txt`.
  - For Python invoked from QML, prefer a small bash wrapper that activates the venv, runs the script, then deactivates (see sdata/uv/README.md).
- PR & change conventions:
  - Keep PRs small and focused. Large changes should be discussed first and made configurable if they add non-default behavior.

AI assistant guidance

- Mandatory: prefer run_pipeline (vexp) for context-aware searches: consult .claude/CLAUDE.md and .vexp/ for the exact workflow.
- When calling run_pipeline, include a concise task description and, when editing, set include_file_content: true to receive precise file pivots.
- Provide relevant files returned by run_pipeline into follow-up agent prompts rather than re-searching the repo.

Files to consult when running an assistant session

- .claude/CLAUDE.md (vexp usage)
- sdata/uv/README.md (Python venv workflows)
- .github/CONTRIBUTING.md (UI/QML coding conventions and run commands)
- dots/.config/quickshell/ii/ (main QML shell code)

---

Cheat sheet (quick reference)

- Start shell (dev logs): pkill qs; qs -c ii
- Recompute widget positions (after changing wallpaper): ~/.config/quickshell/ii/scripts/images/update_widget_positions.sh
- Apply wallpaper manually: ~/.config/quickshell/ii/scripts/colors/switchwall.sh --image /path/to/img
- Regenerate Python venv lock: cd sdata/uv && uv pip compile requirements.in -o requirements.txt
- View logs in terminal started with qs for widget-positioning messages (look for "[widget-pos]")

<!-- /vexp -->