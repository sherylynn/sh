#!/bin/bash
sudo apt install axel wget aria2 -y
CADDY_VERSION=0.11.4
CADDY_ARCH=arm7
Server=y
Client=n
Just_Install=n
#CADDY_ARCH=arm
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      CADDY_VERSION="$OPTARG";;
    a)
      CADDY_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

if [ ! -f "/usr/local/bin/caddy" ]; then
#curl https://getcaddy.com | bash -s personal http.filemanager
aria2c https://github.com/mholt/caddy/releases/download/v${CADDY_VERSION}/caddy_v${CADDY_VERSION}_linux_${CADDY_ARCH}.tar.gz && \
  tar -xzf caddy_v${CADDY_VERSION}_linux_${CADDY_ARCH}.tar.gz && \
  sudo install -t /usr/local/bin caddy \
  rm caddy_v${CADDY_VERSION}_linux_${CADDY_ARCH}.tar.gz caddy 
fi
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy
if [ ! -d "/etc/caddy" ]; then
sudo mkdir /etc/caddy
fi

if [ ! -d "/etc/ssl/caddy" ]; then
sudo mkdir /etc/ssl/caddy
fi

if [ ! -f "/etc/caddy/Caddyfile" ]; then
sudo tee /etc/caddy/Caddyfile <<-'EOF'
pi.sherylynn.win {
  proxy / localhost:8080 {
    header_upstream Host {host}
    header_upstream X-Real-IP {remote}
    header_upstream X-Forwarded-Proto {remote}
  }
  gzip
}
EOF
fi

if [ ${Server} = "y" ]; then  
sudo tee /etc/systemd/system/caddy.service <<-'EOF'
[Unit]
Description=caddy Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
; Letsencrypt-issued certificates will be written to this directory.
Environment=CADDYPATH=/etc/ssl/caddy
; Always set "-root" to something safe in case it gets forgotten in the Caddyfile.
ExecStart=/usr/local/bin/caddy -disable-http-challenge -log stdout -agree=true -conf /etc/caddy/Caddyfile
ExecReload=/bin/kill -USR1 $MAINPID
Restart=on-abnormal


; Use graceful shutdown with a reasonable timeout
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5s

; Limit the number of file descriptors; see `man systemd.exec` for more limit settings.
LimitNOFILE=1048576
; Unmodified caddy is not expected to use more than that.
LimitNPROC=512

; Use private /tmp and /var/tmp, which are discarded after caddy stops.
PrivateTmp=true
; Use a minimal /dev
PrivateDevices=true
; Hide /home, /root, and /run/user. Nobody will steal your SSH-keys.
ProtectHome=true
; Make /usr, /boot, /etc and possibly some more folders read-only.
ProtectSystem=full
; … except /etc/ssl/caddy, because we want Letsencrypt-certificates there.
;   This merely retains r/w access rights, it does not add any new. Must still be writable on the host!
ReadWriteDirectories=/etc/ssl/caddy

; The following additional security directives only work with systemd v229 or later.
; They further retrict privileges that can be gained by caddy. Uncomment if you like.
; Note that you may have to add capabilities required by any plugins in use.
;CapabilityBoundingSet=CAP_NET_BIND_SERVICE
;AmbientCapabilities=CAP_NET_BIND_SERVICE
;NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable caddy.service
sudo systemctl start caddy.service
fi  
