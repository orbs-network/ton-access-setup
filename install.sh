#!/bin/bash 

export USER="ubuntu"
export HOME_DIR="$(getent passwd "$USER" | cut -d: -f6)"
export BIN_DIR="${HOME_DIR}bin"
export HOME_TON_ACCESS_DIR="${HOME_DIR}ton-access"
export TON_HTTP_API_DIR="ton-http-api"
export TON_HTTP_API_URL="https://github.com/toncenter/ton-http-api"
export declare -a DEPENDENCY_APPS=("git python3 curl crontab docker mytonctrl jq")
export SCRIPT_NAME="${0##*/}"
export PROJECT_DIRECTORY="$(dirname "$(realpath $SCRIPT_NAME)")"
export PROJECT_TON_ACCESS_DIR="${PROJECT_DIRECTORY}/ton-access"
export GENERATED_LOCAL_CONF="$(awk -F '\"' '/defaultLocalConfigPath/ {print $2}' /usr/src/mytonctrl/mytoninstaller.py)"
export CONFIG_FILE="${PROJECT_DIRECTORY}/install_conf.json"

### Functions
source $PROJECT_DIRECTORY/functions/eecho || { echo "Unable to source function eecho!";exit 1; }
source $PROJECT_DIRECTORY/functions/send_slack || { echo "Unable to source function send_slack!";exit 1; }
#source $PROJECT_DIRECTORY/functions/buildDockerTonNets || { echo "Unable to source function buildDockerTonNets!";exit 1; }
#source $PROJECT_DIRECTORY/functions/send_telegram

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
SLACK_URL="$(jq -r '.SLACK_URL' $CONFIG_FILE)"
#TELEGRAM_GROUP_ID="$(jq -r '.TELEGRAM_GROUP_ID' $CONFIG_FILE)"
#TELEGRAM_BOT_TOKEN="$(jq -r '.TELEGRAM_BOT_TOKEN' $CONFIG_FILE)"
## Notifiaction channels
#{ [ -z "$SLACK_URL" ] || [ -z "$TELEGRAM_GROUP_ID" ] || [ -z "$TELEGRAM_BOT_TOKEN" ]; } && eecho "One or more core variables are empty, check SLACK_URL, TELEGRAM_GROUP_ID, TELEGRAM_BOT_TOKEN"
[ -z "$SLACK_URL" ] && eecho "Core variable is empty, check SLACK_URL"
# If user have home dir
[ ! -d "$HOME_DIR" ] && eecho "Unable to find home directory for \"$USER\"."
# Can user execute docke command
[ "$(sudo -u $USER -- docker ps &>/dev/null; echo $?)" -gt 0 ] && eecho "User $USER is unable to execute docker commands! Add docker group to $USER."
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
  	
#rm -r "$CONFIG_DIR"

### Na kraju cleanup bi valjao posto se svaki put pokrece/skida projekat iznova 
