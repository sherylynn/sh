# as start function
if [[ $openPathIsFunction  ]]; then
  zd(){
    case $(platform) in
      win) start $1 ;;
      linux) thunar $1;;
      macos) open $1;;
    esac
  }
else
  # as alias
  case $(platform) in
    win) alias zd="start" ;;
    linux) alias zd="thunar" ;;
    macos) alias zd="open" ;;
  esac
fi
