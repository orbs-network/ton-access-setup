#!/bin/bash

### Initial setup

echo -n "[1/11] Creating config directory... "
[ -d "$PROJECT_TON_ACCESS_DIR" ] || eecho "$PROJECT_TON_ACCESS_DIR doesn't exist! This folder is mandatory to exist. Check repository."
CONFIG_DIR="$PROJECT_TON_ACCESS_DIR/config"
rm -r $CONFIG_DIR &>/dev/null
mkdir $CONFIG_DIR
[ ! -d "$CONFIG_DIR" ] && eecho "Failed!" || echo "Done"

echo -n "[2/11] Downloading global-mainnet.json and global-testnet.json... "
curl -sL "https://ton-blockchain.github.io/global.config.json" > $CONFIG_DIR/global-mainnet.json; [ ! -s "$CONFIG_DIR/global-mainnet.json" ] && eecho "Error occurred while trying to download global-mainnet.json file! Check URL \"https://ton-blockchain.github.io/global.config.json\"";
curl -sL "https://ton-blockchain.github.io/testnet-global.config.json" > $CONFIG_DIR/global-testnet.json; [ ! -s "$CONFIG_DIR/global-testnet.json" ] && eecho "Error occurred while trying to download global-testnet.json file! Check URL \"https://ton-blockchain.github.io/testnet-global.config.json\"";
echo "Done"

echo "[3/11] Generating local configuration file... "
(sudo -u ubuntu -- python3 /usr/src/mytonctrl/mytoninstaller.py <<< clcf >/dev/null || eecho "Failed! Try to execute \"python3 /usr/src/mytonctrl/mytoninstaller.py <<< clcf\" manually to inspect the issue.") && echo "Done"

echo "[4/11] Configuring fastly keys... "
read -p "Enter FASTLY_SERVICE_ID: " FASTLY_SERVICE_ID ; [ -z "$FASTLY_SERVICE_ID" ] && eecho "FASTLY_SERVICE_ID can't be empty!"
read -p "Enter FASTLY_API_KEY: " FASTLY_API_KEY; [ -z "$FASTLY_API_KEY" ] && eecho "FASTLY_API_KEY can'y be empty!"
sed -e 's/FASTLY_SERVICE_ID=xxx/FASTLY_SERVICE_ID='"$FASTLY_SERVICE_ID"'/' -e 's/FASTLY_API_KEY=xxx/FASTLY_API_KEY='"$FASTLY_API_KEY"'/' $PROJECT_TON_ACCESS_DIR/fastly.env 
echo ""

echo -n "[5/11] Copying ton-access to $HOME_DIR... "
[ -d "$HOME_TON_ACCESS_DIR" ] && rm -rf "$HOME_TON_ACCESS_DIR"
cp -r "$PROJECT_TON_ACCESS_DIR" "$HOME_DIR" ; [ $? -gt 0 ] && eecho "ton-access directory copy failed! Check ton-access location in git project. (PROJECT_TON_ACCESS_DIR: $PROJECT_TON_ACCESS_DIR)";
chown -R $USER:$USER "$HOME_TON_ACCESS_DIR" || eecho "Failed to change owner of file $HOME_TON_ACCESS_DIR"
echo "Done"

echo -n "[6/11] Copying \"$GENERATED_LOCAL_CONF\" in $HOME_TON_ACCESS_DIR/config/ ... "
[ -f "$GENERATED_LOCAL_CONF" ] && cp "$GENERATED_LOCAL_CONF" "$HOME_TON_ACCESS_DIR/config/" || eecho "File $GENERATED_LOCAL_CONF doesn't exist! Try to generate config file manually."
[ ! -f "$HOME_TON_ACCESS_DIR/config/local.config.json" ] && eecho "Failed! Unable to find $HOME_TON_ACCESS_DIR/config/local.config.json"
echo "Done"

echo "[7/11] Build v2 local docker images testnet and mainnet... "
[ -d "$TON_HTTP_API_DIR" ] && rm -r $TON_HTTP_API_DIR
git clone "$TON_HTTP_API_URL" && THA="$(basename "$_" .git)"
cd "$THA" || eecho "Unable to clone TON HTTP API project from GitHub or variable THA is empty!";
cp ../build-v2.env ./.env
git checkout v3
# build mainnet
build "mainnet" "master"
# build testnet
build "testnet" "testnet"
cd - || eecho "Unable to return to previous directory $OLD_PWD"
rm -r "$THA"
echo "Done"

echo -n "[8/11] Executing \"docker compose up -d\" in $HOME_TON_ACCESS_DIR as root... "
cd "$HOME_TON_ACCESS_DIR" || eecho "Unable to change directory to HOME_TON_ACCESS_DIR"
if ! sudo docker compose -f docker-compose.yaml up -d; then eecho "Failed to run docker compose up."; send_telegram "Failed to run docker compose up."; fi
cd - || eecho "Unable to return to previous directory $OLD_PWD"
echo "Done"

# Check if mngr endpoint is working
curl http://localhost/mngr/