#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/AstralZX/My-Dots.git"
DOTFILES_DIR="$HOME/My-Dots"
PREFIX="/usr/local"
BUILD_DIR="/tmp/my-dots-lfs-build"
LOG_DIR="$BUILD_DIR/logs"
JOBS=$(nproc)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[x]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run as root. The script will use sudo where needed."
    fi
}

check_lfs_tools() {
    info "Checking LFS toolchain..."
    local missing=()
    for cmd in gcc g++ make cmake meson ninja pkg-config git curl wget python3; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing tools: ${missing[*]}"
        warn "Make sure you've built the LFS toolchain and these are in your PATH."
    fi
}

setup_env() {
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64:${LD_LIBRARY_PATH:-}"
    export PATH="$PREFIX/bin:$PATH"
    mkdir -p "$BUILD_DIR" "$LOG_DIR"
}

clone_source() {
    local name="$1" url="$2" rev="${3:-}"
    section "Cloning $name"
    cd "$BUILD_DIR"
    if [[ -d "$name" ]]; then
        cd "$name" && git pull
    else
        git clone "$url" "$name"
    fi
    if [[ -n "$rev" ]]; then
        cd "$name" && git checkout "$rev"
    fi
}

build_and_install() {
    local name="$1"
    shift
    local log="$LOG_DIR/${name}.log"

    section "Building $name"
    cd "$BUILD_DIR/$name"
    rm -rf build

    info "Configuring..."
    "$@" > "$log" 2>&1 || { error "Configure failed for $name. Check $log"; }

    info "Compiling ($JOBS jobs)..."
    ninja -C build -j"$JOBS" >> "$log" 2>&1 || { error "Build failed for $name. Check $log"; }

    info "Installing..."
    sudo ninja -C build install >> "$log" 2>&1 || { error "Install failed for $name. Check $log"; }

    # Fix pkg-config paths
    if [[ -d "$PREFIX/lib/pkgconfig" ]]; then
        for pc in "$PREFIX/lib/pkgconfig/"*.pc; do
            [[ -f "$pc" ]] && sudo ln -sf "$pc" "/usr/lib/pkgconfig/$(basename "$pc")" 2>/dev/null || true
        done
    fi
    sudo ldconfig 2>/dev/null || true

    info "$name installed."
}

build_cmake() {
    local name="$1"; shift
    build_and_install "$name" cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release "$@"
}

build_meson() {
    local name="$1"; shift
    build_and_install "$name" meson setup build --prefix="$PREFIX" --buildtype=release "$@"
}

# ─── DEPENDENCY BUILDERS ───────────────────────────────────────────

build_wayland() {
    clone_source "wayland" "https://gitlab.freedesktop.org/wayland/wayland.git"
    build_meson "wayland" -Ddocumentation=false -Dtests=false
}

build_wayland_protocols() {
    clone_source "wayland-protocols" "https://gitlab.freedesktop.org/wayland/wayland-protocols.git"
    build_meson "wayland-protocols"
}

build_libinput() {
    clone_source "libinput" "https://gitlab.freedesktop.org/libinput/libinput.git"
    build_meson "libinput" -Dlibwacom=false -Ddebug-gui=false -Dtests=false -Ddocs=false
}

build_xkbcommon() {
    clone_source "xkbcommon" "https://github.com/xkbcommon/libxkbcommon.git"
    build_meson "xkbcommon" -Denable-docs=false -Denable-wayland=true -Denable-x11=false
}

build_wlroots() {
    clone_source "wlroots" "https://gitlab.freedesktop.org/wlroots/wlroots.git" "0.20.0"
    build_meson "wlroots" -Dexamples=false -Dxwayland=enabled -Dbackends=libinput
}

build_scenefx() {
    clone_source "scenefx" "https://github.com/wlrfx/scenefx.git"
    build_meson "scenefx"
    # Fix pkg-config symlink
    sudo ln -sf "$PREFIX/lib/pkgconfig/scenefx-0.5.pc" "/usr/lib/pkgconfig/scenefx-0.5.pc" 2>/dev/null || true
    sudo ln -sf "$PREFIX/lib/libscenefx-0.5.so" "/usr/lib/libscenefx-0.5.so" 2>/dev/null || true
    sudo ldconfig 2>/dev/null || true
}

build_peachwm() {
    clone_source "peachwm" "https://github.com/HuntedByTheIRS/peachwm.git"
    section "Building peachwm"
    cd "$BUILD_DIR/peachwm"
    make release -j"$JOBS"
    sudo make install
    info "peachwm installed to $PREFIX/bin/peachwm"
}

build_pipewire() {
    clone_source "pipewire" "https://gitlab.freedesktop.org/pipewire/pipewire.git"
    build_meson "pipewire" -Dsession-managers=[] -Dexamples=disabled -Dtests=disabled
}

