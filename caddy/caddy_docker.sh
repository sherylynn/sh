if [ ! -d "$HOME/caddy" ]; then
  mkdir $HOME/caddy
fi
if [ ! -f "$HOME/caddy/Caddyfile" ]; then
cp $HOME/sh/hk/Caddyfile $HOME/caddy/Caddyfile
fi

docker run -itd --name v2ray --restart=always --net=host -v $HOME:/etc/v2ray v2ray/official
docker run -d --name caddy \
  --restart=always 
  -v $HOME/caddy/Caddyfile:/etc/Caddyfile \
  -v $HOME/caddy:/root/.caddy \
  -p 80:80 -p 443:443 \
  abiosoft/caddy
