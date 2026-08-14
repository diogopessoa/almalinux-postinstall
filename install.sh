#!/usr/bin/env bash

# Descrição: Script pessoal de configuração do AlmaLinux 10 Atomic
# Author: Diogo Pessoa
# Versão: 1.0
# GitHub: https://github.com/diogopessoa/almalinux-postinstall/

set -Eeuo pipefail
export SYSTEMD_PAGER=""
export NONINTERACTIVE=1

# ============================================================
# FUNÇÕES DE LOG E CORES
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }

# ---------------- Verificação de Usuário ----------------
if [[ $EUID -eq 0 ]]; then
    echo "Não execute este script como root: ./install.sh"
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
# VARIÁVEIS DE STATUS
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
echo -e "${BLUE}╰────────────────────────────────────╯${NC}\n"

# ============================================================
# HOMEBREW
# ============================================================
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [[ ! -x "$BREW_BIN" ]]; then
    info "Instalando Homebrew..."

    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        && [[ -x "$BREW_BIN" ]]; then
        status_brew="${GREEN} ✓${NC}"
        success "Homebrew instalado"
    else
        warning "Não foi possível instalar o Homebrew em $BREW_BIN"
    fi
else
    status_brew="${GREEN} ✓${NC}"
    success "Homebrew já instalado"
fi

