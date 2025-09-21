#!/usr/bin/env bash
set -e
echo "[BACKUP] Starting encrypted backup..."

export $(grep -v '^#' ~/.ai_builder/.env | xargs)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$HOME/.ai_builder/backups/backup_$TIMESTAMP.tar.gz"
SECURE_BACKUP="$BACKUP_FILE.gpg"

mkdir -p ~/.ai_builder/backups

# Packe alle sensiblen Daten
tar -czf "$BACKUP_FILE" -C "$HOME/.ai_builder/secure" .

# Verschlüssele Backup
echo "$SERVER_PASS" | gpg --batch --yes --passphrase-fd 0 -c "$BACKUP_FILE"

rm "$BACKUP_FILE"
echo "[BACKUP] Encrypted backup created: $SECURE_BACKUP"
