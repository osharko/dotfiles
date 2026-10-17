#!/bin/bash
# ── Setup autenticazione ─────────────────────────────────────────────────
# Fingerprint (fprintd + PAM), gnome-keyring e sync auth di DMS (lock/greeter).
#
# Eseguito da `chezmoi apply` (run_onchange). Richiede sudo: lancialo dal
# tuo terminale. È idempotente: le righe vengono aggiunte solo se assenti,
# e viene creato un backup *.chezmoi.bak prima di modificare un file PAM.
#
# Per forzare una riesecuzione senza cambiare altro, incrementa `version`.
# version: 4
set -euo pipefail

PAMDIR=/etc/pam.d

if [ ! -d "$PAMDIR" ]; then
    echo "▸ Nessun $PAMDIR: salto il setup auth"
    exit 0
fi

# Aggiunge una riga in cima a un file PAM (solo se assente).
prepend_line() {
    local file="$1" line="$2" tmp
    if [ ! -f "$file" ]; then
        echo "  · $file assente, salto"
        return 0
    fi
    if sudo grep -qxF "$line" "$file"; then
        echo "  · già presente: ${file#/etc/pam.d/}"
        return 0
    fi
    echo "  + ${file#/etc/pam.d/}: $line"
    tmp=$(mktemp)
    { echo "$line"; sudo cat "$file"; } >"$tmp"
    sudo cp -n "$file" "${file}.chezmoi.bak"
    sudo install -m 644 "$tmp" "$file"
    rm -f "$tmp"
}

# Aggiunge una riga in fondo a un file PAM (solo se assente).
append_line() {
    local file="$1" line="$2"
    if [ ! -f "$file" ]; then
        echo "  · $file assente, salto"
        return 0
    fi
    if sudo grep -qxF "$line" "$file"; then
        echo "  · già presente: ${file#/etc/pam.d/}"
        return 0
    fi
    echo "  + ${file#/etc/pam.d/}: $line"
    sudo cp -n "$file" "${file}.chezmoi.bak"
    printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null
}

echo "▸ Abilito fprintd..."
sudo systemctl enable --now fprintd 2>/dev/null || true

echo "▸ PAM: fingerprint (login, greetd e sudo includono system-auth)"
# 'sufficient': se l'impronta va a buon fine l'auth riesce, altrimenti si
# prosegue con la password. La password resta sempre come fallback.
prepend_line "$PAMDIR/system-auth" "auth       sufficient   pam_fprintd.so max-tries=1 timeout=10"

echo "▸ PAM: gnome-keyring (sblocco keyring al login)"
append_line "$PAMDIR/system-auth" "auth       optional     pam_gnome_keyring.so"
append_line "$PAMDIR/system-auth" "session    optional     pam_gnome_keyring.so auto_start"

# Greeter (login) e lock screen hanno PAM separati:
#   - greeter  → /etc/pam.d/greetd        → `dms-greeter sync --auth`
#   - lock     → /etc/pam.d/dankshell     → `dms auth sync`
echo "▸ DMS: sync auth del greeter (login)..."
if command -v dms-greeter >/dev/null 2>&1; then
    DMS_PRIVESC=sudo dms-greeter sync --auth -y 2>&1 | sed 's/^/  /' \
        || echo "  ⚠ 'dms-greeter sync --auth' non riuscito; esegui a mano: DMS_PRIVESC=sudo dms-greeter sync --auth"
    # Applica/rimuove l'auto-login su greetd in base a greeterAutoLogin.
    DMS_PRIVESC=sudo dms-greeter sync --autologin -y 2>&1 | sed 's/^/  /' \
        || echo "  ⚠ 'dms-greeter sync --autologin' non riuscito; esegui a mano: DMS_PRIVESC=sudo dms-greeter sync --autologin"
else
    echo "  · dms-greeter non trovato, salto"
fi

echo "▸ DMS: sync auth del lock screen..."
if command -v dms >/dev/null 2>&1; then
    DMS_PRIVESC=sudo dms auth sync -y 2>&1 | sed 's/^/  /' \
        || echo "  ⚠ 'dms auth sync' non riuscito; esegui a mano: DMS_PRIVESC=sudo dms auth sync"
else
    echo "  · dms non trovato, salto"
fi

if command -v fprintd-list >/dev/null 2>&1; then
    if ! fprintd-list "$USER" 2>/dev/null | grep -q '^ - #'; then
        echo "▸ Nessuna impronta registrata: enroll con 'fprintd-enroll'"
    fi
fi

echo "✓ Setup auth completato"
