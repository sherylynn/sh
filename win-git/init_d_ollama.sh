#!/bin/bash
SCRIPT_NAME="ollama"
#code-server_init_d.sh
sudo tee /etc/init.d/${SCRIPT_NAME} <<EOF
#!/bin/sh
DESC='${SCRIPT_NAME}'
NAME=${SCRIPT_NAME}
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME} <<-'EOF'
case "$1" in 
    start) 
     $0 stop 
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME} <<EOF
     su $(whoami) -c '$(
  cd "$(dirname "$0")"
  pwd
)/server_${SCRIPT_NAME}.sh'
     ;; 
    stop) 
     killall ollama
     ;; 
    *) 
     echo "Usage: ./code-server_init_d.sh start|stop" >&2 
     ;; 
esac 
EOF
sudo chmod 777 /etc/init.d/${SCRIPT_NAME}
sudo rm -f /etc/rc3.d/S01${SCRIPT_NAME}
sudo ln -s /etc/init.d/${SCRIPT_NAME} /etc/rc3.d/S01${SCRIPT_NAME}
