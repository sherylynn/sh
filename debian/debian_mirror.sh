#!/bin/bash
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#mirrors.ustc.edu.cn#mirror.aliyun.com#g +wq!

# ---------- 对单个源文件执行镜像替换 ----------
# 自动识别 Debian 传统 One-Line (sources.list) 与 DEB822 (*.sources) 两种格式
process_file() {
    local f="$1"
    [ -e "$f" ] || { echo "[skip] 文件不存在: $f"; return 0; }
    echo "edit $f"

    if [[ "$f" == *.sources ]]; then
        # ---- DEB822 格式 (/etc/apt/sources.list.d/*.sources) ----
        # 关键字段: URIs / Suites / Components / Types / Signed-By
        sudo sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' "$f"
        sudo sed -i 's|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' "$f"
        # 注释掉 Signed-By 段（对应传统格式里删除 [signed-by=...]）
        sudo sed -i -E 's|^[[:space:]]*Signed-By:|#Signed-By:|g' "$f"
        # 等价于传统格式 [trusted=yes]：在 deb/deb-src 的行添加 Trusted: yes
        # 注意：DEB822 里一行 Types 控制一个段落，这里只在段落首行加，避免重复
        if ! sudo grep -q '^Trusted:' "$f" 2>/dev/null; then
            sudo sed -i -E '/^[[:space:]]*Types:[[:space:]]+.*deb/a\Trusted: yes' "$f"
        fi
    else
        # ---- 传统 One-Line 格式 (sources.list) ----
        sudo sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' "$f"
        sudo sed -i 's|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' "$f"
        sudo sed -i 's|\[signed-by="/usr/share/keyrings/debian-archive-keyring.gpg"\]||g' "$f"
        sudo sed -i 's|deb  http|deb  [trusted=yes] http|' "$f"

        # Add deb-src entries for any missing ones
        echo "Checking for and adding missing deb-src entries to $f..."

        # Create temporary files securely
        local SHOULD_EXIST_TMP DO_EXIST_TMP MISSING_TMP
        SHOULD_EXIST_TMP=$(mktemp)
        DO_EXIST_TMP=$(mktemp)
        MISSING_TMP=$(mktemp)

        # Ensure cleanup happens on exit
        trap 'rm -f "$SHOULD_EXIST_TMP" "$DO_EXIST_TMP" "$MISSING_TMP"' RETURN

        # Get potential deb-src lines from the target file
        # Note: We read the file with sudo in case it's not readable by the current user
        sudo grep '^deb ' "$f" 2>/dev/null | sed 's/^deb /deb-src /' | sort > "$SHOULD_EXIST_TMP"

        # Get existing deb-src lines from the target file
        sudo grep '^deb-src ' "$f" 2>/dev/null | sort > "$DO_EXIST_TMP"

        # Find missing lines using comm
        comm -23 "$SHOULD_EXIST_TMP" "$DO_EXIST_TMP" > "$MISSING_TMP"

        # Append missing lines if any exist
        if [ -s "$MISSING_TMP" ]; then
            echo "Adding the following missing deb-src lines:"
            cat "$MISSING_TMP"
            cat "$MISSING_TMP" | sudo tee -a "$f" > /dev/null
            echo "Successfully added missing deb-src lines."
        else
            echo "No missing deb-src lines found."
        fi
    fi
}

# ---------- 参数解析与文件选择 ----------
DEBIAN_SOURCES="/etc/apt/sources.list.d/debian.sources"

if [[ -z "$1" ]]; then
    FILE="/etc/apt/sources.list"
    echo "edit default sources.list"
    process_file "$FILE"
    if [ -e "$DEBIAN_SOURCES" ]; then
        echo ""
        echo "发现 DEB822 格式文件 $DEBIAN_SOURCES，一并编辑"
        process_file "$DEBIAN_SOURCES"
    fi
else
    FILE="$1"
    echo "edit $1"
    process_file "$FILE"
fi


#sudo vi /etc/apt/sources.list +%s#security.debian.org#mirror.aliyun.com#g +wq!
#sudo vi /etc/apt/sources.list +%s/main$/main\ contrib\ non-free/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirror\./mirrors/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirrorsaliyun/mirrors\.aliyun/g +wq!
#sudo vi /etc/apt/sources.list +%s#mirror.aliyun.com#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s/stretch/testing/g +wq!
#sudo apt update
