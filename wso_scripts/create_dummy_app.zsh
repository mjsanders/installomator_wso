#! /bin/zsh
# create_dummy_app.zsh 
#
# Create dummy package for apps installed with installomator
#
# Contributers:
#    Edwin Pijper - @belastingdienst.nl

#--------------------------------------------------------------------------------
# Declare global variables
#--------------------------------------------------------------------------------
APP=
APP_ALREADY_INSTALLED=
APP_EXECUTABLE=
APP_LABEL=
APP_LOWER=
APP_PACKAGE_PATH=
APP_VERSION=
MYORG_APP_VERSION=
MYORG_IDENTIFIER=
CATEGORY=
CODE_SIGN= 
CUR_DIR=$(pwd)
DESCRIPTION=
DESCRIPTION_FILE=
ICON_LOCATION=
ICON_NAME=
IDENTIFIER=
INPUT_ANS=
INSTALLED_APP_PATH=
INSTALLOMATOR=/usr/local/Installomator/Installomator.sh
NEW_ICON_NAME=
NR_FILES_SOURCE_PATH=
PACKAGE_PATH=
PLIST=
PROGRAM=$0
PROGRAM_DIR=/usr/local/mac_tools
SCRIPTS_INCLUDED=
SOURCE_PATH=
CURRENT_USER=

#-----------------------------------------
# Voor testen zonder package te maken
#PROGRAM_BIN_DIR=$(dirname "${PROGRAM}")
#cd "${PROGRAM_BIN_DIR}"
#PROGRAM_BIN_DIR=$(pwd)
#cd ..
#PROGRAM_DIR=$(pwd)
#cd ${CUR_DIR}
#-----------------------------------------

# set to 0 for production, 1 for debugging
# while debugging, items will be downloaded to the parent directory of this script
# debug mode 0, no debug logging is created
# debug mode 1, gives you some information about variables  
# debug mode 2, will show debug information using set -x
DEBUG=0

#--------------------------------------------------------------------------------
# Usage
# Prints the way you have to use the program
# Input:
# -
# Return:
# -
#--------------------------------------------------------------------------------
Usage()
{
    echo ""
    echo "Usage: ${PROGRAM} -a <APP LABEL> -p <PACKAGE PATH> -s <SOURCE PATH> [-d <0|1|2>] [-i] "
    echo "Creates a munki package in <package path>/<APP name>/<version> and creates documentation"
    echo "in <source directory readme.md"
    echo ""
    echo "-a|--app_label     APP label which used in Installomator"
    echo "                   see for label: https://github.com/Installomator/Installomator/blob/main/Labels.txt"
    echo "-d|--debug         0: no debug info, 1 show VATIABLES, 2 show set -x"
    echo "-i|--data_included scripts and description included in the package"
    echo "-p|--package_path  location to store the package and information to use in WorkSpace One"
    echo "-s|--source_path   bitbucket location where to store the source information"
    echo "--description_file File including path witch contains the description info"
    echo ""
    echo "EXAMPLE 1: creating logitechoptionsplus"
    echo "${PROGRAM} "'-a logitechoptionsplus -p "/Users/Shared/WSO/" -s "/Users/Shared/bitbucket/logitech_options_plus"'
    echo ""
    echo "EXAMPLE 2: creating gimp app with debugging on"
    echo "${PROGRAM} "'-a gimp -p "/Users/Shared/WSO/" -s "/Users/Shared/bitbucket/gimp/" -d 1'
    exit 1
}


