apk add vim git htop
apk add git automake autoconf make g++ pcre-dev xz-dev
cd ~
git clone https://github.com/ggreer/the_silver_searcher.git
cd the_silver_searcher
./build.sh
makr install
