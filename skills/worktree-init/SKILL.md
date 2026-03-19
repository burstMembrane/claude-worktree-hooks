---
name: worktree-init
version: 0.1.0
description: >
  This skill should be used when the user asks to "set up worktrees",
  "create worktree config", "generate worktree config", "initialize worktree",
  "configure worktree setup", "create .worktree.yml", "prepare project for worktrees",
  "set up parallel Claude sessions", or reports that worktrees are missing files
  (like .env) or that dependencies are not installed in new worktrees. Not for
  actually creating or removing worktrees -- that is handled by the plugin hooks
  automatically when running `claude --worktree`.
---

# Worktree Init -- Guided .worktree.yml Creation

Generate a `.worktree.yml` configuration file for the worktree-setup plugin by scanning
the current project and presenting findings to the user for confirmation.

See `.worktree.example.yml` in the plugin root for a starter template.

## What .worktree.yml Does

The worktree-setup plugin reads `.worktree.yml` from the project root when `claude --worktree`
is invoked. It has two sections:

```yaml
copy:
  - .env
  - .env.local

setup:
  - npm install
```

- **copy**: Files/directories from the main repo not tracked by git (env files, data dirs,
  local config). Copied recursively. Missing entries silently skipped.
- **setup**: Shell commands to run in the worktree root after creation. Typically dependency
  installation. Failures are logged but not fatal.

## Guided Setup Procedure

### Step 1: Check Dependencies

Verify that `yq` and `jq` are available, as the worktree-create hook requires them.
Run `command -v yq` and `command -v jq`. If either is missing, inform the user before
proceeding:

- **jq**: `brew install jq` (macOS) or `apt-get install jq` (Linux)
- **yq**: `brew install yq` (macOS) or `go install github.com/mikefarah/yq/v4@latest`

### Step 2: Check for Existing Config

Check if `.worktree.yml` already exists in the project root. If it does, ask the
user whether to overwrite or edit the existing file.

### Step 3: Scan for Copyable Files

Scan the project root for files that are commonly needed but not tracked by git.
Use `git ls-files --others --ignored --exclude-standard` to find gitignored files,
then filter to relevant categories:

**Environment files** (high priority):
- `.env`, `.env.local`, `.env.development`, `.env.test`, `.env.production`
- `.env.*` patterns

**Local configuration** (medium priority):
- `.local.yml`, `.local.json`, `local.settings.json`
- `config/local.*`

**Data and fixtures** (check if gitignored):
- `data/`, `fixtures/`, `seeds/`
- `secrets/`, `certs/`, `.keys/`

Present findings grouped by priority. Use `AskUserQuestion` with `multiSelect: true`
to let the user pick which files to include.

### Step 4: Detect Setup Commands

Scan the project to determine what setup commands are needed:

**Node.js**: Check for `package.json`. If found, detect the package manager:
1. Read `packageManager` field from `package.json` (e.g. `"pnpm@8.6.0"`)
2. Check for lockfiles: `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `bun.lock`, `package-lock.json`
3. Default to `npm` if no signal found
4. Suggest `<pm> install`

**Python**: Check for `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `Pipfile`, `uv.lock`.
- uv.lock or pyproject.toml with `[tool.uv]`: `uv sync`
- pyproject.toml with poetry: `poetry install`
- pyproject.toml with pip: `pip install -e '.[dev]'`
- requirements.txt: `pip install -r requirements.txt`
- Pipfile: `pipenv install --dev`

**Rust**: Check for `Cargo.toml`. Suggest `cargo build`.

**Go**: Check for `go.mod`. Suggest `go mod download`.

**Ruby**: Check for `Gemfile`. Suggest `bundle install`.

**Elixir**: Check for `mix.exs`. Suggest `mix deps.get`.

**General**: Check for `Makefile` with an `install` or `setup` target.

Present detected commands. Use `AskUserQuestion` to let the user confirm, modify,
or add additional setup commands.

### Step 5: Write the Config

Assemble the `.worktree.yml` from the user's selections and write it to the project root.
Use this format:

```yaml
copy:
  - .env
  - .env.local

setup:
  - npm install
```

Omit sections that are empty (e.g. if no files to copy, omit `copy:` entirely).

After writing, inform the user:
- The file location
- That it should be committed to git so the team shares the config
- That `claude --worktree <name>` will now use this config automatically
