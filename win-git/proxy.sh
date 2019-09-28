#export http_proxy=http://127.0.0.1:8087
export http_proxy=http://127.0.0.1:10808
export https_proxy=http://127.0.0.1:10808

git config --global https.proxy http://127.0.0.1:10808
git config --global https.proxy https://127.0.0.1:10808
