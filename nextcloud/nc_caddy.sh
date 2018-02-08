#/bin/bash
if [ ! -d "$HOME/nextcloud"]; then
mkdir $HOME/nextcloud
fi

if [ ! -f "$HOME/nextcloud/Caddyfile" ]; then
cp $HOME/sh/nextcloud/Caddyfile $HOME/nextcloud/Caddyfile
fi

docker-compose -f ~/sh/nextcloud/nc_caddy.yml up -d