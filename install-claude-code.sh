#!/usr/bin/env bash
# =============================================================================
# Vibe Coding Incubator — Lesson 1 Installer (Mac & Linux)
# Detects your OS, lets you choose your IDE (VS Code / WebStorm / Both),
# and installs: Git, Node.js, your IDE, Claude Code CLI + IDE plugin
#
# - Idempotent: skips anything already installed
# - PATH-aware: refreshes PATH after every install so subsequent steps work
# - Persists PATH: ensures ~/.local/bin and other dirs survive terminal restarts
#
# Usage:
#   curl -fsSL <url>/install-claude-code.sh | bash
#   OR: bash install-claude-code.sh
#
# Windows users: Run the PowerShell script instead:
#   irm <url>/Install-ClaudeCode-Windows.ps1 | iex
# =============================================================================

# Don't use set -e; we handle errors per-step so one failure doesn't abort everything
set +e

# --- Colors & helpers --------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $1"; }
step()    { echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

# --- Detect OS ---------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Darwin)  OS="mac" ;;
        Linux)   OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*)
            fail "You're running this in a Bash-like shell on Windows (Git Bash / MSYS / Cygwin)."
            fail "Please use the PowerShell installer instead:"
            echo ""
            echo "  irm <url>/Install-ClaudeCode-Windows.ps1 | iex"
            echo ""
            exit 1
            ;;
        *)
            fail "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
}

detect_os

# --- Detect Linux package manager --------------------------------------------
if [[ "$OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
    elif command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MGR="zypper"
    else
        fail "Could not detect a supported package manager (apt, dnf, yum, pacman, zypper)."
        exit 1
    fi
fi

# --- Detect shell config file ------------------------------------------------
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

# --- PATH helpers -------------------------------------------------------------

# Refresh PATH in the current session after installing something.
# Sources shell RC, adds common bin dirs, clears bash's command cache.
refresh_path() {
    # Source shell config to pick up changes from installers
    if [[ -f "$SHELL_RC" ]]; then
        source "$SHELL_RC" 2>/dev/null || true
    fi

    # Ensure common binary directories are in PATH for this session
    local dirs_to_add=(
        "$HOME/.local/bin"          # Claude CLI installs here
        "/opt/homebrew/bin"         # Homebrew (Apple Silicon)
        "/usr/local/bin"            # Homebrew (Intel Mac) / standard installs
        "/snap/bin"                 # Snap packages (Linux)
    )
    for dir in "${dirs_to_add[@]}"; do
        if [[ -d "$dir" ]] && [[ ":$PATH:" != *":$dir:"* ]]; then
            export PATH="$dir:$PATH"
        fi
    done

    # Clear bash's command lookup cache
    hash -r 2>/dev/null || true
}

# Ensure a directory is persistently in PATH by writing to the shell RC file.
# This survives terminal restarts.
persist_path_dir() {
    local dir="$1"
    local marker="$2"  # A grep-able string to avoid duplicate entries
    if [[ -z "$marker" ]]; then
        marker="$dir"
    fi
    if ! grep -q "$marker" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Added by Vibe Coding Incubator installer" >> "$SHELL_RC"
        echo "export PATH=\"$dir:\$PATH\"" >> "$SHELL_RC"
        info "Added $dir to $SHELL_RC"
    fi
}

# --- Package install helpers --------------------------------------------------
pkg_install() {
    local pkg="$1"
    if [[ "$OS" == "mac" ]]; then
        brew install "$pkg"
    else
        case "$PKG_MGR" in
            apt)     sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg" ;;
            dnf)     sudo dnf install -y -q "$pkg" ;;
            yum)     sudo yum install -y -q "$pkg" ;;
            pacman)  sudo pacman -S --noconfirm "$pkg" ;;
            zypper)  sudo zypper install -y "$pkg" ;;
        esac
    fi
    refresh_path
}

install_nodejs() {
    if [[ "$OS" == "mac" ]]; then
        brew install node
    else
        case "$PKG_MGR" in
            apt)
                info "Adding NodeSource repository for Node.js LTS..."
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y -qq nodejs
                ;;
            dnf)
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                sudo dnf install -y -q nodejs
                ;;
            yum)
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                sudo yum install -y -q nodejs
                ;;
            pacman)
                sudo pacman -S --noconfirm nodejs npm
                ;;
            zypper)
                sudo zypper install -y nodejs npm
                ;;
        esac
    fi
    refresh_path
}

