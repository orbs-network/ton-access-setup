#!/bin/bash 

USER="ubuntu"
HOME_DIR="$(getent passwd "$USER" | cut -d: -f6)"
BIN_DIR="$HOME_DIR/bin"
HOME_TON_ACCESS_DIR="$HOME_DIR/ton-access"
TON_HTTP_API_DIR="ton-http-api"
declare -a DEPENDENCY_APPS=("git python3 curl crontab docker mytonctrl jq gh")
SCRIPT_NAME="${0##*/}"
PROJECT_DIRECTORY="$(dirname "$(realpath $SCRIPT_NAME)")"
PROJECT_TON_ACCESS_DIR="$PROJECT_DIRECTORY/ton-access"
GENERATED_LOCAL_CONF="$(awk -F '"' '/defaultLocalConfigPath/ {print $2}' /usr/src/mytonctrl/mytoninstaller.py)"
UPDATER_SCRIPT_NAME="ton_access_setup_updater"
UPDATER_SCRIPT="$BIN_DIR/$UPDATER_SCRIPT_NAME.sh"
UPDATER_SERVICE="$UPDATER_SCRIPT_NAME.service"
CONFIG_FILE="./install_conf.json"

# Error echo
function eecho() {
	printf '\e\x1b[31m%s\n\x1b[0m' "$@" 1>&2
	exit 1;
}

# Notifications to slack
function send_slack () {
	[ -z "$SLACK_URL" ] && echo "Unable to send slack because SLACK_URL variable is empty!" && return 1;
	FORMATED_MESSAGE="$(echo "$1" | sed 's/"/\\"/g' | sed "s/'/\\'/g" )"
	curl -s -X POST "$SLACK_URL" -H 'Content-type: application/json' --data '{"text":"'"$(hostname): $FORMATED_MESSAGE"'"}' >/dev/null
}

# Build-v2
function build() {
    # Function parameters
    local TAG="$1"
    local BRANCH="$2"

    # Set the environment variable    
    export IMAGE_TAG="$TAG"
    export TON_BRANCH="$BRANCH"

    # Run docker compose build
    if ! docker compose build --no-cache; then eecho "Unable to build tag: $TAG and branch: $BRANCH!"; fi
}

