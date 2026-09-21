#!/bin/bash
# init_d_devspace.sh —— 把 devspace MCP + cloudflared 隧道注册进 SysV/rc3 自启动
#
# 生成 /etc/init.d/devspace 并软链到 /etc/rc3.d/S01devspace。
# 容器启动时由 termux/chroot/cli.sh 的 start_init()（遍历 ${CHROOT_DIR}/etc/rc3.d/S*）
# 以 `S01devspace start` 拉起，与 noVNC / ttyd / code-server 同一套机制。
#
# 实际启停逻辑在 win-git/server_devspace.sh；desktop/autostart 与 rc3 都只调用它。
# server_devspace.sh 自身负责 flock + 进程存在性检查，因此两个入口可并存而不会双启动。
SCRIPT_NAME="devspace"
MANAGER="$(cd "$(dirname "$0")"; pwd)/server_devspace.sh"
INIT_LOG="/root/.devspace/initd.log"

sudo tee /etc/init.d/${SCRIPT_NAME}<<EOF
#!/bin/sh
DESC='${SCRIPT_NAME} MCP + cloudflared tunnel'
NAME=${SCRIPT_NAME}
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME}<<-'EOF'
case "$1" in
    start)
EOF
sudo tee -a /etc/init.d/${SCRIPT_NAME}<<EOF
     mkdir -p /root/.devspace
     printf '\n[%s] starting ${SCRIPT_NAME} service\n' "\$(date '+%F %T')" >>${INIT_LOG}

     # rc3 并发拉起所有 S* 服务，其控制管道可能在固定 grace period 后消失。
     # 这里先把 start 整体 detach，避免收到 SIGHUP/SIGPIPE。
     if [ ! -f '${MANAGER}' ]; then
       printf '%s\n' "ERROR: ${MANAGER} not found" >>${INIT_LOG}
     else
       # 不做 stop：如果 desktop 已经启动，server_devspace.sh 会直接复用；
       # 如果两个入口同时启动，server_devspace.sh 的 flock 会串行化 check-and-start。
       nohup setsid /bin/bash '${MANAGER}' autostart-start </dev/null >>${INIT_LOG} 2>&1 &
     fi
     ;;
    stop)
     if [ -f '${MANAGER}' ]; then
       /bin/bash '${MANAGER}' stop >>${INIT_LOG} 2>&1
     fi
     ;;
    *)
     echo "Usage: ./${SCRIPT_NAME}_init_d.sh start|stop" >&2
     ;;
esac
EOF
sudo chmod 777 /etc/init.d/${SCRIPT_NAME}
sudo rm -f /etc/rc3.d/S01${SCRIPT_NAME}
sudo ln -s /etc/init.d/${SCRIPT_NAME} /etc/rc3.d/S01${SCRIPT_NAME}

echo "已注册 rc3 自启动："
ls -la /etc/init.d/${SCRIPT_NAME} /etc/rc3.d/S01${SCRIPT_NAME}
