#!/bin/bash
SCRIPT_NAME="noVNC"
#code-server_init_d.sh
sudo tee /etc/init.d/${SCRIPT_NAME}<<EOF
#!/bin/sh
DESC='${SCRIPT_NAME}'
NAME=${SCRIPT_NAME}
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME}<<-'EOF'
case "$1" in 
    start) 
     $0 stop 
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME}<<EOF
     mkdir -p /root/.vnc
     printf '\n[%s] starting noVNC service\n' "\$(date '+%F %T')" >>/root/.vnc/server-noVNC-startup.log

     # termux_all_in_one starts rc3 services concurrently and its controlling
     # pipe can disappear after the fixed startup grace period. Detach the
     # complete desktop/VNC bootstrap here, before it performs its own sleeps
     # and status writes, so it cannot receive SIGHUP/SIGPIPE halfway through.
     nohup setsid /bin/bash '$(cd "$(dirname "$0")";pwd)/server_${SCRIPT_NAME}.sh' \
       </dev/null >>/root/.vnc/server-noVNC-startup.log 2>&1 &
     startup_pid=\$!
     printf '%s\n' "\$startup_pid" >/root/.vnc/server-noVNC-startup.pid
     ;; 
    stop) 
     if [ -s /root/.vnc/server-noVNC-startup.pid ]; then
       startup_pid=\$(cat /root/.vnc/server-noVNC-startup.pid 2>/dev/null)
       case "\$startup_pid" in
         *[!0-9]*|'') ;;
         *)
           # A stale PID file must never be allowed to kill an unrelated,
           # subsequently reused process ID.
           if [ -r "/proc/\$startup_pid/cmdline" ] && \
              tr '\\0' ' ' <"/proc/\$startup_pid/cmdline" | grep -Fq 'server_${SCRIPT_NAME}.sh'; then
             kill -TERM -- "-\$startup_pid" 2>/dev/null || kill -TERM "\$startup_pid" 2>/dev/null || true
           fi
           ;;
       esac
     fi
     if [ -s /root/.vnc/novnc-proxy.pid ]; then
       proxy_pid=\$(cat /root/.vnc/novnc-proxy.pid 2>/dev/null)
       case "\$proxy_pid" in
         *[!0-9]*|'') ;;
         *) kill -TERM -- "-\$proxy_pid" 2>/dev/null || kill -TERM "\$proxy_pid" 2>/dev/null || true ;;
       esac
     fi
     pkill -f '^/bin/bash /root/sh/win-git/server_noVNC\.sh$' 2>/dev/null || true
	     pkill -f '^python3 /root/tools/noVNC/utils/newhome_websockify.py .* 10086 127\\.0\\.0\\.1:5900\$' 2>/dev/null || true
	     pkill -x wayvnc 2>/dev/null || true
	     pkill -x x11vnc 2>/dev/null || true
     rm -f /root/.vnc/server-noVNC-startup.pid /root/.vnc/novnc-proxy.pid
     ;; 
    *) 
     echo "Usage: ./${SCRIPT_NAME}_init_d.sh start|stop" >&2 
     ;; 
esac 
EOF
sudo chmod 777 /etc/init.d/${SCRIPT_NAME}
sudo rm -f /etc/rc3.d/S01${SCRIPT_NAME}
sudo ln -s /etc/init.d/${SCRIPT_NAME} /etc/rc3.d/S01${SCRIPT_NAME}
