#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CHEZMOI_SOURCE_DIR:-"$(dirname "$(readlink -f "$0")")"}"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── 0. Prerequisiti ──
if ! command -v paru &>/dev/null; then
    echo "▸ Installing paru..."
    sudo pacman -S --noconfirm paru
fi

if ! command -v chezmoi &>/dev/null; then
    echo "▸ Installing chezmoi..."
    paru -S --noconfirm --needed chezmoi
fi

# ── 1. Pacchetti ufficiali ──
if command -v pacman &>/dev/null; then
    echo "▸ Installing official packages..."
    xargs -d '\n' sudo pacman -S --noconfirm --needed < "$PROJECT_DIR/pkglist.txt"
fi

# ── 2. Pacchetti AUR (via paru) ──
if command -v paru &>/dev/null; then
    echo "▸ Installing AUR packages..."
    xargs -d '\n' paru -S --noconfirm --needed < "$PROJECT_DIR/foreign-pkglist.txt"
fi

# ── 3. Defaults SSH ──
ENV_FILE="$PROJECT_DIR/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

: "${VAULT:=PersonalConfiguration}"
: "${SSH_ITEM:=Default}"
: "${SSH_CONFIG_DOC:=config}"
: "${SSH_AUTH_KEYS_DOC:=authorized_keys}"
: "${SSH_PRIVATE_KEY_PATH:=$HOME/.ssh/id_ed25519}"
: "${SSH_PUBLIC_KEY_PATH:=$HOME/.ssh/id_ed25519.pub}"
: "${SSH_CONFIG_PATH:=$HOME/.ssh/config}"
: "${SSH_AUTH_KEYS_PATH:=$HOME/.ssh/authorized_keys}"

# Crea .env con default se non esiste
if [ ! -f "$ENV_FILE" ]; then
    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<-EOF
# Generato automaticamente dal bootstrap
VAULT=$VAULT
SSH_ITEM=$SSH_ITEM
SSH_CONFIG_DOC=$SSH_CONFIG_DOC
SSH_AUTH_KEYS_DOC=$SSH_AUTH_KEYS_DOC
SSH_PRIVATE_KEY_PATH=$SSH_PRIVATE_KEY_PATH
SSH_PUBLIC_KEY_PATH=$SSH_PUBLIC_KEY_PATH
SSH_CONFIG_PATH=$SSH_CONFIG_PATH
SSH_AUTH_KEYS_PATH=$SSH_AUTH_KEYS_PATH
EOF
    echo "▸ Created $ENV_FILE with defaults"
fi

# ── 4. Esporta SSH da 1Password ──
if command -v op &>/dev/null; then
    if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
        echo "▸ Using OP_SERVICE_ACCOUNT_TOKEN for headless auth"
    fi

    if op whoami --format json 2>/dev/null; then
        echo "▸ Exporting SSH keys from 1Password..."

        mkdir -p "$(dirname "$SSH_PRIVATE_KEY_PATH")"

        op item get "$SSH_ITEM" --vault "$VAULT" --fields "chiave privata" --reveal > "$SSH_PRIVATE_KEY_PATH"
        chmod 600 "$SSH_PRIVATE_KEY_PATH"

        op item get "$SSH_ITEM" --vault "$VAULT" --fields "public key" > "$SSH_PUBLIC_KEY_PATH"
        chmod 644 "$SSH_PUBLIC_KEY_PATH"

        op document get "$SSH_CONFIG_DOC" --vault "$VAULT" --force --output "$SSH_CONFIG_PATH"
        chmod 600 "$SSH_CONFIG_PATH"

        op document get "$SSH_AUTH_KEYS_DOC" --vault "$VAULT" --force --output "$SSH_AUTH_KEYS_PATH"
        chmod 644 "$SSH_AUTH_KEYS_PATH"

        echo "✓ SSH keys exported"
    else
        echo "⚠ 1Password not logged in."
        echo "  Set OP_SERVICE_ACCOUNT_TOKEN in .env for headless auth."
        echo "  Or run 'op signin' and re-run: cd \"$PROJECT_DIR\" && chezmoi apply"
    fi
else
    echo "⚠ 1Password CLI not found — install 1password-cli (AUR) and re-run"
fi

echo "✓ Bootstrap complete"
