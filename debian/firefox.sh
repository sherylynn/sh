#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
TOOLSRC_NAME=firefoxrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

#原来和版本无关
notneed()
{
    #创建一个保存 APT 库密钥的目录： 
    sudo install -d -m 0755 /etc/apt/keyrings 

    #导入 Mozilla APT 密钥环： 
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

    #把 Mozilla APT 库添加到源列表中： 
    #echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
    sudo cp ~/sh/debian/mozilla.list /etc/apt/sources.list.d/


    #配置 APT 优先使用 Mozilla 库中的包：
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla
    #更新软件列表并安装 Firefox .deb 包： 
    sudo apt remove firefox-esr -y && sudo apt autoremove -y
    sudo apt-get update && sudo apt-get install firefox -y

    #使用 .deb 包设置 Firefox 语言
    sudo apt-get install firefox-l10n-zh-cn -y

    #如果是testing版本
    sudo apt-get install firefox-nightly -y
    sudo apt-get install firefox-nightly-l10n-zh-cn -y
}
#sudo apt install firefox-esr -y
notneed
if [[ $(whoami) == "root" ]]; then
    #如果是root则关闭sandbox
    echo 'export MOZ_DISABLE_CONTENT_SANDBOX=1'>${TOOLSRC}
    echo 'export MOZ_X11_EGL=1'>>${TOOLSRC}
fi
