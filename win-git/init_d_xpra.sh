#!/bin/bash
set -e

SCRIPT_NAME="xpra"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SERVER_SCRIPT="$SCRIPT_DIR/server_${SCRIPT_NAME}.sh"

if [ ! -f "$SERVER_SCRIPT" ]; then
  echo "错误：找不到运行脚本 $SERVER_SCRIPT" >&2
  exit 1
fi

sudo tee /etc/init.d/${SCRIPT_NAME} >/dev/null <<EOF_INIT
#!/bin/sh
DESC='${SCRIPT_NAME}'
NAME=${SCRIPT_NAME}
SERVER_SCRIPT='${SERVER_SCRIPT}'
LOG_DIR=/root/.xpra
PID_FILE=/root/.xpra/server-xpra-startup.pid
LOG_FILE=/root/.xpra/server-xpra-startup.log

case "\$1" in
  start)
    \$0 stop
    mkdir -p "\$LOG_DIR"
    chmod 700 "\$LOG_DIR"
    printf '\n[%s] starting Xpra service\n' "\$(date '+%F %T')" >>"\$LOG_FILE"
    nohup setsid /bin/bash "\$SERVER_SCRIPT" </dev/null >>"\$LOG_FILE" 2>&1 &
    startup_pid=\$!
    printf '%s\n' "\$startup_pid" >"\$PID_FILE"
    ;;
  stop)
    if [ -s "\$PID_FILE" ]; then
      startup_pid=\$(cat "\$PID_FILE" 2>/dev/null)
      case "\$startup_pid" in
        *[!0-9]*|'') ;;
        *)
          if [ -r "/proc/\$startup_pid/cmdline" ] && \
             tr '\\0' ' ' <"/proc/\$startup_pid/cmdline" | grep -Fq 'server_xpra.sh'; then
            kill -TERM -- "-\$startup_pid" 2>/dev/null || kill -TERM "\$startup_pid" 2>/dev/null || true
          fi
          ;;
      esac
    fi
    pkill -f '^/bin/bash .*/server_xpra\.sh$' 2>/dev/null || true
    rm -f "\$PID_FILE" /root/.xpra/newhome-shadow.pid
    ;;
  status)
    if [ -s "\$PID_FILE" ]; then
      startup_pid=\$(cat "\$PID_FILE" 2>/dev/null)
      if [ -n "\$startup_pid" ] && kill -0 "\$startup_pid" 2>/dev/null; then
        echo "Xpra startup process is running (pid=\$startup_pid)"
        exit 0
      fi
    fi
    echo "Xpra is not running"
    exit 3
    ;;
  restart)
    \$0 stop
    sleep 1
    \$0 start
    ;;
  *)
    echo "Usage: /etc/init.d/${SCRIPT_NAME} start|stop|restart|status" >&2
    exit 2
    ;;
esac
EOF_INIT

sudo chmod 755 /etc/init.d/${SCRIPT_NAME}
sudo rm -f /etc/rc3.d/S01${SCRIPT_NAME}
sudo ln -s /etc/init.d/${SCRIPT_NAME} /etc/rc3.d/S01${SCRIPT_NAME}
echo "已安装 /etc/init.d/${SCRIPT_NAME} 并注册 rc3: /etc/rc3.d/S01${SCRIPT_NAME}"
