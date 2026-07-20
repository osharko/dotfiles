#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/osharko/dotfiles.git"

echo "▸ Checking system..."
if ! command -v pacman &>/dev/null; then
    echo "✗ This script requires pacman (Arch/CachyOS)"
    exit 1
fi

if ! command -v paru &>/dev/null; then
    echo "▸ Installing paru..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    (cd /tmp/paru && makepkg -si --noconfirm)
    rm -rf /tmp/paru
    echo "✓ paru installed"
else
    echo "✓ paru already present"
fi

if ! command -v chezmoi &>/dev/null; then
    echo "▸ Installing chezmoi..."
    if pacman -Si chezmoi &>/dev/null; then
        sudo pacman -S --noconfirm chezmoi
    else
        paru -S --noconfirm chezmoi
    fi
    echo "✓ chezmoi installed"
else
    echo "✓ chezmoi already present"
fi

echo "▸ Deploying dotfiles with chezmoi..."
chezmoi init --apply "$REPO_URL"

echo ""
echo "──────────────────────────────────────"
echo "  Bootstrap base complete!"
echo "  The run_once script will now install"
echo "  all packages and handle 1Password."
echo "──────────────────────────────────────"
