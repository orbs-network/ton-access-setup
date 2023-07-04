#!/bin/bash
# Description: This script will prepare ton-access-nodes Git project for deployment of docker compose file.

eecho() {
	echo $@ 1>&2
	exit 1;
}

[[ ! $(id -un) == "ubuntu" ]] && eecho "Execute this script as \"ubuntu\" user.";
[ -z $(find . -type d -name ".git") ] && eecho "Execute this script inside of Git project."
MAIN_DIR="$HOME"

echo -n "[1/3] Creating config directory... "
CONFIG_DIR="$([ -d config ] && rm -rf config; mkdir -v config)"
[ ! -d $CONFIG_DIR ] && eecho "Failed!"
echo "Done"

echo -n "[2/3] Downloading global-mainnet.json and global-testnet.json... "
curl -sL https://ton-blockchain.github.io/global.config.json > $CONFIG_DIR/global-mainnet.json; [ $? -gt 0 ] && eecho "Error occurred while trying to download global-mainnet.json file!";
curl -sL https://ton-blockchain.github.io/testnet-global.config.json > $CONFIG_DIR/global-testnet.json; [ $? -gt 0 ] && eecho "Error occurred while trying to download global-testnet.json file!";
echo "Done"

echo -n "[3/3] Copying ton-access to $MAIN_DIR... "
cp -r ./ton-access $MAIN_DIR ; [ $? -gt 0 ] && eecho "ton-access directory copy failed!";
echo "Done"

# Stop further execution
exit $?

### Possible to add: 
echo -n "[4/?] Generating local configuration file... "
python3 /usr/src/mytonctrl/mytoninstaller.py <<< clcf >/dev/null
[ $? -gt 0 ] && eecho "Failed!"
echo "Done"

echo "[5/?] Executing docker compose up -d in $MAIN_DIR/ton-access as root... "
cd $TON_ACCESS_DIR && sudo docker compose up -d
[ $? -eq 0 ] && echo "Removing $GIT_PROJECT_DIR..." && rm -rf $GIT_PROJECT_DIR && echo "Done"

### Old install.sh content:
cp -r ./ton-access ../
source ../ton-access/get-global-config.sh
