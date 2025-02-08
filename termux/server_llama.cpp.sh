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
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 80 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-32B-abliterated-IQ4_XS.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-14B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-32B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-Sex.f16.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Tifa-Deepsex-14b-CoT-Q4_K_M.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/lightnovel_cpt.IQ4_XS.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8

#不能先运行这个命令会导致后续运行到一半后死掉
#sudo killall llama-server &&
#sudo pkill -f llama-server
#sudo sh -c "killall llama-server && /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/MN-Halide-12b-v1.0.Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8"
sudo killall llama-server
sleep 1
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/MN-Halide-12b-v1.0.Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 41 -t 6
sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/MN-Halide-12b-v1.0.Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 2
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-1M-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-7B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/uncensoredai_UncensoredLM-DeepSeek-R1-Distill-Qwen-14B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-7B-abliterated-Q4_K_M.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-14B-abliterated.Q4_K_S.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/DeepSeek-R1-Distill-Qwen-1.5B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/phi-4-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 80 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/phi-4-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 70 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/phi-4-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 99 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/phi-4-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-14B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 99 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 50 -t 2
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 40 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 30 -t 8
#非常卡顿
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 25 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 25 -t 2
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Dolphin3.0-Llama3.1-8B-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 20 -t 8
#sudo /data/local/tmp/llama.cpp/build/bin/llama-server -m /sdcard/Download/Dolphin3.0-Qwen2.5-3b-Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 8
