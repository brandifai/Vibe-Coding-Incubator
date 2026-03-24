# =============================================================================
# Vibe Coding Incubator — Lesson 1 Windows Installer
# Lets you choose your IDE (VS Code / WebStorm / Both), then installs:
# Git, Node.js, your IDE, Claude Code CLI + IDE plugin, PATH config
#
# - Idempotent: skips anything already installed
# - PATH-aware: refreshes PATH after every install so subsequent steps work
# - Persists PATH: ensures .local\bin survives terminal restarts
#
# Usage: Run in PowerShell (NOT Git Bash):
#   irm <url>/Install-ClaudeCode-Windows.ps1 | iex
#   OR: .\Install-ClaudeCode-Windows.ps1
#
# Mac/Linux users: Run the bash script instead:
#   curl -fsSL <url>/install-claude-code.sh | bash
# =============================================================================

#Requires -Version 5.1

# --- Guard: must be PowerShell, not Git Bash ----------------------------------
if ($env:MSYSTEM -or $env:MINGW_PREFIX) {
    Write-Host "`n[FAIL] You are running this in Git Bash. Please use PowerShell instead." -ForegroundColor Red
    Write-Host "       Right-click Start menu -> Windows PowerShell, then re-run this script.`n" -ForegroundColor Yellow
    exit 1
}

