#!/usr/bin/env bash

# Description: Personal AlmaLinux 10 Atomic configuration script
# Author: Diogo Pessoa
# Version: 1.0
# GitHub: https://github.com/diogopessoa/almalinux-postinstall/

set -Eeuo pipefail
export SYSTEMD_PAGER=""
export NONINTERACTIVE=1

# ============================================================
# LOGGING AND COLOR FUNCTIONS
# ============================================================
RED='\u001B[0;31m'
GREEN='\u001B[0;32m'
BLUE='\u001B[0;34m'
YELLOW='\u001B[1;33m'
BOLD='\u001B[1m'
NC='\u001B[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# ---------------- User Check ----------------
if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script as root: ./install.sh"
    exit 1
fi

# ============================================================
# SUDO KEEP-ALIVE
# ============================================================
sudo -v

while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ============================================================
# STATUS VARIABLES
# ============================================================
status_brew="${RED} ✗${NC}"
status_brew_update="${RED} ✗${NC}"
status_distrobox_upgrade="${RED} ✗${NC}"
status_zsh_packages="${RED} ✗${NC}"
status_zshrc="${RED} ✗${NC}"
status_default_shell="${RED} ✗${NC}"
status_brew_bash="${RED} ✗${NC}"
status_network="${RED} ✗${NC}"
status_fonts="${RED} ✗${NC}"
status_icons="${RED} ✗${NC}"
status_bootc_manager="${RED} ✗${NC}"
status_flatpak="${RED} ✗${NC}"

echo -e "${BLUE}╭────────────────────────────────────╮${NC}"
echo -e "${GREEN}│  ${BOLD}AlmaLinux Postinstall ${NC}${GREEN}  │${NC}"
echo -e "${BLUE}╰────────────────────────────────────╯${NC}
"

# ============================================================
# HOMEBREW
# ============================================================
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [[ ! -x "$BREW_BIN" ]]; then
    info "Installing Homebrew..."

    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        && [[ -x "$BREW_BIN" ]]; then
        status_brew="${GREEN} ✓${NC}"
        success "Homebrew installed"
    else
        warning "Could not install Homebrew at $BREW_BIN"
    fi
else
    status_brew="${GREEN} ✓${NC}"
    success "Homebrew is already installed"
fi

