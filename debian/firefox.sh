#!/bin/bash
#创建一个保存 APT 库密钥的目录： 
sudo install -d -m 0755 /etc/apt/keyrings 

#导入 Mozilla APT 密钥环： 
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

#把 Mozilla APT 库添加到源列表中： 
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null

#配置 APT 优先使用 Mozilla 库中的包：
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla

#更新软件列表并安装 Firefox .deb 包： 
sudo apt-get update && sudo apt-get install firefox

#使用 .deb 包设置 Firefox 语言
sudo apt-get install firefox-l10n-zh
