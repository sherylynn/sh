if [ ! -d "$HOME/caddy" ]; then
  mkdir $HOME/caddy
fi
if [ ! -f "$HOME/caddy/Caddyfile" ]; then
cp $HOME/sh/raspberry/Caddyfile_pi $HOME/caddy/Caddyfile
fi

docker run -d --name caddy \
  --restart=always \
  -v $HOME/caddy/Caddyfile:/etc/Caddyfile \
  -v $HOME/caddy:/root/.caddy \
  --net=host detroitenglish/docker-caddy-rpi \
  -email=352281674@qq.com