install_vscode() {
    if [[ "$OS" == "mac" ]]; then
        brew install --cask visual-studio-code
    else
        case "$PKG_MGR" in
            apt)
                info "Adding VS Code repository..."
                sudo apt-get install -y -qq wget gpg apt-transport-https
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
                sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
                rm -f /tmp/packages.microsoft.gpg
                sudo apt-get update -qq
                sudo apt-get install -y -qq code
                ;;
            dnf|yum)
                info "Adding VS Code repository..."
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
                if [[ "$PKG_MGR" == "dnf" ]]; then
                    sudo dnf install -y -q code
                else
                    sudo yum install -y -q code
                fi
                ;;
            pacman)
                warn "On Arch Linux, install VS Code from the AUR or install code (OSS) with:"
                warn "  sudo pacman -S code"
                sudo pacman -S --noconfirm code 2>/dev/null || true
                ;;
            zypper)
                info "Adding VS Code repository..."
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode 2>/dev/null || true
                sudo zypper refresh
                sudo zypper install -y code
                ;;
        esac
    fi
    refresh_path
}

install_webstorm() {
    if [[ "$OS" == "mac" ]]; then
        brew install --cask webstorm
    else
        # Use snap if available (works across most Linux distros)
        if command -v snap &>/dev/null; then
            info "Installing WebStorm via snap..."
            sudo snap install webstorm --classic
            # Persist /snap/bin in PATH for future terminal sessions
            if [[ -d "/snap/bin" ]]; then
                persist_path_dir "/snap/bin" "/snap/bin"
            fi
        else
            # Fallback: use JetBrains Toolbox
            warn "snap is not available. Installing JetBrains Toolbox instead..."
            warn "You can install WebStorm from within the Toolbox app."
            local TOOLBOX_URL="https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"
            local TOOLBOX_TMP="/tmp/jetbrains-toolbox.tar.gz"
            curl -fsSL -o "$TOOLBOX_TMP" "$TOOLBOX_URL"
            sudo tar -xzf "$TOOLBOX_TMP" -C /opt/
            rm -f "$TOOLBOX_TMP"
            local TOOLBOX_BIN=$(find /opt/jetbrains-toolbox-* -name "jetbrains-toolbox" -type f 2>/dev/null | head -1)
            if [[ -n "$TOOLBOX_BIN" ]]; then
                info "Launching JetBrains Toolbox — install WebStorm from the app."
                "$TOOLBOX_BIN" &
            else
                warn "JetBrains Toolbox extracted to /opt/ but binary not found. Launch it manually."
            fi
        fi
    fi
    refresh_path
}

install_vscode_claude_extension() {
    if command -v code &>/dev/null; then
        if code --list-extensions 2>/dev/null | grep -qi "anthropic"; then
            success "Claude Code VS Code extension already installed."
        else
            info "Installing Claude Code VS Code extension..."
            code --install-extension anthropic.claude-code 2>/dev/null && \
                success "Claude Code VS Code extension installed." || \
                warn "Could not install extension automatically. Install manually: VS Code -> Extensions -> search 'Claude Code'"
        fi
    else
        local SHORTCUT="Ctrl+Shift+X"
        [[ "$OS" == "mac" ]] && SHORTCUT="Cmd+Shift+X"
        warn "VS Code 'code' command not available. Install the extension manually:"
        warn "  Open VS Code -> $SHORTCUT -> search 'Claude Code' -> Install"
    fi
}

install_webstorm_claude_plugin() {
    local PLUGIN_ID="claude-code"

    # Try to find the WebStorm CLI launcher
    local WS_CMD=""
    if command -v webstorm &>/dev/null; then
        WS_CMD="webstorm"
    elif [[ "$OS" == "mac" ]] && [[ -f "/usr/local/bin/webstorm" ]]; then
        WS_CMD="/usr/local/bin/webstorm"
    elif [[ "$OS" == "mac" ]] && [[ -f "$HOME/Library/Application Support/JetBrains/Toolbox/scripts/webstorm" ]]; then
        WS_CMD="$HOME/Library/Application Support/JetBrains/Toolbox/scripts/webstorm"
    fi

    if [[ -n "$WS_CMD" ]]; then
        info "Installing Claude Code plugin for WebStorm..."
        "$WS_CMD" installPlugins "$PLUGIN_ID" 2>/dev/null && \
            success "Claude Code WebStorm plugin installed." || \
            warn "Automatic plugin install failed. See manual steps below."
    fi

    # Always show manual instructions as a fallback / confirmation
    echo ""
    info "To verify or manually install the Claude Code plugin in WebStorm:"
    echo "  1. Open WebStorm"
    if [[ "$OS" == "mac" ]]; then
        echo "  2. Go to WebStorm -> Settings -> Plugins  (or Cmd+,)"
    else
        echo "  2. Go to File -> Settings -> Plugins  (or Ctrl+Alt+S)"
    fi
    echo "  3. Click the 'Marketplace' tab"
    echo "  4. Search for 'Claude Code'"
    echo "  5. Click 'Install' on the Anthropic plugin"
    echo "  6. Restart WebStorm when prompted"
}

