yum install -y hg darcs
wget https://raw.github.com/ocaml/opam/master/shell/opam_installer.sh -O - | sh -s /usr/local/bin
/usr/local/bin/opam init --comp 4.05.0
#编译时间太长，放弃