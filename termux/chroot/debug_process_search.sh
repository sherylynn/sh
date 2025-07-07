#!/data/data/com.termux/files/usr/bin/bash

# 进程搜索性能调试脚本
# 用于分析进程搜索的耗时情况

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CHROOT_DIR="/data/local/mnt"

echo "🔍 进程搜索性能调试工具"
echo "=========================="

# 检查容器是否挂载
if ! grep -q " ${CHROOT_DIR%/} " /proc/mounts 2>/dev/null; then
    echo "❌ 容器未挂载，无法进行进程搜索测试"
    echo "请先启动容器: bash $SCRIPT_DIR/cli.sh start"
    exit 1
fi

echo "✅ 容器已挂载: $CHROOT_DIR"
echo ""

# 测试各个搜索方法的性能
echo "🧪 开始性能测试..."

# 1. 测试 fuser 性能
echo "🔍 测试 fuser 性能:"
if command -v fuser >/dev/null 2>&1; then
    echo "  ✓ fuser 命令可用"
    
    # 测试 fuser -v
    echo "  🔍 测试 fuser -v (详细模式)..."
    local start_time=$(date +%s.%N)
    local fuser_result=$(sudo fuser -v "${CHROOT_DIR}" 2>/dev/null)
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "    ⏱️  耗时: ${duration}秒"
    if [ -n "$fuser_result" ]; then
        local pids=$(echo "$fuser_result" | awk 'NR>1 && $2~/^[0-9]+$/ {print $2}' | sort -u)
        echo "    📋 找到进程: $pids"
        echo "    📊 进程数量: $(echo "$pids" | wc -w)"
    else
        echo "    ℹ️  未找到进程"
    fi
    
    # 测试 fuser (简单模式)
    echo "  🔍 测试 fuser (简单模式)..."
    start_time=$(date +%s.%N)
    fuser_result=$(sudo fuser "${CHROOT_DIR}" 2>/dev/null)
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "    ⏱️  耗时: ${duration}秒"
    if [ -n "$fuser_result" ]; then
        echo "    📋 找到进程: $fuser_result"
        echo "    📊 进程数量: $(echo "$fuser_result" | wc -w)"
    else
        echo "    ℹ️  未找到进程"
    fi
else
    echo "  ❌ fuser 命令不可用"
fi

echo ""

# 2. 测试 lsof 性能
echo "🔍 测试 lsof 性能:"
if command -v lsof >/dev/null 2>&1; then
    echo "  ✓ lsof 命令可用"
    
    # 测试 lsof (非递归)
    echo "  🔍 测试 lsof (非递归)..."
    start_time=$(date +%s.%N)
    local lsof_result=$(sudo lsof "${CHROOT_DIR}" 2>/dev/null)
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "    ⏱️  耗时: ${duration}秒"
    if [ -n "$lsof_result" ]; then
        local pids=$(echo "$lsof_result" | awk 'NR>1 {print $2}' | sort -u)
        echo "    📋 找到进程: $pids"
        echo "    📊 进程数量: $(echo "$pids" | wc -w)"
    else
        echo "    ℹ️  未找到进程"
    fi
    
    # 测试 lsof +D (递归)
    echo "  🔍 测试 lsof +D (递归模式)..."
    start_time=$(date +%s.%N)
    lsof_result=$(sudo lsof +D "${CHROOT_DIR}" 2>/dev/null)
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "    ⏱️  耗时: ${duration}秒"
    if [ -n "$lsof_result" ]; then
        pids=$(echo "$lsof_result" | awk 'NR>1 {print $2}' | sort -u)
        echo "    📋 找到进程: $pids"
        echo "    📊 进程数量: $(echo "$pids" | wc -w)"
    else
        echo "    ℹ️  未找到进程"
    fi
else
    echo "  ❌ lsof 命令不可用"
fi

echo ""

# 3. 测试 busybox lsof 性能
echo "🔍 测试 busybox lsof 性能:"
if [ -n "$busybox" ] && sudo $busybox lsof >/dev/null 2>&1; then
    echo "  ✓ busybox lsof 可用"
    
    # 测试 busybox lsof
    echo "  🔍 测试 busybox lsof..."
    start_time=$(date +%s.%N)
    local busybox_result=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}")
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "    ⏱️  耗时: ${duration}秒"
    if [ -n "$busybox_result" ]; then
        local lsof_full=$(sudo $busybox lsof | awk '{print $1}' | grep -c '^lsof')
        if [ "${lsof_full}" -eq 0 ]; then
            pids=$(echo "$busybox_result" | awk '{print $1}' | uniq)
        else
            pids=$(echo "$busybox_result" | awk '{print $2}' | uniq)
        fi
        echo "    📋 找到进程: $pids"
        echo "    📊 进程数量: $(echo "$pids" | wc -w)"
    else
        echo "    ℹ️  未找到进程"
    fi
else
    echo "  ❌ busybox lsof 不可用"
fi

echo ""

# 4. 测试 /proc 扫描性能
echo "🔍 测试 /proc 扫描性能:"
echo "  🔍 扫描 /proc 目录..."
start_time=$(date +%s.%N)
local proc_pids=""
for pid in /proc/[0-9]*; do
    [ -d "$pid" ] || continue
    pid_num=${pid##*/}
    if [ -f "$pid/maps" ] && grep -q "${CHROOT_DIR%/}" "$pid/maps" 2>/dev/null; then
        proc_pids="$proc_pids $pid_num"
    fi
done 2>/dev/null
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

echo "    ⏱️  耗时: ${duration}秒"
if [ -n "$proc_pids" ]; then
    echo "    📋 找到进程: $proc_pids"
    echo "    📊 进程数量: $(echo "$proc_pids" | wc -w)"
else
    echo "    ℹ️  未找到进程"
fi

echo ""

# 5. 系统信息
echo "📊 系统信息:"
echo "  🖥️  系统进程总数: $(ls /proc/[0-9]* 2>/dev/null | wc -l)"
echo "  📁 容器目录大小: $(du -sh "${CHROOT_DIR}" 2>/dev/null | cut -f1 || echo "未知")"
echo "  🔗 容器挂载点数量: $(grep " ${CHROOT_DIR%/}" /proc/mounts | wc -l)"

echo ""

# 6. 性能建议
echo "💡 性能优化建议:"
echo "  1. 如果 fuser 耗时较长，考虑使用简单模式 (去掉 -v 参数)"
echo "  2. 如果 lsof 递归搜索耗时过长，考虑使用非递归模式"
echo "  3. 如果 /proc 扫描耗时过长，考虑限制扫描范围"
echo "  4. 可以设置搜索超时，避免长时间等待"
echo "  5. 考虑并行执行多个搜索方法，取最快的结果"

echo ""
echo "🎯 推荐优化策略:"
echo "  🔹 优先使用 fuser (简单模式) - 通常最快"
echo "  🔹 如果 fuser 失败，使用 lsof (非递归) - 较快"
echo "  🔹 最后使用 /proc 扫描 - 最慢但最全面"
echo "  🔹 设置合理的超时时间 (3-5秒)" 