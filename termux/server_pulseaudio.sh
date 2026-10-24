#!/data/data/com.termux/files/usr/bin/bash
# Dedicated foreground entry for termux-services/runsv.
# Do not kill existing servers or spawn detached readiness pollers on every
# runsv retry; those patterns caused process churn and CPU spikes.
exec pulseaudio --daemonize=no \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713" \
  --exit-idle-time=-1