# Checks
[[ ! $(id -u) -eq 0 ]] && eecho "Execute this script with sudo: \"sudo ./$SCRIPT_NAME\".";
[ ! $(command -v jq &>/dev/null) ] && eecho "JQ command not found! Install JQ command and start script again."
[ -s $CONFIG_FILE ] || { echo "Unable to find config file for installation script! Check if you have install_conf.json file in $PROJECT_DIRECTORY" ; exit 1; }
GH_RELEASES_API_ENDPOINT="$(jq -r '.GH_RELEASES_API_ENDPOINT' $CONFIG_FILE)"
GH_TOKEN="$(jq -r '.GH_TOKEN' $CONFIG_FILE)"
# Notifications
SLACK_URL="$(jq -r '.SLACK_URL' $CONFIG_FILE)"
TELEGRAM_GROUP_ID="$(jq -r '.TELEGRAM_GROUP_ID' $CONFIG_FILE)"
TELEGRAM_BOT_TOKEN="$(jq -r '.TELEGRAM_BOT_TOKEN' $CONFIG_FILE)"
{ [ -z "$GH_RELEASES_API_ENDPOINT" ] || [ -z "$GH_TOKEN" ] || [ -z "$SLACK_URL" ] || [ -z "$TELEGRAM_GROUP_ID" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; } && eecho "One or more core variables are empty! Check install_conf.json file; all variables must have a value!"
[[ ! -d "$HOME_DIR" ]] && eecho "Unable to find home directory for \"$USER\"."
for APP in ${DEPENDENCY_APPS[@]}
do
        if ! command -v "$APP" &> /dev/null
        then
			[[ "$APP" == "mytonctrl" ]] && APP="$APP (Download: install.sh and uninstall.sh scripts from https://github.com/ton-blockchain/mytonctrl/blob/master/scripts/)"
			DEPENDENCIES+=$(echo -e "\n\t - $APP")
        fi
done
([ -n "$DEPENDENCIES" ] && echo "Install dependencies and execute this script again.") && eecho "Dependencies:$DEPENDENCIES"
[ "$(docker ps &>/dev/null; echo $?)" -gt 0 ] && eecho "User $USER is unable to execute docker commands! Add docker group to $USER."
[ -z "$SCRIPT_NAME" ] && eecho "SCRIPT_NAME variable is empty. Check command \"basename \$0\""
[ -z "$PROJECT_DIRECTORY" ] && eecho "Can't determine project directory! Check commands dirname and \"realpath $SCRIPT_NAME\"."
[ -z "$(find $PROJECT_DIRECTORY -type d -name ".git")" ] && eecho "Can't find .git dir inside of $PROJECT_DIRECTORY dir. Execute this script inside of Git project for git commands to work."
REPO_NAME="$(basename $PROJECT_DIRECTORY)"; [ -z "$REPO_NAME" ] && eecho "Unable to get name of repository! Check command basename of repositry directory (PROJECT_DIRECTORY: $PROJECT_DIRECTORY)."
[ -d "$BIN_DIR" ] || mkdir $BIN_DIR
RELEASED_TAG="$(git describe --tags)" # Get current tag of repository

### Base installation
echo -n "[1/10] Creating config directory... "
[ -d "$PROJECT_TON_ACCESS_DIR" ] || eecho "$PROJECT_TON_ACCESS_DIR doesn't exist! This folder is mandatory to exist. Check repository."
CONFIG_DIR="$PROJECT_TON_ACCESS_DIR/config"
rm -r $CONFIG_DIR &>/dev/null
mkdir $CONFIG_DIR
[ ! -d "$CONFIG_DIR" ] && eecho "Failed!" || echo "Done"

echo -n "[2/10] Downloading global-mainnet.json and global-testnet.json... "
curl -sL "https://ton-blockchain.github.io/global.config.json" > $CONFIG_DIR/global-mainnet.json; [ ! -s "$CONFIG_DIR/global-mainnet.json" ] && eecho "Error occurred while trying to download global-mainnet.json file! Check URL \"https://ton-blockchain.github.io/global.config.json\"";
curl -sL "https://ton-blockchain.github.io/testnet-global.config.json" > $CONFIG_DIR/global-testnet.json; [ ! -s "$CONFIG_DIR/global-testnet.json" ] && eecho "Error occurred while trying to download global-testnet.json file! Check URL \"https://ton-blockchain.github.io/testnet-global.config.json\"";
echo "Done"

echo "[3/10] Generating local configuration file... "
(sudo -u ubuntu -- python3 /usr/src/mytonctrl/mytoninstaller.py <<< clcf >/dev/null || eecho "Failed! Try to execute \"python3 /usr/src/mytonctrl/mytoninstaller.py <<< clcf\" manually to inspect the issue.") && echo "Done"

echo "[4/11] Configuring fastly keys... "
read -p "Enter FASTLY_SERVICE_ID: " FASTLY_SERVICE_ID ; [ -z "$FASTLY_SERVICE_ID" ] && eecho "FASTLY_SERVICE_ID can't be empty!"
read -p "Enter FASTLY_API_KEY: " FASTLY_API_KEY; [ -z "$FASTLY_API_KEY" ] && eecho "FASTLY_API_KEY can'y be empty!"
sed -e 's/FASTLY_SERVICE_ID=xxx/FASTLY_SERVICE_ID='"$FASTLY_SERVICE_ID"'/' -e 's/FASTLY_API_KEY=xxx/FASTLY_API_KEY='"$FASTLY_API_KEY"'/' $PROJECT_TON_ACCESS_DIR/fastly.env 
echo ""

echo -n "[5/11] Copying ton-access to $HOME_DIR... "
[ -d "$HOME_TON_ACCESS_DIR" ] && rm -rf "$HOME_TON_ACCESS_DIR"
cp -r "$PROJECT_TON_ACCESS_DIR" "$HOME_DIR" ; [ $? -gt 0 ] && eecho "ton-access directory copy failed! Check ton-access location in git project. (PROJECT_TON_ACCESS_DIR: $PROJECT_TON_ACCESS_DIR)";
echo "Done"

echo -n "[6/11] Copying \"$GENERATED_LOCAL_CONF\" in $HOME_TON_ACCESS_DIR/config/ ... "
[ -f "$GENERATED_LOCAL_CONF" ] && cp "$GENERATED_LOCAL_CONF" "$HOME_TON_ACCESS_DIR/config/" || eecho "File $GENERATED_LOCAL_CONF doesn't exist! Try to generate config file manually."
[ ! -f "$HOME_TON_ACCESS_DIR/config/local.config.json" ] && eecho "Failed! Unable to find $HOME_TON_ACCESS_DIR/config/local.config.json"
echo "Done"

echo "[7/11] Build v2 local docker images testnet and mainnet... "
[ -d "$TON_HTTP_API_DIR" ] && rm -r $TON_HTTP_API_DIR
git clone https://github.com/orbs-network/ton-http-api && THA="$(basename "$_" .git)"
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
if ! sudo docker compose -f docker-compose.yaml up -d; then eecho "Failed to run docker compose up."; fi
cd - || eecho "Unable to return to previous directory $OLD_PWD"
echo "Done"
  	
rm -r "$CONFIG_DIR"

### Generate updater script
echo -n "[9/11] Generating updater script to $UPDATER_SCRIPT... "
[ -f "$UPDATER_SCRIPT" ] && rm "$UPDATER_SCRIPT"
cat <<ENDSCRIPT1 > "$UPDATER_SCRIPT"
#!/bin/bash
HOME_DIR="$HOME_DIR"
HOME_TON_ACCESS_DIR="$HOME_TON_ACCESS_DIR"
TON_HTTP_API_DIR="$TON_HTTP_API_DIR"
declare -a DEPENDENCY_APPS=("$DEPENDENCY_APPS")
SCRIPT_NAME="$SCRIPT_NAME"
PROJECT_DIRECTORY="$PROJECT_DIRECTORY"
PROJECT_TON_ACCESS_DIR="$PROJECT_TON_ACCESS_DIR"
GENERATED_LOCAL_CONF="$GENERATED_LOCAL_CONF"
LOG_FILE="$HOME_DIR/$(basename "$PROJECT_DIRECTORY").log"
SLACK_URL="$SLACK_URL"
RELEASED_TAG="$RELEASED_TAG"
GH_RELEASES_API_ENDPOINT="$GH_RELEASES_API_ENDPOINT"
GH_TOKEN="$GH_TOKEN"
TELEGRAM_GROUP_ID="$TELEGRAM_GROUP_ID"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"

ENDSCRIPT1
# Generate second half of the script
cat <<'ENDSCRIPT2' >> "$UPDATER_SCRIPT"
# Error echo
function eecho() {
    printf "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: %s\n" "$@" 1>&2 >$LOG_FILE
	send_slack "$@"
	exit 1;
}

# Informational echo
function iecho() {
    printf "$(date '+%Y-%m-%d %H:%M:%S') - INFO: %s\n" "$@" >$LOG_FILE
}

# Notifications to slack
function send_slack () {
    [ -z "$SLACK_URL" ] && eecho "Unable to send slack because SLACK_URL variable is empty!"
    FORMATED_MESSAGE="$(echo "$1" | sed 's/"/\\"/g' | sed "s/'/\\'/g" )"
    curl -s -X POST $SLACK_URL -H 'Content-type: application/json' --data '{"text":"'"$(hostname): $SCRIPT_NAME: $FORMATED_MESSAGE"'"}' >/dev/null
}

# Notificatios to telegram
function send_telegram () {
	([ -z "$TELEGRAM_GROUP_ID" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]) && eecho "Unable to send telegram because requred variables TELEGRAM_GROUP_ID and TELEGRAM_BOT_TOKEN are not present!"
    FORMATED_MESSAGE="$(echo "$1" | sed 's/"/\\"/g' | sed "s/'/\\'/g" )"
    curl -s --data "text=$FORMATED_MESSAGE" --data "chat_id=$TELEGRAM_GROUP_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage' > /dev/null
}

# Check if new tag has been released
function check() {
    cd $PROJECT_DIRECTORY
    [ -z "$GH_RELEASES_API_ENDPOINT" ] && eecho "Variable GH_RELEASES_API_ENDPOINT is empty!";
    [ -z "$GH_TOKEN" ] && eecho "Variable GH_TOKEN is empty!";
    # Get info from latest release
	RELEASE="$(curl -s -H "Authorization: Bearer $GH_TOKEN" "$GH_RELEASES_API_ENDPOINT" | jq -r '"\(.name)~!~\(.tag_name)~!~\(.published_at)~!~\(.body)~!~\(.label)~!~\(.author.login)~!~\(.html_url)"')"; [ -z "$RELEASE" ] && eecho "Variable RELEASE is empty!";
	RELEASE_NAME="$(echo $RELEASE | awk -F '~!~' '{print $1}')"; [ -z "$RELEASE_NAME" ] && eecho "Variable RELEASE_NAME is empty!";
	RELEASE_TAG="$(echo $RELEASE | awk -F '~!~' '{print $2}')"; [ -z "$RELEASE_TAG" ] && eecho "Variable RELEASE_TAG is empty!";
	RELEASE_TIME="$(echo $RELEASE | awk -F '~!~' '{print $3}')"; [ -z "$RELEASE_TIME" ] && eecho "Variable RELEASE_TIME is empty!";
	RELEASE_BODY="$(echo $RELEASE | awk -F '~!~' '{print $4}')"; [ -z "$RELEASE_BODY" ] && echo "Variable RELEASE_BODY is empty!";
	RELEASE_LABEL="$(echo $RELEASE | awk -F '~!~' '{print $5}')"; [ -z "$RELEASE_LABEL" ] && eecho "Variable RELEASE_LABEL is empty!";
	RELEASE_USER="$(echo $RELEASE | awk -F '~!~' '{print $6}')"; [ -z "$RELEASE_USER" ] && eecho "Variable RELEASE_USER is empty!";
	RELEASE_URL="$(echo $RELEASE | awk -F '~!~' '{print $7}')"; [ -z "$RELEASE_URL" ] && eecho "Variable RELEASE_URL is empty!";

	# Check if we are at the latest release
	[[ "$RELEASED_TAG" == "$RELEASE_TAG" ]] && return 0;
	RELEASED_TAG="$RELEASE_TAG"
	send_slack "Latest release has been changed. Release \"$RELEASE_NAME\"($RELEASE_TAG) have been released on $RELEASE_TIME by $RELEASE_USER. URL: $RELEASE_URL"
	send_telegram "Latest release has been changed. Release \"$RELEASE_NAME\"($RELEASE_TAG) have been released on $RELEASE_TIME by $RELEASE_USER. URL: $RELEASE_URL"
	# Sync with repository
	git pull --tags -r origin $RELEASE_TAG 1>/dev/null 2>$LOG_FILE || send_slack "Unable to pull from origin using tag $RELEASE_TAG. Check log at $LOG_FILE for more info."
	git checkout -f $RELEASE_TAG 1>/dev/null 2>$LOG_FILE || send_slack "Unable to checkout to tag $RELEASE_TAG. Check log at $LOG_FILE for more info."

	# Check commit hash
    if [[ "$(git rev-list -n 1 tags/$RELEASE_TAG)" != "$(git rev-parse HEAD)" ]]; then
     	eecho "Local and remote commit hashes are the same. Check commits on Github."
    fi

	STATUS=$(git status --porcelain)
    if [ ! -z "$STATUS" ]; then
       	eecho "git status: $STATUS!"
    fi

### BEGIN. Define steps to do after new release/tag

	iecho -n "[1/1] Step 1... "
		send_slack "Running step 1... Done"
	iecho "Done"

### END
}

### Main
while true;
do
        check
        sleep 10s
done
ENDSCRIPT2
[ ! -s $UPDATER_SCRIPT ] && eecho "Script $UPDATER_SCRIPT not generated. Check if file exist and have content. You can find updater script in install.sh script inside \"### Generate updater script\" section."
echo "Done"
chmod 700 $UPDATER_SCRIPT || eecho "Failed to change permissions for file $UPDATER_SCRIPT"

### Generate updater service
echo -n "[10/11] Generating service job for updater script... "
[ -f "/etc/systemd/system/$UPDATER_SERVICE" ] && rm "/etc/systemd/system/$UPDATER_SERVICE"
if [ -z "$(systemctl --all list-unit-files -t service | grep -w "$UPDATER_SERVICE")" ]
then
	cat > "/etc/systemd/system/$UPDATER_SERVICE" << ENDSERVICE
[Unit]
Description=Updater script for Ton Access Setup 
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=/bin/bash $UPDATER_SCRIPT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
ENDSERVICE
else
   	echo "$UPDATER_SERVICE already exist! Status: $(systemctl is-active $UPDATER_SERVICE)($(systemctl is-enabled $UPDATER_SERVICE))"
fi
[ ! -s "/etc/systemd/system/$UPDATER_SERVICE" ] && eecho "Failed to generate $UPDATER_SERVICE. Create service manually. You can find service in install.sh script inside \"### Generate updater service\" section."
echo "Done"

echo -n "[11/11] Enabling and restarting $UPDATER_SERVICE... "
systemctl stop "$UPDATER_SERVICE" &>/dev/null
systemctl daemon-reload 
systemctl start "$UPDATER_SERVICE" &>/dev/null
systemctl enable "$UPDATER_SERVICE" &>/dev/null
[ "$(systemctl is-active "$UPDATER_SERVICE" &>/dev/null; echo $?)" -gt 0 ] && eecho "$UPDATER_SERVICE not started! Check service with \"systemctl status $UPDATER_SERVICE\" ."
echo "Done"

echo -n "[12/12] Setup permissions for local ton-access-setup folders"
chown -R $USER:$USER "$UPDATER_SCRIPT" || eecho "Failed to change owner of file $UPDATER_SCRIPT"
chown -R $USER:$USER "$BIN_DIR" || eecho "Failed to change owner of file $BIN_DIR"
chown -R $USER:$USER "$HOME_TON_ACCESS_DIR" || eecho "Failed to change owner of file $HOME_TON_ACCESS_DIR"
echo "Done"