# Garantir que o ambiente do Brew esteja ativo nesta sessão do script
if [[ -x "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
else
    warning "Homebrew não está disponível; etapas dependentes do Brew serão ignoradas."
fi

# ============================================================
# HOMEBREW AUTO-UPDATE
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Instalando Homebrew Auto-Update..."

    if curl -fsSL https://raw.githubusercontent.com/diogopessoa/brew-update/main/install.sh | bash; then
        status_brew_update="${GREEN} ✓${NC}"
        success "Homebrew Auto-Update instalado com sucesso"
    else
        warning "Falha ao instalar o Homebrew Auto-Update"
    fi
fi

# ============================================================
# DISTROBOX CONTAINERS AUTO-UPDATE
# ============================================================
info "Instalando Distrobox Containers Auto-Update..."

if curl -fsSL https://raw.githubusercontent.com/diogopessoa/distrobox-upgrade/main/distrobox-upgrade.sh | bash; then
    status_distrobox_upgrade="${GREEN} ✓${NC}"
    success "Distrobox Containers Auto-Update instalado com sucesso"
else
    warning "Falha ao instalar o Distrobox Containers Auto-Update"
fi

# ============================================================
# INSTALAÇÃO ZSH + STARSHIP + PLUGINS (VIA HOMEBREW)
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Instalando Zsh, Starship e plugins via Homebrew..."

    if brew install -y zsh starship zsh-syntax-highlighting zsh-autosuggestions; then
        status_zsh_packages="${GREEN} ✓${NC}"
        success "Pacotes do Zsh e Starship instalados"
    else
        warning "Falha ao instalar Zsh, Starship ou plugins"
    fi
else
    warning "Zsh, Starship e plugins não foram instalados porque o Homebrew não está disponível"
fi

# ============================================================
# CONFIGURAÇÃO DO ~/.zshrc
# ============================================================
info "Configurando o arquivo ~/.zshrc..."

cat << 'EOF' > "$HOME/.zshrc"
# ============================================================
# MENSAGEM DE BOAS-VINDAS DO ZSH
if [[ -o interactive ]]; then
    echo "\033[1;32m>_ Zsh\033[0m está pronto!"
    echo ""
fi

# ============================================================
# HOMEBREW ENV
# ============================================================
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ============================================================
# INTERPRETA # COMO COMENTÁRIO MESMO EM MODO INTERATIVO
# ============================================================
setopt INTERACTIVE_COMMENTS

# ============================================================
# ALIASES (DISTROBOX & SISTEMA)
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
# PLUGINS DO ZSH (A ORDEM DE CARREGAMENTO É CRUCIAL!)
# ============================================================
BREW_SHARE="/home/linuxbrew/.linuxbrew/share"

# 1. Autosuggestions
if [ -f "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$BREW_SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# 2. Syntax Highlighting (DEVE SER O ÚLTIMO!)
if [ -f "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
EOF

status_zshrc="${GREEN} ✓${NC}"
success "Arquivo ~/.zshrc gerado com sucesso"

# ============================================================
# DEFINIR ZSH DO BREW COMO SHELL PADRÃO
# ============================================================
BREW_ZSH="/home/linuxbrew/.linuxbrew/bin/zsh"

if [[ -x "$BREW_ZSH" ]]; then
    info "Definindo Zsh do Homebrew como Shell padrão do usuário..."

    if grep -Fxq "$BREW_ZSH" /etc/shells 2>/dev/null; then
        success "Caminho $BREW_ZSH já está em /etc/shells"
    else
        if echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null; then
            success "Caminho $BREW_ZSH adicionado ao /etc/shells"
        else
            warning "Não foi possível adicionar $BREW_ZSH ao /etc/shells"
        fi
    fi

    if sudo usermod --shell "$BREW_ZSH" "$USER"; then
        # Reseta comando customizado do Ptyxis se existir
        gsettings reset org.gnome.Ptyxis default-profile-command 2>/dev/null || true
        status_default_shell="${GREEN} ✓${NC}"
        success "Shell padrão alterado para Zsh"
    else
        warning "Não foi possível alterar o shell padrão para Zsh"
    fi
else
    warning "Zsh do Homebrew não está disponível; shell padrão não foi alterado"
fi

# ============================================================
# INTEGRAÇÃO HOMEBREW + BASH
# ============================================================
if [[ -x "$BREW_BIN" ]]; then
    info "Configurando Homebrew para Bash..."

    if sudo tee /etc/profile.d/homebrew.sh >/dev/null << 'EOF'
# Homebrew (AlmaLinux Atomic)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF
    then
        status_brew_bash="${GREEN} ✓${NC}"
        success "Integração Homebrew/Bash criada"
    else
        warning "Não foi possível criar a integração Homebrew/Bash"
    fi
fi

# ============================================================
# DISABLE NETWORK WAIT-ONLINE
# ============================================================
info "Desativando NetworkManager-wait-online.service..."

if sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null; then
    status_network="${GREEN} ✓${NC}"
    success "NetworkManager-wait-online.service desativado"
else
    warning "Não foi possível desativar NetworkManager-wait-online.service"
fi

# ============================================================
# OFFICE FONTS
# ============================================================
info "Instalando Office Fonts..."

FONTS_DIR="$HOME/.local/share/fonts/office_fonts"
TMP_ZIP="/tmp/office_fonts.zip"

mkdir -p "$FONTS_DIR"

if curl -fsSL \
    https://raw.githubusercontent.com/diogopessoa/my-packages-lists/main/silverblue/office_fonts.zip \
    -o "$TMP_ZIP" \
    && python3 -c "import zipfile; zipfile.ZipFile('$TMP_ZIP').extractall('$FONTS_DIR')" \
    && fc-cache -f "$HOME/.local/share/fonts"; then

    status_fonts="${GREEN} ✓${NC}"
    success "Fontes instaladas"
else
    warning "Falha ao instalar as Office Fonts"
fi

rm -f "$TMP_ZIP"

# ============================================================
# HATTER ICONS THEME
# ============================================================
info "Instalando Hatter Icons Theme..."

ICONS_DIR="$HOME/.local/share/icons"
HATTER_DIR="/tmp/Hatter_clone"

rm -rf "$HATTER_DIR"

if git clone --depth 1 https://github.com/Mibea/Hatter.git "$HATTER_DIR" 2>/dev/null \
    && mkdir -p "$ICONS_DIR" \
    && rm -rf "$ICONS_DIR/Hatter" \
    && cp -r "$HATTER_DIR/Hatter" "$ICONS_DIR/"; then

    gtk-update-icon-cache -f "$ICONS_DIR/Hatter" 2>/dev/null || true
    status_icons="${GREEN} ✓${NC}"
    success "Tema de ícones Hatter instalado"
else
    warning "Falha ao instalar o tema de ícones Hatter"
fi

rm -rf "$HATTER_DIR"

# ============================================================
# BOOTC MANAGER
# ============================================================
info "Instalando Bootc Manager..."

if curl -fsSL https://raw.githubusercontent.com/diogopessoa/bootc-manager/main/install.sh | bash; then
    status_bootc_manager="${GREEN} ✓${NC}"
    success "Bootc Manager instalado com sucesso"
else
    warning "Falha ao instalar o Bootc Manager"
fi

# ============================================================
# FLATHUB E PACOTES FLATPAK
# ============================================================
info "Configurando Flathub..."

if sudo flatpak config --system --set languages "pt" \
    && sudo flatpak remote-add \
        --if-not-exists \
        --system \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo; then

    lista_apps=(
        com.brave.Browser
        com.mattjakeman.ExtensionManager
        io.github.kolunmi.Bazaar
        io.github.thetumultuousunicornofdarkness.cpu-x
        net.nokyan.Resources
        org.gnome.SimpleScan
        org.localsend.localsend_app
        page.codeberg.libre_menu_editor.LibreMenuEditor
        page.tesk.Refine
    )

    if sudo flatpak install --system --assumeyes flathub "${lista_apps[@]}"; then
        status_flatpak="${GREEN} ✓${NC}"
        success "Flatpaks instalados"
    else
        warning "Falha ao instalar um ou mais Flatpaks"
    fi
else
    warning "Não foi possível configurar o Flathub"
fi

# ============================================================
# PAINEL RESUMO DE STATUS
# ============================================================
echo -e "\n"
echo "▶ Sumário de Modificações:"
echo -e " $status_brew Homebrew"
echo -e " $status_brew_update Homebrew Auto-Update"
echo -e " $status_distrobox_upgrade Distrobox Auto-Update"
echo -e " $status_zsh_packages Zsh + Starship + Plugins (Brew)"
echo -e " $status_zshrc Configuração ~/.zshrc"
echo -e " $status_default_shell Zsh definido como Shell Padrão"
echo -e " $status_brew_bash Integração Homebrew/Bash"
echo -e " $status_network Network wait-online desativado"
echo -e " $status_fonts Office Fonts"
echo -e " $status_icons Hatter Icons Theme"
echo -e " $status_bootc_manager Bootc Manager"
echo -e " $status_flatpak Apps Flatpak instalados"
echo ""
echo -e "${BLUE}${BOLD}Tudo pronto! Reinicie o sistema para aplicar as mudanças.${NC}"
read -rp "Pressione Enter para encerrar..."
echo ""