# Ensure that the Brew environment is active in this script session
if [[ -x "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
else
    warning "Homebrew is not available; Brew-dependent steps will be skipped."
fi

# ============================================================
# HOMEBREW AUTO-UPDATE
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Installing Homebrew Auto-Update..."

    if curl -fsSL https://raw.githubusercontent.com/diogopessoa/brew-update/main/install.sh | bash; then
        status_brew_update="${GREEN} ✓${NC}"
        success "Homebrew Auto-Update installed successfully"
    else
        warning "Failed to install Homebrew Auto-Update"
    fi
fi

# ============================================================
# DISTROBOX CONTAINERS AUTO-UPDATE
# ============================================================
info "Installing Distrobox Containers Auto-Update..."

if curl -fsSL https://raw.githubusercontent.com/diogopessoa/distrobox-upgrade/main/distrobox-upgrade.sh | bash; then
    status_distrobox_upgrade="${GREEN} ✓${NC}"
    success "Distrobox Containers Auto-Update installed successfully"
else
    warning "Failed to install Distrobox Containers Auto-Update"
fi

# ============================================================
# ZSH + STARSHIP + PLUGINS INSTALLATION (VIA HOMEBREW)
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Installing Zsh, Starship, and plugins via Homebrew..."

    if brew install -y zsh starship zsh-syntax-highlighting zsh-autosuggestions; then
        status_zsh_packages="${GREEN} ✓${NC}"
        success "Zsh and Starship packages installed"
    else
        warning "Failed to install Zsh, Starship, or plugins"
    fi
else
    warning "Zsh, Starship, and plugins were not installed because Homebrew is unavailable"
fi

# ============================================================
# CONFIGURATION OF ~/.zshrc
# ============================================================
info "Configuring the ~/.zshrc file..."

cat << 'EOF' > "$HOME/.zshrc"
# ============================================================
# ZSH WELCOME MESSAGE
if [[ -o interactive ]]; then
    echo "\u001B[1;32m>_ Zsh\u001B[0m is ready!"
    echo ""
fi

# ============================================================
# HOMEBREW ENVIRONMENT
# ============================================================
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ============================================================
# TREAT # AS A COMMENT EVEN IN INTERACTIVE MODE
# ============================================================
setopt INTERACTIVE_COMMENTS

# ============================================================
# ALIASES (DISTROBOX AND SYSTEM)
# ============================================================
alias apt="distrobox enter ubuntu -- sudo apt"
alias dnf="distrobox enter fedora -- sudo dnf"

# ============================================================
# STARSHIP PROMPT
# ============================================================
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ============================================================
# ZSH PLUGINS (LOADING ORDER IS CRUCIAL!)
# ============================================================
BREW_SHARE="/home/linuxbrew/.linuxbrew/share"

# 1. Autosuggestions
if [ -f "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# 2. Syntax Highlighting (MUST BE LOADED LAST!)
if [ -f "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
EOF

status_zshrc="${GREEN} ✓${NC}"
success "~/.zshrc file generated successfully"

# ============================================================
# SET BREW'S ZSH AS THE DEFAULT SHELL
# ============================================================
BREW_ZSH="/home/linuxbrew/.linuxbrew/bin/zsh"

if [[ -x "$BREW_ZSH" ]]; then
    info "Setting Homebrew's Zsh as the user's default shell..."

    if grep -Fxq "$BREW_ZSH" /etc/shells 2>/dev/null; then
        success "Path $BREW_ZSH is already in /etc/shells"
    else
        if echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null; then
            success "Path $BREW_ZSH added to /etc/shells"
        else
            warning "Could not add $BREW_ZSH to /etc/shells"
        fi
    fi

    if sudo usermod --shell "$BREW_ZSH" "$USER"; then
        # Reset Ptyxis custom command if it exists
        gsettings reset org.gnome.Ptyxis default-profile-command 2>/dev/null || true
        status_default_shell="${GREEN} ✓${NC}"
        success "Default shell changed to Zsh"
    else
        warning "Could not change the default shell to Zsh"
    fi
else
    warning "Homebrew's Zsh is unavailable; the default shell was not changed"
fi

# ============================================================
# HOMEBREW + BASH INTEGRATION
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Configuring Homebrew for Bash..."

    if sudo tee /etc/profile.d/homebrew.sh >/dev/null << 'EOF'
# Homebrew (AlmaLinux Atomic)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF
    then
        status_brew_bash="${GREEN} ✓${NC}"
        success "Homebrew/Bash integration created"
    else
        warning "Could not create the Homebrew/Bash integration"
    fi
fi

# ============================================================
# DISABLE NETWORK WAIT-ONLINE
# ============================================================
info "Disabling NetworkManager-wait-online.service..."

if sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null; then
    status_network="${GREEN} ✓${NC}"
    success "NetworkManager-wait-online.service disabled"
else
    warning "Could not disable NetworkManager-wait-online.service"
fi

# ============================================================
# OFFICE FONTS
# ============================================================
info "Installing Office Fonts..."

FONTS_DIR="$HOME/.local/share/fonts/office_fonts"
TMP_ZIP="/tmp/office_fonts.zip"

mkdir -p "$FONTS_DIR"

if curl -fsSL \
    https://raw.githubusercontent.com/diogopessoa/my-packages-lists/main/silverblue/office_fonts.zip \
    -o "$TMP_ZIP" \
    && python3 -c "import zipfile; zipfile.ZipFile('$TMP_ZIP').extractall('$FONTS_DIR')" \
    && fc-cache -f "$HOME/.local/share/fonts"; then

    status_fonts="${GREEN} ✓${NC}"
    success "Fonts installed"
else
    warning "Failed to install the Office Fonts"
fi

rm -f "$TMP_ZIP"

# ============================================================
# HATTER ICONS THEME
# ============================================================
info "Installing the Hatter Icons Theme..."

ICONS_DIR="$HOME/.local/share/icons"
HATTER_DIR="/tmp/Hatter_clone"

rm -rf "$HATTER_DIR"

if git clone --depth 1 https://github.com/Mibea/Hatter.git "$HATTER_DIR" 2>/dev/null \
    && mkdir -p "$ICONS_DIR" \
    && rm -rf "$ICONS_DIR/Hatter" \
    && cp -r "$HATTER_DIR/Hatter" "$ICONS_DIR/"; then

    gtk-update-icon-cache -f "$ICONS_DIR/Hatter" 2>/dev/null || true
    status_icons="${GREEN} ✓${NC}"
    success "Hatter icon theme installed"
else
    warning "Failed to install the Hatter icon theme"
fi

rm -rf "$HATTER_DIR"

# ============================================================
# BOOTC MANAGER
# ============================================================
info "Installing Bootc Manager..."

if curl -fsSL https://raw.githubusercontent.com/diogopessoa/bootc-manager/main/install.sh | bash; then
    status_bootc_manager="${GREEN} ✓${NC}"
    success "Bootc Manager installed successfully"
else
    warning "Failed to install Bootc Manager"
fi

# ============================================================
# FLATHUB AND FLATPAK PACKAGES
# ============================================================
info "Configuring Flathub..."

if sudo flatpak config --system --set languages "pt" \
    && sudo flatpak remote-add \
        --if-not-exists \
        --system \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo; then

    app_list=(
        com.mattjakeman.ExtensionManager
        io.github.kolunmi.Bazaar
        io.github.thetumultuousunicornofdarkness.cpu-x
        org.gnome.SimpleScan
        org.localsend.localsend_app
        page.codeberg.libre_menu_editor.LibreMenuEditor
        page.tesk.Refine
    )

    if sudo flatpak install --system --assumeyes flathub "${app_list[@]}"; then
        status_flatpak="${GREEN} ✓${NC}"
        success "Flatpaks installed"
    else
        warning "Failed to install one or more Flatpaks"
    fi
else
    warning "Could not configure Flathub"
fi

# ============================================================
# STATUS SUMMARY PANEL
# ============================================================
echo -e "
"
echo "▶ Modification Summary:"
echo -e " $status_brew Homebrew"
echo -e " $status_brew_update Homebrew Auto-Update"
echo -e " $status_distrobox_upgrade Distrobox Auto-Update"
echo -e " $status_zsh_packages Zsh + Starship + Plugins (Brew)"
echo -e " $status_zshrc ~/.zshrc Configuration"
echo -e " $status_default_shell Zsh Set as Default Shell"
echo -e " $status_brew_bash Homebrew/Bash Integration"
echo -e " $status_network Network wait-online Disabled"
echo -e " $status_fonts Office Fonts"
echo -e " $status_icons Hatter Icons Theme"
echo -e " $status_bootc_manager Bootc Manager"
echo -e " $status_flatpak Flatpak Apps Installed"
echo ""
echo -e "${BLUE}${BOLD}Everything is ready! Restart the system to apply the changes.${NC}"
read -rp "Press Enter to exit..."
echo ""
