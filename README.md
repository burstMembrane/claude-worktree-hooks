# worktree-setup

A Claude Code plugin that automates worktree setup and teardown. When you run `claude --worktree`, it reads a `.worktree.yml` config from your project root, copies files, and runs setup commands -- so every worktree starts fully configured.

## Installation

```bash
claude plugin add /path/to/worktree-setup
```

Or for local development:

```bash
claude --plugin-dir /path/to/worktree-setup
```

### Dependencies

The hook scripts require two CLI tools:

- **jq**: `brew install jq` (macOS) or `apt-get install jq` (Linux)
- **yq**: `brew install yq` (macOS) or `go install github.com/mikefarah/yq/v4@latest`

## Quick start

1. Install the plugin
2. Run `/worktree-setup:worktree-init` inside a Claude session to generate `.worktree.yml` interactively
3. Commit `.worktree.yml` to your repo
4. Run `claude --worktree my-feature` -- setup happens automatically

## Configuration

Create a `.worktree.yml` in your project root (or use the init skill to generate one):

```yaml
# Files and directories to copy from the main repo into each new worktree.
# Directories are copied recursively. Missing entries are silently skipped.
copy:
  - .env
  - .env.local

# Commands to run inside the worktree after creation.
# Each command runs in the worktree root. Failures are logged, not fatal.
setup:
  - npm install
```

See `.worktree.example.yml` for a starter template.

### copy

List files and directories that exist in your repo but aren't tracked by git. These get copied from the main repo into each new worktree. Common entries:

- `.env`, `.env.local` -- environment variables and secrets
- `data/`, `fixtures/` -- local data directories
- `secrets/`, `certs/` -- credentials

### setup

Shell commands to run in the worktree root after creation. Typically dependency installation:

- `npm install`, `pnpm install`, `yarn install`, `bun install`
- `pip install -e '.[dev]'`, `poetry install`
- `cargo build`, `go mod download`, `bundle install`

## How it works

The plugin registers two hooks:

**WorktreeCreate** -- runs when `claude --worktree <name>` is invoked, before the TUI renders:
1. Creates a git worktree at `.claude/worktrees/<name>/` on branch `worktree-<name>`
2. Reads `.worktree.yml` and copies listed files/directories
3. Runs setup commands, logging output to `.worktree-setup.log`
4. Prints the worktree path on stdout (the only thing Claude reads)

**WorktreeRemove** -- runs when you choose to remove a worktree after exiting:
1. Removes the git worktree
2. Deletes the `worktree-*` branch

If the worktree already exists (e.g. you kept it from a previous session), the create hook reuses it.

## Plugin structure

```
worktree-setup/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── worktree-create.sh
│       └── worktree-remove.sh
├── skills/
│   └── worktree-init/
│       └── SKILL.md
└── .worktree.example.yml
```

## Gotchas

- **stdout is sacred**: The create hook must print only the worktree path on stdout. All progress output goes to `/dev/tty`. If anything else leaks to stdout, Claude can't parse the path and hangs.
- **Reusing worktrees**: If you "keep" a worktree and later run `claude --worktree` with the same name, the hook skips creation and reuses the existing directory.
- **Setup failures aren't fatal**: If a setup command fails, the worktree still gets created. Check `.worktree-setup.log` in the worktree for details.
