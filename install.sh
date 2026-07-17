#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/AstralZX/My-Dots.git"
DOTFILES_DIR="$HOME/My-Dots"
PEACHWM_REPO="https://github.com/HuntedByTheIRS/peachwm.git"
SCENEFX_REPO="https://github.com/wlrfx/scenefx.git"
BUILD_DIR="/tmp/my-dots-build"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root."
    fi
}

detect_distro() {
    if [[ -f /etc/cachyos-release ]]; then
        DISTRO="cachyos"
    elif [[ -f /etc/artix-release ]]; then
        DISTRO="artix"
    elif command -v pacman &>/dev/null; then
        DISTRO="arch"
    else
        error "This script supports Arch-based distros only. For NixOS, use install-nixos.sh."
    fi
    info "Detected distro: $DISTRO"
}

install_packages() {
    info "Installing system packages..."

    local pkgs=(
        # Build essentials
        base-devel pkg-config clang lld meson ninja cmake

        # Wayland / WM deps
        wayland libinput xkbcommon wayland-protocols
        wlroots

        # Desktop apps
        kitty rofi waybar mako flameshot mpvpaper
        thunar exo

        # Media
        ffmpeg playerctl wireplumber

        # System
        brightnessctl networkmanager bluez bluez-utils
        polkit-gnome xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        lm_sensors pacman-contrib less bc iproute2 procps-ng

        # Terminal / shell
        zsh bat neovim python python-pip

        # Fonts
        ttf-jetbrains-mono-nerd

        # Cursor
        bibata-cursor-theme

        # Misc
        curl git
    )

    if [[ "$DISTRO" == "cachyos" ]]; then
        pkgs+=(scenefx-wlroots20-git)
    fi

    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_pacman_aur_helper() {
    if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
        info "No AUR helper found. Installing paru..."
        cd "$BUILD_DIR"
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin
        makepkg -si --noconfirm
        cd "$HOME"
    fi
}

install_aur_packages() {
    info "Installing AUR packages..."

    local aur_pkgs=(
        pfetch
        zsh-autosuggestions
        zsh-syntax-highlighting
        spicetify-cli
    )

    if command -v paru &>/dev/null; then
        paru -S --needed --noconfirm "${aur_pkgs[@]}"
    elif command -v yay &>/dev/null; then
        yay -S --needed --noconfirm "${aur_pkgs[@]}"
    else
        warn "No AUR helper available. Skipping AUR packages."
        warn "Install manually: ${aur_pkgs[*]}"
    fi
}

install_starship() {
    if ! command -v starship &>/dev/null; then
        info "Installing starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
        info "starship already installed."
    fi
}

build_scenefx() {
    if [[ "$DISTRO" == "cachyos" ]]; then
        info "SceneFX installed via CachyOS repo, skipping build."
        return
    fi

    if pkg-config --exists scenefx-0.5 2>/dev/null; then
        info "SceneFX 0.5 already installed."
        return
    fi

    info "Building SceneFX from source (wlroots 0.20 compatible)..."
    cd "$BUILD_DIR"
    rm -rf scenefx
    git clone "$SCENEFX_REPO"
    cd scenefx
    meson setup build --prefix=/usr/local
    ninja -C build
    sudo ninja -C build install

    # Fix pkg-config search path on Arch
    sudo ln -sf /usr/local/lib/pkgconfig/scenefx-0.5.pc /usr/lib/pkgconfig/scenefx-0.5.pc 2>/dev/null || true
    sudo ln -sf /usr/local/lib/libscenefx-0.5.so /usr/lib/libscenefx-0.5.so 2>/dev/null || true
    sudo ldconfig

    info "SceneFX installed."
}

build_peachwm() {
    if command -v peachwm &>/dev/null; then
        info "peachwm already installed."
        return
    fi

    info "Building peachWM..."
    cd "$BUILD_DIR"
    rm -rf peachwm
    git clone "$PEACHWM_REPO"
    cd peachwm
    make release -j$(nproc)
    sudo make install

    info "peachWM installed to /usr/local/bin/peachwm"
}

install_python_deps() {
    info "Installing Python dependencies..."
    pip3 install --user --upgrade PyQt6 Pillow 2>/dev/null || {
        warn "pip3 install failed, trying pip..."
        pip install --user --upgrade PyQt6 Pillow 2>/dev/null || warn "Could not install Python packages automatically."
    }
}

setup_configs() {
    info "Setting up configuration files..."

    # Ensure config directories exist
    mkdir -p "$HOME/.config/peachwm"
    mkdir -p "$HOME/.config/kitty"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/waybar/scripts"
    mkdir -p "$HOME/.config/mako"
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xdg-desktop-portal"
    mkdir -p "$HOME/.local/bin"

    # peachwm
    cp "$DOTFILES_DIR/peachwm/config.lua" "$HOME/.config/peachwm/config.lua"

    # kitty
    cp "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    cp -r "$DOTFILES_DIR/kitty/themes" "$HOME/.config/kitty/"

    # rofi
    cp "$DOTFILES_DIR/rofi/"*.rasi "$HOME/.config/rofi/"

    # waybar
    cp "$DOTFILES_DIR/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
    cp "$DOTFILES_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"
    cp "$DOTFILES_DIR/waybar/scripts/"*.sh "$HOME/.config/waybar/scripts/"
    chmod +x "$HOME/.config/waybar/scripts/"*.sh

    # mako
    cp "$DOTFILES_DIR/mako/config" "$HOME/.config/mako/config"

    # Thunar
    cp "$DOTFILES_DIR/Thunar/"* "$HOME/.config/Thunar/"

    # xdg-desktop-portal
    cp "$DOTFILES_DIR/xdg-desktop-portal/"* "$HOME/.config/xdg-desktop-portal/"

    # selector.py
    cp "$DOTFILES_DIR/selector.py" "$HOME/.local/bin/selector.py"
    chmod +x "$HOME/.local/bin/selector.py"

    # zshrc (backup existing)
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
        warn "Backed up existing .zshrc to .zshrc.bak"
    fi
    cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

    info "Configs installed."
}

setup_zsh() {
    if [[ "$SHELL" != *"zsh"* ]]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
        info "Default shell changed to zsh. Log out and back in for it to take effect."
    else
        info "zsh is already the default shell."
    fi
}

cleanup() {
    info "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}

main() {
    echo ""
    echo "  My-Dots Installer (Arch-based)"
    echo "  =============================="
    echo ""

    check_root
    detect_distro

    mkdir -p "$BUILD_DIR"

    # Clone dotfiles if not already present
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        info "Cloning My-Dots repo..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        info "My-Dots repo already cloned at $DOTFILES_DIR"
        cd "$DOTFILES_DIR" && git pull
    fi

    install_packages
    install_pacman_aur_helper
    install_aur_packages
    install_starship
    build_scenefx
    build_peachwm
    install_python_deps
    setup_configs
    setup_zsh
    cleanup

    echo ""
    info "Installation complete!"
    echo ""
    echo "  Next steps:"
    echo "    1. Log out and select peachwm from your display manager"
    echo "    2. Or run 'peachwm' from a TTY"
    echo "    3. Place wallpapers in ~/Pictures/"
    echo "    4. Edit ~/.config/peachwm/config.lua to customize"
    echo ""
}

main "$@"
