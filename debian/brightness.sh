#brightness_file=/sys/class/backlight/acpi_video0/brightness
brightness_file=~/1.txt

increase(){
  echo $[$(cat $brightness_file)+1] | sudo tee $brightness_file
}
decrease(){
  echo $[$(cat $brightness_file)-1] | sudo tee $brightness_file
}
case $1 in
  -) $(decrease) ;;
  +) $(increase) ;;
  *) $(increase) ;;
esac

cat $brightness_file
echo 1> $brightness_file
