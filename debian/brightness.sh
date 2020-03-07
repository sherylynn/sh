brightness_file=/sys/class/backlight/acpi_video0/brightness
#brightness_file=~/1.txt

increase(){
  echo $(($(cat $brightness_file)+1)) | sudo tee $brightness_file
}
decrease(){
  echo $(($(cat $brightness_file)-1)) | sudo tee $brightness_file
}
equl(){
  local x=$1
  echo $x |sudo tee $brightness_file
}
case $1 in
  -) echo $(decrease ) ;;
  +) echo $(increase ) ;;
  [0-9]) echo $(equl $1) ;;
  *) echo "use:\n '-'  to decrease\n '+'  to increase\n'0-9' to set" ;;
esac

#cat $brightness_file
#echo 1>$brightness_file
