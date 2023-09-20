brew install nasm ragel binutils coreutils libtool autoconf automake cmake makedepend sdl2 lua@5.1 luarocks gettext pkg-config wget gnu-getopt grep bison ccache p7zip
cd ~
git clone https://github.com/koreader/koreader.git
export PATH="$(brew --prefix)/opt/gettext/bin:$(brew --prefix)/opt/gnu-getopt/bin:$(brew --prefix)/opt/bison/bin:$(brew --prefix)/opt/grep/libexec/gnubin:${PATH}"
export PATH="/usr/local/bin:/usr/local/sbin:${PATH/:\/usr\/local\/bin/}"
export LDFLAGS="-L/opt/homebrew/opt/libiconv/lib"
#export DYLD_LIBRARY="/opt/homebrew/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libiconv/include"
export MACOSX_DEPLOYMENT_TARGET=12.00
cd koreader && ./kodev fetch-thirdparty
#./kodev build
./kodev release macos -d
#./kodev release macos