#--------------------------------------------------------------------------------
GetArgs()
{
# Set arguments used in the command
# Input:
# Arguments from the command
# Return:
# -
#--------------------------------------------------------------------------------
  while [[ "$#" -gt 0 ]]
  do 
    case $1 in
      -a|--app_label)
        APP_LABEL="$2"
        [[ ${APP_LABEL[1,1]} = '-' ]] &&  Display_Error_Usage "Wrong APP_LABEL \"${APP_LABEL}\""
        shift
        ;;
      --categories)
        CATEGORIES="$2"
        shift
        [[ ${CATEGORIES[1,1]} = '-' ]] &&  Display_Error_Usage "Wrong CATEGORIES \"${CATEGORIES}\""
        ;;
      -d|--debug)
        DEBUG="$2"
        shift
        ((DEBUG == 0 || DEBUG == 1 || DEBUG == 2)) || Display_Error_Usage "Wrong DEBUG Level \"${DEBUG}\""
        ;;
      --description_file)
        DESCRIPTION_FILE="$2"
        shift
        [[ ${DESCRIPTION_FILE[1,1]} = '-' ]] &&  Display_Error_Usage "Worng DESCRIPTION_FILE \"$DESCRIPTION_FILE\""
        ;;
      -i|--data_included)
        SCRIPTS_INCLUDED="Included"
        ;;
      -p|--package_path)
        PACKAGE_PATH="$2"
        shift
        [[ ${PACKAGE_PATH[1,1]} = '-' ]] &&  Display_Error_Usage "Wrong PACKAGE_PATH \"${PACKAGE_PATH}\""
        ;;
      -s|--source_path)
        SOURCE_PATH="$2"
        shift
        [[ ${SOURCE_PATH[1,1]} = '-' ]] &&  Display_Error_Usage "Wrong SOURCE_PATH \"${SOURCE_PATH}\""
        ;;
       *)
        echo "ERROR: \"$1\" is an illegal option"
        Usage
        ;;
    esac
    shift
  done

  [[ ${DEBUG} -eq 2 ]] && set -x
  
  [[ -z "${APP_LABEL}" ]] && Display_Error_Usage "ERROR: APP label (-a) is missing"

  [[ -z "${PACKAGE_PATH}" ]] && "ERROR: Package path (-p) is missing"
  
  [[ -z "${SOURCE_PATH}" ]] && "ERROR: Source path (-s) is missing"

  if [[ -n "${DESCRIPTION_FILE}" ]] 
  then
    [[ ! -f "${DESCRIPTION_FILE}" ]] && Display_Error_Usage "ERROR: Description file \"${DESCRIPTION_FILE}\" is not a file"
  fi
  
  NR_FILES_SOURCE_PATH=$(ls "${SOURCE_PATH}" | wc -l)
  
  if [[ ${DEBUG} -eq 1 ]]
  then
    Display_title "Known variabeles"
    Display_vars APP_LABEL "${APP_LABEL}"
    Display_vars CUR_DIR "${CUR_DIR}"
    Display_vars DESCRIPTION_FILE "${DESCRIPTION_FILE}"
    Display_vars INSTALLOMATOR "${INSTALLOMATOR}"
    Display_vars PACKAGE_PATH "${PACKAGE_PATH}"
    Display_vars PROGRAM "${PROGRAM}"
    Display_vars PROGRAM_DIR "${PROGRAM_DIR}"
    Display_vars SCRIPTS_INCLUDED "${SCRIPTS_INCLUDED}"
    Display_vars SOURCE_PATH "${SOURCE_PATH}"
  fi

  print "Check input"
  Check_app_label "${APP_LABEL}"

  # Get home_dir user
  printf "cd\npwd" > /tmp/get_homedir$$.sh
  chmod +x /tmp/get_homedir$$.sh
  getUser
  HOMEDIR=$(runAsUser /tmp/get_homedir$$.sh)
  rm -f /tmp/get_homedir$$.sh
  
  if [[ "${PACKAGE_PATH[1]}" = "~" ]]
  then
    PACKAGE_PATH="${HOMEDIR}/${PACKAGE_PATH:2}"
  fi
  Check_dirs "Package path" "${PACKAGE_PATH}"
  
  if [[ "${SOURCE_PATH[1]}" = "~" ]]
  then
    SOURCE_PATH="${HOMEDIR}/${SOURCE_PATH:2}"
  fi
  Check_dirs "Source path" "${SOURCE_PATH}"
}

#--------------------------------------------------------------------------------
Display_Error_Usage()
{
# Print Error message because wrong input
# Input:
# $1: message
# Return:
# -
#--------------------------------------------------------------------------------
  MSG=$1
  print "ERROR: ${MSG}"
  Usage
}

#--------------------------------------------------------------------------------
Display_info()
{
# Print the comming action 
# Input:
# $1: message
# $2: tabs before message
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  MSG=$1
  if [[ -n $2 ]]
  then
    for ((i=1;i<=$2;i++))
    {
      MSG="   ${MSG}"
    }
  fi
  printf "%-60s: " ${MSG}
}


