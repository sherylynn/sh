#/bin/bash
docker run -itd --name chromium --restart=always -p 8000:8000 -p 8082:8082 \
  -v ~/chromium:/home/chromium \
  chromium /bin/bash
docker attach chromium
