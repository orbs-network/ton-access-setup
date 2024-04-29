#!/bin/bash 

export USER="$(whoami)"
#export HOME_DIR="$(getent passwd "$USER" | cut -d: -f6)"
export HOME_DIR="$HOME"
export BIN_DIR="$HOME_DIR/bin"
export HOME_TON_ACCESS_DIR="$HOME_DIR/ton-access"
export TON_HTTP_API_DIR="ton-http-api"
export TON_HTTP_API_URL="https://github.com/toncenter/ton-http-api"
export declare -a DEPENDENCY_APPS=("git python3 curl crontab docker mytonctrl jq gh")
export SCRIPT_NAME="${0##*/}"
export PROJECT_DIRECTORY="$(dirname "$(realpath $SCRIPT_NAME)")"
export PROJECT_TON_ACCESS_DIR="$PROJECT_DIRECTORY/ton-access"
export GENERATED_LOCAL_CONF="$(awk -F '\"' '/defaultLocalConfigPath/ {print $2}' /usr/src/mytonctrl/mytoninstaller.py)"
export UPDATER_SCRIPT_NAME="ton_access_setup_updater"
export UPDATER_SCRIPT="$BIN_DIR/$UPDATER_SCRIPT_NAME.sh"
export UPDATER_SERVICE="$UPDATER_SCRIPT_NAME.service"
# Secondary script that will do the update
export UPDATE_SCRIPT="update"
export UPDATE_SCRIPT="$BIN_DIR/$UPDATE_SCRIPT_NAME.sh"

### Functions
# Error echo
source $BIN_DIR/functions/eecho
# Notifications to slack
source $BIN_DIR/functions/send_slack
# Build-v2
source $BIN_DIR/functions/buildDockerTonNets
# Generate Updater systemd service file
source $BIN_DIR/functions/generateSystemdService
# Function restart service
source $BIN_DIR/functions/restartService

### Checks
# Execute as root
[[ ! $(id -u) -eq 0 ]] && eecho "Execute this script with sudo: \"sudo ./$SCRIPT_NAME\".";
# Dependencie apps
for APP in ${DEPENDENCY_APPS[@]}
do
        if ! command -v "$APP" &> /dev/null
        then
			[[ "$APP" == "mytonctrl" ]] && APP="$APP (Download: install.sh and uninstall.sh scripts from https://github.com/ton-blockchain/mytonctrl/blob/master/scripts/)"
			DEPENDENCIES+=$(echo -e "\n\t - $APP")
        fi
done
([ -n "$DEPENDENCIES" ] && echo "Install dependencies and execute this script again.") && eecho "Dependencies:$DEPENDENCIES"
#SLACK_URL="$(jq -r '.SLACK_URL' $CONFIG_FILE)"
#TELEGRAM_GROUP_ID="$(jq -r '.TELEGRAM_GROUP_ID' $CONFIG_FILE)"
#TELEGRAM_BOT_TOKEN="$(jq -r '.TELEGRAM_BOT_TOKEN' $CONFIG_FILE)"
# Notifiaction channels
{ [ -z "$SLACK_URL" ] || [ -z "$TELEGRAM_GROUP_ID" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; } && eecho "One or more core variables are empty, check SLACK_URL, TELEGRAM_GROUP_ID, TELEGRAM_BOT_TOKEN"
# If user have home dir
[[ ! -d "$HOME_DIR" ]] && eecho "Unable to find home directory for \"$USER\"."
# Can user execute docke command
[ "$(docker ps &>/dev/null; echo $?)" -gt 0 ] && eecho "User $USER is unable to execute docker commands! Add docker group to $USER."
# Is SCRIPT_NAME variable empty
[ -z "$SCRIPT_NAME" ] && eecho "SCRIPT_NAME variable is empty. Check command \"basename \$0\""
# Is PROJECT_DIRECTORY variable empty
[ -z "$PROJECT_DIRECTORY" ] && eecho "Can't determine project directory! Check commands dirname and \"realpath $SCRIPT_NAME\"."
# Check .git directory
[ -z "$(find $PROJECT_DIRECTORY -type d -name ".git")" ] && eecho "Can't find .git dir inside of $PROJECT_DIRECTORY dir. Execute this script inside of Git project for git commands to work."
# Try to get repository name
REPO_NAME="$(basename $PROJECT_DIRECTORY)"; [ -z "$REPO_NAME" ] && eecho "Unable to get name of repository! Check command basename of repositry directory (PROJECT_DIRECTORY: $PROJECT_DIRECTORY)."
# Create bin dir if doesn't exist
[ -d "$BIN_DIR" ] || mkdir $BIN_DIR
# Because script is running as root, give USER ownership to bin folder
chown -R $USER:$USER "$BIN_DIR" || eecho "Failed to change owner of file $BIN_DIR"
# Try to get current tag 
CURRENT_TAG="$(git describe --tags)"

### Base installation
./baseInstall.sh
  	
rm -r "$CONFIG_DIR"

### Generate updater script
echo -n "[9/11] Generating updater script to $UPDATER_SCRIPT... "
[ -f "$UPDATER_SCRIPT" ] && rm "$UPDATER_SCRIPT"
cat <<'ENDSCRIPT1' | tee "$UPDATER_SCRIPT" > "$UPDATE_SCRIPT"
#!/bin/bash
HOME_DIR="$HOME_DIR"
HOME_TON_ACCESS_DIR="$HOME_TON_ACCESS_DIR"
TON_HTTP_API_DIR="$TON_HTTP_API_DIR"
declare -a DEPENDENCY_APPS=("$DEPENDENCY_APPS")
PROJECT_DIRECTORY="$PROJECT_DIRECTORY"
PROJECT_TON_ACCESS_DIR="$PROJECT_TON_ACCESS_DIR"
GENERATED_LOCAL_CONF="$GENERATED_LOCAL_CONF"
LOG_FILE="$HOME_DIR/$(basename "$PROJECT_DIRECTORY").log"
SLACK_URL="$SLACK_URL"
CURRENT_TAG="$CURRENT_TAG"
TELEGRAM_GROUP_ID="$TELEGRAM_GROUP_ID"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"

# Error echo
source $BIN_DIR/functions/eecho
# Informational echo
source $BIN_DIR/functions/iecho
source $BIN_DIR/functions/send_slack
source $BIN_DIR/functions/send_telegram
source $BIN_DIR/functions/checkGitTag

ENDSCRIPT1
# Generate second half of the script
cat <<'ENDSCRIPT2' >> "$UPDATER_SCRIPT"
SCRIPT_NAME="$0"

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
chown -R $USER:$USER "$UPDATER_SCRIPT" || eecho "Failed to change owner of file $UPDATER_SCRIPT"

### Generate update.sh script that will execute update of ton-access-setup project
cat <<'ENDSCRIPT3' >> "$UPDATE_SCRIPT"
SCRIPT_NAME="$0"
source $BIN_DIR/functions/eecho
source $BIN_DIR/functions/iecho
source $BIN_DIR/functions/send_slack
source $BIN_DIR/functions/send_telegram

source $BIN_DIR/functions/update

ENDSCRIPT3

### Generate updater service
generateSystemdService
restartService