# --- Helper: check if WebStorm is installed -----------------------------------
webstorm_is_installed() {
    command -v webstorm &>/dev/null && return 0
    [[ "$OS" == "mac" ]] && [[ -d "/Applications/WebStorm.app" ]] && return 0
    [[ "$OS" == "linux" ]] && command -v snap &>/dev/null && snap list webstorm &>/dev/null 2>&1 && return 0
    return 1
}

# --- Banner -------------------------------------------------------------------
OS_LABEL="macOS"
[[ "$OS" == "linux" ]] && OS_LABEL="Linux ($PKG_MGR)"

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Vibe Coding Incubator — Setup (Lesson 1)          ║${NC}"
echo -e "${BOLD}║   Detected OS: $(printf '%-38s' "$OS_LABEL")║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}\n"
info "This script will install everything you need for the course."
[[ "$OS" == "mac" ]]   && info "You may be prompted for your Mac password during installation."
[[ "$OS" == "linux" ]] && info "You may be prompted for your sudo password during installation."
echo ""

# --- Paid Account Notice ------------------------------------------------------
echo -e "${YELLOW}${BOLD}IMPORTANT: Claude Code requires a paid Claude account to work.${NC}"
echo ""
echo "  The free tier is NOT enough for real development work."
echo "  You need one of the following:"
echo ""
echo -e "    ${BOLD}Pro Plan${NC}   — \$20/month  (good for learning & small projects)"
echo -e "    ${BOLD}Max Plan${NC}   — \$100/month (recommended for serious building)"
echo -e "    ${BOLD}API / Console${NC} — Pay-per-token at platform.claude.com"
echo ""
echo -e "  Sign up or upgrade here: ${BOLD}https://claude.ai/upgrade${NC}"
echo ""
read -rp "Press Enter to continue (or Ctrl+C to cancel)..." </dev/tty
echo ""

# --- IDE Selection Prompt -----------------------------------------------------
echo -e "${BOLD}Which code editor would you like to install?${NC}"
echo ""
echo "  1) VS Code         — Free. Recommended for beginners."
echo "  2) WebStorm         — By JetBrains. Requires a license (30-day free trial)."
echo "  3) Both             — Install VS Code and WebStorm."
echo ""

IDE_CHOICE=""
while [[ -z "$IDE_CHOICE" ]]; do
    read -rp "Enter your choice (1, 2, or 3): " IDE_INPUT </dev/tty
    case "$IDE_INPUT" in
        1) IDE_CHOICE="vscode" ;;
        2) IDE_CHOICE="webstorm" ;;
        3) IDE_CHOICE="both" ;;
        *) warn "Please enter 1, 2, or 3." ;;
    esac
done

INSTALL_VSCODE=false
INSTALL_WEBSTORM=false
case "$IDE_CHOICE" in
    vscode)    INSTALL_VSCODE=true ;;
    webstorm)  INSTALL_WEBSTORM=true ;;
    both)      INSTALL_VSCODE=true; INSTALL_WEBSTORM=true ;;
esac

IDE_LABEL="VS Code"
$INSTALL_WEBSTORM && IDE_LABEL="WebStorm"
$INSTALL_VSCODE && $INSTALL_WEBSTORM && IDE_LABEL="VS Code + WebStorm"

echo ""
success "Selected: $IDE_LABEL"

# ==============================================================================
# INSTALLATION STEPS (SOP order: package manager, Node.js, Git, IDE, plugin, CLI)
# ==============================================================================

# --- 1. Package Manager (Mac: Homebrew / Linux: already detected) -------------
step "1/7  Package Manager"
if [[ "$OS" == "mac" ]]; then
    if command -v brew &>/dev/null; then
        success "Homebrew already installed: $(brew --version | head -1)"
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add to PATH immediately + persist for future shells
        if [[ -f /opt/homebrew/bin/brew ]]; then
            # Apple Silicon Mac
            eval "$(/opt/homebrew/bin/brew shellenv)"
            if ! grep -q '/opt/homebrew/bin/brew' "$SHELL_RC" 2>/dev/null; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
            fi
        elif [[ -f /usr/local/bin/brew ]]; then
            # Intel Mac
            eval "$(/usr/local/bin/brew shellenv)"
            if ! grep -q '/usr/local/bin/brew' "$SHELL_RC" 2>/dev/null; then
                echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_RC"
            fi
        fi
        refresh_path
        if command -v brew &>/dev/null; then
            success "Homebrew installed: $(brew --version | head -1)"
        else
            fail "Homebrew installed but 'brew' not found on PATH. Close and reopen terminal, then re-run."
            exit 1
        fi
    fi
