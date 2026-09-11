#!/bin/bash
# noVNC HTTPS certificate helper.
#
# Keeps a long-lived local CA and re-issues the noVNC server certificate when
# the device hostname/LAN addresses change. Import novnc-ca.crt once on a
# controller and keep trusting that CA; server certificates can then rotate
# without another trust prompt.

set -u

NOVNC_TLS_DIR=${NOVNC_TLS_DIR:-$HOME/.vnc/novnc-tls}
NOVNC_TLS_CA_KEY=${NOVNC_TLS_CA_KEY:-$NOVNC_TLS_DIR/novnc-ca.key}
NOVNC_TLS_CA_CERT=${NOVNC_TLS_CA_CERT:-$NOVNC_TLS_DIR/novnc-ca.crt}
NOVNC_TLS_KEY=${NOVNC_TLS_KEY:-$NOVNC_TLS_DIR/novnc-server.key}
NOVNC_TLS_LEAF_CERT=${NOVNC_TLS_LEAF_CERT:-$NOVNC_TLS_DIR/novnc-server.crt}
NOVNC_TLS_CERT=${NOVNC_TLS_CERT:-$NOVNC_TLS_DIR/novnc-server-fullchain.crt}
NOVNC_TLS_SAN_STATE=${NOVNC_TLS_SAN_STATE:-$NOVNC_TLS_DIR/novnc-server.sans}
NOVNC_TLS_CA_DAYS=${NOVNC_TLS_CA_DAYS:-3650}
NOVNC_TLS_CERT_DAYS=${NOVNC_TLS_CERT_DAYS:-825}

novnc_tls_log() {
  printf '[noVNC TLS] %s\n' "$*"
}