# --- Colors & helpers ---------------------------------------------------------
function Write-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok      { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail    { param($msg) Write-Host "[FAIL]  $msg" -ForegroundColor Red }
function Write-Step    { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor White }

function Test-Command { param($cmd) return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# --- PATH refresh helper -----------------------------------------------------
# Re-reads Machine + User PATH from the registry (picks up winget installs)
# and ensures the Claude CLI directory is always included.
function Refresh-PathInSession {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$userPath;$machinePath"

    # Ensure Claude CLI directory is in current session PATH
    $claudeDir = Join-Path $env:USERPROFILE ".local\bin"
    if ((Test-Path $claudeDir) -and ($env:Path -notlike "*$claudeDir*")) {
        $env:Path = "$claudeDir;$env:Path"
    }
}

# --- WebStorm detection helper ------------------------------------------------
function Test-WebStormInstalled {
    if (Test-Command "webstorm") { return $true }
    if (Test-Path "${env:ProgramFiles}\JetBrains\*WebStorm*") { return $true }
    if (Test-Path "${env:LOCALAPPDATA}\JetBrains\Toolbox\apps\WebStorm\*") { return $true }
    if (Test-Path "${env:LOCALAPPDATA}\Programs\*WebStorm*") { return $true }
    return $false
}

# --- VS Code PATH helper (ensure `code` is in PATH after silent install) -----
function Ensure-VSCodeInPath {
    if (Test-Command "code") { return }
    # Common VS Code binary locations after winget silent install
    $vsCodePaths = @(
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin",
        "${env:ProgramFiles}\Microsoft VS Code\bin"
    )
    foreach ($p in $vsCodePaths) {
        if (Test-Path $p) {
            $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if (-not $currentUserPath -or ($currentUserPath.Split(';') -notcontains $p)) {
                Write-Info "Adding VS Code to User PATH: $p"
                if (-not $currentUserPath) {
                    [Environment]::SetEnvironmentVariable("Path", $p, "User")
                } else {
                    [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$p", "User")
                }
            }
            Refresh-PathInSession
            return
        }
    }
}

# --- Pre-flight: check for winget --------------------------------------------
$hasWinget = Test-Command "winget"
if (-not $hasWinget) {
    Write-Fail "winget is not available. Please install 'App Installer' from the Microsoft Store first."
    Write-Host "  https://apps.microsoft.com/detail/9nblggh4nns1" -ForegroundColor Yellow
    exit 1
}

# --- Banner -------------------------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor White
Write-Host "   Vibe Coding Incubator - Windows Setup (Lesson 1)   " -ForegroundColor White
Write-Host "======================================================" -ForegroundColor White
Write-Host ""
Write-Info "This script will install everything you need for the course."
Write-Info "You may see Windows permission prompts - click 'Yes' to allow.`n"

# --- Paid Account Notice ------------------------------------------------------
Write-Host "IMPORTANT: Claude Code requires a paid Claude account to work." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The free tier is NOT enough for real development work."
Write-Host "  You need one of the following:"
Write-Host ""
Write-Host "    Pro Plan    - `$20/month  (good for learning & small projects)" -ForegroundColor White
Write-Host "    Max Plan    - `$100/month (recommended for serious building)" -ForegroundColor White
Write-Host "    API/Console - Pay-per-token at platform.claude.com" -ForegroundColor White
Write-Host ""
Write-Host "  Sign up or upgrade here: " -NoNewline
Write-Host "https://claude.ai/upgrade" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to continue (or Ctrl+C to cancel)"
Write-Host ""

# --- IDE Selection Prompt -----------------------------------------------------
Write-Host "Which code editor would you like to install?" -ForegroundColor White
Write-Host ""
Write-Host "  1) VS Code       - Free. Recommended for beginners."
Write-Host "  2) WebStorm       - By JetBrains. Requires a license (30-day free trial)."
Write-Host "  3) Both           - Install VS Code and WebStorm."
Write-Host ""

$ideChoice = ""
while ($ideChoice -eq "") {
    $input = Read-Host "Enter your choice (1, 2, or 3)"
    switch ($input) {
        "1" { $ideChoice = "vscode" }
        "2" { $ideChoice = "webstorm" }
        "3" { $ideChoice = "both" }
        default { Write-Warn "Please enter 1, 2, or 3." }
    }
}

$installVSCode   = $ideChoice -eq "vscode" -or $ideChoice -eq "both"
$installWebStorm = $ideChoice -eq "webstorm" -or $ideChoice -eq "both"

$ideLabel = "VS Code"
if ($installWebStorm -and -not $installVSCode) { $ideLabel = "WebStorm" }
if ($installVSCode -and $installWebStorm) { $ideLabel = "VS Code + WebStorm" }

Write-Host ""
Write-Ok "Selected: $ideLabel"

# ==============================================================================
# INSTALLATION STEPS (SOP order: Node.js, Git, IDE, plugin, CLI, PATH)
# ==============================================================================

# --- 1. Node.js (SOP 4.1) ----------------------------------------------------
Write-Step "1/9  Node.js (for your projects - not required by Claude Code)"
if (Test-Command "node") {
    $nodeVer = node --version
    $nodeMajor = [int]($nodeVer -replace 'v(\d+)\..*', '$1')
    if ($nodeMajor -ge 18) {
        Write-Ok "Node.js already installed: $nodeVer"
    } else {
        Write-Warn "Node.js $nodeVer is too old (need v18+). Upgrading..."
        winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent
        Refresh-PathInSession
        if (Test-Command "node") {
            Write-Ok "Node.js upgraded: $(node --version)"
        } else {
            Write-Warn "Node.js upgrade may need a terminal restart to take effect."
        }
    }
} else {
    Write-Info "Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements --silent
    Refresh-PathInSession
    if (Test-Command "node") {
        Write-Ok "Node.js installed: $(node --version)"
    } else {
        Write-Warn "Node.js installed but not on PATH yet. You may need to restart your terminal."
    }
}

# --- 2. Git for Windows (SOP 4.2) --------------------------------------------
Write-Step "2/9  Git for Windows (required for Claude Code)"
if (Test-Command "git") {
    Write-Ok "Git already installed: $(git --version)"
} else {
    Write-Info "Installing Git for Windows..."
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --silent
    Refresh-PathInSession
    if (Test-Command "git") {
        Write-Ok "Git installed: $(git --version)"
    } else {
        Write-Warn "Git installed but not on PATH yet. You may need to restart your terminal."
    }
}

# --- 3. IDE Installation (SOP 4.3) -------------------------------------------
Write-Step "3/9  Code Editor"

if ($installVSCode) {
    if (Test-Command "code") {
        Write-Ok "VS Code already installed: $(code --version | Select-Object -First 1)"
    } else {
        Write-Info "Installing VS Code..."
        winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements --silent
        Refresh-PathInSession
        # winget silent install may not add `code` to PATH; fix it
        Ensure-VSCodeInPath
        if (Test-Command "code") {
            Write-Ok "VS Code installed: $(code --version | Select-Object -First 1)"
        } else {
            Write-Warn "VS Code installed. You may need to restart your terminal for the 'code' command to work."
        }
    }
}

if ($installWebStorm) {
    if (Test-WebStormInstalled) {
        Write-Ok "WebStorm already installed."
    } else {
        Write-Info "Installing WebStorm..."
        winget install --id JetBrains.WebStorm -e --accept-package-agreements --accept-source-agreements --silent
        Refresh-PathInSession
        if (Test-WebStormInstalled) {
            Write-Ok "WebStorm installed."
        } else {
            Write-Warn "WebStorm installed. You may need to restart your terminal or launch it from the Start menu."
        }
    }
}

# --- 4. Default Terminal to PowerShell (SOP 4.4) -----------------------------
Write-Step "4/9  Default Terminal Configuration"

if ($installVSCode) {
    # Automatically set VS Code default terminal to PowerShell
    $vsCodeSettingsDir = Join-Path $env:APPDATA "Code\User"
    $vsCodeSettingsFile = Join-Path $vsCodeSettingsDir "settings.json"

    $terminalSetting = '"terminal.integrated.defaultProfile.windows"'
    $needsUpdate = $true

    if (Test-Path $vsCodeSettingsFile) {
        $content = Get-Content $vsCodeSettingsFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'terminal\.integrated\.defaultProfile\.windows') {
            Write-Ok "VS Code default terminal already configured."
            $needsUpdate = $false
        }
    }

    if ($needsUpdate) {
        Write-Info "Setting VS Code default terminal to PowerShell..."
        if (-not (Test-Path $vsCodeSettingsDir)) {
            New-Item -ItemType Directory -Path $vsCodeSettingsDir -Force | Out-Null
        }

        if (Test-Path $vsCodeSettingsFile) {
            $content = Get-Content $vsCodeSettingsFile -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Trim() -ne "" -and $content.Trim() -ne "{}") {
                # Insert setting before the last closing brace
                $content = $content.TrimEnd()
                if ($content.EndsWith("}")) {
                    $content = $content.Substring(0, $content.Length - 1).TrimEnd()
                    if (-not $content.EndsWith(",") -and -not $content.EndsWith("{")) {
                        $content += ","
                    }
                    $content += "`n    $terminalSetting`: `"PowerShell`"`n}"
                    Set-Content -Path $vsCodeSettingsFile -Value $content -Encoding UTF8
                    Write-Ok "VS Code default terminal set to PowerShell."
                }
            } else {
                # Empty or {} file
                Set-Content -Path $vsCodeSettingsFile -Value "{`n    $terminalSetting`: `"PowerShell`"`n}" -Encoding UTF8
                Write-Ok "VS Code default terminal set to PowerShell."
            }
        } else {
            # No settings file exists
            Set-Content -Path $vsCodeSettingsFile -Value "{`n    $terminalSetting`: `"PowerShell`"`n}" -Encoding UTF8
            Write-Ok "VS Code default terminal set to PowerShell."
        }
    }
}

