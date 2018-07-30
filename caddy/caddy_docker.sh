if [ ! -d "$HOME/caddy" ]; then
  mkdir $HOME/caddy
fi
if [ ! -f "$HOME/caddy/Caddyfile" ]; then
cp $HOME/sh/hk/Caddyfile $HOME/caddy/Caddyfile
fi

docker run -it --name caddy \
  --restart=always \
  -v $HOME/caddy/Caddyfile:/etc/Caddyfile \
  -v $HOME/caddy:/root/.caddy \
  --net=host abiosoft/caddy