novnc_tls_collect_sans() {
  local hostname_value fqdn_value token ip
  local -a sans=()

  sans+=("DNS:localhost" "IP:127.0.0.1" "IP:::1")

  hostname_value=$(hostname 2>/dev/null || true)
  if [[ "$hostname_value" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
    sans+=("DNS:$hostname_value")
  fi

  fqdn_value=$(hostname -f 2>/dev/null || true)
  if [[ "$fqdn_value" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
    sans+=("DNS:$fqdn_value")
  fi

  if command -v ip >/dev/null 2>&1; then
    while IFS= read -r ip; do
      [ -n "$ip" ] && sans+=("IP:$ip")
    done < <(ip -o -4 addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]}')
    while IFS= read -r ip; do
      [ -n "$ip" ] && sans+=("IP:$ip")
    done < <(ip -o -6 addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]}')
  else
    for ip in $(hostname -I 2>/dev/null || true); do
      [ -n "$ip" ] && sans+=("IP:$ip")
    done
  fi

  # Optional comma-separated additions, e.g.
  # NOVNC_TLS_EXTRA_SANS='DNS:chroot.local,IP:192.168.1.20'
  if [ -n "${NOVNC_TLS_EXTRA_SANS:-}" ]; then
    IFS=',' read -r -a extra_sans <<< "$NOVNC_TLS_EXTRA_SANS"
    for token in "${extra_sans[@]}"; do
      token=${token//[[:space:]]/}
      [ -z "$token" ] && continue
      case "$token" in
        DNS:*|IP:*) sans+=("$token") ;;
        *) sans+=("DNS:$token") ;;
      esac
    done
  fi

  printf '%s\n' "${sans[@]}" | sed '/^$/d' | sort -u | paste -sd, -
}

novnc_tls_create_ca() {
  local ca_config
  ca_config=$(mktemp "$NOVNC_TLS_DIR/ca.XXXXXX.cnf") || return 1
  cat >"$ca_config" <<'EOF'
[req]
prompt = no
distinguished_name = dn
x509_extensions = v3_ca

[dn]
CN = NewHome noVNC Local CA
O = NewHome Local Remote Desktop

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

  novnc_tls_log "creating local CA (one-time trust anchor)"
  openssl genrsa -out "$NOVNC_TLS_CA_KEY" 3072 >/dev/null 2>&1 || {
    rm -f "$ca_config"
    return 1
  }
  openssl req -x509 -new -sha256 \
    -key "$NOVNC_TLS_CA_KEY" \
    -days "$NOVNC_TLS_CA_DAYS" \
    -config "$ca_config" \
    -out "$NOVNC_TLS_CA_CERT" >/dev/null 2>&1 || {
      rm -f "$ca_config"
      return 1
    }
  rm -f "$ca_config"
  chmod 600 "$NOVNC_TLS_CA_KEY"
  chmod 644 "$NOVNC_TLS_CA_CERT"
}

novnc_tls_issue_server_cert() {
  local sans="$1"
  local common_name csr ext
  common_name=$(hostname 2>/dev/null || true)
  if [[ ! "$common_name" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]; then
    common_name=localhost
  fi

  csr=$(mktemp "$NOVNC_TLS_DIR/server.XXXXXX.csr") || return 1
  ext=$(mktemp "$NOVNC_TLS_DIR/server.XXXXXX.ext") || {
    rm -f "$csr"
    return 1
  }

  cat >"$ext" <<EOF
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName = $sans
EOF

  novnc_tls_log "issuing server certificate for: $sans"
  openssl genrsa -out "$NOVNC_TLS_KEY" 2048 >/dev/null 2>&1 || {
    rm -f "$csr" "$ext"
    return 1
  }
  openssl req -new -sha256 \
    -key "$NOVNC_TLS_KEY" \
    -subj "/CN=$common_name/O=NewHome noVNC" \
    -out "$csr" >/dev/null 2>&1 || {
      rm -f "$csr" "$ext"
      return 1
    }
  openssl x509 -req -sha256 \
    -in "$csr" \
    -CA "$NOVNC_TLS_CA_CERT" \
    -CAkey "$NOVNC_TLS_CA_KEY" \
    -CAcreateserial \
    -days "$NOVNC_TLS_CERT_DAYS" \
    -extfile "$ext" \
    -out "$NOVNC_TLS_LEAF_CERT" >/dev/null 2>&1 || {
      rm -f "$csr" "$ext"
      return 1
    }

  cat "$NOVNC_TLS_LEAF_CERT" "$NOVNC_TLS_CA_CERT" > "$NOVNC_TLS_CERT"
  printf '%s\n' "$sans" > "$NOVNC_TLS_SAN_STATE"
  chmod 600 "$NOVNC_TLS_KEY"
  chmod 644 "$NOVNC_TLS_LEAF_CERT" "$NOVNC_TLS_CERT" "$NOVNC_TLS_SAN_STATE"
  rm -f "$csr" "$ext"
}

novnc_tls_prepare() {
  command -v openssl >/dev/null 2>&1 || {
    novnc_tls_log "ERROR: openssl is not installed"
    return 1
  }

  umask 077
  mkdir -p "$NOVNC_TLS_DIR"
  chmod 700 "$NOVNC_TLS_DIR"

  # A CA without its private key cannot renew leaf certificates. Recreate the
  # pair together, and tell the user because this invalidates the previous trust.
  if [ ! -s "$NOVNC_TLS_CA_KEY" ] || [ ! -s "$NOVNC_TLS_CA_CERT" ]; then
    if [ -e "$NOVNC_TLS_CA_KEY" ] || [ -e "$NOVNC_TLS_CA_CERT" ]; then
      novnc_tls_log "CA pair is incomplete; recreating it (controllers must trust the new CA)"
      rm -f "$NOVNC_TLS_CA_KEY" "$NOVNC_TLS_CA_CERT" "$NOVNC_TLS_DIR/novnc-ca.srl"
    fi
    novnc_tls_create_ca || {
      novnc_tls_log "ERROR: failed to create local CA"
      return 1
    }
  fi

  local sans previous_sans need_issue=0
  sans=$(novnc_tls_collect_sans)
  previous_sans=$(cat "$NOVNC_TLS_SAN_STATE" 2>/dev/null || true)

  [ -s "$NOVNC_TLS_KEY" ] || need_issue=1
  [ -s "$NOVNC_TLS_LEAF_CERT" ] || need_issue=1
  [ -s "$NOVNC_TLS_CERT" ] || need_issue=1
  [ "$sans" = "$previous_sans" ] || need_issue=1

  # Renew before it gets close to expiry. The CA remains stable.
  if [ -s "$NOVNC_TLS_LEAF_CERT" ] && ! openssl x509 -checkend 604800 -noout -in "$NOVNC_TLS_LEAF_CERT" >/dev/null 2>&1; then
    need_issue=1
  fi

  if [ "$need_issue" -eq 1 ]; then
    novnc_tls_issue_server_cert "$sans" || {
      novnc_tls_log "ERROR: failed to issue server certificate"
      return 1
    }
  fi

  # Verify the leaf really chains to our persisted CA before noVNC starts.
  openssl verify -CAfile "$NOVNC_TLS_CA_CERT" "$NOVNC_TLS_LEAF_CERT" >/dev/null 2>&1 || {
    novnc_tls_log "ERROR: server certificate does not verify against local CA"
    return 1
  }

  export NOVNC_TLS_CA_CERT NOVNC_TLS_CERT NOVNC_TLS_KEY
  novnc_tls_log "HTTPS certificate ready"
  novnc_tls_log "CA certificate to trust once on controllers: $NOVNC_TLS_CA_CERT"
  novnc_tls_log "server certificate: $NOVNC_TLS_LEAF_CERT"
}
