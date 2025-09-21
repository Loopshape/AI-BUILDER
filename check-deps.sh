#!/usr/bin/env bash
set -e

echo "[CHECK] Prüfe erforderliche Tools..."

need_install=()

# Prüfen auf awk/gawk/busybox
if command -v awk >/dev/null 2>&1; then
    echo "[OK] awk gefunden: $(command -v awk)"
elif command -v gawk >/dev/null 2>&1; then
    echo "[OK] gawk gefunden: $(command -v gawk)"
elif command -v busybox >/dev/null 2>&1 && busybox awk '' </dev/null >/dev/null 2>&1; then
    echo "[OK] busybox awk verfügbar"
else
    echo "[MISS] awk/gawk/busybox fehlt"
    need_install+=("gawk")
fi

# Prüfen auf net-tools
if ! command -v ifconfig >/dev/null 2>&1; then
    echo "[MISS] net-tools fehlt"
    need_install+=("net-tools")
else
    echo "[OK] net-tools installiert"
fi

# Prüfen auf vim
if ! command -v vim >/dev/null 2>&1; then
    echo "[MISS] vim fehlt"
    need_install+=("vim")
else
    echo "[OK] vim installiert"
fi

# Prüfen auf xxd
if ! command -v xxd >/dev/null 2>&1; then
    echo "[MISS] xxd fehlt"
    need_install+=("xxd")
else
    echo "[OK] xxd installiert"
fi

# Installation vorschlagen
if [ ${#need_install[@]} -gt 0 ]; then
    echo ""
    echo "[ACTION] Folgende Pakete fehlen: ${need_install[*]}"
    echo "→ Bitte installieren mit:"
    echo "   pkg install ${need_install[*]}"
else
    echo "[DONE] Alle Abhängigkeiten sind installiert ✔"
fi
