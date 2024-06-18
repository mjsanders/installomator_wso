#!/bin/zsh
# AppLabel is label to install
AppLabel="iterm2"
InstallomatorPath="/usr/local/Installomator/Installomator.sh"
Variables="LOGO=ws1 NOTIFY=silent BLOCKING_PROCESS_ACTION=prompt_user"

echo " --> Instal or update $AppLabel with Installomator"
$InstallomatorPath $AppLabel $Variables
echo " --> end of script for $AppLabel with Installomator"
exit 0