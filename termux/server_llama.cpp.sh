#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_NAME="llama.cpp"
#change bash from /usr/bin/bash to realpath
realpath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}
realpathdir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
cd ../../
#LD_LIBRARY_PATH=/vendor/lib64:/apex/com.android.runtime/lib64/bionic/:/system/lib64 llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 99
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 99 -t 8
sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 80 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 50 -t 2
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 40 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 30 -t 8
#非常卡顿
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 25 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 25 -t 2
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Dolphin3.0-Llama3.1-8B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 20 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Dolphin3.0-Qwen2.5-3b-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
