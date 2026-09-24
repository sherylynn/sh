#!/bin/bash
set -eo pipefail

# Install the current supported .NET LTS SDK using Microsoft's official installer.
# The SDK is installed per-user under ~/tools/dotnet so the same script works in
# Linux/macOS/MSYS-style environments without requiring root.
. "$(dirname "$0")/toolsinit.sh"

TOOLSRC_NAME=dotnetrc
TOOLSRC=$(toolsRC "${TOOLSRC_NAME}")
SOFT_HOME=$(install_path)/dotnet
SOFT_TOOL_HOME=$HOME/.dotnet/tools
DOTNET_CHANNEL=${DOTNET_CHANNEL:-10.0}
DOTNET_QUALITY=${DOTNET_QUALITY:-GA}
# NewHome Windows deliberately targets net8.0 for a conservative Windows 10
# runtime surface. Keep the still-supported .NET 8 runtime next to the .NET 10 SDK
# so the same Linux environment can run/debug the Avalonia app locally.
DOTNET_COMPAT_RUNTIME_CHANNEL=${DOTNET_COMPAT_RUNTIME_CHANNEL:-8.0}

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=arm ;;
  aarch64) SOFT_ARCH=arm64 ;;
  *)
    echo "Unsupported architecture: $(arch)" >&2
    exit 1
    ;;
esac

LIB_FILE_NAME=dotnet-install.sh
LIB_URL=https://dot.net/v1/dotnet-install.sh
INSTALLER="$(cache_folder)/${LIB_FILE_NAME}"

# Always refresh the official installer. Microsoft changes download locations over
# time, so keeping an old local copy is less reliable than fetching the stable URL.
curl --fail --location --show-error --retry 5 --retry-delay 1 \
  --connect-timeout 20 --output "${INSTALLER}.part" "${LIB_URL}"
mv -f "${INSTALLER}.part" "${INSTALLER}"
chmod 755 "${INSTALLER}"

mkdir -p "${SOFT_HOME}" "${SOFT_TOOL_HOME}"
"${INSTALLER}" \
  --install-dir "${SOFT_HOME}" \
  --channel "${DOTNET_CHANNEL}" \
  --quality "${DOTNET_QUALITY}" \
  --architecture "${SOFT_ARCH}" \
  --no-path

"${INSTALLER}" \
  --install-dir "${SOFT_HOME}" \
  --channel "${DOTNET_COMPAT_RUNTIME_CHANNEL}" \
  --runtime dotnet \
  --architecture "${SOFT_ARCH}" \
  --no-path

export DOTNET_ROOT="${SOFT_HOME}"
export PATH="${SOFT_HOME}:${SOFT_TOOL_HOME}:${PATH}"

cat >"${TOOLSRC}" <<EOF
export DOTNET_ROOT=${SOFT_HOME}
export PATH=${SOFT_HOME}:${SOFT_TOOL_HOME}:\$PATH
EOF

echo "Installed .NET SDK:"
dotnet --info
