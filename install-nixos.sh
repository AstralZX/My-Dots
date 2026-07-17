#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="https://github.com/AstralZX/My-Dots.git"
DOTFILES_DIR="$HOME/My-Dots"
NIX_CONFIG_DIR="$HOME/.config/nix"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

check_nixos() {
    if [[ ! -f /etc/NIXOS ]]; then
        error "This is not a NixOS system. Use install.sh for Arch-based distros."
    fi
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root."
    fi
}

clone_dotfiles() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        info "Cloning My-Dots repo..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        info "My-Dots repo already cloned at $DOTFILES_DIR"
        cd "$DOTFILES_DIR" && git pull
    fi
}

generate_nix_packages() {
    info "Generating NixOS package configuration..."

    mkdir -p "$NIX_CONFIG_DIR"

    cat > "$NIX_CONFIG_DIR/my-dots-packages.nix" << 'NIXEOF'
# My-Dots NixOS Packages
# Import this in your configuration.nix:
#   imports = [ ./my-dots-packages.nix ];
#
# Or in your flake.nix:
#   myDotsPackages = import ./my-dots-packages.nix;

{ config, pkgs, ... }:

let
  # SceneFX for wlroots 0.20 (build from source via overlay)
  scenefx-wlroots20 = pkgs.scenefx.overrideAttrs (oldAttrs: {
    version = "0.5-wlroots20";
    src = pkgs.fetchFromGitHub {
      owner = "wlrfx";
      repo = "scenefx";
      rev = "master";
      sha256 = pkgs.lib.fakeSha256; # Replace with actual hash after first build
    };
    buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.wlroots_0_20 ];
    mesonFlags = (oldAttrs.mesonFlags or []) ++ [
      "-D wlroots:backends=libinput"
    ];
  });
in
{
  # Add overlay for scenefx if needed
  nixpkgs.overlays = [
    (final: prev: {
      scenefx = scenefx-wlroots20;
    })
  ];

  # System packages
  environment.systemPackages = with pkgs; [
    # Build essentials
    pkg-config
    clang
    lld
    meson
    ninja
    cmake
    gnumake

    # Wayland / WM
    wayland
    libinput
    xkbcommon
    wayland-protocols
    wlroots_0_20

    # SceneFX (from overlay)
    scenefx-wlroots20

    # Desktop apps
    kitty
    rofi-wayland
    waybar
    mako
    flameshot
    mpvpaper

    # File manager
    xfce.thunar
    exo

    # Media
    ffmpeg
    playerctl
    wireplumber

    # System
    brightnessctl
    networkmanager
    bluez
    bluez-tools
    polkit_gnome
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    lm_sensors
    procps
    iproute2
    less
    bc
    coreutils

    # Terminal / shell
    zsh
    bat
    neovim
    python3
    python3Packages.pip

    # Fonts
    jetbrains-mono
    nerd-fonts.jetbrains-mono

    # Cursor
    bibata-cursors

    # Misc
    curl
    git
    pfetch

    # Spicetify (if available)
    # spicetify-cli
  ];

  # Services
  services.xserver = {
    libinput.enable = true;
  };

  services.dbus.enable = true;
  services.xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Bluetooth
  hardware.bluetooth.enable = true;

  # NetworkManager
  networking.networkmanager.enable = true;

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Polkit
  security.polkit.enable = true;

  # Environment variables
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "peachwm";
  };

  # Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];
  };

  # ZSH
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
NIXEOF

    info "Package configuration written to $NIX_CONFIG_DIR/my-dots-packages.nix"
}

generate_flake() {
    info "Generating flake.nix for peachWM..."

    cat > "$NIX_CONFIG_DIR/flake.nix" << 'FLAKEEOF'
{
  description = "My-Dots NixOS Configuration with peachWM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    peachwm = {
      url = "github:HuntedByTheIRS/peachwm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    scenefx = {
      url = "github:wlrfx/scenefx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, peachwm, scenefx, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        peachwm = peachwm.packages.${system}.default;
        scenefx = scenefx.packages.${system}.default;
      };

      nixosConfigurations.my-dots = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./my-dots-packages.nix
          ({ pkgs, ... }: {
            nixpkgs.overlays = [
              (final: prev: {
                peachwm = self.packages.${system}.peachwm;
                scenefx = self.packages.${system}.scenefx;
              })
            ];
          })
        ];
      };
    };
}
FLAKEEOF

    info "Flake written to $NIX_CONFIG_DIR/flake.nix"
}

