rm -rf /data/data/org.gnu.emacs/files
ln -s /data/data/com.termux/files/home /data/data/org.gnu.emacs/files
rm -rf /data/data/com.termux/files/home/fonts
mkdir -p /data/data/com.termux/files/home/.local/share/fonts
ln -s /data/data/com.termux/files/home/.local/share/fonts /data/data/com.termux/files/home/fonts
rm -rf /data/data/com.termux/files/home/fonts/font.ttf
rm  /data/data/com.termux/files/home/.termux/font.ttf
#ln -s /system/fonts/SourceSansPro-Regular.ttf /data/data/com.termux/files/home/.termux/font.ttf
ln -s /system/fonts/DroidSansMono.ttf /data/data/com.termux/files/home/.termux/font.ttf
ln -s /system/fonts/DroidSansMono.ttf /data/data/com.termux/files/home/fonts/font.ttf
