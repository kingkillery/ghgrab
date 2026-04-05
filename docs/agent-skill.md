# ghgrab — Agentic Skill

> This document teaches a coding agent how to use the `ghgrab` CLI tool to discover and download specific files from any GitHub repository without cloning it.

---

## Overview

`ghgrab` is a CLI tool for cherry-picking files and folders from GitHub repositories. It exposes a machine-friendly `agent` subcommand that prints **stable JSON** to stdout — no TUI, no interactive prompts. All agent commands follow the same output envelope, making them safe to parse in scripts and agentic workflows.

---

## Prerequisites

Install `ghgrab` via one of the supported package managers:

```bash
# npm (global)
npm install -g @ghgrab/ghgrab

# Cargo
cargo install ghgrab

# pipx
pipx install ghgrab
```

Verify the installation:

```bash
ghgrab --version
```

---

## Authentication

`ghgrab` uses GitHub's REST API. Anonymous requests are subject to GitHub's lower rate limits (60 requests/hour). For most agentic workflows, supply a GitHub token.

Token resolution order (first match wins):

1. `--token <TOKEN>` flag on the command line
2. `GHGRAB_GITHUB_TOKEN` environment variable
3. `GITHUB_TOKEN` environment variable
4. Token stored with `ghgrab config set token <TOKEN>`

**Recommended for agents**: pass the token via an environment variable so it is not logged in command output.

```bash
export GITHUB_TOKEN=ghp_...
ghgrab agent tree https://github.com/owner/repo
```

Or pass it inline for a single run (the token is not saved):

```bash
ghgrab agent tree https://github.com/owner/repo --token ghp_...
```

---

## JSON Envelope

Every `agent` command prints a single JSON object with this shape:

```json
{
  "api_version": "1",
  "ok": true,
  "command": "<tree|download>",
  "data": { ... },
  "error": null
}
```

On failure, `ok` is `false`, `data` is `null`, and `error` contains:

```json
{
  "error": {
    "code": "<error_code>",
    "message": "Human-readable description"
  }
}
```

### Error codes

| Code | Meaning |
|------|---------|
| `not_found` | Repository, branch, or path does not exist |
| `invalid_url` | The URL is not a valid GitHub repository URL |
| `invalid_token` | The supplied token is invalid or expired |
| `rate_limit` | GitHub API rate limit reached |
| `github_api_error` | Unexpected GitHub API error |
| `invalid_arguments` | Conflicting flags were provided |
| `output_path_error` | The output directory could not be resolved or created |
| `internal_error` | Unexpected internal error |

---

## Step-by-Step Workflow

### 1 — Discover the repository tree

Before downloading, inspect the file tree to find the exact paths you need.

```bash
ghgrab agent tree https://github.com/<owner>/<repo>
```

**Success response** (`ok: true`):

```json
{
  "api_version": "1",
  "ok": true,
  "command": "tree",
  "data": {
    "owner": "rust-lang",
    "repo": "rust",
    "branch": "master",
    "path": "",
    "truncated": false,
    "entries": [
      {
        "path": "README.md",
        "kind": "file",
        "size": 4096,
        "download_url": "https://raw.githubusercontent.com/rust-lang/rust/master/README.md",
        "is_lfs": false
      },
      {
        "path": "src",
        "kind": "dir",
        "size": null,
        "download_url": null,
        "is_lfs": false
      }
    ]
  },
  "error": null
}
```

**`truncated: true`** means the repository is too large for a single recursive tree call. In that case the `entries` array contains only the top-level listing. You can still download paths by name — `agent download` will resolve them lazily.

#### Tree for a subdirectory

Append the path after the repo URL:

```bash
ghgrab agent tree https://github.com/rust-lang/rust/tree/master/src/tools
```

---

### 2 — Download specific files or folders

```bash
ghgrab agent download <URL> [PATH …] [OPTIONS]
```

`PATH` is one or more repo-relative paths (files or directories) taken from the `entries[].path` values returned by `agent tree`.

**Download a single file:**

```bash
ghgrab agent download https://github.com/rust-lang/rust README.md --out ./tmp
```

**Download multiple files at once:**