if ($installWebStorm) {
    Write-Warn "WebStorm: Set your terminal to PowerShell manually:"
    Write-Host "  File -> Settings -> Tools -> Terminal -> Shell path -> powershell.exe" -ForegroundColor White
}

# --- 5. Claude Code IDE Plugin (SOP 4.5) -------------------------------------
Write-Step "5/9  Claude Code IDE Plugin"

if ($installVSCode) {
    if (Test-Command "code") {
        $extensions = code --list-extensions 2>$null
        if ($extensions -match "(?i)anthropic") {
            Write-Ok "Claude Code VS Code extension already installed."
        } else {
            Write-Info "Installing Claude Code VS Code extension..."
            code --install-extension anthropic.claude-code 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Claude Code VS Code extension installed."
            } else {
                Write-Warn "Could not install extension automatically."
                Write-Warn "Install manually: VS Code -> Extensions (Ctrl+Shift+X) -> search 'Claude Code'"
            }
        }
    } else {
        Write-Warn "VS Code 'code' command not available yet."
        Write-Warn "After restarting your terminal, install the extension manually:"
        Write-Warn "  VS Code -> Ctrl+Shift+X -> search 'Claude Code' -> Install"
    }
}

if ($installWebStorm) {
    $wsCmd = $null
    if (Test-Command "webstorm") {
        $wsCmd = "webstorm"
    } else {
        $wsPaths = @(
            "${env:ProgramFiles}\JetBrains\*WebStorm*\bin\webstorm64.exe",
            "${env:LOCALAPPDATA}\Programs\*WebStorm*\bin\webstorm64.exe",
            "${env:LOCALAPPDATA}\JetBrains\Toolbox\apps\WebStorm\*\*\bin\webstorm64.exe"
        )
        foreach ($pattern in $wsPaths) {
            $found = Get-Item $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $wsCmd = $found.FullName; break }
        }
    }

    if ($wsCmd) {
        Write-Info "Attempting to install Claude Code plugin for WebStorm..."
        try {
            & $wsCmd installPlugins "claude-code" 2>$null
            Write-Ok "Claude Code WebStorm plugin install command sent."
        } catch {
            Write-Warn "Automatic plugin install failed. See manual steps below."
        }
    }

    Write-Host ""
    Write-Info "To verify or manually install the Claude Code plugin in WebStorm:"
    Write-Host "  1. Open WebStorm" -ForegroundColor White
    Write-Host "  2. Go to File -> Settings -> Plugins  (or Ctrl+Alt+S)" -ForegroundColor White
    Write-Host "  3. Click the 'Marketplace' tab" -ForegroundColor White
    Write-Host "  4. Search for 'Claude Code'" -ForegroundColor White
    Write-Host "  5. Click 'Install' on the Anthropic plugin" -ForegroundColor White
    Write-Host "  6. Restart WebStorm when prompted" -ForegroundColor White
}