build_wireplumber() {
    clone_source "wireplumber" "https://gitlab.freedesktop.org/pipewire/wireplumber.git"
    build_meson "wireplumber" -Ddocs=disabled -Dtests=disabled
}

build_ffmpeg() {
    clone_source "ffmpeg" "https://git.ffmpeg.org/ffmpeg.git"
    section "Building ffmpeg"
    cd "$BUILD_DIR/ffmpeg"
    ./configure \
        --prefix="$PREFIX" \
        --enable-gpl \
        --enable-version3 \
        --disable-static \
        --enable-shared \
        --disable-programs \
        --disable-doc \
        --disable-network
    make -j"$JOBS"
    sudo make install
}

build_python() {
    clone_source "python" "https://github.com/python/cpython.git" "v3.13.0"
    section "Building Python"
    cd "$BUILD_DIR/python"
    ./configure --prefix="$PREFIX" --enable-optimizations --with-ensurepip=install
    make -j"$JOBS"
    sudo make install
}

build_zsh() {
    clone_source "zsh" "https://git.code.sf.net/p/zsh/code"
    section "Building zsh"
    cd "$BUILD_DIR/zsh"
    ./Util/preconfig autoconf 2>/dev/null || true
    ./configure --prefix="$PREFIX" --with-tcsetpgrp
    make -j"$JOBS"
    sudo make install
}

build_neovim() {
    clone_source "neovim" "https://github.com/neovim/neovim.git" "stable"
    build_cmake "neovim"
}

build_bat() {
    clone_source "bat" "https://github.com/sharkdp/bat.git"
    section "Building bat"
    cd "$BUILD_DIR/bat"
    cargo build --release 2>/dev/null || {
        warn "cargo not found. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        return 1
    }
    sudo cp target/release/bat "$PREFIX/bin/"
    info "bat installed."
}

build_starship() {
    section "Installing starship"
    curl -sS https://starship.rs/install.sh | sh -s -- -y --prefix "$PREFIX"
}

