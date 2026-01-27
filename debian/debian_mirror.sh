#!/bin/bash
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#mirrors.ustc.edu.cn#mirror.aliyun.com#g +wq!

if [[ -z "$1" ]]; then
    FILE="/etc/apt/sources.list"
    echo "edit default sources.list"
else
    FILE="$1"
    echo "edit $1"
fi

sudo vi "$FILE" +%s#deb.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
sudo vi "$FILE" +%s#security.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
sudo vi "$FILE" '+%s#\[signed-by="/usr/share/keyrings/debian-archive-keyring.gpg"\]##g' +wq! 
sudo vi "$FILE" '+%s#deb  http#deb \[trusted=yes\] http' +wq!

# Add deb-src entries for any missing ones
echo "Checking for and adding missing deb-src entries to $FILE..."

# Create temporary files securely
SHOULD_EXIST_TMP=$(mktemp)
DO_EXIST_TMP=$(mktemp)
MISSING_TMP=$(mktemp)

# Ensure cleanup happens on exit
trap 'rm -f "$SHOULD_EXIST_TMP" "$DO_EXIST_TMP" "$MISSING_TMP"' EXIT

# Get potential deb-src lines from the target file
# Note: We read the file with sudo in case it's not readable by the current user
sudo grep '^deb ' "$FILE" 2>/dev/null | sed 's/^deb /deb-src /' | sort > "$SHOULD_EXIST_TMP"

# Get existing deb-src lines from the target file
sudo grep '^deb-src ' "$FILE" 2>/dev/null | sort > "$DO_EXIST_TMP"

# Find missing lines using comm
comm -23 "$SHOULD_EXIST_TMP" "$DO_EXIST_TMP" > "$MISSING_TMP"

# Append missing lines if any exist
if [ -s "$MISSING_TMP" ]; then
    echo "Adding the following missing deb-src lines:"
    cat "$MISSING_TMP"
    cat "$MISSING_TMP" | sudo tee -a "$FILE" > /dev/null
    echo "Successfully added missing deb-src lines."
else
    echo "No missing deb-src lines found."
fi


#sudo vi /etc/apt/sources.list +%s#security.debian.org#mirror.aliyun.com#g +wq!
#sudo vi /etc/apt/sources.list +%s/main$/main\ contrib\ non-free/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirror\./mirrors/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirrorsaliyun/mirrors\.aliyun/g +wq!
#sudo vi /etc/apt/sources.list +%s#mirror.aliyun.com#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s/stretch/testing/g +wq!
#sudo apt update