# --- 6. Claude Code CLI (SOP 4.6) --------------------------------------------
Write-Step "6/9  Claude Code CLI"

# Pre-check: refresh PATH in case a previous partial run installed it
$claudeBinDir = Join-Path $env:USERPROFILE ".local\bin"
Refresh-PathInSession

if (Test-Command "claude") {
    Write-Ok "Claude Code CLI already installed: $(claude --version 2>$null)"
} else {
    Write-Info "Installing Claude Code CLI..."
    try {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    } catch {
        Write-Fail "Failed to download/run the Claude Code installer."
        Write-Fail "Try running manually: irm https://claude.ai/install.ps1 | iex"
    }

    Refresh-PathInSession
    if (Test-Command "claude") {
        Write-Ok "Claude Code CLI installed: $(claude --version 2>$null)"
    } else {
        Write-Warn "CLI installed but not on PATH yet. Will fix in the next step."
    }
}

# --- 7. PATH Configuration (SOP 4.6, mandatory on Windows) -------------------
Write-Step "7/9  PATH Configuration"

$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Only add .local\bin to PATH if claude was actually installed there
# (i.e., via the official installer, not winget/npm/scoop)
$claudeInLocalBin = Test-Path (Join-Path $claudeBinDir "claude.exe")

if ($currentUserPath -and $currentUserPath.Split(';') -contains $claudeBinDir) {
    Write-Ok "PATH already includes $claudeBinDir"
} elseif ($claudeInLocalBin) {
    Write-Info "Adding $claudeBinDir to your User PATH..."
    if (-not $currentUserPath) {
        [Environment]::SetEnvironmentVariable("Path", $claudeBinDir, "User")
    } else {
        [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$claudeBinDir", "User")
    }
    Write-Ok "PATH updated. This will take effect in new terminal windows."
} elseif (Test-Command "claude") {
    $claudeLocation = (Get-Command claude -ErrorAction SilentlyContinue).Source
    Write-Ok "claude available via $claudeLocation (no .local\bin PATH change needed)"
} else {
    Write-Warn "claude not found. You may need to restart your terminal."
}

# Final refresh so verification works
Refresh-PathInSession

# --- 8. Verification (SOP Section 7) -----------------------------------------
Write-Step "8/9  Verification"

# One last PATH refresh
Refresh-PathInSession

Write-Host ""
Write-Host "======================================================" -ForegroundColor White
Write-Host "              Verification Summary                     " -ForegroundColor White
Write-Host "======================================================" -ForegroundColor White

$pass = 0
$total = 0

function Verify-Pass  { param($msg) Write-Ok $msg;   $script:pass++; $script:total++ }
function Verify-Fail  { param($msg) Write-Fail $msg;                  $script:total++ }
function Verify-Warn  { param($msg) Write-Warn $msg;                  $script:total++ }

# -- Git
if (Test-Command "git") { Verify-Pass "Git: $(git --version)" } else { Verify-Fail "Git: NOT FOUND" }

# -- Node.js (must be v18+)
if (Test-Command "node") {
    $nv = node --version
    $nm = [int]($nv -replace 'v(\d+)\..*', '$1')
    if ($nm -ge 18) { Verify-Pass "Node.js: $nv" } else { Verify-Fail "Node.js: $nv (need v18+)" }
} else { Verify-Fail "Node.js: NOT FOUND" }

# -- VS Code
if ($installVSCode) {
    if (Test-Command "code") {
        Verify-Pass "VS Code: $(code --version | Select-Object -First 1)"
    } else {
        Verify-Fail "VS Code: NOT FOUND"
    }
    if ((Test-Command "code") -and ((code --list-extensions 2>$null) -match "(?i)anthropic")) {
        Verify-Pass "Claude Code VS Code Extension: installed"
    } else {
        Verify-Fail "Claude Code VS Code Extension: NOT FOUND"
    }
}

# -- WebStorm
if ($installWebStorm) {
    if (Test-WebStormInstalled) {
        Verify-Pass "WebStorm: installed"
    } else {
        Verify-Fail "WebStorm: NOT FOUND"
    }
    Verify-Warn "Claude Code WebStorm Plugin: verify manually (Settings -> Plugins -> search 'Claude Code')"
}

# -- Claude CLI
if (Test-Command "claude") { Verify-Pass "Claude Code CLI: $(claude --version 2>$null)" } else { Verify-Fail "Claude Code CLI: NOT FOUND (restart terminal and check)" }

# -- PATH (check the persisted registry value, not just the session)
$checkPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($checkPath -and $checkPath.Split(';') -contains $claudeBinDir) {
    Verify-Pass "PATH (persisted): $claudeBinDir in User PATH"
} elseif (Test-Command "claude") {
    $claudeLocation = (Get-Command claude -ErrorAction SilentlyContinue).Source
    Verify-Pass "PATH: claude available via $claudeLocation (no .local\bin needed)"
} else {
    Verify-Fail "PATH (persisted): $claudeBinDir not found in User PATH"
}

# -- Default terminal (VS Code)
if ($installVSCode) {
    $vsFile = Join-Path $env:APPDATA "Code\User\settings.json"
    if ((Test-Path $vsFile) -and ((Get-Content $vsFile -Raw -ErrorAction SilentlyContinue) -match 'terminal\.integrated\.defaultProfile\.windows')) {
        Verify-Pass "VS Code default terminal: configured"
    } else {
        Verify-Fail "VS Code default terminal: NOT configured (Ctrl+Shift+P -> 'Terminal: Select Default Profile' -> PowerShell)"
    }
}

# -- claude doctor
if (Test-Command "claude") {
    Write-Host ""
    Write-Info "Running claude doctor..."
    claude doctor 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "claude doctor reported issues - review the output above."
    }
}