build_kitty() {
    clone_source "kitty" "https://github.com/kovidgoyal/kitty.git"
    section "Building kitty"
    cd "$BUILD_DIR/kitty"
    if command -v go &>/dev/null; then
        make linux-binaries
        sudo cp -r linux-package/bin/* "$PREFIX/bin/"
        sudo cp -r linux-package/lib/* "$PREFIX/lib/" 2>/dev/null || true
    else
        warn "Go not found. kitty requires Go to build."
        warn "Install Go: https://go.dev/dl/"
        warn "Or install kitty from your package manager."
    fi
}

build_waybar() {
    clone_source "waybar" "https://github.com/Alexays/Waybar.git"
    build_meson "waybar" -Dman-pages=disabled -Dtests=disabled
}

build_mako() {
    clone_source "mako" "https://github.com/emersion/mako.git"
    build_meson "mako"
}

build_rofi() {
    clone_source "rofi" "https://github.com/DaveDavenport/rofi.git"
    section "Building rofi"
    cd "$BUILD_DIR/rofi"
    mkdir -p build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" -DWAYLAND=ON -DX11=OFF
    make -j"$JOBS"
    sudo make install
}

build_flameshot() {
    clone_source "flameshot" "https://github.com/flameshot-org/flameshot.git"
    build_cmake "flameshot" -DWITHOUT_UPLOADER=ON
}

build_playerctl() {
    clone_source "playerctl" "https://github.com/altdesktop/playerctl.git"
    build_meson "playerctl"
}

build_brightnessctl() {
    clone_source "brightnessctl" "https://github.com/Hummer12007/brightnessctl.git"
    section "Building brightnessctl"
    cd "$BUILD_DIR/brightnessctl"
    make
    sudo make PREFIX="$PREFIX" install
}

build_mpv() {
    clone_source "mpv" "https://github.com/mpv-player/mpv.git"
    build_meson "mpv" -Dlibmpv=true -Dcplayer=false -Dbuild-date=false
}

build_mpvpaper() {
    clone_source "mpvpaper" "https://github.com/GhostNaN/mpvpaper.git"
    build_meson "mpvpaper"
}

build_exo() {
    clone_source "exo" "https://gitlab.xfce.org/apps/exo.git"
    build_meson "exo"
}

build_thunar() {
    clone_source "thunar" "https://gitlab.xfce.org/xfce/thunar.git"
    build_meson "thunar"
}

build_xdg_portal() {
    clone_source "xdg-desktop-portal" "https://gitlab.freedesktop.org/xdg/xdg-desktop-portal.git"
    build_meson "xdg-desktop-portal"

    clone_source "xdg-desktop-portal-wlr" "https://gitlab.freedesktop.org/wayland/xdg-desktop-portal-wlr.git"
    build_meson "xdg-desktop-portal-wlr"

    clone_source "xdg-desktop-portal-gtk" "https://gitlab.freedesktop.org/xdg/xdg-desktop-portal-gtk.git"
    build_meson "xdg-desktop-portal-gtk"
}

build_polkit() {
    clone_source "polkit" "https://gitlab.freedesktop.org/polkit/polkit.git"
    build_meson "polkit" -Dsystemd=false -Dtests=disabled -Dexamples=false
}

build_networkmanager() {
    clone_source "networkmanager" "https://gitlab.freedesktop.org/NetworkManager/NetworkManager.git"
    build_meson "networkmanager" -Dsystemd=false -Dtests=disabled -Ddocs=false -Dnmtui=false
}

build_bluez() {
    clone_source "bluez" "https://git.kernel.org/pub/scm/bluetooth/bluez.git"
    section "Building bluez"
    cd "$BUILD_DIR/bluez"
    ./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-manpages
    make -j"$JOBS"
    sudo make install
}

build_lm_sensors() {
    clone_source "lm-sensors" "https://github.com/lm-sensors/lm-sensors.git"
    section "Building lm-sensors"
    cd "$BUILD_DIR/lm-sensors"
    make PREFIX="$PREFIX"
    sudo make PREFIX="$PREFIX" install
}

build_pfetch() {
    clone_source "pfetch" "https://github.com/dylanaraps/pfetch.git"
    sudo cp pfetch "$PREFIX/bin/"
    sudo chmod +x "$PREFIX/bin/pfetch"
    info "pfetch installed."
}

install_pip_packages() {
    section "Installing Python packages"
    pip3 install --user PyQt6 Pillow 2>/dev/null || {
        warn "Could not install PyQt6/Pillow. Install manually:"
        warn "  pip3 install PyQt6 Pillow"
    }
}

install_fonts() {
    section "Installing fonts"
    local FONT_DIR="$PREFIX/share/fonts"
    sudo mkdir -p "$FONT_DIR/NerdFonts"

    info "Downloading JetBrains Mono Nerd Font..."
    local FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local FONT_TMP="/tmp/jbmono-nerd.zip"
    curl -L -o "$FONT_TMP" "$FONT_URL"
    sudo unzip -o "$FONT_TMP" -d "$FONT_DIR/NerdFonts/"
    rm -f "$FONT_TMP"

    info "Downloading Bibata cursor theme..."
    local BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"
    local BIBATA_TMP="/tmp/bibata.tar.xz"
    curl -L -o "$BIBATA_TMP" "$BIBATA_URL"
    sudo mkdir -p "$PREFIX/share/icons"
    sudo tar -xf "$BIBATA_TMP" -C "$PREFIX/share/icons/"
    rm -f "$BIBATA_TMP"

    sudo fc-cache -fv
    info "Fonts installed."
}

setup_configs() {
    section "Setting up configurations"

    mkdir -p "$HOME/.config/peachwm"
    mkdir -p "$HOME/.config/kitty"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/waybar/scripts"
    mkdir -p "$HOME/.config/mako"
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xdg-desktop-portal"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/Pictures"

    cp "$DOTFILES_DIR/peachwm/config.lua" "$HOME/.config/peachwm/config.lua"
    cp "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    cp -r "$DOTFILES_DIR/kitty/themes" "$HOME/.config/kitty/"
    cp "$DOTFILES_DIR/rofi/"*.rasi "$HOME/.config/rofi/"
    cp "$DOTFILES_DIR/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
    cp "$DOTFILES_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"
    cp "$DOTFILES_DIR/waybar/scripts/"*.sh "$HOME/.config/waybar/scripts/"
    chmod +x "$HOME/.config/waybar/scripts/"*.sh
    cp "$DOTFILES_DIR/mako/config" "$HOME/.config/mako/config"
    cp "$DOTFILES_DIR/Thunar/"* "$HOME/.config/Thunar/"
    cp "$DOTFILES_DIR/xdg-desktop-portal/"* "$HOME/.config/xdg-desktop-portal/"
    cp "$DOTFILES_DIR/selector.py" "$HOME/.local/bin/selector.py"
    chmod +x "$HOME/.local/bin/selector.py"

    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
        warn "Backed up existing .zshrc to .zshrc.bak"
    fi
    cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

    info "Configs installed."
}

setup_zsh() {
    if command -v zsh &>/dev/null; then
        if [[ "$SHELL" != *"zsh"* ]]; then
            info "Setting zsh as default shell..."
            chsh -s "$(which zsh)"
        fi
    fi
}

cleanup() {
    info "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}

print_menu() {
    echo ""
    echo -e "${CYAN}  Select what to build:${NC}"
    echo ""
    echo "  1) Everything (full install)"
    echo "  2) Core only (wayland, wlroots, scenefx, peachwm)"
    echo "  3) Apps only (kitty, rofi, waybar, mako, etc.)"
    echo "  4) Build from list (interactive)"
    echo "  5) Configs only (skip builds)"
    echo ""
    echo -n "  Choice [1-5]: "
}

build_everything() {
    build_wayland
    build_wayland_protocols
    build_libinput
    build_xkbcommon
    build_pipewire
    build_wireplumber
    build_wlroots
    build_scenefx
    build_peachwm
    build_ffmpeg
    build_python
    build_zsh
    build_neovim
    build_bat
    build_starship
    build_kitty
    build_waybar
    build_mako
    build_rofi
    build_flameshot
    build_playerctl
    build_brightnessctl
    build_mpv
    build_mpvpaper
    build_exo
    build_thunar
    build_xdg_portal
    build_polkit
    build_networkmanager
    build_bluez
    build_lm_sensors
    build_pfetch
    install_pip_packages
    install_fonts
}

build_core() {
    build_wayland
    build_wayland_protocols
    build_libinput
    build_xkbcommon
    build_pipewire
    build_wireplumber
    build_wlroots
    build_scenefx
    build_peachwm
}

build_apps() {
    build_ffmpeg
    build_python
    build_zsh
    build_neovim
    build_bat
    build_starship
    build_kitty
    build_waybar
    build_mako
    build_rofi
    build_flameshot
    build_playerctl
    build_brightnessctl
    build_mpv
    build_mpvpaper
    build_exo
    build_thunar
    build_xdg_portal
    build_polkit
    build_networkmanager
    build_bluez
    build_lm_sensors
    build_pfetch
    install_pip_packages
    install_fonts
}

interactive_build() {
    local builds=(
        "wayland:build_wayland"
        "wayland-protocols:build_wayland_protocols"
        "libinput:build_libinput"
        "xkbcommon:build_xkbcommon"
        "pipewire:build_pipewire"
        "wireplumber:build_wireplumber"
        "wlroots-0.20:build_wlroots"
        "scenefx:build_scenefx"
        "peachwm:build_peachwm"
        "ffmpeg:build_ffmpeg"
        "python:build_python"
        "zsh:build_zsh"
        "neovim:build_neovim"
        "bat:build_bat"
        "starship:build_starship"
        "kitty:build_kitty"
        "waybar:build_waybar"
        "mako:build_mako"
        "rofi:build_rofi"
        "flameshot:build_flameshot"
        "playerctl:build_playerctl"
        "brightnessctl:build_brightnessctl"
        "mpv:build_mpv"
        "mpvpaper:build_mpvpaper"
        "exo:build_exo"
        "thunar:build_thunar"
        "xdg-desktop-portal:build_xdg_portal"
        "polkit:build_polkit"
        "networkmanager:build_networkmanager"
        "bluez:build_bluez"
        "lm-sensors:build_lm_sensors"
        "pfetch:build_pfetch"
    )

    echo ""
    echo -e "${CYAN}  Select packages to build (space-separated numbers):${NC}"
    echo ""
    for i in "${!builds[@]}"; do
        local name="${builds[$i]%%:*}"
        printf "  %2d) %s\n" $((i+1)) "$name"
    done
    echo ""
    echo -n "  Choices: "
    read -ra choices

    for c in "${choices[@]}"; do
        local idx=$((c-1))
        if [[ $idx -ge 0 && $idx -lt ${#builds[@]} ]]; then
            local func="${builds[$idx]#*:}"
            $func
        fi
    done
}

main() {
    echo ""
    echo -e "${CYAN}  My-Dots LFS Installer${NC}"
    echo "  ======================"
    echo ""

    check_root
    check_lfs_tools
    setup_env

    # Clone dotfiles
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        info "Cloning My-Dots repo..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        info "My-Dots repo already present."
        cd "$DOTFILES_DIR" && git pull
    fi

    print_menu
    read -r choice

    case "$choice" in
        1) build_everything ;;
        2) build_core ;;
        3) build_apps ;;
        4) interactive_build ;;
        5) ;;
        *) error "Invalid choice." ;;
    esac

    setup_configs
    setup_zsh
    cleanup

    echo ""
    info "Installation complete!"
    echo ""
    echo "  Next steps:"
    echo "    1. Log out and run 'peachwm' from your session"
    echo "    2. Place wallpapers in ~/Pictures/"
    echo "    3. Edit ~/.config/peachwm/config.lua to customize"
    echo "    4. Make sure $PREFIX/bin is in your PATH"
    echo ""
    echo "  If using a display server, add to /etc/profile:"
    echo "    export PATH=\"$PREFIX/bin:\$PATH\""
    echo "    export XDG_SESSION_TYPE=wayland"
    echo "    export XDG_CURRENT_DESKTOP=peachwm"
    echo ""
}

main "$@"
