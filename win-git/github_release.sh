get_latest_release(){
  local user_repos=$1
  curl --silent "https://api.github.com/repos/${user_repos}/releases/latest" |
    #awk '$0 ~ /tag_name/'
    grep '"tag_name":'
}
echo $(get_latest_release iawia002/annie)
