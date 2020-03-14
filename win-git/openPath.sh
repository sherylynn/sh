# as start function
if [[ $(exist z)==1 ]]; then
  zd(){
    z $1
    case $(platform) in
      win) start . ;;
      linux) xdg-open;;
      macos) open ;;
    esac
  }
else
  # as alias
  case $(platform) in
    win) alias zd="explorer" ;;
    linux) alias zd="xdg-open" ;;
    macos) alias zd="open" ;;
  esac
fi
