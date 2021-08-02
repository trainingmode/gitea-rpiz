#!/bin/bash

##################################################
##################################################
# I N I T I A L I Z A T I O N
##################################################
##################################################

# Extract the Input Arguments
customizerOption="${1}"

##################################################
# Ensure the Script is Run from the /gitea-rpiz Directory
gitearpizDir="$(pwd)" # Print and Store the Current Working Directory
# Attempt to Find the gitea-rpiz.sh in the Current Directory
if [[ ! -e "${gitearpizDir}"/gitea-rpiz.config ]]; then
    echo "ERROR: COULD NOT FIND GITEA-RPIZ!"
    echo "Please only execute from the /gitea-rpiz directory."
    echo ""
    echo "Try the following:"
    echo "cd '/path/to your/gitea-rpiz'"
    echo "bash gitea-rpiz.sh custom"
    exit 1 # Exit with Errors
fi

# Initialize the gitea-rpiz Internal Paths
gitearpizConfig="${gitearpizDir}/gitea-rpiz.config"

##################################################
##################################################
# F U N C T I O N S
##################################################
##################################################

##################################################
# Applies Training Mode's Outset Theme to Whiptail.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [foreground] The foreground color for the theme. Text, etc.
# [background] The background color for the theme.
# [root] The terminal background color for the theme.
whiptailThemeOutset() {
    # Export Whiptail Colors to newt
    export NEWT_COLORS="
        root=${2},${4}
        window=bright${1},${3}
        border=${3},bright${1}
        title=${2},${1}
        textbox=${2},${3}
        acttextbox=${2},${1}
        entry=${2},${1}
        disentry=${2},gray
        listbox=bright${1},${3}
        actsellistbox=${2},${1}
        actlistbox=bright${1},${1}
        compactbutton=bright${1},${3}
        actbutton=bright${1},${3}
        button=${2},${1}
        fullscale=${2},bright${1}
        emptyscale=${2},${1}
    "
}

##################################################
# Applies a dark theme to Whiptail based on the
# input [color] using the Outset Theme.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [colorRoot] The terminal background color for the theme. Default is "black".
whiptailDarkTheme() {
    # Default Inputs
    rootColor="black"
    if [[ -n "${2}" ]]; then rootColor="${2}"; fi # Set the Root Color if a Color was Specified
    # Set the Whiptail Theme
    whiptailThemeOutset "${1}" "white" "black" "${rootColor}"
}

##################################################
# Set the Whiptail Theme Color
whiptailCurrentThemeColor="green"
whiptailDarkTheme "$whiptailCurrentThemeColor"
##################################################
# Set the Whiptail Theme Size
whiptailGaugeWindowSize=(7 50) #"${whiptailGaugeWindowSize[@]}"

##################################################
# B A S H  G O T O
# by Bob Copeland
# https://bobcopeland.com/blog/2012/10/goto-in-bash/
##################################################
function jumpto {
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" "$0" | grep -v ':$')
    eval "$cmd"
    exit
}

##################################################
# Properly moves a Whiptail Gauge Scale, while
# while updating the Whiptail Gauge info text.
#
# [percent] The current completion percent for the Gauge.
# [infoText] The text to update on the Gauge. If empty, does not update.
whiptailGaugeProgress() {
    # Determine Whether the Number of Input Arguments
    if [[ -n "${2}" ]]; then # The Gauge Info Text was Specified
        # Update the Gauge Progress and Info Text
        echo -e "XXX\n${1}\n${2}\nXXX"
    # No Second Argument Specified, Update Only the Gauge Progresss
    else echo "${1}"; fi
}

##################################################
# Opens a Whiptail dialog to ask for a valid file
# or directory path, depending on the input flags.
#
# [titleText] The title of the Whiptail dialog.
# [descriptionText] The description for the Whiptail dialog.
#   -d | Dialog with checks for directory paths.
#   -c [cancelButtonText] | The text for the cancel button. Default is "EXIT".
#   -j [jumptoExitTag] | The [jumpto] tag to use when the user clicks the cancel button. Default is "customreset".
#   -t [defaultInputText] | The default text shown in the input box.
# Returns: [path] The user specified path.
whiptailInputPathReturn="" # Initialize the Function Return
whiptailInputPath() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    # cflag="" cflag="-${flag}";
    # dflag="" dflag="-${flag}";
    # jflag="" jflag="-${flag}";
    # tflag="" tflag="-${flag}";
    cancelButtonText="EXIT"
    isDirectory="false"
    jumptoExitTag="customreset"
    defaultInputText=""
    while getopts "c:dj:t:" flag; do
        case "${flag}" in
            c) cancelButtonText="${OPTARG}" ;;
            d) isDirectory="true" ;;
            j) jumptoExitTag="${OPTARG}" ;;
            t) defaultInputText="${OPTARG}" ;;
            *) echo "Unhandled argument." ;;
    esac; done; shift $((OPTIND-1)) # Reset the Options Index
    # Initialize the Function Returns
    whiptailInputPathReturn=""

    # Set the Specified Dialog Options
    pathDialogText="file"
    pathDialogTitleText="FILE"
    if [[ $isDirectory == "true" ]]; then
        pathDialogText="directory"
        pathDialogTitleText="DIRECTORY"; fi

    # Initialize the Custom Readme File Path for Replacing Invalid Whiptail Input Dialog Entries
    inputPath="${defaultInputText}"
    while true; do # Loop Until a Valid Readme File is Entered
        # Specify the Readme Filepath
        ##################################################
        # Whiptail Input for Directory Path
        whiptailInputDialogPath=$(whiptail --title " ${1} " --ok-button "OK" --cancel-button "${cancelButtonText}" \
            --inputbox "\n${2}" 0 0 "${inputPath}" \
            3>&1 1>&2 2>&3 ) dialogExit=$? ###############
        # Whiptail Dialog Canceled, Exit the Path Installer
        if [[ $dialogExit != 0 ]]; then jumpto "${jumptoExitTag}"; fi # Reset the Customizer Back to Start
        ##################################################
        # Store the Input Path
        inputPath="${whiptailInputDialogPath}"
        ##################################################
        # Confirm the Specified Path Exists
        if [[ -e "${whiptailInputDialogPath}" ]]; then
            # Specified Path Exists, Return the Path
            whiptailInputPathReturn="${whiptailInputDialogPath}"
            return 0 # Return Without Errors
        ##################################################
        # Specified Directory Does Not Exist
        else whiptail --title " INVALID $pathDialogTitleText " --msgbox "The input $pathDialogText does not exist." 0 0 --ok-button "OK" 3>&1 1>&2 2>&3; fi
        ##################################################
    done
}

##################################################
# Opens a Whiptail dialog to ask for a file path,
# confirm it's existence, and ask to create the
# folder if it does not exist.
# [titleText] The title of the Whiptail dialog.
# [descriptionText] The description for the Whiptail dialog.
#   -d | Dialog with checks for directory paths.
#   -c [cancelButtonText] | The text for the cancel button. Default is "EXIT".
#   -j [jumptoExitTag] | The [jumpto] tag to use when the user clicks the cancel button. Default is "customreset".
#   -t [defaultInputText] | The default text shown in the input box.
#   -u [pathOwner] | The user that owns the path.
# Returns: [path] The user specified path.
whiptailInputPathCreateReturn="" # Initialize the Function Return
whiptailInputPathCreate() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    # cflag="" cflag="-${flag}";
    # dflag="" dflag="-${flag}";
    # jflag="" jflag="-${flag}";
    # tflag="" tflag="-${flag}";
    # uflag="" uflag="-${flag}";
    cancelButtonText="EXIT"
    isDirectory="false"
    jumptoExitTag="customreset"
    defaultInputText=""
    pathOwner=""
    while getopts "c:dj:t:u:" flag; do
        case "${flag}" in
            c) cancelButtonText="${OPTARG}" ;;
            d) isDirectory="true" ;;
            j) jumptoExitTag="${OPTARG}" ;;
            t) defaultInputText="${OPTARG}" ;;
            u) pathOwner="${OPTARG}" ;;
            *) echo "Unhandled argument." ;;
    esac; done; shift $((OPTIND-1)) # Reset the Options Index
    # Initialize the Function Returns
    whiptailInputPathCreateReturn=""

    # Set the Specified Dialog Options
    pathDialogText="file"
    pathDialogTitleText="FILE"
    if [[ $isDirectory == "true" ]]; then
        pathDialogText="directory"
        pathDialogTitleText="DIRECTORY"; fi

    # Initialize the Custom Readme File Path for Replacing Invalid Whiptail Input Dialog Entries
    whiptailInputPath="${defaultInputText}"
    while true; do # Loop Until a Valid Readme File is Entered
        # Specify the Readme Filepath
        ##################################################
        # Whiptail Input for Directory Path
        whiptailInputDialogPath=$(whiptail --title " ${1} " --ok-button "OK" --cancel-button "${cancelButtonText}" \
            --inputbox "\n${2}" 0 0 "${whiptailInputPath}" \
            3>&1 1>&2 2>&3 ) dialogExit=$? ###############
        # Whiptail Dialog Canceled, Reset the Customizer Back to Start
        if [[ $dialogExit != 0 ]]; then jumpto "${jumptoExitTag}"; fi
        ##################################################
        # Store the Input File Path
        whiptailInputPath="${whiptailInputDialogPath}"

        ##################################################
        if [[ ! -e "${whiptailInputPath}" ]]; then
            ##################################################
            # Whiptail Confirmation to Create Path
            if (whiptail --title " INVALID $pathDialogTitleText " --yesno "The input $pathDialogText does not exist.\nWould you like to create it?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # User Selected Yes
                # Create the Specified Directory
                if [[ $isDirectory == "true" ]]; then
                    # Determine if a Owner was Specified for the Directory
                    if [[ -n ${pathOwner} ]]; then
                        sudo -u git mkdir -p "${whiptailInputPath}" # Make 'git' the Owner of the Directory
                        # sudo chown -R git:git "${whiptailInputPath}" # Make 'git' the Owner of the Directory
                    # Create the Directory with root Ownership
                    else sudo mkdir -p "${whiptailInputPath}"; fi
                # Create the Specified File
                else
                    # Determine if a Owner was Specified for the File
                    if [[ -n ${pathOwner} ]]; then
                        sudo -u git nano "${whiptailInputPath}" # Make 'git' the Owner of the File
                    # Create the File with root Ownership
                    else sudo nano "${whiptailInputPath}"; fi
                fi
                ##################################################
                whiptail --title " CREATED $pathDialogTitleText " --msgbox "The ${whiptailInputPath} $pathDialogText was created" 0 0 --ok-button "OK" 3>&1 1>&2 2>&3
                ##################################################
                # Return the Path
                whiptailInputPathCreateReturn="${whiptailInputPath}"
                return 0 # Return Without Errors
            fi
            ##################################################
        # Specified Exists, Return the Path
        else whiptailInputPathCreateReturn="${whiptailInputPath}"
            return 0 # Return Without Errors
        fi
    done
}

##################################################
# Reads the gitea-rpiz.config and extracts the
# Gitea working and repositories directories. If
# the gitea-rpiz.config is not found, asks the user
# to enter the paths and flags the gitea-rpiz.config
# as not found.
# Returns: [gitearpizConfigFound] True if the gitea-rpiz.config was found.
#          [giteaDirectory] The path to the Gitea working directory. Default: /var/lib/gitea
#          [repositoriesDirectory] The path to the Gitea repositories. Default: /home/git/repositories
gitearpizConfigFound=true
giteaDirectory="/var/lib/gitea" # Default Gitea Working Directory
repositoriesDirectory="/home/git/repositories" # Default Gitea Repository Directory
gitearpizConfigReader() {
    # Initialize the Function Returns
    giteaDirectory="/var/lib/gitea" # Default Gitea Working Directory
    repositoriesDirectory="/home/git/repositories" # Default Gitea Repository Directory

    # Extract the gitea-rpiz Installation Configuration
    if [[ -e "${gitearpizConfig}" ]]; then # Ensure the gitea-rpiz Installation Configuration File Exists
        ##################################################
        TERM=ansi whiptail --title " READING CONFIG " --infobox "Reading the gitea-rpiz.config..." 0 0
        ##################################################
        # Safely Read the gitea-rpiz.config if it Exists
        while IFS='=' read -r configOption configValue; do # Read the gitea-rpiz.config Line-by-Line
            # Extract the gitea Working Directory Path
            if [[ $configOption == "GITEA_INSTALL_PATH" ]]; then
                giteaDirectory="${configValue}/gitea"
            # Extract the Gitea Repository Directory Path
            elif [[ $configOption == "GITEA_REPO_PATH" ]]; then
                repositoriesDirectory="$configValue"
            fi
        done < "${gitearpizConfig}" # Read from the gitea-rpiz.config
    # gitea-rpiz Configuration Not Found, Prompt User for Required Locations
    else gitearpizConfigFound=false
        ##################################################
        # Whiptail Input Path Dialog for the Repositories Path
        whiptailInputPath -d "CONFIG NOT FOUND" "Cannot locate the gitea-rpiz.config file in the gitea-rpiz directory.\nPlease type the path to your repositories.\n| Default: ${repositoriesDirectory}"
        repositoriesDirectory="${whiptailInputPathReturn}" # Extract the Function Output
        ##################################################
        # Whiptail Input Path Dialog for the Repositories Path
        whiptailInputPath -d "CONFIG NOT FOUND" "Please type the path to your Gitea working directory.\n| Default: ${giteaDirectory}"
        giteaDirectory="${whiptailInputPathReturn}" # Extract the Function Output
        ##################################################
    fi
}

##################################################
# Writes the specified gitea-rpiz.config value.
# [configTag] The config tag to edit. Supported: GITEA_INSTALL_PATH, GITEA_REPO_PATH
# [configValue] The new value for the specified config tag.
gitearpizConfigWriter() {
    # Extract the Inputs
    gitearpizConfigWriteTag="${1}"
    gitearpizConfigWriteValue="${2}"

    # Safely Write to the gitea-rpiz Configuration
    if [[ -e "${gitearpizConfig}" ]]; then # Ensure the gitea-rpiz Installation Configuration File Exists
        sudo sed -i 's|^'"${gitearpizConfigWriteTag}"'=.*|'"${gitearpizConfigWriteTag}=${gitearpizConfigWriteValue}"'|' "${gitearpizConfig}" # Replace the Specified gitea-rpiz.config Value
    # gitea-rpiz Configuration Not Found, Prompt User for Required Locations
    ##################################################
    else whiptail --title " CONFIG NOT FOUND " --msgbox "The gitea-rpiz.config file was not found." 0 0 --ok-button "OK"; fi
    ##################################################
}

##################################################
##################################################
# S C R I P T
##################################################
##################################################