#--------------------------------------------------------------------------------
Display_title()
{
# Print the title 
# Input:
# $1: message
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  MSG=$1
  printf "%s\n" "${MSG:u}"
  LENGTH_MSG=${#MSG}
  for ((i=1;i<=${LENGTH_MSG};i++))
  do  
    printf "-"
  done
  printf "\n"
}


#--------------------------------------------------------------------------------
Display_vars()
{
# Print key and value 
# Input:
# $1: key 
# $2: value
# Return:
# -
#--------------------------------------------------------------------------------
  KEY=$1
  VALUE=$2
  printf "%-25s: %s\n" ${KEY} ${VALUE}
}


#--------------------------------------------------------------------------------
Display_OK()
{
# Print OK 
# Input:
# - 
# Return:
# -
#--------------------------------------------------------------------------------
  print "[ OK ]"
}


#--------------------------------------------------------------------------------
Display_error()
{
# Print Error  
# Input:
# $1: error message
# $2: exit code 
# Return:
# exit code $2
#--------------------------------------------------------------------------------
  print "[ FAIL ]"
  print "\tError: $1"
  print "\tReturn code: $2"
  exit $2
}


#--------------------------------------------------------------------------------
Check_rc()
{
# Print OK when retrun code is "0" or when not "0" and error message  
# Input:
# $1: rc
# $2: comment when failed
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  
  if [[ $1 -eq 0 ]]
  then
    Display_OK
  else
    Display_error $2 $1
  fi
}


#--------------------------------------------------------------------------------
getUser() 
{
# Get user
# Input:
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  # get current user
  if [[ -n "${SUDO_USER}" ]]
  then
    CURRENT_USER=${SUDO_USER}
  else
    CURRENT_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
  fi 
}


#--------------------------------------------------------------------------------
Question()
{
# Ask question yes or no
# Input:
# $1: question
# Return:
# -
#--------------------------------------------------------------------------------
  QUESTION="$1 [Y|N]:"
  INPUT_ANS=""

  while [[ "${INPUT_ANS}" = "" ]]
  do
    vared -p "${QUESTION}" -c INPUT_ANS
    if [ "${INPUT_ANS}" != "Y" -a "${INPUT_ANS}" != "y" -a "${INPUT_ANS}" != "N" -a "${INPUT_ANS}" != "n" ]
    then
      echo "Give an answer \"Y\" if \"yes\" or \"N\" if \"no\""
      INPUT_ANS=""
    fi
  done
  INPUT_ANS=${INPUT_ANS:u}
}


#--------------------------------------------------------------------------------
runAsUser() {
# Run command us user
# Input:
# $1: $@
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  UID=$(id -u "${CURRENT_USER}")
  launchctl asuser ${UID} sudo -u ${CURRENT_USER} "$@"
}


#--------------------------------------------------------------------------------
Check_used_tools()
{
# Check if munkipkg is installed
# Input:
# Arguments from the command
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  ${PROGRAM_DIR}/bin/install_tools.zsh
  
  Display_info "Installomator is installed"
  [[ -s "${INSTALLOMATOR}" ]]
  Check_rc $? "Can't find Installomator (${INSTALLOMATOR})"
}


#--------------------------------------------------------------------------------
Check_app_label()
{
# Checks if app label exists in Installomator  
# Input:
# $1: app label
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
 
  Display_info "APP label exists in Installomator" 1
  /usr/local/Installomator/Installomator.sh > /tmp/ceck_app_label$$
  grep "^$1$" /tmp/ceck_app_label$$ > /dev/null 2>&1
  ANS=$?
  rm -f /tmp/ceck_app_label$$
  Check_rc ${ANS} "Label \"$1\" don't exist. Search for the right label by using command /usr/local/Installomator/Installomator.sh"
}


#--------------------------------------------------------------------------------
Check_dirs()
{
# Checks if input is a directory  
# Input:
# $1: argument
# $2: directory
# Return:
# -
#--------------------------------------------------------------------------------
  ARG=$1
  DIR=$2
  Display_info "${ARG} is a directory" 1
  if [[ -d "${DIR}" ]]
  then
    Display_OK
  else
    Display_error "\"${DIR}\" is not a directory" 100 
  fi
}

#--------------------------------------------------------------------------------
Check_user_root()
{
# Checks if user is root  
# Input:
# -
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  Display_info "user is root"
  if [[ $(whoami) = 'root' ]]
  then
    Display_OK
  else
    Display_error "User has to be \"root\"" 10
  fi
}


#--------------------------------------------------------------------------------
Create_source_dirs()
{
# Create source directories 
# Input:
# $1: SOURCE_PATH
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  SOURCE_PATH=$1
  APP_PACKAGE_PATH=$2
  SCRIPT_DIR="${SOURCE_PATH}/scripts"

  print "Create directory structure"
  Display_info "Create <source dir>/bin and <source dir>/etc directory" 1
  runAsUser mkdir -p "${SOURCE_PATH}/bin" "${SOURCE_PATH}/etc" "${SOURCE_PATH}/data"
  Check_rc $? "mkdir -p \"${SOURCE_PATH}/bin\" \"${SOURCE_PATH}/etc\" \"${SOURCE_PATH}/data\""

# create script dir
  Display_info "create script dir" 1
  runAsUser mkdir -p "${SCRIPT_DIR}"
  Check_rc $? "mkdir -p \"${SCRIPT_DIR}\" FAILED"

  Display_info "create munki_project dir" 1
  runAsUser mkdir -p "${SOURCE_PATH}/munkipkg_project"
  Check_rc $? "mkdir -p \"${SOURCE_PATH}/munkipkg_project\" FAILED"

  Display_info "create package dir" 1
  runAsUser mkdir -p "${APP_PACKAGE_PATH}" 
  Check_rc $? "Can't create app package dir \"${APP_PACKAGE_PATH}\"" 50

}


#--------------------------------------------------------------------------------
Install_app()
{
# Install app to get some information about it  
# Input:
# -
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  LABEL=$1
  Display_info "Install app to get information"
  LOG=/tmp/installomator_${APP_LABEL}$$.log
  eval "${INSTALLOMATOR}" "${LABEL}" > ${LOG} 2>&1
  Check_rc $? "App is not installed"

  APP=$(grep "App(s) found" ${LOG} 2> /dev/null | awk -F\/ '{print $NF}' | sed 's/.app//')
  if [[ -z "${APP}" ]]
  then
    APP=$(grep "Latest version" ${LOG})
    APP="$(echo ${APP} | sed -e  's%^.*version of %%'  -e 's% is.*$%%')"
  fi
  APP_LOWER=${APP:l}
  MYORG_IDENTIFIER=my.org.${APP_LOWER}
  if grep "No previous app found" ${LOG} > /dev/null 2>&1
  then
    APP_ALREADY_INSTALLED="False"
  else
    APP_ALREADY_INSTALLED="True"
  fi
  INSTALLED_APP_PATH="$(grep \"App(s) found\" ${LOG} 2> /dev/null | sed 's/App(s) found: //')"
  [[ -z "${INSTALLED_APP_PATH}" ]] && INSTALLED_APP_PATH=/Applications/${APP}.app
  
  if [[ ${DEBUG} -eq 1 ]]
  then
    Display_title "Found variabeles"
    Display_vars APP "${APP}"
    Display_vars APP_ALREADY_INSTALLED "${APP_ALREADY_INSTALLED}"
    Display_vars MYORG_IDENTIFIER "${MYORG_IDENTIFIER}"
  fi

  rm -f "${LOG}"
}


#--------------------------------------------------------------------------------
Check_uninstaller()
{
# CHeck if unninstaller info is needed
# Input:
# $1: APP
# Return:
# 0: if needed
# 1: if not neeeded
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  set -x

  APP_LABEL=$1
  SOURCE_PATH=$2
  OUTPUTLOG=${SOURCE_PATH}/data/uninstaller.log

  Display_info "Uninstaller info available"
  if /usr/local/uninstaller/uninstaller.sh | grep "^${APP_LABEL}$"
  then
    # app is already configured in uninstaller
    print "NVT: De app is al bekend binnen het uninstaller.sh script" > ${OUTPUTLOG}
    Display_OK
    return 0
  else 
    # app is not know in uninstaller
    Display_OK
    return 1
  fi
}

#--------------------------------------------------------------------------------
Start_stop_app()
{
# Start and stio app to get user info locations  
# Input:
# $1: APP
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  APP=$1
  INSTALLED_APP_PATH=$2
  PLIST="${INSTALLED_APP_PATH}/Contents/Info.plist"
  
  if ! ps -ef | grep "${INSTALLED_APP_PATH}" | grep -v grep > /dev/null 2>&1
  then
    Display_info "Start ${APP}" 1
    open -g -a "${APP}"
    Check_rc $? "App not started"
    
    Display_info "Stop ${APP}" 1
    for i in {1..3}
    do 
      sleep 10
      runAsUser osascript -e "tell app \"${APP}\" to quit" > /dev/null 2>&1
      ANS=$?
      [[ ${ANS} -eq 0 ]] && break
    done
    Check_rc ${ANS} "App not stopped"
  fi 
}


#--------------------------------------------------------------------------------
Get_app_user_settings_files_dirs()
{
# Start and stio app to get user info locations  
# Input:
# $1: APP
# $2: IDENTIFIER
# $3: SOURCE_PATH
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  APP=$1
  IDENTIFIER=$2
  SOURCE_PATH=$3
  PROGRAM_DIR=$4
  APP_LABEL=$5 
  MYORG_IDENTIFIER=$6
  APP_EXECUTABLE=$7
  OUTPUTLOG=${SOURCE_PATH}/data/uninstaller.log

  Display_info "Get app and user settings files and directories" 1
  # get extra labels to find userfiles and directories used in the APP
  LABELS=$(grep "^${APP}:" "${PROGRAM_DIR}/etc/application_user_library_labels" | cut -d: -f2)
  CHECK_LABELS=$(echo ${LABELS} | awk '
    {
      for (i=1;i<=NF;i++) {
        printf("-e %s ", $i)
      }
    }
    END {print ""}')

  printf "%s)\n" ${APP_LABEL} > ${OUTPUTLOG}
  printf "\t  appTitle=\"%s\"\n" ${APP} >> ${OUTPUTLOG}
  printf "\t  appReceipts+=(\"%s\")\n" ${IDENTIFIER} >> ${OUTPUTLOG}
  printf "\t  appProcesses+=(\"%s\")\n" ${APP_EXECUTABLE} >> ${OUTPUTLOG}
  printf "\t  appFiles+=(\"%s\")\n" ${INSTALLED_APP_PATH} >> ${OUTPUTLOG}
  # get the user files and filter only the parent directories
  CMD="runAsUser find ~/Library 2> /dev/null | grep -ve OneDrive -e .Trash -e .git | grep -i -e \"${APP}\" -e \"${IDENTIFIER}\" ${CHECK_LABELS}"
  eval $CMD  | \
    awk ' 
      BEGIN { 
        DIR = "/tmp"
      }
      {
        NEW_DIR = $0
        if ( DIR != substr(NEW_DIR,1,length(DIR)) )
          {
            DIR = NEW_DIR
            print DIR
        }
    }'  > ${OUTPUTLOG}$$
  Check_rc $? "No references found"
 
  # sort and format the file 
  if [[ $(cat ${OUTPUTLOG}$$ | wc -l) -gt 0 ]]
  then
    Display_info "sort found preferences" 1
    IFS=$'\n'
    for FILE in $(cat ${OUTPUTLOG}$$ | sort | awk '{print $0}')
    do
      if [ -d "${FILE}" ]
      then
        printf "\t  appFiles+=(\"%s\")\n" ${FILE}
        #printf "Directory: %s\n" ${FILE}
      else
        printf "\t  appFiles+=(\"%s\")\n" ${FILE}
        #printf "File:      %s\n" ${FILE}
      fi
    done |  sed "s=${HOME}=<<Users>>=" >> ${OUTPUTLOG}
    Check_rc $? "Sort failed"
    printf "\t  ;;\n" ${APP} >> ${OUTPUTLOG}
  fi
  rm -rf ${OUTPUTLOG}$$
}


#--------------------------------------------------------------------------------
Get_app_info()
{
# Get information about the app  
# Input:
# $1: app
# $2: pacakage path
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  Display_info "Get info about the app"
  APP=$1
  PACKAGE_PATH=$2
  MYORG_APP_VERSION=$3
  INSTALLED_APP_PATH=$4
  PLIST="${INSTALLED_APP_PATH}/Contents/Info.plist"  
  [[ ! -s "${PLIST}" ]] && Display_error  "${PLIST} not found" 20
  
  CODE_SIGN=$(codesign -d -r- "${INSTALLED_APP_PATH}" 2> /dev/null | grep designated | sed 's/.*and anchor/anchor/') 
  [[ -z "${CODE_SIGN}" ]] && Display_error "codesign command failed" 10
  IDENTIFIER=$(codesign -d -r- "${INSTALLED_APP_PATH}" 2> /dev/null | grep designated |  cut -d\" -f2)
  [[ -z "${IDENTIFIER}" ]] && Display_error "codesign command failed" 10
  APP_VERSION_KEY="CFBundleShortVersionString"
  APP_VERSION=$(defaults read "${PLIST}" ${APP_VERSION_KEY})
  [[ -z "${APP_VERSION}" ]] && Display_error "${APP_VERSION_KEY} not found in ${PLIST}" 20  
  MYORG_APP_VERSION=$(date +'%y.%m.%d')
  [[ "${APP_VERSION}" = "${MYORG_APP_VERSION}" ]] && MYORG_APP_VERSION="0.0.0.1"
  APP_VERSION_KEY="CFBundleExecutable"
  APP_EXECUTABLE=$(defaults read "${PLIST}" ${APP_VERSION_KEY})
  [[ -z "${APP_EXECUTABLE}" ]] && Display_Error_Usage "app executable not found" 
  
  ICON_NAME_KEY=CFBundleIconFile
  ICON_NAME=$(defaults read "${PLIST}" ${ICON_NAME_KEY})
  [[ -z "${ICON_NAME}" ]] && Display_error "${ICON_NAME_KEY} not found in ${PLIST}" 25  
  ICON_LOCATION="${INSTALLED_APP_PATH}/Contents/Resources/${ICON_NAME}"
  if [[ ! -s "${ICON_LOCATION}" ]] 
  then
    if [[ -s "${ICON_LOCATION}.icns" ]]
    then
      ICON_LOCATION="${ICON_LOCATION}.icns"
    else
      Display_error "Icon file \"${ICON_LOCATION}\" not found" 30
    fi
  fi
  APP_PACKAGE_PATH="${PACKAGE_PATH}/${APP}/${MYORG_APP_VERSION}"

  Display_OK

  if [[ ${DEBUG} -eq 1 ]]
  then
    Display_title "Found variabeles"
    Display_vars MYORG_APP_VERSION "${MYORG_APP_VERSION}"
    Display_vars ICON_LOCATION "${ICON_LOCATION}"
    Display_vars ICON_LNAME "${ICON_NAME}"
    Display_vars IDENTIFIER "${IDENTIFIER}"
    Display_vars APP_PACKAGE_PATH "${APP_PACKAGE_PATH}"
  fi
}


#--------------------------------------------------------------------------------
Create_description()
{
# Get information about the app  
# Input:
# $1: SOURCE_PATH
# $2: DESCRIPTION_FILE
# $3: SCRIPTS_INCLUDED
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  SOURCE_PATH=$1
  DESCRIPTION_FILE=$2
  SCRIPTS_INCLUDED=$3

  SOURCE_DESCRIPTION_FILE=${SOURCE_PATH}/data/description
  if [[ -s "${DESCRIPTION_FILE}" ]]
  then
    if [[ -s "${SOURCE_PATH}/data/description" ]]
    then 
      Display_info "copy description file to description file.bak" 
      runAsUser cp "${SOURCE_DESCRIPTION_FILE}" "${SOURCE_DESCRIPTION_FILE}.bak"
      Check_rc $? "Can't copy ${SOURCE_DESCRIPTION_FILE} to ${SOURCE_DESCRIPTION_FILE}.bak"
      Display_info "Copy description file to <source dir>/data" 1
      runAsUser cp "${DESCRIPTION_FILE}" "${SOURCE_DESCRIPTION_FILE}"
      Check_rc $? "runAsUser cp \"${DESCRIPTION_FILE}\" \"${SOURCE_DESCRIPTION_FILE}\""
      Display_info "Remove given description file" 1
      runAsUser rm "${DESCRIPTION_FILE}" 
      Check_rc $? "runAsUser rm \"${DESCRIPTION_FILE}\""
    else
      Display_info "Copy description file to <source dir>/data" 1
      runAsUser cp "${DESCRIPTION_FILE}" "${SOURCE_DESCRIPTION_FILE}"
      Check_rc $? "runAsUser cp \"${DESCRIPTION_FILE}\" \"${SOURCE_DESCRIPTION_FILE}\""
      Display_info "Remove given description file" 1
      runAsUser rm "${DESCRIPTION_FILE}" 
      Check_rc $? "runAsUser rm \"${DESCRIPTION_FILE}\""
    fi
  fi
  if [[ ${SCRIPTS_INCLUDED} = "Included" ]]
    then
    DESCRIPTION=$(cat ${SOURCE_DESCRIPTION_FILE})
  fi
}


#--------------------------------------------------------------------------------
Copy_icon()
{
# Copy icon file to package dir
# Input:
# $1: icon path
# $2: package dir
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  
  ICON_LOCATION=$1
  APP_PACKAGE_PATH=$2
  SOURCE_PATH=$3
  APP_LOWER=$4

  Display_info "Convert and copy icon file to <package dir>"
  runAsUser sips -s format png "${ICON_LOCATION}" --out "${APP_PACKAGE_PATH}/${APP_LOWER}.png" > /dev/null 2>&1
  Check_rc $? "format png \"${ICON_LOCATION}\" --out \"${APP_PACKAGE_PATH}/${APP_LOWER}.png\""

  Display_info "Convert and copy icon file to <source dir>"
  runAsUser sips -s format png "${ICON_LOCATION}" --out "${SOURCE_PATH}/${APP_LOWER}.png" > /dev/null 2>&1
  Check_rc $? "format png \"${ICON_LOCATION}\" --out \"${SOURCE_PATH}/${APP_LOWER}.png\""
  NEW_ICON_NAME="${SOURCE_PATH}/${APP_LOWER}.png"
}


#--------------------------------------------------------------------------------
Remove_app()
{
# Get information about the app  
# Input:
# $1: installed app path
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  if [[ "${APP_ALREADY_INSTALLED}" = "False" ]]
  then
    Display_info "Verwijder app (was ook niet aanwezig)"
    INSTALLED_APP_PATH="$1"
    rm -rf "${INSTALLED_APP_PATH}"
    Display_OK
  fi
}


#--------------------------------------------------------------------------------
Create_dummy_package_directory()
{
# Create a dummy package  
# Input:
# $1: app name
# $2: source path
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  Display_info "Create dummy package directory" 1
  APP=$1
  SOURCE_PATH=$2
  cd "${SOURCE_PATH}/munkipkg_project"
  rm -rf "${APP}"

  runAsUser munkipkg --create "${APP}" > /dev/null 2>&1 
  Check_rc $? "Can't create a dummy package"
  chown -R ${USER}:staff "${APP}" > /dev/null 2>&1
  
}

#--------------------------------------------------------------------------------
Edit_file()
{
# edit variables in file   
# Input:
# $1: filename
# $2: variables   (VAR=<value>)
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  FILE=$1
  ANS=0

  [[ -s "${FILE}" ]] || {
    Display_info "${FILE} exist"
    Check_rc 30 "File bestaat niet"
    } 
  
  shift
  for ARG in $@
  do
    KEY=$(echo ${ARG} | cut -d= -f1)
    VALUE=$(echo ${ARG} | cut -d= -f2)
    # Change the identifier, name and version
    runAsUser ed -s ${FILE} > /dev/null 2>&1 <<- EOF
      %s=${KEY}=${VALUE}=g
w
q
EOF
  
  [[ $? -ge ${ANS} ]] && ANS=$?
  done
  
  Check_rc ${ANS} "Changing file \"${FILE}\" failed"
}


#--------------------------------------------------------------------------------
Install_script()
{
# Change scripts pre-, post, preun-, postuninstall  
# Input:
# $1: app name
# $2: source path
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  SCRIPT_NAME=$1
  
  if [[ -s "${SCRIPT_DIR}/${SCRIPT_NAME}" ]]
  then  
    Display_info "${SCRIPT_NAME} package template copied" 1
    echo "[ VRAAG ]"
    echo ""
    VRAAG=$(Display_info "${SCRIPT_NAME} consists. Reuse?" 2)
    Question "${VRAAG}"
    if [[ "${INPUT_ANS}" = "N" ]]
    then 
      if [[ -s "${PROGRAM_DIR}/data/${SCRIPT_NAME}" ]]
      then
        Display_info "copy ${SCRIPT_NAME} naar ${SCRIPT_NAME}.bak" 2
        runAsUser cp "${SCRIPT_DIR}/${SCRIPT_NAME}" "${SCRIPT_DIR}/${SCRIPT_NAME}.bak"
        Check_rc $? "Can't copy ${SCRIPT_NAME} to ${SCRIPT_NAME}.bak"
        Display_info "${SCRIPT_NAME} package template copied" 2
        runAsUser cp "${PROGRAM_DIR}/data/${SCRIPT_NAME}" "${SCRIPT_DIR}"
        Check_rc $? "Can't copy ${SCRIPT_NAME} template"
        Display_info "Edit ${SCRIPT_NAME} package" 2
        Edit_file "${SCRIPT_DIR}/${SCRIPT_NAME}" %APP%="${APP}" %APP_LABEL%="${APP_LABEL}" \
             %INSTALLOMATOR%="${INSTALLOMATOR}" %MYORG_IDENTIFIER%="${MYORG_IDENTIFIER}" \
             %IDENTIFIER%="${IDENTIFIER}"
      else
        Display_info "remove ${SCRIPT_NAME}" 2
        runAsUser rm -f "${SCRIPT_DIR}/${SCRIPT_NAME}"
        Check_rc $? "Can't rm ${SCRIPT_NAME}"
      fi
    fi
  else
    if [[ -s "${PROGRAM_DIR}/data/${SCRIPT_NAME}" ]]
    then
      Display_info "${SCRIPT_NAME} package template copied" 2
      runAsUser cp "${PROGRAM_DIR}/data/${SCRIPT_NAME}" "${SCRIPT_DIR}"
      Check_rc $? "Can't copy ${SCRIPT_NAME} template"
      Display_info "Edit ${SCRIPT_NAME} package" 2
      Edit_file "${SCRIPT_DIR}/${SCRIPT_NAME}" %APP%="${APP}" %APP_LABEL%="${APP_LABEL}" \
            %INSTALLOMATOR%="${INSTALLOMATOR}" %MYORG_IDENTIFIER%="${MYORG_IDENTIFIER}" \
            %IDENTIFIER%="${IDENTIFIER}"
    fi
  fi
}


#--------------------------------------------------------------------------------
Edit_dummy_package()
{
# Change plist and pre- postuninstall  
# Input:
# $1: app name
# $2: source path
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x
  
  APP="$1"
  PROGRAM_DIR="$2"
  SOURCE_PATH=$3
  # suggested version <YY.MM.DD>
  MYORG_VERSION=$(date +'%y.%m.%d')

  
  # copy scripts
  for SCRIPT in preinstall postinstall preuninstall postuninstall
  do
    # preinstall aanmaken
    Install_script ${SCRIPT}
    
    # Scripts in source opgenomen
    if [[ ${SCRIPTS_INCLUDED} = "Included" ]]
    then
      SCRIPT_DIR_SOURCE="${SOURCE_PATH}/munkipkg_project/${APP}/scripts"
      [[ -s "${SCRIPT_DIR}/${SCRIPT}" ]] && \
        runAsUser cp "${SCRIPT_DIR}/${SCRIPT}" "${SCRIPT_DIR_SOURCE}"
    fi
  done

  Display_info "Edit build-info.plist" 1
  # Change the identifier, name and version
  runAsUser ed -s ${SOURCE_PATH}/munkipkg_project/${APP}/build-info.plist > /dev/null <<- EOF
    /<key>identifier
    +1
    s=<string>com.github.munki.pkg.*</string>=<string>${MYORG_IDENTIFIER}</string>=
    /<key>version
    +1
    s/1.0/${MYORG_VERSION}/
w
q
EOF
  Check_rc $? "Changing dummy package plist failed" 31
}


#--------------------------------------------------------------------------------
Create_package()
{
# Change plist and pre- postuninstall  
# Input:
# $1: app name
# $2: source package path , the path where munki project is created
# $3: app package path (<one drive/packages/<app>/<version>)
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  Display_info "Create dummy package" 1
  APP="$1"
  SOURCE_PACKAGE_PATH="$2/munkipkg_project/${APP}"
  APP_PACKAGE_PATH="$3"
  DESCRIPTION=$4
  
  DUMMY_PACKAGE_PATH=$(runAsUser munkipkg "${SOURCE_PACKAGE_PATH}" | grep 'Wrote package' | sed 's/pkgbuild: Wrote package to //')
  [[ -s "${DUMMY_PACKAGE_PATH}" ]]
  Check_rc $? "Cannot create munki package" 
  DUMMY_PACKAGE_NAME=$(echo "${DUMMY_PACKAGE_PATH}" | awk -F/ '{print $NF}' )

  Display_info "Copy package naar package path" 
  runAsUser mv "${DUMMY_PACKAGE_PATH}" "${APP_PACKAGE_PATH}"
  Check_rc $? "Cannot move munki dummy package" 

  Display_info "Create package plist" 
  runAsUser makepkginfo "${APP_PACKAGE_PATH}/${DUMMY_PACKAGE_NAME}" -c device_catalog \
    --category=Software --description="${DESCRIPTION}" --developer="${USER}" \
    --displayname="${APP}" --name="${APP}" -r Installomator \
    > "${APP_PACKAGE_PATH}/${APP}-${MYORG_VERSION}.plist"
  Check_rc $? "Cannot create a new plist"
}


#--------------------------------------------------------------------------------
Copy_files()
{
# Copy hulp files 
# Input:
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  echo Create help scripts
  
  Display_info "Copy gitignore" 1
  runAsUser cp "${PROGRAM_DIR}/data/gitignore" "${SOURCE_PATH}/.gitignore"
  Check_rc $? "runAsUser cp \"${PROGRAM_DIR}/data/edit_documentation_template.zsh\" \"${SOURCE_PATH}/bin/edit_documentation.zsh\""

  Display_info "Copy scripts" 1
  runAsUser cp "${PROGRAM_DIR}/data/edit_documentation_template.zsh" "${SOURCE_PATH}/bin/edit_documentation.zsh"
  Check_rc $? "runAsUser cp \"${PROGRAM_DIR}/data/edit_documentation_template.zsh\" \"${SOURCE_PATH}/bin/edit_documentation.zsh\""

  if [[ ! -f "${SOURCE_PATH}/data/description" ]]
  then
    Display_info "Copy description template" 1
    runAsUser cp "${PROGRAM_DIR}/data/description" "${SOURCE_PATH}/data/description"
    Check_rc $? "runAsUser cp \"${PROGRAM_DIR}/data/BAU_Settings\" \""${SOURCE_PATH}/etc/BAU_Settings"\""
  fi

  Display_info "Copy bau info template" 1
  runAsUser cp "${PROGRAM_DIR}/data/BAU_Settings" "${SOURCE_PATH}/etc/BAU_Settings"
  Check_rc $? "runAsUser cp \"${PROGRAM_DIR}/data/BAU_Settings\" \""${SOURCE_PATH}/etc/BAU_Settings"\""

  Display_info "Change bau configfile" 1
  Edit_file "${SOURCE_PATH}/etc/BAU_Settings" %APP%="${APP}" %APP_LABEL%="${APP_LABEL}" \
  %IDENTIFIER%="${IDENTIFIER}"

  Display_info "Copy create_package.zsh" 1
  runAsUser cp "${PROGRAM_DIR}/bin/create_package.zsh" "${SOURCE_PATH}/bin/create_package.zsh"
  Check_rc $? "runAsUser cp \"${PROGRAM_DIR}/bin/create_package.zsh\" \""${SOURCE_PATH}/bin/create_package.zsh"\""

  Display_info "Change create_package.zsh" 1
  Edit_file "${SOURCE_PATH}/bin/create_package.zsh" %APP%="${APP}" 
}


#--------------------------------------------------------------------------------
Create_documentation()
{
# Copy documentation template and fill vars in  
# Input:
# $1: app name
# $2: source package path , the path where munki project is created
# $3: app package path (<one drive/packages/<app>/<version>)
# Return:
# -
#--------------------------------------------------------------------------------
  [[ ${DEBUG} -eq 2 ]] && set -x

  echo "Create documentation" 
  Display_info "Copy documentatie template" 1
  runAsUser cp "${PROGRAM_DIR}/data/readme_template.md" "${SOURCE_PATH}/readme.md"
  Check_rc $? "Copy Documetation template failed"

  Display_info "Change documentation" 1
  Edit_file "${SOURCE_PATH}/readme.md" %APP%="${APP}" %APP_LOWER%="${APP_LOWER}"\
    %APP_VERSION%="${MYORG_APP_VERSION}" %IDENTIFIER%="${IDENTIFIER}" \
    %CODE_SIGN%="${CODE_SIGN}" %SOURCE_PATH%="${SOURCE_PATH}" \
    %ICON_NAME%="${ICON_NAME}" \ %APP_LABEL%="${APP_LABEL}" \
    %SCRIPTS_INCLUDED%="${SCRIPTS_INCLUDED}"  \
    %MYORG_IDENTIFIER%="${MYORG_IDENTIFIER}"

  Display_info "Add scripts" 1
  "${SOURCE_PATH}/bin/edit_documentation.zsh"
  Check_rc $? "${SOURCE_PATH}/bin/edit_documentation.zsh"
}


#--------------------------------------------------------------------------------
Post_actions()
{
# Advice after executed this parogram 
# Input:
# $1: SOURCE_PATH
# Return:
# -
#--------------------------------------------------------------------------------
  NR_FILES_SOURCE_PATH=$1

  print "\nScript fiunshed\n"

  Display_title "Follow-up actoins"
  print "1 CHECK IN SOURCES"
  print "Run the following commands to check the sources into git:\n"
  print "#---------------------------------------------"
  print "cd \"${SOURCE_PATH}\""
  
  if [[ ${NR_FILES_SOURCE_PATH} -eq 2 ]]
  then
    print "git init"
    print "git add --all"
    print "git commit -m \"Initial Commit\""
  else
    print "git add --all"
    print "git commit -m \"<commentaar wijzigingen>\""
  fi
  print "git push"
  print "#---------------------------------------------"

  print "\nFollow-up actoins finished"

}

#--------------------------------------------------------------------------------
# Main
#--------------------------------------------------------------------------------
# Get arguments
print "\nScript started\n"
GetArgs $@

[[ ${DEBUG} -eq 2 ]] && set -x

Check_used_tools
getUser
#Check_user_root
Install_app "${APP_LABEL}"
Get_app_info "${APP}" "${PACKAGE_PATH}" "${MYORG_APP_VERSION}" "${INSTALLED_APP_PATH}"
Create_source_dirs "${SOURCE_PATH}" "${APP_PACKAGE_PATH}"
Create_description "${SOURCE_PATH}" "${DESCRIPTION_FILE}" "${SCRIPTS_INCLUDED=$3}"
Check_uninstaller "${APP_LABEL}" "${SOURCE_PATH}" > /dev/null 2>&1
# if uninstaller available than rc 0 else 1
if [[ $? -eq 1 ]]
then
  # installer app has no information about the app. Get this information
  Start_stop_app "${APP}" "${INSTALLED_APP_PATH}"
  Get_app_user_settings_files_dirs "${APP}" "${IDENTIFIER}" "${SOURCE_PATH}" "${PROGRAM_DIR}" "${APP_LABEL}" "${MYORG_IDENTIFIER}" "${APP_EXECUTABLE}"
fi
Copy_icon "${ICON_LOCATION}" "${APP_PACKAGE_PATH}" "${SOURCE_PATH}" "${APP_LOWER}"
Remove_app "${INSTALLED_APP_PATH}"
echo "Create dummy package"
Create_dummy_package_directory "${APP}" "${SOURCE_PATH}" 
Edit_dummy_package "${APP}" "${PROGRAM_DIR}" "${SOURCE_PATH}"
Create_package "${APP}" "${SOURCE_PATH}" "${APP_PACKAGE_PATH}" "${DESCRIPTION}"
Copy_files
Create_documentation
Post_actions "${NR_FILES_SOURCE_PATH}"