else
    success "Using system package manager: $PKG_MGR"
fi

# --- 2. Node.js (SOP 3.1) ----------------------------------------------------
step "2/7  Node.js (for your projects — not required by Claude Code)"
if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if (( NODE_MAJOR >= 18 )); then
        success "Node.js already installed: $NODE_VER"
    else
        warn "Node.js $NODE_VER is too old (need v18+). Upgrading..."
        install_nodejs
        if command -v node &>/dev/null; then
            success "Node.js upgraded: $(node --version)"
        else
            warn "Node.js upgrade may need a terminal restart to take effect."
        fi
    fi
else
    info "Installing Node.js LTS..."
    install_nodejs
    if command -v node &>/dev/null; then
        success "Node.js installed: $(node --version)"
    else
        warn "Node.js installed but not yet on PATH. You may need to restart your terminal."
    fi
fi

# --- 3. Git -------------------------------------------------------------------
step "3/7  Git"
if command -v git &>/dev/null; then
    success "Git already installed: $(git --version)"
else
    info "Installing Git..."
    pkg_install git
    if command -v git &>/dev/null; then
        success "Git installed: $(git --version)"
    else
        fail "Git installation failed. Please install manually."
    fi
fi

# --- 4. IDE Installation (SOP 3.2) -------------------------------------------
step "4/7  Code Editor"

if $INSTALL_VSCODE; then
    if command -v code &>/dev/null; then
        success "VS Code already installed: $(code --version | head -1)"
    else
        info "Installing VS Code..."
        install_vscode
        if command -v code &>/dev/null; then
            success "VS Code installed: $(code --version | head -1)"
        else
            if [[ "$OS" == "mac" ]]; then
                warn "VS Code installed but 'code' command not found."
                warn "Open VS Code -> Cmd+Shift+P -> 'Shell Command: Install code command in PATH'"
            else
                warn "VS Code installed but 'code' command not found. You may need to restart your terminal."
            fi
        fi
    fi
fi

if $INSTALL_WEBSTORM; then
    if webstorm_is_installed; then
        success "WebStorm already installed."
    else
        info "Installing WebStorm..."
        install_webstorm
        if webstorm_is_installed; then
            success "WebStorm installed."
        else
            warn "WebStorm installed. You may need to restart your terminal or launch it from the Applications folder."
        fi
    fi
fi

# --- 5. Claude Code IDE Plugin (SOP 3.3) -------------------------------------
step "5/7  Claude Code IDE Plugin"

if $INSTALL_VSCODE; then
    install_vscode_claude_extension
fi

if $INSTALL_WEBSTORM; then
    install_webstorm_claude_plugin
fi

# --- 6. Claude Code CLI (SOP 3.4) --------------------------------------------
step "6/7  Claude Code CLI"
if command -v claude &>/dev/null; then
    success "Claude Code CLI already installed: $(claude --version 2>/dev/null || echo 'installed')"
else
    info "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash || true

    # The installer adds ~/.local/bin to the shell RC file.
    # Refresh PATH so we can verify the install immediately.
    refresh_path

    if command -v claude &>/dev/null; then
        success "Claude Code CLI installed: $(claude --version 2>/dev/null || echo 'installed')"
    else
        warn "CLI installed but not yet on PATH. Attempting to fix..."
        # Ensure ~/.local/bin is persisted in shell RC as a fallback
        persist_path_dir '$HOME/.local/bin' '.local/bin'
        refresh_path
        if command -v claude &>/dev/null; then
            success "Claude Code CLI now on PATH: $(claude --version 2>/dev/null || echo 'installed')"
        else
            fail "CLI installed but not on PATH. Close and reopen your terminal, then run: claude --version"
        fi
    fi
fi

# --- 7. Verification ---------------------------------------------------------
step "7/7  Verification"

# Final PATH refresh to catch everything
refresh_path

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              Verification Summary                    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"

PASS=0
TOTAL=0

