#!/bin/bash
. $(dirname "$0")/toolsinit.sh

NAME=qq

# =====================================================================================
# IMPORTANT: MANUAL STEP REQUIRED
# =====================================================================================
# The download URL for QQ for Linux changes frequently and is not static.
# You must manually obtain the correct download link from the official website.
#
# 1. Go to: https://im.qq.com/linuxqq/index.shtml
# 2. Right-click on the 'arm64' download button and copy the link address.
# 3. Paste the copied URL into the 'SOFT_URL' variable below.
# =====================================================================================

# Paste the download URL here
SOFT_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.18_250710_arm64_01.deb"

# --- Script execution starts here ---

PLATFORM=$(platform)
CURRENT_ARCH=$(arch)

if [[ "$PLATFORM" != "linux" ]] || [[ "$CURRENT_ARCH" != "aarch64" ]]; then
  echo "Error: This script is designed for ARM64 Linux only."
  echo "Current Platform: $PLATFORM, Current Architecture: $CURRENT_ARCH"
  exit 1
fi

if [ -z "$SOFT_URL" ]; then
  echo "Error: Download URL is not set."
  echo "Please edit this script (qq.sh) and add the correct download URL to the 'SOFT_URL' variable."
  exit 1
fi

SOFT_FILE_NAME=$(basename "$SOFT_URL")

echo "Downloading QQ for Linux (ARM64) from the provided URL..."
$(cache_downloader "$SOFT_FILE_NAME" "$SOFT_URL")

if [ ! -f "$(cache_folder)/${SOFT_FILE_NAME}" ]; then
    echo "Download failed. Please check the URL in the script."
    exit 1
fi

echo "Installing ${SOFT_FILE_NAME}..."
sudo dpkg -i "$(cache_folder)/${SOFT_FILE_NAME}"

echo "Fixing and installing dependencies..."
sudo apt-get install -f -y

echo "Applying --no-sandbox fix..."
sudo sed -i 's/^Exec=.*$/& --no-sandbox/' /usr/share/applications/qq.desktop

echo "QQ installation process finished."