##################################################
# Check for a Previous Gitea Installation
giteaAppDir="/usr/local/bin/gitea" # The Gitea Recommended Installation Directory
giteaAppPath="/usr/local/bin/gitea/gitea" # The Gitea Recommended Binary Path
giteaAppIniPath="/etc/gitea/app.ini" # The Gitea app.ini Recommended File Path
if [[ ! -e "${giteaAppDir}" ]] || [[ ! -e "${gitearpizConfig}" ]]; then
    ##################################################
    # Whiptail Confirmation to Continue Installation
    if (! whiptail --title " GITEA NOT FOUND " --yesno "Gitea was not found or was not installed\nusing gitea-rpiz.\nWould you like to continue customizing Gitea?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Cancel the Gitea Installation
        ##################################################
        whiptail --title " CUSTOMIZING CANCELLED " --msgbox "Gitea customization cancelled." 0 0 --ok-button "OK"
        ##################################################
        # Exit Without Errors
        exit 0
    fi
    ##################################################
fi

##################################################
# Gitea Customizer for Raspberry Pi Zero
##################################################
# Begin Script
jumpto start
# GOTO start
start:

# Import the Input Customizer Option Argument
if [[ -n "${customizerOption}" ]]; then
    wmenuGiteaCustom="${customizerOption}"

# No Customizer Input Argument, Ask User for Desired Option
else
    ##################################################
    # Whiptail Menu for Gitea Customizer
    wmenuGiteaCustom=$(
        whiptail --title " GITEA RPIZ " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nHow would you like to customize Gitea?" 0 0 0 \
        "BACKUP"    "Backup Gitea." \
        "BROWSE"    "Browse local Gitea locations." \
        "CONFIG"    "Edit the Gitea app.ini." \
        "EZFIG"     "Easily configure Gitea app.ini settings." \
        "GITIGNORE" "Install a custom .gitignore." \
        "LABELS"    "Install a custom label set." \
        "LAUNCHER"  "Install a desktop/menu launcher." \
        "LICENSE"   "Install a custom license." \
        "README"    "Install a custom readme." \
        "RESTORE"   "Restore Gitea." \
        "SERVICE"   "Easy Gitea Service handler." \
        "THEME"     "Install a custom theme." \
        "UPDATE"    "Update the Gitea executable." \
    3>&2 2>&1 1>&3 ) dialogExit=$? ###################
    # Whiptail Dialog Canceled, Exit the Gitea Customization
    if [[ $dialogExit != 0 ]]; then exit; fi
    ##################################################
    case $wmenuGiteaCustom in
        # Continue the Customization if a Valid Option was Entered
        BACKUP | BROWSE | CONFIG | EZFIG | GITIGNORE | LABELS | LAUNCHER | LICENSE | README | RESTORE | SERVICE | THEME | UPDATE)
            wmenuGiteaCustom="${wmenuGiteaCustom,,}" # Set the gitea-rpiz Customizer Option as All Lowercase
            ;;
    esac

fi

##################################################
# Searches the Gitea app.ini for the input header and config tags
# and returns true if they are found, along with the line index
# of the config tag.
#
# [headerTag] The header tag the config is under including brackets, as a string.
# [configTag] The configuration tag, as a string.
#   -f [appIniFile] | The path to the app.ini file.
#   -v | Print verbose output.
# RETURNS: [1] bool, headerTagExists - Returns true if the header tag was found.
#          [2] bool, configTagExists - Returns true if the config tag was found.
#          [3] int, configLineIndex - The line index the config tag was found on.
declare findConfigAppIniReturn # Initialize the [findConfigAppIni()] Return Array
function findConfigAppIni() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    fflag=""
    vflag=""
    # findAppIni="${giteaAppIniPath}"
    findAppIni="/etc/gitea/app.ini"
    printDebug="false"
    while getopts "f:v" flag; do
        case "${flag}" in
            f) fflag="-${flag}"; findAppIni="${OPTARG}" ;;
            v) vflag="-${flag}"; printDebug="true" ;;
            *) echo "Unhandled argument." ;;
        esac
    done
    shift $((OPTIND-1)) # Reset the Options Index
    # Extract Inputs
    findHeaderTag="${1}"
    findConfigTag="${2}"
    # Reset the Array used to Store Return Values
    unset findConfigAppIniReturn
    # Read the app.ini Line by Line
    headerTagExists="false"
    configTagExists="false"
    configLineIndex=0 # The Current Line Index
    while IFS=, read -r readline; do
        # Increment the Current Line Index
        ((++configLineIndex))
        # Search for the Configuration Tag
        if [[ $headerTagExists == "true" ]]; then
            if [[ "${readline}" == *"${findConfigTag}"* ]]; then
                # Flag that the Config Tag was Found
                if [[ $printDebug ==  "true" ]]; then echo "${findConfigTag} setting found..."; fi
                configTagExists="true"
                # Stop Reading the app.ini and Return the Results
                break
            fi
        # Search for the Header Tag
        else
            if [[ "${readline}" == *"${findHeaderTag}"* ]]; then
                # Flag that the Header was Found and to Begin Searching for the Config
                if [[ $printDebug ==  "true" ]]; then echo "${findHeaderTag} section found..."; fi
                headerTagExists="true"
            fi
        fi
    done < <(sudo cat "${findAppIni}") #< "${findAppIni}"

    # Return the Search Results
    findConfigAppIniReturn=("$headerTagExists" "$configTagExists" "$configLineIndex")
}
##################################################

##################################################
# Edits the input Gitea app.ini config setting.
#
# Uses [findConfigAppIni()] to properly determine whether
# or not to insert or replace the config setting.
#
# [headerTag] The header tag, as a string. Ex: "[repository.upload]".
# [configTag] The config tag, as a string. Ex: "MAX_SIZE".
# [configValue] The value to set for the config setting.
#   -f [appIniFile] | The path to the app.ini file.
#   -v | Print verbose output.
#   -h | Print help.
function editConfigAppIni() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    fflag=""
    vflag=""
    appIniFile="${giteaAppIniPath}"
    printDebug="false"
    while getopts "f:hv" flag; do
        case "${flag}" in
            f) fflag="-${flag}"; appIniFile="${OPTARG}" ;;
            h) echo "Help output." ;;
            v) vflag="-${flag}"; printDebug="true" ;;
            *) echo "Unhandled argument." ;;
        esac
    done
    shift $((OPTIND-1)) # Reset the Options Index
    # Extract the Input Tags and Config Setting Value
    headerTag="${1}"
    configTag="${2}"
    configValue="${3}"
    # Insert '\' Escaping Backslashes Before the '[]' Brackets for the Match Pattern
    headerTagMatch="\\${headerTag:0:${#headerTag}-1}\\${headerTag:${#headerTag}-1}"

    # Search the app.ini for the Header and Config Tags
    if [[ "${fflag}" == "-f" ]] && [[ "${vflag}" == "-v" ]]; then # Search the -f app.ini File with -v Verbose Output
        findConfigAppIni "${fflag}" "${appIniFile}" "${vflag}" "${headerTag}" "${configTag}"
    elif [[ "${fflag}" == "-f" ]]; then # Search the -f app.ini File
        findConfigAppIni "${fflag}" "${appIniFile}" "${headerTag}" "${configTag}"
    elif [[ "${vflag}" == "-v" ]]; then # Search the Application app.ini with -v Verbose Output
        findConfigAppIni "${vflag}" "${headerTag}" "${configTag}"
    else # Search the Application app.ini
        findConfigAppIni "${headerTag}" "${configTag}"
    fi
    # Extract the Search Results
    foundHeaderTag=${findConfigAppIniReturn[0]} # Extract Whether or Not the Header Tag was Found
    foundConfigTag=${findConfigAppIniReturn[1]} # Extract Whether or Not the Config Tag was Found
    foundLineIndex=${findConfigAppIniReturn[2]} # Extract the Line Number the Config Tag was Found On

    # Edit the app.ini if the Config Tag was Found
    if [[ $foundConfigTag == "true" ]]; then
        if [[ $printDebug ==  "true" ]]; then echo "Updating the ${headerTag} ${configTag}..."; fi
        # Replace the Entire Line Configuration at the Line Index Found
        sudo sed -i ''"${foundLineIndex}"'s|^'"${configTag}"'.*|'"${configTag}"' = '"${configValue}"'|' "${appIniFile}"
    # The Config Tag was Not Found, Add the Config
    else
        # Add the Config Tag Below the Header Tag
        if [[ $foundHeaderTag == "true" ]]; then
            if [[ $printDebug ==  "true" ]]; then echo "${configTag} not found, adding the setting to app.ini..."; fi
            # Insert the Config Tag Below the Header Tag
            sudo sed -i '/^'"${headerTagMatch}"'.*/a '"${configTag}"' = '"${configValue}"'' "${appIniFile}"
        # The Config Tag was Not Found, Add Both the Header and Config Tags
        else
            # Add the Header Tag to the End of the app.ini
            if [[ $printDebug ==  "true" ]]; then echo "${headerTag} not found, adding the section to app.ini..."; fi
            sudo sed -i -e '$a\\n'"${headerTag}"'' "${appIniFile}" # Add a Newline and the Header Tag to the End of the app.ini
            # Add the Config Tag to the End of the app.ini
            if [[ $printDebug ==  "true" ]]; then echo "${configTag} not found, adding the setting to app.ini..."; fi
            sudo sed -i -e '$a\'"${configTag}"' = '"${configValue}"'' "${appIniFile}" # Add the Config Tag to the End of the app.ini
        fi
    fi
}
##################################################

##################################################
# Reads the Gitea app.ini for the input header and
# config tags and returns the config value, if found.
#
# [headerTag] The header tag the config is under including brackets, as a string.
# [configTag] The configuration tag, as a string.
#   -f [appIniFile] | The path to the app.ini file.
#   -v | Print verbose output.
# RETURNS: readConfigAppIniReturn - The value for the input config tag. Empty if not found.
readConfigAppIniReturn=""
function readConfigAppIni() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    fflag=""
    vflag=""
    readAppIni="/etc/gitea/app.ini"
    printDebug="false"
    while getopts "f:v" flag; do
        case "${flag}" in
            f) fflag="-${flag}"; readAppIni="${OPTARG}" ;;
            v) vflag="-${flag}"; printDebug="true" ;;
            *) echo "Unhandled argument." ;;
        esac
    done
    shift $((OPTIND-1)) # Reset the Options Index
    # Extract Inputs
    readHeaderTag="${1}"
    readConfigTag="${2}"
    # Reset the Return Value
    readConfigAppIniReturn=""

    # Search the app.ini for the Header and Config Tags
    if [[ "${fflag}" == "-f" ]] && [[ "${vflag}" == "-v" ]]; then # Search the -f app.ini File with -v Verbose Output
        findConfigAppIni "${fflag}" "${readAppIni}" "${vflag}" "${readHeaderTag}" "${readConfigTag}"
    elif [[ "${fflag}" == "-f" ]]; then # Search the -f app.ini File
        findConfigAppIni "${fflag}" "${readAppIni}" "${readHeaderTag}" "${readConfigTag}"
    elif [[ "${vflag}" == "-v" ]]; then # Search the Application app.ini with -v Verbose Output
        findConfigAppIni "${vflag}" "${readHeaderTag}" "${readConfigTag}"
    else # Search the Application app.ini
        findConfigAppIni "${readHeaderTag}" "${readConfigTag}"
    fi
    # Extract the Search Results
    foundHeaderTag=${findConfigAppIniReturn[0]} # Extract Whether or Not the Header Tag was Found
    foundConfigTag=${findConfigAppIniReturn[1]} # Extract Whether or Not the Config Tag was Found
    foundLineIndex=${findConfigAppIniReturn[2]} # Extract the Line Number the Config Tag was Found On

    # Read the app.ini if the Input Config Tag was Found
    if [[ $foundConfigTag == "true" ]]; then
        # Return the Value of the Input Config Tag
        readConfigAppIniReturn=$(sudo sed -n "${foundLineIndex}p" "${readAppIni}") # Only Print the Specified Line
        # Remove the Config Tag and All Whitespace from the Extracted Value
        readConfigAppIniReturn="${readConfigAppIniReturn//$readConfigTag = /}" # Remove the Config Tag
        readConfigAppIniReturn="${readConfigAppIniReturn//$readConfigTag=/}" # Remove the Config Tag
        # Remove Preceeding and Trailing Whitespace from the Extracted Value
        # readConfigAppIniReturn="${readConfigAppIniReturn/% /}" # Remove Preceeding Whitespace 
        # readConfigAppIniReturn="${readConfigAppIniReturn/# /}" # Remove Trailing Whitespace 
        readConfigAppIniReturn="${readConfigAppIniReturn##([[:blank:]])}" # Remove Single Preceeding Whitespace 
        # readConfigAppIniReturn="${readConfigAppIniReturn%%([[:blank:]])}" # Remove Trailing Whitespace 
    # The Input Config Tag was Not Found, Return Nothing
    else readConfigAppIniReturn=""; fi
}
##################################################

##################################################
# Gitea Backup
if [[ "${wmenuGiteaCustom}" == "backup" ]]; then
    # User Specified Storage Path
    ##################################################
    # Whiptail Input Path Dialog for the Backup Archive File Path
    whiptailInputPathCreate -d -u "git" "GITEA BACKUP" "Please type the directory to store the archive.\n| EXAMPLE: /mnt/My Drive/gitea backups"
    giteaBackupStorePath="${whiptailInputPathCreateReturn}" # Extract the Function Output
    ##################################################

    ##################################################
    # Extract the Newest Backup Archive Filename
    pushd "${giteaBackupStorePath}" || return > /dev/null 2>&1 # Move into the Specified Backup Path
    backupArchiveLastName="gitea-backup-XXXXXXXXXX.zip" # Initialize the Name of the Newest Backup Archive Generated by Gitea
    for fileList in $(ls * -t --sort=time); do backupArchiveLastName="${fileList}"; break; done # Only Extract the Newest File Name
    popd || return > /dev/null 2>&1 # Return to the Original Working Directrory

    while true; do # Loop Until Gitea Itself Backsup Successfully
        ##################################################
        TERM=ansi whiptail --title " BACKING UP GITEA " --infobox "Backing up Gitea..." 0 0
        ##################################################
        # Ensure the Backup Directory is Writable to Anyone
        sudo chmod -R 777 "${giteaBackupStorePath}"
        pushd "${giteaBackupStorePath}" || return > /dev/null 2>&1 # Move into the Specified Backup Path
        # Backup Gitea as the 'git' User into the User Specified Directory (-t)
        sudo -u git "${giteaAppPath}" -c "${giteaAppIniPath}" dump -t "${giteaBackupStorePath}" > /dev/null 2>&1

        ##################################################
        # Extract the Backup Archive Filename
        backupArchiveName="gitea-backup-XXXXXXXXXX.zip" # Initialize the Name of the Backup Archive Generated by Gitea
        for fileList in $(ls * -t --sort=time); do backupArchiveName="${fileList}"; break; done # Only Extract the Newest File Name
        popd || return > /dev/null 2>&1 # Return to the Original Working Directrory

        # Ensure Gitea was Backed Up by Checking the New Backup Filename Against the Old Backup Filename
        if [[ "${backupArchiveLastName}" != "${backupArchiveName}" ]]; then break # Gitea Backup was Successful, Continue Backup
        # Gitea Backup Failed
        else
            ##################################################
            # Whiptail Confirmation to Copy Folder Contents
            if (! whiptail --title " BACKUP FAILED " --yesno "Gitea itself failed to backup\n\nWould you like to retry?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Gitea Backup Cancelled, Reset the Customizer Back to Start
                jumpto customreset
            fi
            ##################################################
        fi
    done

    ##################################################
    # (FIX) Backup the Gitea Working Directory
    # Gitea will only backup the contents of the application
    # directory, regardless of external storage preferences.
    ##################################################
    TERM=ansi whiptail --title " BACKING UP WORKING DIRECTORY " --infobox "Backing up the Gitea working directory..." 0 0
    ##################################################
    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader
    # Make root the Owner of the Gitea Working Directory (Gitea Requires Single Ownership for the Working Directory)
    sudo chown -R root:root "${giteaDirectory}"
    sudo chmod -R 777 "${giteaDirectory}"
    pushd "${giteaDirectory}" || return > /dev/null 2>&1 # Move into the Gitea Working Directory
    # Backup the Gitea Custom Folder to the Gitea Backup Archive
    sudo zip -u -r -q "${giteaBackupStorePath}/${backupArchiveName}" "custom"
    # Add the Gitea Data Folder to the Gitea Backup Archive
    sudo zip -u -r -q "${giteaBackupStorePath}/${backupArchiveName}" "data"
    # Add the Gitea Log Folder to the Gitea Backup Archive
    sudo zip -u -r -q "${giteaBackupStorePath}/${backupArchiveName}" "log"
    popd || return > /dev/null 2>&1 # Return to the Original Working Directrory
    # Restore Ownership of the Gitea Working Directory to the 'git' User
    sudo chown -R git:git "${giteaDirectory}"
    sudo chmod -R 755 "${giteaDirectory}"
    ##################################################

    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
    ##################################################

    ##################################################
    whiptail --title " BACKUP SUCCESSFUL " --msgbox "Gitea successfully backed up to:\n${backupArchiveName}" 0 0 --ok-button "OK"
    ##################################################

##################################################
# Gitea Local Browser
elif [[ "${wmenuGiteaCustom}" == "browse" ]]; then
    ##################################################
    # Whiptail Menu for Browsing Gitea
    giteaWMenuBrowse=$(
        whiptail --title " BROWSE GITEA " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nWhere would you like to browse?" 0 0 0 \
        "1." "Gitea Application Directory" \
        "2." "Gitea Working Directory" \
        "3." "Repositories Directory" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit the Gitea Browser
    if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
    ##################################################
    # Convert the Selected Menu Option and Continue the Customization
    case $giteaWMenuBrowse in
        "1.") giteaQuickBrowserPath=1;; 
        "2.") giteaQuickBrowserPath=2;;
        "3.") giteaQuickBrowserPath=3;;
    esac

    # Browse the Gitea Application Directory
    if [[ $giteaQuickBrowserPath -eq 1 ]]; then
        # # Extract the Gitea Application Directory
        # giteaAppDirPath=$(dirname "${giteaAppDir}")
        # Open the Gitea Application Directory if it Exists
        if [ -d "${giteaAppDir}" ]; then
            sudo pcmanfm "${giteaAppDir}"
        # Gitea Application Directory Does Not Exist
        else
            ##################################################
            whiptail --title " ERROR BROWSING " --msgbox "Could not locate your Gitea application directory at:\n${"${giteaAppDir}"}\nGitea might not exist or was installed without gitea-rpiz." 0 0 --ok-button "OK"
            ##################################################
            # Reset the Customizer Back to Start
            jumpto customreset
        fi

    # Browse the Gitea Working Directory
    elif [[ $giteaQuickBrowserPath -eq 2 ]]; then
        # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
        gitearpizConfigReader
        # Open the Gitea Working Directory if it Exists
        if [ -d "${giteaDirectory}" ]; then
            sudo pcmanfm "${giteaDirectory}"
        # Gitea Working Directory Does Not Exist
        else
            ##################################################
            whiptail --title " ERROR BROWSING " --msgbox "Could not locate your Gitea working directory at:\n${giteaDirectory}\nPlease check that it exists." 0 0 --ok-button "OK"
            ##################################################
            # Reset the Customizer Back to Start
            jumpto customreset
        fi

    # Browse the Repositories Directory
    elif [[ $giteaQuickBrowserPath -eq 3 ]]; then
        # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
        gitearpizConfigReader
        # Open the Gitea Repositories Directory if it Exists
        if [ -d "${repositoriesDirectory}" ]; then
            sudo pcmanfm "${repositoriesDirectory}"
        # Gitea Repositories Directory Does Not Exist
        else
            ##################################################
            whiptail --title " ERROR BROWSING " --msgbox "Your respositories directory does not yet exist on your external drive.\nNew repositories will be created at:\n${repositoriesDirectory}" 0 0 --ok-button "OK"
            ##################################################
            # Reset the Customizer Back to Start
            jumpto customreset
        fi

    fi

