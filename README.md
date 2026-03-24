# Vibe-Coding-Incubator


# Claude Code Installation Scripts

Automated installers for the **Vibe Coding Incubator — Lesson 1** development environment. These scripts install Git, Node.js, your choice of IDE (VS Code / WebStorm / Both), the Claude Code CLI, and the Claude Code IDE plugin.

## Prerequisites

- **A paid Claude account** — Pro ($20/mo), Max ($100/mo), or API/Console (pay-per-token). The free tier is not sufficient. Sign up at [claude.ai/upgrade](https://claude.ai/upgrade).
- **macOS, Linux, or Windows 10/11**

### Windows-specific

- **PowerShell 5.1+** (pre-installed on Windows 10/11)
- **winget** (App Installer) — pre-installed on Windows 11; Windows 10 users can get it from the [Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1)

### macOS-specific

- The script will install [Homebrew](https://brew.sh) if not already present

### Linux-specific

- A supported package manager: `apt`, `dnf`, `yum`, `pacman`, or `zypper`
- `sudo` access for package installation

## Usage

### Mac / Linux

```bash
# Option 1: Run directly from a URL
curl -fsSL <url>/install-claude-code.sh | bash

# Option 2: Run locally
bash scripts/install-claude-code.sh
```

### Windows

Run in **PowerShell** (not Git Bash, not CMD):

```powershell
# Option 1: Run directly from a URL
irm <url>/Install-ClaudeCode-Windows.ps1 | iex

# Option 2: Run locally
.\scripts\Install-ClaudeCode-Windows.ps1
```

> **Note:** If you get an execution policy error, run this first:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

## What Gets Installed

| Step | Mac/Linux | Windows |
|------|-----------|---------|
| **Package Manager** | Homebrew (Mac) / system pkg manager (Linux) | winget (required pre-install) |
| **Node.js** | LTS via Homebrew or NodeSource | LTS via winget |
| **Git** | Via package manager | Git for Windows via winget |
| **IDE** | VS Code and/or WebStorm (your choice) | VS Code and/or WebStorm (your choice) |
| **IDE Plugin** | Claude Code extension/plugin | Claude Code extension/plugin |
| **Claude Code CLI** | Via official installer (`claude.ai/install.sh`) | Via official installer (`claude.ai/install.ps1`) |
| **PATH config** | Persists `~/.local/bin` in shell RC (if needed) | Persists `.local\bin` in User PATH registry (if needed) |
| **Default terminal** | — | Sets VS Code default terminal to PowerShell |

## Features

- **Idempotent** — safely re-run at any time; skips anything already installed
- **IDE choice** — prompted to pick VS Code, WebStorm, or both
- **PATH-aware** — refreshes PATH after each install so subsequent steps work without restarting
- **Smart PATH persistence** — only modifies shell config / registry if the Claude CLI was installed via the official installer (skips if installed via Homebrew, winget, npm, scoop, etc.)
- **Verification summary** — runs automated checks at the end and reports pass/fail for each component
- **`claude doctor`** — runs the built-in diagnostic tool to catch any remaining issues

## Post-Install Steps

1. **Close and reopen your terminal** to pick up PATH changes
2. Run `claude --version` to confirm the CLI works
3. Run `claude doctor` to check for issues
4. Open your IDE and verify the Claude Code plugin is active (look for the Spark icon in VS Code)
5. Run `claude` to authenticate with your Claude account (opens browser)

## Troubleshooting

### Claude CLI not found after install

Close your terminal completely and open a new one. The PATH changes only take effect in new sessions.

**Mac/Linux:** Verify your shell RC file has the PATH entry:
```bash
grep '.local/bin' ~/.zshrc  # or ~/.bashrc
```

**Windows:** Check the User PATH in registry:
```powershell
[Environment]::GetEnvironmentVariable("Path", "User")
```

### VS Code `code` command not found (Mac)

Open VS Code, press `Cmd+Shift+P`, type **"Shell Command: Install 'code' command in PATH"**, and run it.

### WebStorm plugin not installing automatically

Install manually: Open WebStorm → Settings → Plugins → Marketplace tab → search **"Claude Code"** → Install → Restart.

### Windows: Script blocked by execution policy

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Node.js version too old

The scripts require Node.js v18+. If an older version is detected, the script will attempt to upgrade it automatically.