Write-Host ""
if ($pass -eq $total) {
    Write-Host "All $total/$total checks passed!" -ForegroundColor Green
} else {
    Write-Host "$pass/$total checks passed. See warnings above." -ForegroundColor Yellow
}

# -- Manual GUI checks
if ($installVSCode) {
    Write-Host ""
    Write-Warn "MANUAL CHECK: Open VS Code and verify the Spark icon is visible in the toolbar/sidebar"
    Write-Warn "MANUAL CHECK: Click the Spark icon to confirm the Claude Code panel opens"
}

# --- 9. Authentication (SOP 4.7) ---------------------------------------------
Write-Step "9/9  Authentication"

Write-Host "Claude Code requires you to sign in with your Claude account." -ForegroundColor White
Write-Host ""
$authChoice = Read-Host "Would you like to authenticate now? (y/n)"
if ($authChoice -eq "y" -or $authChoice -eq "Y") {
    Write-Info "Launching Claude Code... Your browser will open for sign-in."
    Write-Info "Return here after signing in."
    if (Test-Command "claude") {
        claude
    } else {
        Write-Warn "Claude CLI not found. Open a NEW PowerShell window and run: claude"
    }
} else {
    Write-Host ""
    Write-Info "Skipping authentication. Open a new PowerShell window and run 'claude' when ready."
}

# --- Next Steps ---------------------------------------------------------------
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. CLOSE this terminal and open a NEW PowerShell window"
Write-Host "  2. Run:  claude --version   (confirm it works in a new terminal)"
Write-Host "  3. Run:  claude doctor      (check for issues)"
if ($installVSCode) {
    Write-Host "  4. Open VS Code, click the Spark icon, and send your first prompt"
}
if ($installWebStorm) {
    Write-Host "  4. Open WebStorm, verify the Claude Code plugin (Settings -> Plugins)"
}
Write-Host "  5. Send your first prompt!"
Write-Host ""
Write-Host "You're ready for Lesson 2!" -ForegroundColor Green
Write-Host ""