install_peachwm_nix() {
    info "Installing peachWM via Nix..."

    if command -v nix &>/dev/null; then
        nix profile install github:HuntedByTheIRS/peachwm 2>/dev/null || {
            warn "Could not install peachWM via nix profile."
            warn "Add it to your flake inputs or build manually."
        }
    else
        warn "nix command not found. Install Nix first."
    fi
}

setup_configs() {
    info "Setting up configuration files..."

    mkdir -p "$HOME/.config/peachwm"
    mkdir -p "$HOME/.config/kitty"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/waybar/scripts"
    mkdir -p "$HOME/.config/mako"
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xdg-desktop-portal"
    mkdir -p "$HOME/.local/bin"

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

install_python_deps() {
    info "Installing Python dependencies..."
    pip3 install --user --upgrade PyQt6 Pillow 2>/dev/null || {
        warn "pip3 install failed, trying nix..."
        nix-shell -p python3Packages.pyqt6 python3Packages.pillow --run "echo 'Python deps available in nix-shell'" 2>/dev/null || true
    }
}

setup_home_manager() {
    if command -v home-manager &>/dev/null; then
        info "home-manager detected. Generating home configuration..."

        cat > "$NIX_CONFIG_DIR/home.nix" << 'HMEOF'
{ config, pkgs, ... }:

{
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "24.05";

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    initExtra = builtins.readFile ~/My-Dots/.zshrc;
  };

  programs.starship = {
    enable = true;
  };

  programs.bat = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  home.packages = with pkgs; [
    kitty
    rofi-wayland
    waybar
    mako
    flameshot
    mpvpaper
    playerctl
    brightnessctl
    ffmpeg
    curl
    git
    pfetch
    xfce.thunar
    exo
  ];

  xdg.configFile = {
    "peachwm/config.lua".source = ~/My-Dots/peachwm/config.lua;
    "kitty/kitty.conf".source = ~/My-Dots/kitty/kitty.conf;
    "mako/config".source = ~/My-Dots/mako/config;
    "waybar/config.jsonc".source = ~/My-Dots/waybar/config.jsonc;
    "waybar/style.css".source = ~/My-Dots/waybar/style.css;
  };

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    XDG_SESSION_TYPE = "wayland";
  };
}
HMEOF

        info "Home Manager config written to $NIX_CONFIG_DIR/home.nix"
    else
        warn "home-manager not installed. Skipping home-manager configuration."
        warn "Install it with: nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && nix-channel --update"
    fi
}

print_instructions() {
    echo ""
    info "NixOS setup complete!"
    echo ""
    echo "  To apply the configuration:"
    echo ""
    echo "  Option 1 - Add to existing configuration.nix:"
    echo "    Copy contents of $NIX_CONFIG_DIR/my-dots-packages.nix"
    echo "    into your /etc/nixos/configuration.nix imports list."
    echo "    Then run: sudo nixos-rebuild switch"
    echo ""
    echo "  Option 2 - Use the flake:"
    echo "    cd $NIX_CONFIG_DIR"
    echo "    nixos-rebuild switch --flake .#my-dots"
    echo ""
    echo "  Option 3 - Install peachWM standalone:"
    echo "    nix profile install github:HuntedByTheIRS/peachwm"
    echo ""
    echo "  After rebuild:"
    echo "    1. Log out and select peachwm from your display manager"
    echo "    2. Or run 'peachwm' from a TTY"
    echo "    3. Place wallpapers in ~/Pictures/"
    echo "    4. Edit ~/.config/peachwm/config.lua to customize"
    echo ""
}

main() {
    echo ""
    echo "  My-Dots NixOS Installer"
    echo "  ======================="
    echo ""

    check_nixos
    check_root

    clone_dotfiles
    generate_nix_packages
    generate_flake
    setup_home_manager
    install_python_deps
    setup_configs
    print_instructions
}

main "$@"
