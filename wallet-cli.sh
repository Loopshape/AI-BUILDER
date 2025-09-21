#!/usr/bin/env bash
set -e
export $(grep -v '^#' ~/.ai_builder/.env | xargs)

# Temporär Wallet entschlüsseln
gpg --batch --yes --passphrase "$SERVER_PASS" -d ~/.ai_builder/wallets/wallet.gpg > /tmp/wallet.json

# Balance prüfen (Simulation / ersetzt mit lncli/lightning-cli)
BALANCE=$(jq '.balance' /tmp/wallet.json)
CHANNELS=$(jq '.channels | length' /tmp/wallet.json)

echo "Balance: $BALANCE"
echo "Open Channels: $CHANNELS"

# Aufräumen
rm /tmp/wallet.json
