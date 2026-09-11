#!/usr/bin/env bash
# Trust the NewHome noVNC local CA for the current desktop user.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CA_FILE=${1:-$SCRIPT_DIR/novnc-ca.crt}
CA_NAME="NewHome noVNC Local CA"

[ -s "$CA_FILE" ] || {
  echo "CA certificate not found: $CA_FILE" >&2
  echo "Download https://YOUR-NOVNC-HOST:10086/novnc-ca.crt first." >&2
  exit 1
}
openssl x509 -in "$CA_FILE" -noout -subject >/dev/null

case "$(uname -s)" in
  Darwin)
    keychain="$HOME/Library/Keychains/login.keychain-db"
    security add-trusted-cert -r trustRoot -k "$keychain" "$CA_FILE"
    echo "Installed $CA_NAME in the macOS login keychain. Restart Firefox."
    ;;
  Linux)
    installed=0
    if command -v certutil >/dev/null 2>&1; then
      while IFS= read -r db; do
        [ -d "$db" ] || continue
        certutil -D -d "sql:$db" -n "$CA_NAME" >/dev/null 2>&1 || true
        certutil -A -d "sql:$db" -n "$CA_NAME" -t "C,," -i "$CA_FILE"
        echo "Installed $CA_NAME in browser profile: $db"
        installed=1
      done < <(find "$HOME/.mozilla/firefox" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)

      nssdb="$HOME/.pki/nssdb"
      mkdir -p "$nssdb"
      [ -f "$nssdb/cert9.db" ] || certutil -N -d "sql:$nssdb" --empty-password
      certutil -D -d "sql:$nssdb" -n "$CA_NAME" >/dev/null 2>&1 || true
      certutil -A -d "sql:$nssdb" -n "$CA_NAME" -t "C,," -i "$CA_FILE"
      echo "Installed $CA_NAME for Chromium-family browsers."
      installed=1
    fi

    if command -v update-ca-certificates >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
      sudo install -m 0644 "$CA_FILE" /usr/local/share/ca-certificates/newhome-novnc-ca.crt
      sudo update-ca-certificates
      echo "Installed $CA_NAME in the Linux system trust store."
      installed=1
    fi
    if [ "$installed" -eq 0 ]; then
      echo "Install libnss3-tools (certutil), or import $CA_FILE manually in Firefox Settings > Certificates." >&2
      exit 1
    fi
    echo "Restart the browser before reconnecting."
    ;;
  *)
    echo "Unsupported platform. Import $CA_FILE as a trusted root CA manually." >&2
    exit 2
    ;;
esac
