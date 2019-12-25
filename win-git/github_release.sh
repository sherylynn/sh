get_latest_release_version(){
  local user_repos=$1
  curl --silent "https://api.github.com/repos/${user_repos}/releases/latest" |
  #awk '$0 ~ /tag_name/'
  grep '"tag_name":' |
  #use '"' to split string and print $4
  awk -F '["]' '{print $4}'  
}
echo $(get_latest_release_version iawia002/annie)
echo $(get_latest_release_version nodejs/node)
