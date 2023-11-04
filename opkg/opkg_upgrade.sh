opkg list-upgradable | cut -f 1 -d ' ' | xargs -r opkg upgrade
