defaults write com.apple.finder AppleShowAllFiles TRUE && killall Finder
sudo Install\ macOS\ Mojave.app/Contents/Resources/createinstallmedia --volume /Volumes/USB/
mkdir -p /Volumes/Install\ macOS\ Mojave/.IABootFile/
cp -p prelinkedkernel /Volumes/Install\ macOS\ Mojave/.IABootFile/
cp -p prelinkedkernel /Volumes/Install\ macOS\ Mojave/System/Library/PrelinkedKernels/
