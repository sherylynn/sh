winPath(){
  #return ${1////\\}
  # shell 函数只能返回整数
  local x=$1
  local x_drive=${x///c/C:}
  local x_backsplash=${x_drive////\\}
  local x_semicolon=${x_backsplash//:/;}
  local x_c=${x_semicolon//C;/C:}
  echo $x_c
}
DoubleBackSlash(){
  local y=$1
  local y_double=${y//\\/\\\\}
  echo $y_double
}
winDoublePath(){
  local x=$1
  local z_winPath=$(winPath $x)
  local z_winPath_Double=$(DoubleBackSlash $z_winPath)
  echo $z_winPath_Double
}
