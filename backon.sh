#!/usr/bin/env bash
set -e
echo "[RESTORE] Restore encrypted backup..."

read -p "Enter backup filename: " BACKUP_FILE
echo "$SERVER_PASS" | gpg --batch --yes --passphrase-fd 0 -d "$BACKUP_FILE" | tar -xz -C ~/.ai_builder/secure

echo "[RESTORE] Backup restored to ~/.ai_builder/secure"