verify_pass()  { success "$1"; ((PASS++)); ((TOTAL++)); }
verify_fail()  { fail "$1";                ((TOTAL++)); }
verify_warn()  { warn "$1";                ((TOTAL++)); }

# -- Git
if command -v git &>/dev/null; then
    verify_pass "Git: $(git --version)"
else
    verify_fail "Git: NOT FOUND"
fi

# -- Node.js (must be v18+)
if command -v node &>/dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if (( NODE_MAJOR >= 18 )); then
        verify_pass "Node.js: $NODE_VER"
    else
        verify_fail "Node.js: $NODE_VER (need v18+, run: brew install node)"
    fi
else
    verify_fail "Node.js: NOT FOUND"
fi

# -- VS Code
if $INSTALL_VSCODE; then
    if command -v code &>/dev/null; then
        verify_pass "VS Code: $(code --version 2>/dev/null | head -1)"
    else
        verify_fail "VS Code: NOT FOUND"
    fi

    if command -v code &>/dev/null && code --list-extensions 2>/dev/null | grep -qi "anthropic"; then
        verify_pass "Claude Code VS Code Extension: installed"
    else
        verify_fail "Claude Code VS Code Extension: NOT FOUND"
    fi
fi

# -- WebStorm
if $INSTALL_WEBSTORM; then
    if webstorm_is_installed; then
        verify_pass "WebStorm: installed"
    else
        verify_fail "WebStorm: NOT FOUND"
    fi

    verify_warn "Claude Code WebStorm Plugin: verify manually (Settings -> Plugins -> search 'Claude Code')"
fi

# -- Claude CLI
if command -v claude &>/dev/null; then
    verify_pass "Claude Code CLI: $(claude --version 2>/dev/null || echo 'installed')"
else
    verify_fail "Claude Code CLI: NOT FOUND"
fi

# -- PATH persistence check
if grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
    verify_pass "PATH: ~/.local/bin persisted in $SHELL_RC"
else
    # If claude is available via another persistent PATH (e.g., Homebrew), that's fine
    claude_path="$(command -v claude 2>/dev/null || true)"
    if [[ -n "$claude_path" && "$claude_path" != *".local/bin"* ]]; then
        verify_pass "PATH: claude available via $claude_path (no ~/.local/bin needed)"
    else
        verify_fail "PATH: ~/.local/bin not found in $SHELL_RC (claude may not work in new terminals)"
        warn "  Fix: Add this line to $SHELL_RC:"
        warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

# -- claude doctor
if command -v claude &>/dev/null; then
    echo ""
    info "Running claude doctor..."
    claude doctor 2>&1 || warn "claude doctor reported issues — review the output above."
fi

echo ""
if (( PASS == TOTAL )); then
    echo -e "${GREEN}${BOLD}All $TOTAL/$TOTAL checks passed!${NC}"
else
    echo -e "${YELLOW}${BOLD}$PASS/$TOTAL checks passed.${NC} See warnings above."
fi

# -- Manual GUI checks reminder
if $INSTALL_VSCODE; then
    echo ""
    warn "MANUAL CHECK: Open VS Code and verify the Spark icon is visible in the toolbar/sidebar"
    warn "MANUAL CHECK: Click the Spark icon to confirm the Claude Code panel opens"
fi

# --- Authentication (SOP 3.5) ------------------------------------------------
echo ""
echo -e "${BOLD}Authentication:${NC}"
echo "  Claude Code requires you to sign in with your Claude account."
echo ""
read -rp "Would you like to authenticate now? (y/n): " AUTH_INPUT </dev/tty
if [[ "$AUTH_INPUT" =~ ^[Yy]$ ]]; then
    info "Launching Claude Code... Your browser will open for sign-in."
    info "Return here after signing in."
    claude 2>/dev/null || warn "Authentication launch failed. Run 'claude' manually in a new terminal."
else
    echo ""
    info "Skipping authentication. Run 'claude' in your terminal when ready."
fi

# --- Next Steps ---------------------------------------------------------------
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo "  1. Close and reopen your terminal (to pick up PATH changes)"
echo "  2. Run:  claude --version   (confirm it works in a new terminal)"
echo "  3. Run:  claude doctor      (check for issues)"
if $INSTALL_VSCODE; then
    echo "  4. Open VS Code, click the Spark icon, and send your first prompt"
fi
if $INSTALL_WEBSTORM; then
    echo "  4. Open WebStorm, verify the Claude Code plugin is installed (Settings -> Plugins)"
fi
echo ""
echo -e "${BOLD}You're ready for Lesson 2!${NC}"
echo ""
