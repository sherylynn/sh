#重新签名以访问外部硬盘
sudo codesign --sign - --force --deep /Applications/WeChat.app
#把老的备份拷贝过去
mv ~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application\ Support/com.tencent.xinWeChat/2.0b4.0.9/Backup /Volumes/bak/
ln -s /Volumes/bak/Backup ~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application\ Support/com.tencent.xinWeChat/2.0b4.0.9/Backup
