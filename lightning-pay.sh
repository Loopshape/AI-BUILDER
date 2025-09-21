#!/usr/bin/env bash
set -e
export $(grep -v '^#' ~/.ai_builder/.env | xargs)
INVOICE="$1"
if [ -z "$INVOICE" ]; then
  echo "Missing invoice" >&2
  exit 1
fi

# Temporär Wallet entschlüsseln
gpg --batch --yes --passphrase "$SERVER_PASS" -d ~/.ai_builder/wallets/wallet.gpg > /tmp/wallet.json

# Hier echte Lightning-Zahlung ausführen (Simulation)
echo "Paying invoice: $INVOICE" 
echo "Payment successful (simulation)"

# Aufräumen
rm /tmp/wallet.json