```bash
ghgrab agent download https://github.com/rust-lang/rust \
  src/tools/rustfmt README.md \
  --out ./tmp
```

**Download an entire subdirectory:**

```bash
ghgrab agent download https://github.com/rust-lang/rust \
  --subtree src/tools \
  --out ./tmp
```

**Download the entire repository:**

```bash
ghgrab agent download https://github.com/rust-lang/rust \
  --repo \
  --out ./tmp
```

**Download into the current working directory without creating a repo subfolder:**

```bash
ghgrab agent download https://github.com/rust-lang/rust README.md \
  --cwd --no-folder
```

**Success response** (`ok: true`):

```json
{
  "api_version": "1",
  "ok": true,
  "command": "download",
  "data": {
    "owner": "rust-lang",
    "repo": "rust",
    "branch": "master",
    "output_dir": "/tmp/rust",
    "downloaded_paths": [
      "README.md",
      "src/tools/rustfmt/src/lib.rs"
    ],
    "errors": []
  },
  "error": null
}
```

`errors` is a list of per-file error strings. A non-empty `errors` array means some files failed even though the overall command succeeded (`ok: true`).

---

## Download Options Reference

| Flag | Description |
|------|-------------|
| `--repo` | Download the entire repository. Cannot be combined with positional paths or `--subtree`. |
| `--subtree <PATH>` | Download one subtree. Cannot be combined with positional paths or `--repo`. |
| `--out <DIR>` | Save files to a custom directory. Defaults to the user's Downloads folder. |
| `--cwd` | Save files to the current working directory. |
| `--no-folder` | Do not create a subfolder named after the repository inside the output directory. |
| `--token <TOKEN>` | One-time GitHub token (not stored). |

---

## Common Patterns

### Pattern A — Download one file from a known path

```bash
ghgrab agent download https://github.com/owner/repo path/to/file.txt --out ./output
```

### Pattern B — Explore first, then download

```bash
# 1. List top-level entries
ghgrab agent tree https://github.com/owner/repo

# 2. Download the paths you want
ghgrab agent download https://github.com/owner/repo docs/guide.md src/config.toml --out ./output
```

### Pattern C — Download a folder from a large (truncated) repo

For repos where `truncated: true`, you can still download by path. `ghgrab` resolves the subtree lazily.

```bash
ghgrab agent download https://github.com/large-org/big-repo \
  --subtree path/to/folder \
  --out ./output
```

### Pattern D — Authenticated download in CI

```bash
ghgrab agent download https://github.com/private-org/repo README.md \
  --token "$GITHUB_TOKEN" \
  --out ./workspace
```

### Pattern E — Parse JSON output in a shell script

```bash
result=$(ghgrab agent download https://github.com/owner/repo README.md --out ./tmp)

ok=$(echo "$result" | jq -r '.ok')
if [ "$ok" != "true" ]; then
  code=$(echo "$result" | jq -r '.error.code')
  msg=$(echo "$result" | jq -r '.error.message')
  echo "Download failed [$code]: $msg" >&2
  exit 1
fi

output_dir=$(echo "$result" | jq -r '.data.output_dir')
echo "Files saved to: $output_dir"
```

---

## Decision Tree for Agents

```
Goal: download specific files from a GitHub repo
│
├─ Do you know the exact file paths?
│   ├─ YES → ghgrab agent download <URL> <path1> <path2> --out <dir>
│   └─ NO  → ghgrab agent tree <URL>
│               └─ Inspect entries[].path, then download as above
│
├─ Do you want an entire subdirectory?
│   └─ ghgrab agent download <URL> --subtree <subdir> --out <dir>
│
└─ Do you want the whole repo?
    └─ ghgrab agent download <URL> --repo --out <dir>
```

---

## Notes for Agents

- Always check `ok` before reading `data`.
- `truncated: true` in a tree response does not prevent downloading — `agent download` handles it.
- Path separators must be forward slashes (`/`). Backslashes are normalized automatically.
- Leading and trailing slashes in paths are stripped automatically.
- The `branch` field in tree/download responses shows the branch that was actually used (useful when the default branch is not `main`).
- `is_lfs: true` entries are transparently handled by `agent download` — no extra steps needed.