##################################################
# Gitea app.ini Config
elif [[ "${wmenuGiteaCustom}" == "config" ]]; then
    ##################################################
    whiptail --title " APP.INI CONFIG " --msgbox "You are about to manually edit the app.ini for Gitea.\n\nCheck the official reference for a complete list of settings:\nhttps://github.com/go-gitea/gitea/blob/main/custom/conf/app.example.ini" 0 0 --ok-button "OK"
    ##################################################

    # Manually Edit the Gitea app.ini
    sudo nano "${giteaAppIniPath}"

    # Restart the Gitea Service
    { ################################################
    whiptailGaugeProgress 45 # Move Progress Gauge
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nRestarting Gitea to apply the app.ini configuration..." "${whiptailGaugeWindowSize[@]}" 0
    ##################################################

    # Finalization
    ##################################################
    whiptail --title " CONFIGURED GITEA " --msgbox "Successfully configured the app.ini for Gitea." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Easy Configurator
elif [[ "${wmenuGiteaCustom}" == "ezfig" ]]; then
###################################################
# GOTO ezfigskip
ezfigskip:
    while true; do # Loop Until Exited
        ##################################################
        # Whiptail Menu for Gitea Ezfig
        giteaSettingEzfig=$(
            whiptail --title " GITEA CONFIGURATOR " --ok-button "OK" --cancel-button "EXIT" \
            --menu "\nWhat would you like to configure?" 0 0 0 \
             "0" "[] | Edit a custom Gitea setting." \
             "1" "[repository] ROOT | The root path to locally stored git repositories." \
             "2" "[repository] FORCE_PRIVATE | Default privacy for newly created repos." \
             "3" "[repository] PREFERRED_LICENSES | Prioritize licenses for new repos." \
             "4" "[repository] DISABLE_MIRRORS | Disable creating new repo mirrors." \
             "5" "[repository] DEFAULT_BRANCH | Default branch name for new repos." \
             "6" "[server] LFS_CONTENT_PATH | The path to locally stored LFS files." \
             "7" "[server] OFFLINE_MODE | All files are served locally." \
             "8" "[server] HTTP_PORT | The HTTP port to access your server." \
             "9" "[server] SSH_PORT | The SSH port to access your server." \
            "10" "[server] DISABLE_SSH | Disables SSH access to your server." \
            "11" "[indexer] REPO_INDEXER_ENABLED | Enables repo file indexing." \
            "12" "[indexer] REPO_INDEXER_INCLUDE | Specify files and folders to search." \
            "13" "[indexer] REPO_INDEXER_EXCLUDE | Exclude files/folders from search." \
            "14" "[indexer] MAX_FILE_SIZE | Maximum size of files searched." \
            "15" "[repository.upload] FILE_MAX_SIZE | Maximum size in MB for files." \
            "16" "[repository.upload] MAX_FILES | Maximum number of files per upload." \
            "17" "[repository.upload] TEMP_PATH | Temporary path to uploaded files." \
            "18" "[attachment] MAX_SIZE | Maximum size in MB for files." \
            "19" "[attachment] MAX_FILES | Maximum number of files per upload." \
            "20" "[attachment] PATH | The path to store files." \
            "21" "[release.attachment] MAX_SIZE | Maximum size in MB for files." \
            "22" "[release.attachment] MAX_FILES | Maximum number of files per upload." \
            "23" "[release.attachment] PATH | The path to store files." \
            "24" "[picture] AVATAR_UPLOAD_PATH | The path to store user avatars." \
            "25" "[picture] REPOSITORY_AVATAR_UPLOAD_PATH | Path to store repo avatars." \
            "26" "[ui] EXPLORE_PAGING_NUM | Max repos shown on a single Explore page." \
            "27" "[ui] MEMBERS_PAGING_NUM | Max users shown on a single Explore page." \
            "28" "[ui] ISSUE_PAGING_NUM | Maximum issues displayed on a single page." \
            "29" "[ui] FEED_PAGING_NUM | Maximum items displayed on the home feed." \
            "30" "[ui] GRAPH_MAX_COMMIT_NUM | Maximum commits shown on commit graphs." \
            "31" "[ui] MAX_DISPLAY_FILE_SIZE | Maximum size of files displayed." \
            "32" "[ui] SHOW_USER_EMAIL | Display emails on the Explore Users page." \
            "33" "[ui] DEFAULT_THEME | Default sitewide theme." \
            "34" "[ui] THEMES | Specify all available themes." \
            "35" "[ui] REACTIONS | Specify all available reaction emojis." \
            "36" "[ui] CUSTOM_EMOJIS | Specify all available emojis." \
        3>&2 2>&1 1>&3 ) dialogExit=$? ###################
        # Whiptail Dialog Canceled, Exit the Gitea Configurator
        if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
        ##################################################

        ##################################################
        # Configure the Gitea Repository Path
        if [[ $giteaSettingEzfig -eq 1 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository]'
            configTag="ROOT"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            # Whiptail Input Path Dialog for the Repositories Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "REPOSITORIES PATH" "Please type the new path to store repositories.\n| EXAMPLE: /mnt/My Drive/repositories"
            giteaEzRootPath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################

            # Update the Gitea Repository Path
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRootPath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

            # Edit the gitea-rpiz.config File if it Exists
            if [ -e "${giteaAppIniPath}" ]; then
                ##################################################
                TERM=ansi whiptail --title " UPDATING GITEA-RPIZ " --infobox "Updating the gitea-rpiz.config..." 0 0
                ##################################################
                sudo sed -i 's|^GITEA_REPO_PATH=.*|GITEA_REPO_PATH='"${giteaEzRootPath}"'|' "${giteaAppIniPath}"
                ##################################################
                # Clear the ANSI xterm Terminal
                TERM=ansi whiptail --clear --infobox "Updating the gitea-rpiz.config..." 0 0
                ##################################################
            # gitea-rpiz.config was Not Found
            ##################################################
            else whiptail --title " GITEA-RPIZ ERROR " --msgbox "gitea-rpiz.config could not be found.\nPlease manually update the GITEA_REPO_PATH." 0 0 --ok-button "OK"; fi
            ##################################################

        # Configure the Gitea Default Repository Visibility
        elif [[ $giteaSettingEzfig -eq 2 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzVisibility=$(
                whiptail --title " DEFAULT VISIBILITY " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose the default visibility for new repositories.\nVisibility may be changed after a repo is created." 0 0 0 \
                "PUBLIC" "New repos are public by default." \
                "PRIVATE" "New repos are private by default." \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzVisibility == "PUBLIC" ]]; then
                # Default Visibility is Public
                giteaEzVisibility=false
            elif [[ $giteaEzVisibility == "PRIVATE" ]]; then
                # Default Visibility is Private
                giteaEzVisibility=true
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[repository]'
            configTag="FORCE_PRIVATE"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzVisibility}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Preferred Licenses
        elif [[ $giteaSettingEzfig -eq 3 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository]'
            configTag="PREFERRED_LICENSES"
            ##################################################
            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzLicenses=$(whiptail --title " PREFERRED LICENSES " --inputbox "\nPlease enter a comma-separated list of licenses, with a name tag matching any installed license.\nCustom licenses: ${giteaDirectory}/custom/options/license\n| EXAMPLE: Apache License 2.0,MIT License,LICENSE.md" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzLicenses}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Repository Mirror Creation
        elif [[ $giteaSettingEzfig -eq 4 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzMirrors=$(
                whiptail --title " DISABLE MIRRORS " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose if new repository mirrors can\nbe created. Existing mirrors will remain valid." 0 0 0 \
                "ENABLE" "Enable the creation of new mirrors." \
                "DISABLE" "Disable the creation of new mirrors." \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzMirrors == "ENABLE" ]]; then
                # Turn Offline Mode Off
                giteaEzMirrors=false
            elif [[ $giteaEzMirrors == "DISABLE" ]]; then
                # Turn Offline Mode On
                giteaEzMirrors=true
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[repository]'
            configTag="DISABLE_MIRRORS"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzMirrors}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Default Branch
        elif [[ $giteaSettingEzfig -eq 5 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository]'
            configTag="DEFAULT_BRANCH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzDefaultBranch=$(whiptail --title " DEFAULT BRANCH " --inputbox "\nPlease enter the default branch name\nto use when creating new repositories.\n| EXAMPLE: main" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzDefaultBranch}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea LFS File Path
        elif [[ $giteaSettingEzfig -eq 6 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[server]'
            configTag="LFS_CONTENT_PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Default Path to Release Attachments
            giteaDefaultLFSPath="${giteaDirectory}/data/lfs"

            ##################################################
            # Whiptail Input Path Dialog for the Release Attachments Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "LFS CONTENT PATH" "Please enter the path to store LFS files.\nThe default path is: ${giteaDefaultLFSPath}\n\n| EXAMPLE: /mnt/My Drive/gitea/data/lfs"
            giteaEzLFSPath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzLFSPath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Offline Mode
        elif [[ $giteaSettingEzfig -eq 7 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzOffline=$(
                whiptail --title " OFFLINE MODE " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose the Gitea mode for serving files." 0 0 0 \
                "ONLINE" " " \
                "OFFLINE" " " \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzOffline == "ONLINE" ]]; then
                # Turn Offline Mode Off
                giteaEzOffline=false
            elif [[ $giteaEzOffline == "OFFLINE" ]]; then
                # Turn Offline Mode On
                giteaEzOffline=true
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[server]'
            configTag="OFFLINE_MODE"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzOffline}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea HTTP Port
        elif [[ $giteaSettingEzfig -eq 8 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[server]'
            configTag="HTTP_PORT"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzHTTPPort=$(whiptail --title " HTTP PORT " --inputbox "\nPlease enter the HTTP port to access your server.\n| EXAMPLE: 4242" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzHTTPPort}"
            # Edit the ROOT_URL Config Setting in the Gitea app.ini
            editConfigAppIni "${headerTag}" "ROOT_URL" "http://localhost:${giteaEzHTTPPort}/"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea SSH Port
        elif [[ $giteaSettingEzfig -eq 9 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[server]'
            configTag="SSH_PORT"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzSSHPort=$(whiptail --title " SSH PORT " --inputbox "\nPlease enter the SSH port to access your server.\n| EXAMPLE: 42" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzSSHPort}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea SSH Access
        elif [[ $giteaSettingEzfig -eq 10 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzSSHDisable=$(
                whiptail --title " SSH ACCESS " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose if SSH access is available for your server." 0 0 0 \
                "ENABLED" " " \
                "DISABLED" " " \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzSSHDisable == "ENABLED" ]]; then
                # SSH Access is Enabled
                giteaEzSSHDisable=false
            elif [[ $giteaEzSSHDisable == "DISABLED" ]]; then
                # SSH Access is Disabled
                giteaEzSSHDisable=true
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[server]'
            configTag="DISABLE_SSH"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzSSHDisable}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Indexer
        elif [[ $giteaSettingEzfig -eq 11 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzIndexer=$(
                whiptail --title " REPO INDEXER ENABLED " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose to enable or disable the indexer." 0 0 0 \
                "ENABLE" "Allow repository files to be searched." \
                "DISABLE" "Do not search repository files." \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzIndexer == "ENABLE" ]]; then
                # Enable the Indexer
                giteaEzIndexer=true
            elif [[ $giteaEzIndexer == "DISABLE" ]]; then
                # Disable the Indexer
                giteaEzIndexer=false
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[indexer]'
            configTag="REPO_INDEXER_ENABLED"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzIndexer}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Indexer Include List
        elif [[ $giteaSettingEzfig -eq 12 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[indexer]'
            configTag="REPO_INDEXER_INCLUDE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzIndexerInclude=$(whiptail --title " REPO INDEXER INCLUDE " --inputbox "\nPlease enter a comma-separated list of glob patterns for searchable files and folders, or leave blank to search everything.\n| EXAMPLE: *.h,*.cpp,source/**" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzIndexerInclude}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Indexer Exclude List
        elif [[ $giteaSettingEzfig -eq 13 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[indexer]'
            configTag="REPO_INDEXER_EXCLUDE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzIndexerExclude=$(whiptail --title " REPO INDEXER EXCLUDE " --inputbox "\nPlease enter a comma-separated list of glob patterns for files and folders that will not be indexed.\n| EXAMPLE: *.exe,*.mp4,resources/bin/**" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzIndexerExclude}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Indexer Maximum File Size
        elif [[ $giteaSettingEzfig -eq 14 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[indexer]'
            configTag="MAX_FILE_SIZE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzIndexerMaxFileSize=$(whiptail --title " MAX FILE SIZE " --inputbox "\nPlease enter the maximum size, in bits, for indexed files.\n | Default: 1048576" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzIndexerMaxFileSize}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Repository File Size
        elif [[ $giteaSettingEzfig -eq 15 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository.upload]'
            configTag="MAX_SIZE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzRepoMaxFileSize=$(whiptail --title " MAX FILE SIZE " --inputbox "\nPlease enter the maximum size, in MB, for files uploaded to repositories." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRepoMaxFileSize}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Repository File Count per Upload
        elif [[ $giteaSettingEzfig -eq 16 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository.upload]'
            configTag="MAX_FILES"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzRepoMaxFileCount=$(whiptail --title " MAX FILE COUNT " --inputbox "\nPlease enter the maximum number of files per upload to repositories." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRepoMaxFileCount}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Repository Temporary File Path
        elif [[ $giteaSettingEzfig -eq 17 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[repository.upload]'
            configTag="TEMP_PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            # Whiptail Input Path Dialog for the Temporary Upload Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "TEMP UPLOAD PATH" "Please enter the path to temporarily store files uploaded to repositories.\n\nThis folder is cleared upon Gitea restart. Files are stored in your /repositories folder and can be retrieved with a git clone.\n\n| EXAMPLE: /mnt/My Drive/gitea/data/tmp/uploads"
            giteaEzRepoTempFilePath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRepoTempFilePath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Attachment File Size
        elif [[ $giteaSettingEzfig -eq 18 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[attachment]'
            configTag="MAX_SIZE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzAttachMaxFileSize=$(whiptail --title " MAX FILE SIZE " --inputbox "\nPlease enter the maximum size, in MB, for attachment files." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzAttachMaxFileSize}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Attachment File Count per Upload
        elif [[ $giteaSettingEzfig -eq 19 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[attachment]'
            configTag="MAX_FILES"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzAttachMaxFileCount=$(whiptail --title " MAX FILE COUNT " --inputbox "\nPlease enter the maximum number of attachment files per upload." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzAttachMaxFileCount}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Attachment File Path
        elif [[ $giteaSettingEzfig -eq 20 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[attachment]'
            configTag="PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Default Path to Attachments
            giteaDefaultAttachmentsPath="${giteaDirectory}/data/attachments"

            ##################################################
            # Whiptail Input Path Dialog for the Attachments Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "ATTACHMENTS PATH" "Please enter the path to store uploaded attachment files.\nThe default path is: ${giteaDefaultAttachmentsPath}\n\n| EXAMPLE: /mnt/My Drive/gitea/data/attachments"
            giteaEzAttachFilePath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################
            # Whiptail Confirmation to Copy Folder Contents
            if (whiptail --title " COPY DEFAULT " --yesno "Copy the contents of the default folder?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Copy the Contents of the Default Gitea Directory to the Specified Directory
                sudo cp -r "${giteaDefaultAttachmentsPath}"/* "${giteaEzAttachFilePath}"
            fi
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzAttachFilePath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Release Attachment File Size
        elif [[ $giteaSettingEzfig -eq 21 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[release.attachment]'
            configTag="MAX_SIZE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzRelAttachMaxFileSize=$(whiptail --title " MAX FILE SIZE " --inputbox "\nPlease enter the maximum size, in MB, for release attachment files." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRelAttachMaxFileSize}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Maximum Release Attachment File Count per Upload
        elif [[ $giteaSettingEzfig -eq 22 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[release.attachment]'
            configTag="MAX_FILES"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzRelAttachMaxFileCount=$(whiptail --title " MAX FILE COUNT " --inputbox "\nPlease enter the maximum number of release attachment files per upload." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRelAttachMaxFileCount}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Release Attachment File Path
        elif [[ $giteaSettingEzfig -eq 23 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[release.attachment]'
            configTag="PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Default Path to Release Attachments
            giteaDefaultRelAttachmentsPath="${giteaDirectory}/data/attachments"

            ##################################################
            # Whiptail Input Path Dialog for the Release Attachments Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "REL ATTACH PATH" "Please enter the path to store uploaded release attachment files.\nThe default path is: ${giteaDefaultRelAttachmentsPath}\n\n| EXAMPLE: /mnt/My Drive/gitea/data/attachments"
            giteaEzRelAttachFilePath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################
            # Whiptail Confirmation to Copy Folder Contents
            if (whiptail --title " COPY DEFAULT " --yesno "Copy the contents of the default folder?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Copy the Contents of the Default Gitea Directory to the Specified Directory
                sudo cp -r "${giteaDefaultRelAttachmentsPath}"/* "${giteaEzRelAttachFilePath}"
            fi
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRelAttachFilePath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea User Avatar Storage Path
        elif [[ $giteaSettingEzfig -eq 24 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[picture]'
            configTag="AVATAR_UPLOAD_PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Default Path to Avatars
            giteaDefaultAvatarsPath="${giteaDirectory}/data/avatars"

            ##################################################
            # Whiptail Input Path Dialog for the User Avatars Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "AVATARS PATH" "Please enter the path to store user avatars.\nThe default path is: ${giteaDefaultAvatarsPath}\n\n| EXAMPLE: /mnt/My Drive/gitea/data/avatars"
            giteaEzAvatarsPath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################
            # Whiptail Confirmation to Copy Folder Contents
            if (whiptail --title " COPY DEFAULT " --yesno "Copy the contents of the default folder?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Copy the Contents of the Default Gitea Directory to the Specified Directory
                sudo cp -r "${giteaDefaultAvatarsPath}"/* "${giteaEzAvatarsPath}"
            fi
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzAvatarsPath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Repository Avatar Storage Path
        elif [[ $giteaSettingEzfig -eq 25 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[picture]'
            configTag="REPOSITORY_AVATAR_UPLOAD_PATH"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader
            # Default Path to Avatars
            giteaDefaultRepoAvatarsPath="${giteaDirectory}/data/repo-avatars"

            ##################################################
            # Whiptail Input Path Dialog for the User Avatars Path
            whiptailInputPathCreate -d -u "git" -c "CANCEL" -j ezfigskip -t "${readConfigAppIniReturn}" "REPO AVATARS PATH" "Please enter the path to store repository avatars.\nThe default path is: ${giteaDefaultRepoAvatarsPath}\n\n| EXAMPLE: /mnt/My Drive/gitea/data/repo-avatars"
            giteaEzRepoAvatarsPath="${whiptailInputPathCreateReturn}" # Extract the Function Output
            ##################################################
            # Whiptail Confirmation to Copy Folder Contents
            if (whiptail --title " COPY DEFAULT " --yesno "Copy the contents of the default folder?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                # Copy the Contents of the Default Gitea Directory to the Specified Directory
                sudo cp -r "${giteaDefaultRepoAvatarsPath}"/* "${giteaEzRepoAvatarsPath}"
            fi
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzRepoAvatarsPath}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Repositories per Explore Page
        elif [[ $giteaSettingEzfig -eq 26 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="EXPLORE_PAGING_NUM"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxReposPage=$(whiptail --title " EXPLORE PAGING NUM " --inputbox "\nPlease enter the maximum number of repositories displayed on a single Explore page.\n | Default: 20" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxReposPage}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Users/Organizations per Explore Page
        elif [[ $giteaSettingEzfig -eq 27 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="MEMBERS_PAGING_NUM"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxUsersPage=$(whiptail --title " MEMBERS PAGING NUM " --inputbox "\nPlease enter the maximum number of users/organizations displayed on a single Explore page.\n | Default: 20" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxUsersPage}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Issues per Page
        elif [[ $giteaSettingEzfig -eq 28 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="ISSUE_PAGING_NUM"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxIssuesPage=$(whiptail --title " ISSUE PAGING NUM " --inputbox "\nPlease enter the maximum number of issues displayed on a single page.\n | Default: 10" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxIssuesPage}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Home Feed Items per Page
        elif [[ $giteaSettingEzfig -eq 29 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="FEED_PAGING_NUM"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxHomeFeed=$(whiptail --title " FEED PAGING NUM " --inputbox "\nPlease enter the maximum number of items displayed on the home feed.\n | Default: 20" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxHomeFeed}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Home Feed Items per Page
        elif [[ $giteaSettingEzfig -eq 30 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="GRAPH_MAX_COMMIT_NUM"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxHomeFeed=$(whiptail --title " GRAPH MAX COMMIT NUM " --inputbox "\nPlease enter the maximum number of commits displayed on commit graphs.\n | Default: 100" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxHomeFeed}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Maximum Display File Size
        elif [[ $giteaSettingEzfig -eq 31 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="MAX_DISPLAY_FILE_SIZE"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIMaxDisplayFileSize=$(whiptail --title " MAX DISPLAY FILE SIZE " --inputbox "\nPlease enter the maximum size, in bits, for files displayed in the file preview.\n | Default: 8388608" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIMaxDisplayFileSize}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI User Email Visibility
        elif [[ $giteaSettingEzfig -eq 32 ]]; then
            ##################################################
            # Whiptail Menu for Gitea Ezfig
            giteaEzUIShowEmail=$(
                whiptail --title " SHOW USER EMAIL " --ok-button "OK" --cancel-button "EXIT" \
                --menu "\nPlease choose to display or hide the emails on the Explore Users page." 0 0 0 \
                "SHOW" "Show user emails on the Explore page." \
                "HIDE" "Hide user emails on the Explore page." \
            3>&2 2>&1 1>&3 ) dialogExit=$? ##################
            # Whiptail Dialog Canceled, Exit the Gitea Configurator
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer Back to Start
            ##################################################
            # Enusre and Convert Valid Response into Proper Config Value
            if [[ $giteaEzUIShowEmail == "SHOW" ]]; then
                # Show User Emails on the Explore Users Page
                giteaEzUIShowEmail=true
            elif [[ $giteaEzUIShowEmail == "HIDE" ]]; then
                # Hide User Emails on the Explore Users Page
                giteaEzUIShowEmail=false
            fi

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="SHOW_USER_EMAIL"
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIShowEmail}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Default Theme
        elif [[ $giteaSettingEzfig -eq 33 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="DEFAULT_THEME"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            ##################################################
            giteaEzUIDefaultTheme=$(whiptail --title " DEFAULT THEME " --inputbox "\nPlease enter the default sitewide Gitea theme.\n| EXAMPLE: arc-green" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIDefaultTheme}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea Available Themes
        elif [[ $giteaSettingEzfig -eq 34 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="THEMES"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader

            ##################################################
            giteaEzUIThemes=$(whiptail --title " THEMES " --inputbox "\nPlease enter a comma-separated list of themes, with a name tag matching any installed theme.\nCustom themes: ${giteaDirectory}/custom/public/css\n| EXAMPLE: gitea,arc-green,gitnight" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIThemes}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Reactions
        elif [[ $giteaSettingEzfig -eq 35 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="REACTIONS"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader

            ##################################################
            giteaEzUIReactions=$(whiptail --title " REACTIONS " --inputbox "\nPlease enter a comma-separated list of issue/PR/comment reactions, with a name tag matching any installed emoji.\nCustom emojis: ${giteaDirectory}/custom/public/img/emoji\n| EXAMPLE: +1, -1, laugh, hooray, confused, heart, rocket, eyes" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUIReactions}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure the Gitea UI Emojis
        elif [[ $giteaSettingEzfig -eq 36 ]]; then
            ##################################################
            # Header and Config Tags
            headerTag='[ui]'
            configTag="CUSTOM_EMOJIS "
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"

            # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
            gitearpizConfigReader

            ##################################################
            giteaEzUICustomEmojis=$(whiptail --title " CUSTOM EMOJIS  " --inputbox "\nPlease enter a comma-separated list of available emojis, with a name tag matching any installed emoji.\nCustom emojis: ${giteaDirectory}/custom/public/img/emoji\n| EXAMPLE: gitea, codeberg, gitlab, git, github" 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzUICustomEmojis}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        # Configure a Custom Gitea Setting
        elif [[ $giteaSettingEzfig -eq 0 ]] || [[ $giteaSettingEzfig -eq 00 ]]; then
            ##################################################
            whiptail --title " CUSTOM OPTION " --msgbox "Reference the app.example.ini at:\nhttps://github.com/go-gitea/gitea/blob/main/custom/conf/app.example.ini\n\nFind the [header.tag] and PARAM_TAG you wish to edit." 0 0 --ok-button "OK"
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################
            giteaEzCustomHeader=$(whiptail --title " SECTION HEADER " --inputbox "\nEnter the section [header.tag] without brackets." 0 0 --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################
            giteaEzCustomConfig=$(whiptail --title " PARAM TAG " --inputbox "\nEnter the PARAM_TAG for the config setting." 0 0 --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            
            ##################################################
            # Header and Config Tags
            headerTag="[${giteaEzCustomHeader}]"
            configTag="${giteaEzCustomConfig}"
            ##################################################
            # Read the Gitea app.ini and Extract the Config Value
            readConfigAppIni "${headerTag}" "${configTag}"
            
            ##################################################
            giteaEzCustomValue=$(whiptail --title " PARAM VALUE " --inputbox "\nEnter the new value for the config setting." 0 0 "${readConfigAppIniReturn}" --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
            # Whiptail Dialog Canceled, Skip Updating the Gitea Setting
            if [[ $dialogExit != 0 ]]; then jumpto ezfigskip; fi # Reset the Customizer to the Start of the Ezfig
            ##################################################

            # Ensure the Configuration Exists and Edit the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UPDATING APP.INI " --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################
            # Edit the Gitea app.ini # headerTag # configTag # configValue
            editConfigAppIni "${headerTag}" "${configTag}" "${giteaEzCustomValue}"
            ##################################################
            # Clear the ANSI xterm Terminal
            TERM=ansi whiptail --clear --infobox "Updating the Gitea app.ini..." 0 0
            ##################################################

        fi

        ##################################################
        # Restart the Gitea Service
        { ##################################################
        whiptailGaugeProgress 45 # Move Progress Gauge
        sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
        } | whiptail --gauge "\nRestarting Gitea to apply the app.ini configuration..." "${whiptailGaugeWindowSize[@]}" 0

        # Finalization
        ##################################################
        whiptail --title " CONFIGURED GITEA " --msgbox "Successfully configured the app.ini for Gitea." 0 0 --ok-button "OK"
        ##################################################
        # # Reset the Customizer Back to Start
        # jumpto customreset

    done

##################################################
# Gitea .gitignore Installer
elif [[ "${wmenuGiteaCustom}" == "gitignore" ]]; then
    ##################################################
    # Whiptail Input Path Dialog for the Custom .gitignore File Path
    whiptailInputPath "GITIGNORE INSTALLER" "Please enter the full path to the custom .gitignore file to install.\n| EXAMPLE: ${gitearpizDir}/custom/Go.gitignore"
    customGitignorePath="${whiptailInputPathReturn}" # Extract the Function Output
    ##################################################
    # Extract the Filename from the Full Filepath
    customGitignoreName=$(basename "${customGitignorePath}")

    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader

    # Ensure the Gitea Custom .gitignore Folder Exists
    giteaCustomGitignorePath="custom/options/gitignore" # Intialize the Local Path to the Custom .gitignore Directory
    if [[ ! -d "${giteaDirectory}/${giteaCustomGitignorePath}" ]]; then # Custom .gitignore Folder Does Not Exist
        sudo mkdir -p "${giteaDirectory}/${giteaCustomGitignorePath}"; fi

    ##################################################
    { # Copy the Specified .gitignore into the Gitea Custom .gitignore Folder
    whiptailGaugeProgress 20
    sudo cp "${customGitignorePath}" "${giteaDirectory}/${giteaCustomGitignorePath}" > /dev/null 2>&1; whiptailGaugeProgress 60
    # Restart the Gitea Service
    whiptailGaugeProgress 80 "\nRestarting Gitea to apply the .gitignore installation..."
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nInstalling the Custom .gitignore..." "${whiptailGaugeWindowSize[@]}" 0

    # Finalization
    ##################################################
    whiptail --title " GITIGNORE INSTALLED " --msgbox "Successfully installed $customGitignoreName\nas a custom .gitignore for Gitea." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Label Set Installer
elif [[ "${wmenuGiteaCustom}" == "labels" ]]; then
    ##################################################
    # Whiptail Input Path Dialog for the Custom Label Set File Path
    whiptailInputPath "LABEL SET INSTALLER" "Please enter the full path to the custom label set to install.\n| EXAMPLE: ${gitearpizDir}/custom/Github Labels"
    customLabelsPath="${whiptailInputPathReturn}" # Extract the Function Output
    ##################################################
    # Extract the Filename from the Full Filepath
    customLabelsName=$(basename "${customLabelsPath}")

    # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
    gitearpizConfigReader

    # Ensure the Gitea Custom Labels Folder Exists
    giteaCustomLabelsPath="custom/options/label" # Intialize the Local Path to the Custom Labels Directory
    if [[ ! -d "${giteaDirectory}/${giteaCustomLabelsPath}" ]]; then # Custom Labels Folder Does Not Exist
        sudo mkdir -p "${giteaDirectory}/${giteaCustomLabelsPath}"; fi

    ##################################################
    { # Copy the Specified Labels into the Gitea Custom Labels Folder
    whiptailGaugeProgress 20
    sudo cp "${customLabelsPath}" "${giteaDirectory}/${giteaCustomLabelsPath}" > /dev/null 2>&1; whiptailGaugeProgress 60
    # Restart the Gitea Service
    whiptailGaugeProgress 80 "\nRestarting Gitea to apply the label set installation..."
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nInstalling the custom label set..." "${whiptailGaugeWindowSize[@]}" 0

    # Finalization
    ##################################################
    whiptail --title " LABEL SET INSTALLED " --msgbox "Successfully installed $customLabelsName\nas a custom label set for Gitea." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# gitea-rpiz Launcher Installer
elif [[ "${wmenuGiteaCustom}" == "launcher" ]]; then
    # Launcher Icons Sourced from: /usr/share/icons
    # Browse the Folders and Type the Name of the Icon
    ##################################################
    # Whiptail Menu for Browsing Gitea
    giteaDesktopLauncher=$(
        whiptail --title " LAUNCHER INSTALLER " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nLaunchers allow quick access to gitea-rpiz utilities." 0 0 0 \
        "GITEA BACKUP" "Backup Utility" \
        "GITEA CONFIG" "gitea-rpiz Easy Config" \
        "GITEA CUSTOMIZER" "gitea-rpiz Customizer" \
        "GITEA RESTORE" "Restoration Utility" \
        "GITEA SERVICE" "Gitea Service Handler" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit the gitea-rpiz Launcher Installer
    if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
    ##################################################
    # Continue the Launcher Installation if a Valid Option was Entered
    case $giteaDesktopLauncher in
        "GITEA BACKUP") # Intitialize the Gitea Backup Desktop Launcher Info
            giteaDesktopLauncherName="Gitea Backup"
            giteaDesktopLauncherComment="Easily Backup Gitea"
            giteaDesktopLauncherExec='gitea-rpiz-custom.sh" backup'
            giteaDesktopLauncherIcon="drive-multidisk"
            giteaDesktopLauncherFile="gitea-rpiz-backup.desktop"
            ;;

        "GITEA CONFIG") # Intitialize the gitea-rpiz Easy Config Launcher Info
            giteaDesktopLauncherName="Gitea Config"
            giteaDesktopLauncherComment="Easily Configure Basic Gitea Settings"
            giteaDesktopLauncherExec='gitea-rpiz-custom.sh" ezfig'
            giteaDesktopLauncherIcon="package_system"
            giteaDesktopLauncherFile="gitea-rpiz-config.desktop"
            ;;

        "GITEA CUSTOMIZER") # Intitialize the gitea-rpiz Customizer Desktop Launcher Info
            giteaDesktopLauncherName="Gitea Customizer"
            giteaDesktopLauncherComment="Configure Gitea for Raspberry Pi Zero"
            giteaDesktopLauncherExec='gitea-rpiz-custom.sh"'
            giteaDesktopLauncherIcon="gitea.svg"
            giteaDesktopLauncherFile="gitea-rpiz-custom.desktop"
            ;;

        "GITEA RESTORE") # Intitialize the Gitea Restore Desktop Launcher Info
            giteaDesktopLauncherName="Gitea Restore"
            giteaDesktopLauncherComment="Easily Restore Gitea"
            giteaDesktopLauncherExec='gitea-rpiz-custom.sh" restore'
            giteaDesktopLauncherIcon="preferences-system-network"
            giteaDesktopLauncherFile="gitea-rpiz-restore.desktop"
            ;;

        "GITEA SERVICE") # Intitialize the Gitea Service Desktop Launcher Info
            giteaDesktopLauncherName="Gitea Service"
            giteaDesktopLauncherComment="Quickly Perform Gitea Service Tasks"
            giteaDesktopLauncherExec='gitea-rpiz-custom.sh" service'
            giteaDesktopLauncherIcon="x-package-repository"
            giteaDesktopLauncherFile="gitea-rpiz-service.desktop"
            ;;
    esac

    ##################################################
    # Whiptail Input Path Dialog for the gitea-rpiz Path
    # whiptailInputPath -d "GITEA RPIZ FOLDER" "Please enter the path to your gitea-rpiz folder.\n| EXAMPLE: /home/pi/gitea-rpiz"
    # giteaDesktopLauncherWorkingPath="${whiptailInputPathReturn}" # Extract the Function Output
    giteaDesktopLauncherWorkingPath="${gitearpizDir}" # Extract the Current gitea-rpiz Working Directory
    ##################################################
    # Prepend the gitea=rpiz Working Path to the Desktop Launcher Executable Path
    giteaDesktopLauncherExec='bash "'"${giteaDesktopLauncherWorkingPath}/${giteaDesktopLauncherExec}"
    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader

    ##################################################
    # Downloads the Gitea Icon
    # RETURNS: [giteaIconPath] The path to the Gitea icon.
    giteaIconFilename="gitea.svg"
    giteaIconPath="${giteaDirectory}/custom/public/img/logo.svg"
    giteaDownloadIcon() {
        # Initialize the Function Returns
        giteaIconPath=""

        ##################################################
        TERM=ansi whiptail --title " DOWNLOADING GITEA ICON " --infobox "Downloading the Gitea icon.svg..." 0 0
        ##################################################

        # Ensure the Public Images Folder Exists
        giteaImagesDirectory="${giteaDirectory}/custom/public/img"
        giteaIconPath="${giteaDirectory}/custom/public/img/${giteaIconFilename}"
        if [[ ! -e "${giteaImagesDirectory}"  ]]; then
            sudo mkdir -p "${giteaImagesDirectory}" > /dev/null 2>&1; fi

        # Download the Gitea Icon into the Gitea Working Directory
        sudo pushd "${giteaImagesDirectory}" || return > /dev/null 2>&1
        sudo wget -q -O "${giteaIconFilename}" https://raw.githubusercontent.com/go-gitea/gitea/main/assets/logo.svg # Download the Gitea logo.svg as gitea.svg
        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
        ##################################################
        popd || return > /dev/null 2>&1 # Return to the Original Working Directrory
    }

    ##################################################
    # If Using the Gitea icon.svg, Convert to the Gitea Icon Path
    if [[ "${giteaDesktopLauncherIcon}" == "${giteaIconFilename}" ]]; then
        # Ensure the Gitea Icon Exists
        if [[ ! -e "${giteaIconPath}" ]]; then giteaDownloadIcon; fi # Download the Gitea Icon into the Gitea Working Directory if it Does Not Exist
        # Convert to the Gitea icon.svg Path
        giteaDesktopLauncherIcon="${giteaIconPath}"; fi

    ##################################################
    # Whiptail Menu for Gitea Launcher Location
    giteaDesktopLauncherLocation=$(
        whiptail --title " LAUNCHER LOCATION " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nPlease choose where to install the launcher." 0 0 0 \
        "1." "Desktop" \
        "2." "Main Menu" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit the Gitea Launcher Installer
    if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
    ##################################################
    case $giteaDesktopLauncherLocation in
        "1.") giteaDesktopLauncherLocation=1 # Convert the Whiptail Dialog Menu Output
            # Install the Desktop Launcher on the Desktop
            giteaDesktopLauncherPath="/home/pi/Desktop";;
        "2.") giteaDesktopLauncherLocation=2 # Convert the Whiptail Dialog Menu Output
            # Install the Desktop Launcher in the Main Menu
            giteaDesktopLauncherPath="/home/pi/.local/share/applications";;
    esac

    ##################################################
    # Ensure the Gitea Main Menu Category Exists if Installing a Main Menu Launcher
    if [[ $giteaDesktopLauncherLocation -eq 2 ]]; then
        # Path to Main Menu Categories
        menuCategoryDirectoryFile="/home/pi/.local/share/desktop-directories/gitea-rpiz.directory"
        # Create the Main Menu Category Directory File if it Does Not Exist
        if [ ! -e "${menuCategoryDirectoryFile}" ]; then
            # Ensure the Gitea Icon Exists
            if [[ ! -e "${giteaIconPath}" ]]; then giteaDownloadIcon; fi # Download the Gitea Icon into the Gitea Working Directory

            ##################################################
            TERM=ansi whiptail --title " CREATING MENU CATEGORY " --infobox "Main Menu category not found, creating..." 0 0
            ##################################################
            giteaMenuDirectoryName="Gitea"
            giteaMenuDirectoryComment="gitea-rpiz Utilities"
            giteaMenuDirectoryType="Directory"
            giteaMenuDirectoryIcon="${giteaIconPath}"
            # Write the Desktop Directory File
            ##################################################
            TERM=ansi whiptail --title " WRITING MENU DIRECTORY " --infobox "Writing the Main Menu directory file..." 0 0
            ##################################################
            giteaDesktopLauncherOutput="[Desktop Entry]"$'\n'
            giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Name=${giteaMenuDirectoryName}"$'\n'
            giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Comment=${giteaMenuDirectoryComment}"$'\n'
            giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Type=${giteaMenuDirectoryType}"$'\n'
            giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Icon=${giteaMenuDirectoryIcon}"
            echo "${giteaDesktopLauncherOutput}" | sudo tee "${menuCategoryDirectoryFile}" > /dev/null
        fi
    fi

    ##################################################
    # Write the Desktop Launcher File
    giteaDesktopLauncherCategory="Gitea;"
    giteaDesktopLauncherType="Application"
    giteaDesktopLauncherTerminal="true"
    giteaDesktopLauncherNoDisplay="false"
    giteaDesktopLauncherHidden="false"
    ##################################################
    TERM=ansi whiptail --title " CREATING LAUNCHER " --infobox "Writing the desktop launcher file..." 0 0
    ##################################################
    giteaDesktopLauncherOutput="[Desktop Entry]"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Name=${giteaDesktopLauncherName}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Comment=${giteaDesktopLauncherComment}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Categories=${giteaDesktopLauncherCategory}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Exec=${giteaDesktopLauncherExec}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Path=${giteaDesktopLauncherWorkingPath}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Icon=${giteaDesktopLauncherIcon}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Type=${giteaDesktopLauncherType}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Terminal=${giteaDesktopLauncherTerminal}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}NoDisplay=${giteaDesktopLauncherNoDisplay}"$'\n'
    giteaDesktopLauncherOutput="${giteaDesktopLauncherOutput}Hidden=${giteaDesktopLauncherHidden}"$'\n'
    echo "${giteaDesktopLauncherOutput}" | sudo tee "${giteaDesktopLauncherPath}/${giteaDesktopLauncherFile}" > /dev/null
    #echo "${giteaDesktopLauncherOutput}" | sudo tee "${giteaDesktopLauncherPath}/${giteaDesktopLauncherName}" > /dev/null
    ##################################################
    # Rename the Launcher File to the Launcher Name, if Installing to the Desktop
    if [[ $giteaDesktopLauncherLocation -eq 1 ]]; then sudo mv "${giteaDesktopLauncherPath}/${giteaDesktopLauncherFile}" "${giteaDesktopLauncherPath}/${giteaDesktopLauncherName}"; fi
    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Writing the desktop launcher file..." 0 0
    ##################################################

    # Finalization
    ##################################################
    whiptail --title " INSTALLED LAUNCHER " --msgbox "Successfully installed the ${giteaDesktopLauncherName} launcher to:\n${giteaDesktopLauncherPath}" 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea License Installer
elif [[ "${wmenuGiteaCustom}" == "license" ]]; then
    ##################################################
    # Whiptail Input Path Dialog for the Custom License File Path
    whiptailInputPath "LICENSE INSTALLER" "Please enter the full path to the custom license file to install.\n| EXAMPLE: ${gitearpizDir}/custom/MIT License"
    customLicensePath="${whiptailInputPathReturn}" # Extract the Function Output
    ##################################################
    # Extract the Filename from the Full Filepath
    customLicenseName=$(basename "${customLicensePath}")

    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader

    # Ensure the Gitea Custom License Folder Exists
    giteaCustomLicensePath="custom/options/license" # Intialize the Local Path to the Custom License Directory
    if [[ ! -d "${giteaDirectory}/${giteaCustomLicensePath}" ]]; then # Custom License Folder Does Not Exist
        sudo mkdir -p "${giteaDirectory}/${giteaCustomLicensePath}"; fi

    ##################################################
    # Whiptail Confirmation to Replace License Tags
    licenseTagYear=("<year>" "[yyyy]"); licenseTagYearReplace="" # Initialize the List of Year License Tags to Replace
    licenseTagName=("<copyright holders>" "[name of copyright owner]"); licenseTagNameReplace="" # Initialize the List of Owner Name License Tags to Replace
    if (whiptail --title " AUTO LICENSE " --yesno "Would you like to replace tags in the license?\n\nSupported tags:\nOwner: ${licenseTagName[*]}\nYear: ${licenseTagYear[*]}" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Whiptail Dialog Confirmed, Replace the License Tags
        ##################################################
        licenseOwnerName=$(whiptail --title " COPYRIGHT OWNER " --inputbox "\nPlease enter the copyright owners.\n| EXAMPLE: Owner1 Name, Owner2 Name" 0 0 --ok-button "OK" --nocancel 3>&1 1>&2 2>&3)
        ##################################################
        currentYear=$(date +%Y) # Initialize the Current Year Default Value with +%Y from date
        licenseValidYear=$(whiptail --title " LICENSE YEAR " --inputbox "\nPlease enter the license year." 0 0 "$currentYear" --ok-button "OK" --nocancel 3>&1 1>&2 2>&3)
        ##################################################

        ##################################################
        # Searches the input [licenseFile] for the specified
        # tags in the [tagsList] and returns the single tag
        # found within the [licenseFile].
        #
        # [tagsList] The list of tags to search for in the license.
        # [licenseFile] The license file to search
        # RETURNS: [tagName] The name of the single tag found in the license.
        findLicenseTagReturn=""
        findLicenseTag() {
            # Extract the Inputs
            local -n tagsList="$1" # Import the Input Array by Name Reference -n. Allows for Positioning the Tags List Before the License File
            licenseFile="${2}"
            # Initialize the Returns
            findLicenseTagReturn=""
            # Determine the License Tag Replacement
            for tagName in "${tagsList[@]}"; do
                # Attempt to Find the License Tag in the License File
                if [[ "${licenseFile}" == *"$tagName"* ]]; then # Found the Owner Tag Type
                    #  Convert the Tag for Replacement
                    findLicenseTagReturn="$tagName"; break; fi; done # Convert the License Tag Array and Stop Searching
        }
        
        ##################################################
        TERM=ansi whiptail --title " FINDING LICENSE TAGS " --infobox "Determining the replacement tags..." 0 0
        ##################################################
        # Determine the License Tag Replacements
        license="$(<"${customLicensePath}")" # Search the Entire Specified License File
        # Determine the License Owner Tag Replacement
        findLicenseTag licenseTagName "${license}" # Search the License File for the Tag
        licenseTagNameReplace="$findLicenseTagReturn" # Store the Found License Tag
        # Determine the License Year Tag Replacement
        findLicenseTag licenseTagYear "${license}" # Search the License File for the Tag
        licenseTagYearReplace="$findLicenseTagReturn" # Store the Found License Tag
        # Clear the Lincese File from Memory
        license=""
        
        ##################################################
        TERM=ansi whiptail --title " REPLACING LICENSE TAGS " --infobox "Replacing the license tags..." 0 0
        ##################################################
        # Replace the License Owner Tag
        sudo sed -i 's|'"${licenseTagNameReplace}"'|'"${licenseOwnerName}"'|' "${customLicensePath}"
        # Replace the License Valid Year Tag
        sudo sed -i 's|'"${licenseTagYearReplace}"'|'"${licenseValidYear}"'|' "${customLicensePath}"

        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "Cleaning up..." 0 0
        ##################################################
    fi

    ##################################################
    { # Copy the Specified License into the Gitea Custom License Folder
    whiptailGaugeProgress 20
    sudo cp "${customLicensePath}" "${giteaDirectory}/${giteaCustomLicensePath}" > /dev/null 2>&1; whiptailGaugeProgress 60
    # Restart the Gitea Service
    whiptailGaugeProgress 80 "\nRestarting Gitea to apply the license installation..."
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nInstalling the custom license..." "${whiptailGaugeWindowSize[@]}" 0

    # Finalization
    ##################################################
    whiptail --title " LICENSE INSTALLED " --msgbox "Successfully installed $customLicenseName\nas a custom license for Gitea." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Readme Installer
elif [[ "${wmenuGiteaCustom}" == "readme" ]]; then
    ##################################################
    # Whiptail Input Path Dialog for the Custom Readme File Path
    whiptailInputPath "README INSTALLER" "Please enter the full path to the custom readme file to install.\n| EXAMPLE: ${gitearpizDir}/custom/README.md"
    customReadmePath="${whiptailInputPathReturn}" # Extract the Function Output
    ##################################################
    # Extract the Filename from the Full Filepath
    customReadmeName=$(basename "${customReadmePath}")

    # Reads the gitea-rpiz.config and Extracts the Gitea Working and Repositories Directories
    gitearpizConfigReader

    # Ensure the Gitea Custom Readme Folder Exists
    giteaCustomReadmePath="custom/options/readme" # Intialize the Local Path to the Custom Readme Directory
    if [[ ! -d "${giteaDirectory}/${giteaCustomReadmePath}" ]]; then # Custom Readme Folder Does Not Exist
        sudo mkdir -p "${giteaDirectory}/${giteaCustomReadmePath}"; fi

    ##################################################
    { # Copy the Specified Readme into the Gitea Custom Readme Folder
    whiptailGaugeProgress 20
    sudo cp "${customReadmePath}" "${giteaDirectory}/${giteaCustomReadmePath}" > /dev/null 2>&1; whiptailGaugeProgress 60
    # Restart the Gitea Service
    whiptailGaugeProgress 80 "\nRestarting Gitea to apply the readme installation..."
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nInstalling the custom readme..." "${whiptailGaugeWindowSize[@]}" 0

    # Finalization
    ##################################################
    whiptail --title " README INSTALLED " --msgbox "Successfully installed $customReadmeName\nas a custom readme for Gitea." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Restore
elif [[ "${wmenuGiteaCustom}" == "restore" ]]; then
    # User Specified Storage Path
    ##################################################
    # Whiptail Input Path Dialog for the Backup Archive File Path
    whiptailInputPath -d "RESTORE ARCHIVE PATH" "Please type the path to the archive to use for restoring Gitea.\n| EXAMPLE: /mnt/My Drive/gitea backups/gitea-dump-XXXXXXXXXX.zip"
    giteaRestoreArchivePath="${whiptailInputPathReturn}" # Extract the Function Output
    ##################################################
    # Extract the File Name and Title
    giteaRestoreArchiveName=$(basename "${giteaRestoreArchivePath}")
    giteaRestoreArchiveTitle="${giteaRestoreArchiveName//.zip/}" # Trim the .zip Filetype Suffix
    # Extract the File Directory
    giteaRestoreArchiveDirectory=$(dirname "${giteaRestoreArchivePath}")

    ##################################################
    TERM=ansi whiptail --title " PREPARING " --infobox "Preparing to backup Gitea." 0 0
    ##################################################
    # Ensure zip is Installed for Unzipping the Gitea Backup Archive
    if ! command -v zip &>/dev/null; then
        ##################################################
        if (whiptail --title " ZIP NOT FOUND " --yesno "zip is required to restore Gitea.\nWould you like to install zip?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            # Continue the Zip Installation
            ##################################################
            TERM=ansi whiptail --title " INSTALL ZIP " --infobox "Installing zip..." 0 0
            ##################################################
            sudo apt install zip > /dev/null 2>&1
        else # User Does Not Want to Install Zip
            ##################################################
            whiptail --title " RESTORE CANCELLED " --msgbox "Gitea restoration cancelled." 0 0 --ok-button "OK"
            ##################################################
            # Reset the Customizer Back to Start
            jumpto customreset
        fi
        ##################################################
    fi
    # Ensure sqlite3 is Installed for Unzipping the Gitea Backup Archive
    if ! command -v sqlite3 &>/dev/null; then
        ##################################################
        if (whiptail --title " SQLITE NOT FOUND " --yesno "SQLite3 is required to restore Gitea.\nWould you like to install SQLite3?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            # Continue the SQLite3 Installation
            ##################################################
            TERM=ansi whiptail --title " INSTALL SQLITE " --infobox "Installing SQLite3..." 0 0
            ##################################################
            sudo apt install sqlite3 > /dev/null 2>&1
        else # User Does Not Want to Install SQLite3
            ##################################################
            whiptail --title " RESTORE CANCELLED " --msgbox "Gitea restoration cancelled." 0 0 --ok-button "OK"
            ##################################################
            # Reset the Customizer Back to Start
            jumpto customreset
        fi
        ##################################################
    fi

    ##################################################
    TERM=ansi whiptail --title " UNZIPPING ARCHIVE " --infobox "Unzipping the Gitea backup archive..." 0 0
    ##################################################
    # Create the Temporary Archive Extraction Directory
    giteaRestoreArchiveExtractionDirectory="${giteaRestoreArchiveDirectory}/${giteaRestoreArchiveTitle}"
    sudo mkdir -p "${giteaRestoreArchiveExtractionDirectory}"
    pushd "${giteaRestoreArchiveExtractionDirectory}" || return > /dev/null 2>&1 # Move into the Temprorary Backup Archive Extraction Directory
    # Unzip the Gitea Backup Archive
    sudo unzip "${giteaRestoreArchivePath}" > /dev/null 2>&1
    popd || return > /dev/null 2>&1 # Return to the Original Working Directrory

    ##################################################
    TERM=ansi whiptail --title " RESTORING APP.INI " --infobox "Restoring the Gitea app.ini..." 0 0
    ##################################################
    # Extract the Name of the Gitea app.ini Directory
    giteaAppIniDir=$(dirname "${giteaAppIniPath}")
    # Move the Extracted app.ini and Force Overwrite the Old Gitea app.ini
    sudo mv -f "${giteaRestoreArchiveExtractionDirectory}"/app.ini "${giteaAppIniDir}" > /dev/null 2>&1

    ##################################################
    TERM=ansi whiptail --title " UPDATING GITEA-RPIZ CONFIG " --infobox "Restoring the gitea-rpiz.config repositories path..." 0 0
    ##################################################
    # Read the Gitea app.ini, Extract the Repositories Directory, and Update the gitea-rpiz.config
    readConfigAppIni '[repository]' "ROOT"
    gitearpizConfigWriter "GITEA_REPO_PATH" "${readConfigAppIniReturn}"
    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader

    ##################################################
    TERM=ansi whiptail --title " RESTORING REPOSITORIES " --infobox "Restoring your repositories..." 0 0
    ##################################################
    # Sync the Contents of the Gitea Repositories Directory with the Extracted /repos Folder
    sudo rsync -r "${giteaRestoreArchiveExtractionDirectory}/"repos/ "${repositoriesDirectory}/"

    # ##################################################
    # TERM=ansi whiptail --title " RESTORING LFS DATA " --infobox "Restoring the Gitea LFS data folder..." 0 0
    # ##################################################
    # # Restore the LFS Folder from the /data Directory in the Backup, as Gitea will Backup LFS Files Twice
    giteaLFSDataDir="data/lfs" # Initialize the Name of the Gitea LFS Data Directory
    # giteaRepoLFSDir=".lfs" # Initialize the Name of the Gitea Repository LFS Directory
    # # Move the Contents of the Extracted /data/lfs Folder and Force Overwrite All the Old Files
    # sudo mv -f "${giteaRestoreArchiveExtractionDirectory}/${giteaLFSDataDir}"/* "${repositoriesDirectory}/${giteaRepoLFSDir}" > /dev/null 2>&1
    # Remove the Extracted /data/lfs Folder (It's Entirely Duplicated from /repos/.lfs)
    sudo rm -r "${giteaRestoreArchiveExtractionDirectory}/${giteaLFSDataDir}"

    ##################################################
    TERM=ansi whiptail --title " RESTORING CUSTOM " --infobox "Restoring the Gitea custom folder..." 0 0
    ##################################################
    giteaCustomDir="data" # Initialize the Name of the Gitea Custom Directory
    sudo mkdir -p "${giteaDirectory}/${giteaCustomDir}" # Ensure the Gitea Custom Directory Exists
    # Sync the Contents of the Gitea Custom Directory with the Extracted /custom Folder
    sudo rsync -r "${giteaRestoreArchiveExtractionDirectory}/${giteaCustomDir}/" "${giteaDirectory}/${giteaCustomDir}/"

    ##################################################
    TERM=ansi whiptail --title " RESTORING DATA " --infobox "Restoring the Gitea data folder..." 0 0
    ##################################################
    giteaDataDir="data" # Initialize the Name of the Gitea Data Directory
    giteaDatabase="gitea.db" # Initialize the Name of the Gitea Database
    # Remove the Extracted Gitea Database if Another Database Exists to Prevent Overwriting (SQL Dump will be Injected Below)
    if [[ -e "${giteaDirectory}/${giteaDataDir}/${giteaDatabase}" ]]; then sudo rm "${giteaRestoreArchiveExtractionDirectory}/${giteaDataDir}/${giteaDatabase}"; fi 
    # Sync the Contents of the Gitea Data Directory with the Extracted /data Folder
    sudo rsync -r "${giteaRestoreArchiveExtractionDirectory}/${giteaDataDir}/" "${giteaDirectory}/${giteaDataDir}/"

    ##################################################
    TERM=ansi whiptail --title " RESTORING LOGS " --infobox "Restoring Gitea logs..." 0 0
    ##################################################
    giteaLogDir="log" # Initialize the Name of the Gitea Logs Directory
    # Sync the Contents of the Gitea Log Directory with the Extracted /log Folder
    sudo rsync -r "${giteaRestoreArchiveExtractionDirectory}/${giteaLogDir}/" "${giteaDirectory}/${giteaLogDir}/"

    ##################################################
    TERM=ansi whiptail --title " RESTORING DATABASE " --infobox "Restoring your Gitea database..." 0 0
    ##################################################
    giteaDatabaseDump="gitea-db.sql" # Initialize the Name of the Gitea Database Dump
    # Ensure the root User Owns the Gitea Database and SQL Dump
    sudo chown root:root --silent "${giteaDirectory}/${giteaDataDir}/${giteaDatabase}" "${giteaRestoreArchiveExtractionDirectory}/${giteaDatabaseDump}" > /dev/null 2>&1
    # Import the Extracted SQL Database Backup Dump
    sqlite3 "${giteaDirectory}/${giteaDataDir}/${giteaDatabase}" < "${giteaRestoreArchiveExtractionDirectory}/${giteaDatabaseDump}" > /dev/null 2>&1
    # Restore Ownership of the the Gitea Database to the 'git' User
    sudo chown -R git:git --silent "${giteaDirectory}/${giteaDataDir}/${giteaDatabase}" > /dev/null 2>&1

    ##################################################
    TERM=ansi whiptail --title " REPAIRING PRIVILEGES " --infobox "Repairing 'git' user privileges..." 0 0
    ##################################################
    # Ensure the 'git' User Owns the app.ini and Gitea Working Directory
    sudo chown -R git:git --silent "${giteaAppIniPath}" "${giteaDirectory}" > /dev/null 2>&1

    # Restart the Gitea Service
    { ################################################
    whiptailGaugeProgress 45 # Move Progress Gauge
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 90
    } | whiptail --gauge "\nRestarting Gitea to apply the app.ini configuration..." "${whiptailGaugeWindowSize[@]}" 0
    ##################################################

    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
    ##################################################
    # Remove the Unzipped Backup Archive Directory
    sudo rm -r "${giteaRestoreArchiveExtractionDirectory}"

    ##################################################
    # Regenerate Git-Hooks
    ##################################################
    if (whiptail --title " GIT-HOOKS " --yesno "Would you like to regenerate your git-hooks?\n\nCustom git-hooks must be regenerated if\nthe Gitea executable file was moved." 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        ##################################################
        TERM=ansi whiptail --title " REGENERATING GIT-HOOKS " --infobox "Regenerating your git-hooks..." 0 0
        ##################################################
        sudo -u git "${giteaAppPath}" -c "${giteaAppIniPath}" admin regenerate hooks > /dev/null 2>&1
    fi
    ##################################################

    ##################################################
    whiptail --title " RESTORED GITEA " --msgbox "Gitea was successfully restored using:\n${giteaRestoreArchivePath}\n\nPlease sign out of Gitea to refresh your credentials." 0 0 --ok-button "OK"
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Service Handler
elif [[ "${wmenuGiteaCustom}" == "service" ]]; then
    while true; do # Loop Until a Valid Option File is Selected
        ##################################################
        # Whiptail Menu for Gitea Service Utilities
        giteaWMenuServices=$(
            whiptail --title " GITEA SERVICE HANDLER " --ok-button "OK" --cancel-button "EXIT" \
            --menu "\nHow would you like to update the Gitea Service?" 0 0 0 \
            "START"   "Starts the Gitea Service." \
            "RESTART" "Restarts the Gitea Service." \
            "STOP"    "Stops the Gitea Service." \
            "ENABLE"  "Enables the Gitea Service on system boot." \
            "DISABLE" "Disables the Gitea Service on system boot." \
        3>&2 2>&1 1>&3 ) dialogExit=$? ##################
        # Whiptail Dialog Canceled, Exit the Service Handler
        if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
        ##################################################
        # Continue the Customization if a Valid Option was Entered
        case $giteaWMenuServices in
            "START") # Start the Gitea Service
                { ##################################################
                whiptailGaugeProgress 50 # Move Progress Gauge
                sudo systemctl -q start gitea; whiptailGaugeProgress 100
                } | whiptail --gauge "\nStarting Gitea..." "${whiptailGaugeWindowSize[@]}" 0

                # Finalization
                ##################################################
                whiptail --title " STARTED GITEA " --msgbox "Successfully started the Gitea Service." 0 0 --ok-button "OK"
                ##################################################
                ;;

            "RESTART") # Restart the Gitea Service
                { ##################################################
                whiptailGaugeProgress 45 # Move Progress Gauge
                # sudo systemctl -q stop gitea; whiptailGaugeProgress 90
                # sudo systemctl -q start gitea; whiptailGaugeProgress 100
                sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
                } | whiptail --gauge "\nRestarting Gitea..." "${whiptailGaugeWindowSize[@]}" 0

                # Finalization
                ##################################################
                whiptail --title " RESTARTED GITEA " --msgbox "Successfully restarted the Gitea service." 0 0 --ok-button "OK"
                ##################################################
                ;;

            "STOP") # End the Gitea Service
                { ##################################################
                whiptailGaugeProgress 50 # Move Progress Gauge
                sudo systemctl -q stop gitea; whiptailGaugeProgress 100
                } | whiptail --gauge "\nStopping Gitea..." "${whiptailGaugeWindowSize[@]}" 0
                ##################################################

                # Finalization
                ##################################################
                whiptail --title " STOPPED GITEA " --msgbox "Successfully stopped the Gitea Service." 0 0 --ok-button "OK"
                ##################################################
                ;;

            "ENABLE") # Enable the Gitea Service On Boot
                { ##################################################
                whiptailGaugeProgress 20 # Move Progress Gauge
                sudo systemctl enable gitea --now > /dev/null 2>&1; whiptailGaugeProgress 100
                } | whiptail --gauge "\nEnabling Gitea on boot..." "${whiptailGaugeWindowSize[@]}" 0
                ##################################################

                # Finalization
                ##################################################
                whiptail --title " ENABLED GITEA " --msgbox "Successfully enabled the Gitea Service on boot." 0 0 --ok-button "OK"
                ##################################################
                ;;

            "DISABLE") # Disable the Gitea Service On Boot
                { ##################################################
                whiptailGaugeProgress 50 # Move Progress Gauge
                sudo systemctl disable -q gitea > /dev/null 2>&1; whiptailGaugeProgress 100 # Complete the Progress Gauge
                } | whiptail --gauge "\nDisabling Gitea on boot..." "${whiptailGaugeWindowSize[@]}" 0
                ##################################################

                # Finalization
                ##################################################
                whiptail --title " DISABLED GITEA " --msgbox "Successfully disabled the Gitea Service on boot." 0 0 --ok-button "OK"
                ##################################################
                ;;
        esac
    done

##################################################
# Gitea Theme Installer
elif [[ "${wmenuGiteaCustom}" == "theme" ]]; then
    ##################################################
    # Whiptail Menu for Gitea CSS Theme
    giteaThemeInstall=$(
        whiptail --title " GITEA THEME " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nWhich theme would you like to install?" 0 0 0 \
         "1." "Gitday Theme (Light)" \
         "2." "Gitnight Theme (Dark)" \
         "3." "Full Black Theme (Dark)" \
         "4." "Berry Theme (Dark)" \
         "5." "Biluochun Tea Theme (Dark)" \
         "6." "Chai Tea Theme (Neutral)" \
         "7." "Cherry Theme (Dark)" \
         "8." "Deepsea Theme (Dark)" \
         "9." "Derry Rose Theme (Light)" \
        "10." "Dreamy Theme (Dark)" \
        "11." "Dulce Theme (Light)" \
        "12." "Custom Theme" \
        "13." "Remove Theme" \
        "14." "Replace Site Logo" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit the Theme Installer
    if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
    ##################################################
    # Continue the Theme Installation if a Valid Option was Entered
    case $giteaThemeInstall in
        "1.") giteaThemeName="gitday"
            giteaThemeInstall=1;; # Convert the Selected Item
        "2.") giteaThemeName="gitnight"
            giteaThemeInstall=2;; # Convert the Selected Item
        "3.") giteaThemeName="fullblack"
            giteaThemeInstall=3;; # Convert the Selected Item
        "4.") giteaThemeName="berry"
            giteaThemeInstall=4;; # Convert the Selected Item
        "5.") giteaThemeName="biluochuntea"
            giteaThemeInstall=5;; # Convert the Selected Item
        "6.") giteaThemeName="chaitea"
            giteaThemeInstall=6;; # Convert the Selected Item
        "7.") giteaThemeName="cherry"
            giteaThemeInstall=7;; # Convert the Selected Item
        "8.") giteaThemeName="deepsea"
            giteaThemeInstall=8;; # Convert the Selected Item
        "9.") giteaThemeName="derryrose"
            giteaThemeInstall=9;; # Convert the Selected Item
        "10.") giteaThemeName="dreamy"
            giteaThemeInstall=10;; # Convert the Selected Item
        "11.") giteaThemeName="dulce"
            giteaThemeInstall=11;; # Convert the Selected Item
        "12.") giteaThemeName="custom"
            giteaThemeInstall=12;; # Convert the Selected Item
        "13.") giteaThemeName="remove"
            giteaThemeInstall=13;; # Convert the Selected Item
        "14.") giteaThemeName="logo"
            giteaThemeInstall=14;; # Convert the Selected Item
    esac

    ##################################################
    # Read the gitea-rpiz.config and Extract the Gitea Working and Repositories Directories
    gitearpizConfigReader
    # Construct the Proper Gitea Theme Paths
    giteaThemesDirectory="${giteaDirectory}/custom/public/css"
    giteaLogoDirectory="${giteaDirectory}/custom/public/img"

    ##################################################
    # Theme Installer Prep
    # [themeName] The name of the theme to initialize. Ex: "gitnight"
    themeInititalize() {
        # Extract the Input
        themeName="${1}"
        ##################################################
        TERM=ansi whiptail --title " INSTALLING ${themeName^^} " --infobox "Installing the ${themeName^} Theme..." 0 0 # ${x^^} for All Uppercase, ${x^} for Capital Case
        ##################################################
        # Create the Folders for Custom Gitea Themes and Ignore "Already Exists" Errors
        sudo mkdir -p "${giteaThemesDirectory}/" > /dev/null 2>&1
    }

    ##################################################
    # Theme Installer
    # Installs the input theme to the Gitea app.ini,
    # then prompts to install the input theme as the
    # default sitewide Gitea theme.
    # [themeName] The name of the theme to install. Ex: "gitnight"
    themeInstaller() {
        # Extract the Inputs
        themeName="${1}"
        # Extract the Current List of Available Gitea Themes
        giteaThemesList="gitea,arc-green" # Initialize the Default List of Available Gitea Themes
        findConfigAppIni '[ui]' "THEMES" # Extract the Current List of Available Themes from the app.ini
        if [[ "${findConfigAppIniReturn[1]}" == "true" ]]; then # Ensure the THEMES Config Tag Exists in the Gitea app.ini
            foundLineIndex=${findConfigAppIniReturn[2]} # Extract the Line Number the Config Tag was Found On
            giteaThemesList=$(sudo sed -n "${foundLineIndex}p" "${giteaAppIniPath}") # Extract the Line Containing the Gitea Available Themes List
            giteaThemesList="${giteaThemesList// /}" # Remove All Whitespace from the Extracted Line
            giteaThemesList="${giteaThemesList#THEMES=}" # Remove the Config Tag from the Extracted Line
        fi
        ##################################################
        TERM=ansi whiptail --title " INSTALLING THEME " --infobox "Installing the ${themeName^} Theme to the app.ini..." 0 0
        ##################################################
        # Safely Install the Theme to the Gitea app.ini
        if [[ "${giteaThemesList}" != *"${themeName}"* ]]; then # Check that the Current List of Available Themes Does Not Contain the Specified Theme
            if [[ "${giteaThemesList}" ]]; then editConfigAppIni '[ui]' "THEMES" "${giteaThemesList},${themeName}"; fi fi # Append the Theme to the List of Available Gitea Themes
        ##################################################
        # Whiptail Confirmation to Set the Theme as the Default
        if (whiptail --title " SET DEFAULT THEME " --yesno "Would you like to set the ${themeName^}\nTheme as the default theme?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            # Install the Theme as the Default Gitea Theme
            editConfigAppIni '[ui]' "DEFAULT_THEME" "${themeName}"
        fi
        ##################################################
    }

    ##################################################
    # Theme Uninstaller
    # Uninstalls the input theme from the Gitea app.ini.
    # [themeName] The name of the theme to uninstall. Ex: "gitnight"
    themeUninstaller() {
        # Extract the Inputs
        themeName="${1}"
        # Extract the Current List of Available Gitea Themes
        giteaThemesList="gitea,arc-green" # Initialize the Default List of Available Gitea Themes
        findConfigAppIni '[ui]' "THEMES" # Extract the Current List of Available Themes from the app.ini
        if [[ "${findConfigAppIniReturn[1]}" == "true" ]]; then # Ensure the THEMES Config Tag Exists in the Gitea app.ini
            ##################################################
            TERM=ansi whiptail --title " UNINSTALLING THEME " --infobox "Uninstalling the ${themeName^} Theme from the app.ini..." 0 0
            ##################################################
            # Extract the Current List of Available Gitea Themes
            foundLineIndex=${findConfigAppIniReturn[2]} # Extract the Line Number the Config Tag was Found On
            giteaThemesList=$(sudo sed -n "${foundLineIndex}p" "${giteaAppIniPath}") # Extract the Line Containing the Gitea Available Themes List
            giteaThemesList="${giteaThemesList// /}" # Remove All Whitespace from the Extracted Line
            giteaThemesList="${giteaThemesList#THEMES=}" # Remove the Config Tag from the Extracted Line

            # Safely Remove the Theme from the Theme List
            if [[ "${giteaThemesList}" == *"${themeName}"* ]]; then # The Theme Name was Found Within the List of Themes
                # Safely Remove the Theme from the Beginning or Middle of the List
                if [[ "${giteaThemesList}" == *"${themeName},"* ]]; then
                    giteaThemesList="${giteaThemesList//${themeName},/}"
                # Safely Remove the Theme from the Middle or End of the List
                elif [[ "${giteaThemesList}" == *",${themeName}"* ]]; then
                    giteaThemesList="${giteaThemesList//,${themeName}/}"
                # Safely Remove the Only Theme from the List
                elif [[ "${giteaThemesList}" == "${themeName}" ]]; then
                    giteaThemesList=""
                fi
                # Uninstall the Theme from the List of Available Gitea Themes
                editConfigAppIni '[ui]' "THEMES" "${giteaThemesList}"
            fi
        fi
    }

    ##################################################
    # Theme Remover
    # Removes all files for the input theme.
    # [themeName] The name of the theme to remove. Ex: "gitnight"
    themeRemove() {
        # Extract the Input
        themeRemoveName="${1}"
        # Ensure the Theme Name is Valid and the First 6 Characters of the Input Theme Name Contain the theme- Prefix
        if [[ "${themeRemoveName:0:6}" != *"theme-"* ]]; then themeRemoveName="theme-${themeRemoveName}"; fi
        # Construct the Path to the Specified Theme
        themePath="${giteaThemesDirectory}/${themeRemoveName}"
        ##################################################
        TERM=ansi whiptail --title " REMOVING THEME " --infobox "Removing the ${themeRemoveName^} Theme..." 0 0
        ##################################################
        # Safely Remove the Theme, if it Exists
        if [[ -e "${themePath}.css" ]]; then # Ensure a Theme File Exists
            # Remove All Theme Files
            sudo rm "${themePath}".*
        # The Theme Does Not Exist
        ##################################################
        else TERM=ansi whiptail --title " SKIPPING REMOVAL " --infobox "The ${themeRemoveName^} Theme does not exist. Skipping removal..." 0 0; fi
        ##################################################
    }

    ##################################################
    # Internal Theme Installer
    # Installs a theme packaged with gitea-rpiz.
    # [themeName] The name of the theme to install. Supported: gitnight
    internalThemeInstaller() {
        # Extract the Inputs
        themeName="${1}"
        ##################################################
        TERM=ansi whiptail --title " INSTALLING THEME " --infobox "Installing the ${themeName^} Theme..." 0 0 
        ##################################################
        themeInstallName="theme-${themeName}.css"
        # Create the Folder for the Theme
        themeInititalize "${themeName}"

        ##################################################
        # Ensure Internal Theme Exists
        ##################################################
        # Paths to the Internal Theme
        themeInstallPath="${gitearpizDir}/custom/themes/${themeInstallName}" # Installation Path for the Internal Theme
        # Check if the Internal Theme is in the gitea-rpiz Custom Directory
        if [[ -e "${themeInstallPath}" ]]; then
            # Theme Exists, Copy the Theme Files
            sudo cp "${themeInstallPath}" "${giteaThemesDirectory}/" # Copy the Theme File to the Gitea Custom Themes Folder
        # Theme Does Not Exist, Download the Theme
        ##################################################
        else TERM=ansi whiptail --title " DOWNLOADING THEME " --infobox "Downloading the ${themeName^} Theme..." 0 0 # Capital Case ^ the Theme Name
        ##################################################
            # Download the Internal Theme into the Gitea Custom Themes Directory
            pushd "${giteaThemesDirectory}" > /dev/null || return
            sudo wget -q https://raw.githubusercontent.com/trainingmode/gitea-rpiz/main/custom/themes/"${themeInstallName}" > /dev/null 2>&1
            popd > /dev/null || return
        fi
        ##################################################

        ##################################################
        # Install the Internal Theme
        themeInstaller "${themeName}"
    }

    ##################################################
    # Install Internal gitea-rpiz Theme
    if [[ $giteaThemeInstall -lt 12 ]]; then # An Internal Theme Menu Item was Selected
        # Path to the Internal Theme
        giteaThemeInstallPath="${giteaThemesDirectory}/theme-${giteaThemeName}.css"

        # Check if the Internal Theme was Previously Installed
        if [[ -e "${giteaThemeInstallPath}" ]]; then
            ##################################################
            TERM=ansi whiptail --title " THEME INSTALLED " --msgbox "The ${giteaThemeName^} Theme is already installed." 0 0 --ok-button "OK"
            ##################################################
        # Gitnight Theme is Not Installed, Install the Gitnight Theme
        else internalThemeInstaller "${giteaThemeName}"; fi

    ##################################################
    # Install a Custom Theme
    elif [[ $giteaThemeInstall -eq 12 ]]; then
        ##################################################
        # Whiptail Input Dialog for the Custom Theme Name to Install
        giteaThemeInstallCustomName=$(whiptail --title " CUSTOM THEME " --inputbox "\nPlease enter the name of the new theme." 0 0 --ok-button "OK" --nocancel 3>&1 1>&2 2>&3) dialogExit=$?
        ##################################################
        # Export the Custom Theme Name and Theme Install Name
        giteaThemeName="${giteaThemeInstallCustomName}"
        # Ensure the First 6 Characters of the Input Theme Name Contain the theme- Prefix
        if [[ "${giteaThemeName:0:6}" != "theme-" ]]; then themeInstallName="theme-${giteaThemeName}"
        # Custom Theme Name Already Contains theme- Prefix
        else themeInstallName="${giteaThemeName}"; fi

        # Check if the Custom Theme was Previously Installed
        if [[ -e "${giteaThemesDirectory}/${themeInstallName}.css" ]]; then # Ensure Theme File Does Not Exist
            ##################################################
            TERM=ansi whiptail --title " THEME INSTALLED " --msgbox "The ${giteaThemeName^} Theme is already installed." 0 0 --ok-button "OK"
            ##################################################
        # The Custom Theme is Not Installed, Install the Theme
        else
            ##################################################
            # Whiptail Input Dialog for the Custom Theme Name to Install
            giteaThemeInstallCustomPath=$(whiptail --title " CUSTOM THEME " --inputbox "\nPlease enter the path to the theme to install.\nEnter nothing to create a new theme.\n| EXAMPLE: /mnt/My Drive/themes/dark.css" 0 0 --ok-button "OK" --nocancel 3>&1 1>&2 2>&3) dialogExit=$?
            ##################################################

            # Create the Folders for the Custom Gitea Theme
            themeInititalize "${giteaThemeName}"

            ##################################################
            # Copy the Theme File if a Valid Path to a .css File was Specified
            if [[ "${giteaThemeInstallCustomPath}" ]] && [[ "${giteaThemeInstallCustomPath}" == *".css"* ]]; then # -n is Default # Ensure .css File was Specified
                # Copy the Theme File to the Custom Theme Folder Using the Specified Theme Installation Name
                sudo cp "${giteaThemeInstallCustomPath}" "${giteaThemesDirectory}/${themeInstallName}.css" > /dev/null 2>&1
                # Install the Theme File
                themeInstaller "${giteaThemeName}"

            ##################################################
            else # The Theme Does Not Contain CSS Files
                ##################################################
                # Whiptail Confirmation to Create .css File
                if (whiptail --title " NO CSS FOUND " --yesno "The chosen theme does not contain any .css files.\nWould you like to create one?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
                    # Create a .css File for the Custom Theme
                    ##################################################
                    TERM=ansi whiptail --title " CREATING CSS " --infobox "Creating a .css file for the custom theme..." 0 0 
                    ##################################################
                    # Create and Edit the Custom .css Theme
                    sudo nano "${giteaThemesDirectory}/${themeInstallName}.css"

                    ##################################################
                    # Install the Theme File
                    themeInstaller "${giteaThemeName}"

                ##################################################
                else whiptail --title " THEME ERROR " --msgbox "The chosen theme does not contain any .css files.\nThe theme cannot be installed." 0 0 --ok-button "OK"
                ##################################################
                    # Reset the Customizer Back to Start
                    jumpto customreset
                fi
            fi
        fi

    ##################################################
    # Remove a Theme
    elif [[ $giteaThemeInstall -eq 13 ]]; then
        ##################################################
        # Whiptail Menu for Theme Uninstallation
        giteaThemeRemove=$(
            whiptail --title " UNINSTALL THEME " --ok-button "OK" --cancel-button "EXIT" \
            --menu "\nPlease choose a theme to remove." 0 0 0 \
             "1." "Gitday Theme" \
             "2." "Gitnight Theme" \
             "3." "Full Black Theme" \
             "4." "Berry Theme" \
             "5." "Biluochun Tea Theme" \
             "6." "Chai Tea Theme" \
             "7." "Cherry Theme" \
             "8." "Deepsea Theme" \
             "9." "Derry Rose Theme" \
            "10." "Dreamy Theme" \
            "11." "Dulce Theme" \
            "12." "Custom Theme" \
        3>&2 2>&1 1>&3 ) dialogExit=$? ##################
        # Whiptail Dialog Canceled, Exit the Theme Uninstaller
        if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start
        ##################################################

        ##################################################
        # Remove the Midnight Theme
        if [[ "${giteaThemeRemove:0:1}" -lt 2 ]]; then # The First Character in the Selected Item was an Internal Theme Menu Item
            # Initialize the Theme Name
            case $giteaThemeRemove in
                 "1.") giteaThemeName="gitnight";; # Convert the Selected Item
                 "2.") giteaThemeName="gitday";; # Convert the Selected Item
                 "3.") giteaThemeName="fullblack";; # Convert the Selected Item
                 "4.") giteaThemeName="berry";; # Convert the Selected Item
                 "5.") giteaThemeName="biluochuntea";; # Convert the Selected Item
                 "6.") giteaThemeName="chaitea";; # Convert the Selected Item
                 "7.") giteaThemeName="cherry";; # Convert the Selected Item
                 "8.") giteaThemeName="deepsea";; # Convert the Selected Item
                 "9.") giteaThemeName="derryrose";; # Convert the Selected Item
                "10.") giteaThemeName="dreamy";; # Convert the Selected Item
                "11.") giteaThemeName="dulce";; # Convert the Selected Item
            esac
            # Remove the Theme
            ##################################################
            TERM=ansi whiptail --title " REMOVING THEME " --infobox "Removing the ${giteaThemeName^} Theme..." 0 0
            ##################################################
            # Remove the Theme Files
            themeRemove "${giteaThemeName}"
            # Uninstall the Theme from the Gitea app.ini
            themeUninstaller "${giteaThemeName}"

        ##################################################
        # Remove a Custom Gitea Theme
        elif [[ "$giteaThemeRemove" == "2." ]]; then
            ##################################################
            # Whiptail Input Dialog for the Custom Theme Name to Remove
            giteaThemeRemoveName=$(whiptail --title " REMOVE CUSTOM THEME " --inputbox "\nWARNING: All theme files will be deleted.\nPlease enter the name of the theme to remove.\nThemes can be found at: ${giteaThemesDirectory}\n| EXAMPLE: gitday" 0 0 --ok-button "OK" --nocancel 3>&1 1>&2 2>&3) dialogExit=$?
            ##################################################
            # Export the Custom Theme Name for the Success Message
            giteaThemeName="${giteaThemeRemoveName}"
            # Ensure the Input Theme Name Does Not Contain the theme- Prefix
            if [[ "${giteaThemeName:0:6}" == "theme-" ]]; then giteaThemeName="${giteaThemeName:6}"; fi # Trim the First 6 Characters
            # Ensure the Input Theme Name Does Not Contain the .css Suffix
            if [[ "${giteaThemeName:(-3)}" == ".css" ]]; then giteaThemeName="${giteaThemeName:0:-3}"; fi # Trim the Last 3 Characters

            ##################################################
            TERM=ansi whiptail --title " REMOVING ${giteaThemeName^^} " --infobox "Removing the ${giteaThemeName^} Theme..." 0 0
            ##################################################
            # Remove the Theme Files
            themeRemove "${giteaThemeName}"
            # Uninstall the Theme from the Gitea app.ini
            themeUninstaller "${giteaThemeName}"
        fi
    ##################################################
    # Replace the Site Logo
    elif [[ $giteaThemeInstall -eq 14 ]]; then
        ##################################################
        # Whiptail Input Dialog for the Custom Theme Name to Install
        giteaLogoInstallCustomPath=$(whiptail --title " REPLACE LOGO " --inputbox "\nPlease enter the path to the logo to install.\nSVG is recommended.\n\nThis will replace the sitewide logo.* file at:\n${giteaLogoDirectory}\n\n| EXAMPLE: /mnt/My Drive/themes/img/logo.svg" 0 0 --ok-button "OK" --cancel-button "EXIT" 3>&1 1>&2 2>&3) dialogExit=$?
        ##################################################
        # Whiptail Dialog Canceled, Exit the Logo Installer
        if [[ $dialogExit != 0 ]]; then jumpto customreset; fi # Reset the Customizer Back to Start

        # Ensure the Specified Logo File Exisits
        if [[ -e "${giteaLogoInstallCustomPath}" ]]; then # The Specified Logo File Exists, Install the Logo
            ##################################################
            TERM=ansi whiptail --title " REPLACING LOGO " --infobox "Replacing the sitewide logo..." 0 0 
            ##################################################
            # Copy the Specified Logo File as "logo." and Insert the Filetype (.*) Extracted from the Logo Path
            sudo cp "${giteaLogoInstallCustomPath}" "${giteaLogoDirectory}/logo.${giteaLogoInstallCustomPath##*.}" # Remove All Characters After the Last Period to Extract the Filetype
        # Gitnight Theme is Not Installed, Install the Gitnight Theme
        ##################################################
        else TERM=ansi whiptail --title " LOGO NOT FOUND " --msgbox "The specified logo was not found.\nPlease enter a valid path.\n\n${giteaLogoInstallCustomPath}" 0 0 --ok-button "OK"; fi
        ##################################################

    fi

    # Restart Gitea to Apply the Theme Changes
    ##################################################
    # Restart the Gitea Service
    { ##################################################
    whiptailGaugeProgress 45 # Move Progress Gauge
    sudo service gitea restart > /dev/null 2>&1; whiptailGaugeProgress 100
    } | whiptail --gauge "\nRestarting Gitea to apply the theme changes..." "${whiptailGaugeWindowSize[@]}" 0

    # Finalization
    ##################################################
    # Print Theme Installed Message
    themeInstallSuccessMessage="Successfully installed the ${giteaThemeName^} Theme.\nSelect the theme in your Gitea account settings."
    # Print Theme Removed Message if Uninstalled a Theme
    if [[ $giteaThemeInstall -eq 13 ]]; then themeInstallSuccessMessage="Successfully removed the ${giteaThemeName^} Theme."
    elif [[ $giteaThemeInstall -eq 14 ]]; then themeInstallSuccessMessage="Successfully replaced the sitewaide logo."; fi
    ##################################################
    whiptail --title " UPDATED THEME " --msgbox "$themeInstallSuccessMessage\n\nPlease clear your browser's cache to apply the changes." 0 0 --ok-button "OK"
    ##################################################

    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
    ##################################################
    # Reset the Customizer Back to Start
    jumpto customreset

##################################################
# Gitea Updater
elif [[ "${wmenuGiteaCustom}" == "update" ]]; then
    ##################################################
    # Downloads a list of published Gitea version tags.
    giteaVersionTags=() # Initialize the Menu List of All Published Gitea Versions
    function downloadGiteaVersionTags() {
        ##################################################
        TERM=ansi whiptail --title " CONNECTING TO DL.GITEA.IO " --infobox "Attempting to connect to:\ndl.gitea.io" 0 0
        ##################################################
        # Safely Establish Connection to dl.gitea.io
        ping -c 1 dl.gitea.io > /dev/null 2>&1; exitStatus="$?" # ping -q Flag is Not Completely Silent
        # Ensure Connection was Established
        if [[ "$exitStatus" != 0 ]]; then
            # Could Not Connect to dl.gitea.io, Exit Installer
            ##################################################
            whiptail --title " CONNECTION FAILED " --msgbox "Failed to establish a connection to:\ndl.gitea.io." 0 0 --ok-button "OK"
            ##################################################
            jumpto customreset; fi # Reset the Customizer Back to Start

        ##################################################
        TERM=ansi whiptail --title " DOWNLOADING PUBLISHED VERSION TAGS " --infobox "Downloading all published version tags from:\ndl.gitea.io" 0 0
        ##################################################
        # Download All Gitea Version Directories for Listing
        giteaVersionDownloadTopDir="${gitearpizDir}/dl.gitea.io"
        giteaVersionDownloadDir="${giteaVersionDownloadTopDir}/gitea"
        wget -r --no-parent --level 1 --reject "main*,*.html,*.htm" -q https://dl.gitea.io/gitea/ > /dev/null 2>&1 # Ignore Non-Directories
        # Cleanse the Download Directory
        sudo rm "${giteaVersionDownloadDir}"/*.tmp > /dev/null 2>&1

        ##################################################
        # Construct the List of All Published Gitea Versions
        giteaVersionsPublished=() # Initialize the List of Published Gitea Version Tags
        for giteaVersionPublishedTag in "${giteaVersionDownloadDir}"/*; do # Cycle Through and Add Each File * in the [giteaVersionDownloadDir]
            # Add and Extract the Basename, as the Glob Extracts the Full Path
            giteaVersionsPublished+=($(basename "${giteaVersionPublishedTag}"))
        done
        # Remove the Temporary dl.gitea.io Directory
        sudo rm -r "${giteaVersionDownloadTopDir}" > /dev/null 2>&1

        ##################################################
        # Sort the List of All Published Gitea Versions
        #giteaVersionsPublished=($(for gverPub in "${giteaVersionsPublished[*]}"; do echo $gverPub; done | sort --version-sort))
        IFS=$'\n' giteaVersionsPublished=($(sort --version-sort --reverse <<< "${giteaVersionsPublished[*]}")) # Expand the List of All Published Version Tags and Separate by Newline
        unset IFS # Reset IFS Separator from Using Newline Separation
        ##################################################
        # Construct the Menu List from All Published Gitea Versions
        giteaVersionTags=() # Initialize the Menu List of All Published Gitea Versions
        validGiteaInstallTags="false" # Initialize Whether or Not the Gitea Version Tags were Properly Downloaded (By Checking if the 1.14.3 Tag Exists)
        for giteaVersionPublished in "${giteaVersionsPublished[@]}"; do # Cycle Through and Add Each Version Tag as a Menu Item
            # List Item: [version] [version-binary-name]
            giteaVersionTags+=("${giteaVersionPublished}" "gitea-${giteaVersionPublished}-linux-arm-6")
            # Check for the 1.15 Tag to Ensure Downloaded Version Tags are Valid (And Have Not Been Moved Elsewhere)
            if [[ "${giteaVersionPublished}" == *"1.15"* ]]; then validGiteaInstallTags="true"; fi # Valid Version Tags Found
        done
        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "Downloaded published Gitea version tags." 0 0
        ##################################################
        # Ensure the Downloaded Gitea Version Tags are Valid
        if [[ "$validGiteaInstallTags" == "false" ]]; then 
            # Could Not Find Valid to dl.gitea.io, Exit Installer
            ##################################################
            whiptail --title " INVALID VERSION TAGS " --msgbox "Failed to download valid Gitea version tags.\nThe Gitea download may have been moved.\n\nPlease open an issue below:\nhttps://github.com/trainingmode/gitea-rpiz/issues/new" 0 0 --ok-button "OK"
            ##################################################
            jumpto customreset; fi # Reset the Customizer Back to Start

    }

    ##################################################
    # Downloads the specified Gitea executable version.
    # [versionDownload] The version of Gitea to download.
    function downloadGiteaBinary() {
        # Extract the Input Arguments
        giteaVersionDownload="${1}"

        # Create the Gitea Application Temporary Directory
        giteaAppDirTemp="${giteaAppDir}/temp"
        sudo mkdir -p "${giteaAppDirTemp}"
        # Move to the Gitea Application Temporary Directory
        pushd "${giteaAppDirTemp}" > /dev/null 2>&1 || return
        while true; do
            ##################################################
            TERM=ansi whiptail --title " DOWNLOADING GITEA ${giteaVersionDownload} " --infobox "Downloading Gitea version ${giteaVersionDownload}..." 0 0
            ##################################################
            # Download the Specified Gitea Version
            sudo wget -O gitea "https://dl.gitea.io/gitea/${giteaVersionDownload}/gitea-${giteaVersionDownload}-linux-arm-6"
            # Mark the Gitea Binary as Executable
            sudo chmod +x gitea
            # Make the 'git' User the Owner of the Gitea Binary
            sudo chown git:git gitea

            ##################################################
            # Ensure the Gitea Binary was Downloaded
            if [[ -e "${giteaAppDirTemp}/gitea" ]]; then
                # Gitea Downloaded Successfully, Overwrite the Old Executable
                sudo mv -f "${giteaAppDirTemp}/gitea" "${giteaAppPath}"
                # Continue the Update
                break
            # Gitea did Not Download
            else
                ##################################################
                # Whiptail Confiration to Retry Downloading Gitea
                if (! whiptail --title " DOWNLOAD FAILED " --yesno "Gitea failed to download, would you like to retry?" 0 0 --yes-button "YES" --no-button "EXIT" 3>&1 1>&2 2>&3); then
                    # Gitea Download Retry Cancelled, Exit With Errors
                    exit 1; fi
                ##################################################
            fi
        done
        # Remove the Gitea Application Temporary Directory
        sudo rm -r "${giteaAppDirTemp}"
        # Return to the gitea-rpiz Directory
        popd > /dev/null 2>&1 || return
    }

    ##################################################
    # Download All Published Gitea Version Tags
    downloadGiteaVersionTags

    ##################################################
    # Gitea Installer for Raspberry Pi Zero
    ##################################################
    # Whiptail Menu for Gitea Updater
    wmenuGiteaUpdate=$(
        whiptail --title " GITEA UPDATER " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nPlease choose the version of Gitea to install." 0 0 0 \
        "${giteaVersionTags[@]}" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Reset the Customizer Back to Start
    if [[ $dialogExit != 0 ]]; then jumpto customreset; fi
    ##################################################

    ##################################################
    # Update to the Specified Version of Gitea
    downloadGiteaBinary "${wmenuGiteaUpdate}"

    ##################################################
    # Clear the ANSI xterm Terminal
    TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
    ##################################################

    ##################################################
    whiptail --title " UPDATED GITEA " --msgbox "Gitea was successfully updated to version ${wmenuGiteaUpdate}.\n\nPlease sign out of Gitea to refresh your credentials." 0 0 --ok-button "OK"
    ##################################################

##################################################
else
    ##################################################
    whiptail --title " INVALID OPTION " --msgbox "Please enter a valid option." 0 0 --ok-button "OK"
    ##################################################
fi

##################################################
# GOTO customreset
customreset:
##################################################
# Clear the ANSI xterm Terminal
#TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
##################################################
# Exit Customizer if Opened with an Input Argument
if [[ -n "${customizerOption}" ]]; then
    exit 0 # Exit Without Errors
# Reset the Customizer Back to Start if No Input Argument
else
    cd "${gitearpizDir}" || return # Reset to the gitea-rpiz Directory
    jumpto start
fi
