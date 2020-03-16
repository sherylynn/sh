# as start function
if [[ $(exist z)==1 ]]; then
  zd(){
    z $1
    case $(platform) in
      win) start . ;;
      linux) xdg-open .;;
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
zcode(){
  z $1
  code ./
}

zpush(){
  git -C $ZSH_HOME push
}

zreload(){
  source $ZSH_HOME/win-git/toolsinit.sh
  source $ZSH_HOME/win-git/openPath.sh
}
zedit(){
  $EDITOR $ZSH_HOME/win-git/toolsinit.sh
}
zgit(){
  #$EDITOR -C "gs"
  git -C $ZSH_HOME commit -a
}
alias zc="zcode"
alias zg="zgit"
alias zp="zpush"
alias zr="zreload"
alias ze="zedit"
