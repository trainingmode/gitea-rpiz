#!/bin/bash

##################################################
# Ensure the Script is Run from the /gitea-rpiz Directory
gitearpizDir="$(pwd)" # Print and Store the Current Working Directory
# Attempt to Find the gitea-rpiz.sh in the Current Directory
if [[ ! -e "${gitearpizDir}"/gitea-rpiz.sh ]]; then
    echo "ERROR: COULD NOT FIND GITEA-RPIZ!"
    echo "Please only execute from the /gitea-rpiz directory."
    echo ""
    echo "Try the following:"
    echo "cd '/path/to your/gitea-rpiz'"
    echo "bash gitea-rpiz.sh custom"
    exit 1 # Exit with Errors
fi

# Construct the Path to the gitea-rpiz.config
gitearpizConfig="${gitearpizDir}"/gitea-rpiz.config

####################################################
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

####################################################
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

####################################################
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

####################################################
# Set the Whiptail Theme Color
whiptailCurrentThemeColor="red"
whiptailDarkTheme "$whiptailCurrentThemeColor"
####################################################
# Set the Whiptail Theme Size
whiptailGaugeWindowSize=(7 50) #"${whiptailGaugeWindowSize[@]}"

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
# Uninstalling Gitea from your Raspberry Pi
##################################################

# Ensure Gitea was Previously Installed using gitea-rpiz
if [[ ! -e "${gitearpizConfig}" ]]; then # Ensure the gitea-rpiz Installation Configuration File Exists
    ##################################################
    # Whiptail Confiration to Continue Uninstallation
    if (! whiptail --title " GITEA NOT FOUND " --yesno "Gitea was not installed using gitea-rpiz.\nWould you like to continue the uninstallation?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Cancel the Gitea Uninstallation
        ##################################################
        whiptail --title " UNINSTALL CANCELLED " --msgbox "Cancelling the uninstallation. Gitea was not removed." 0 0 --ok-button "OK"
        ##################################################
        # Exit Without Errors
        exit 0
    fi
    ##################################################
fi

##################################################
# Whiptail Confiration to Confirm Uninstallation and Cancel if Specified
if (! whiptail --title " UNINSTALL GITEA " --yesno "Are you sure you want to uninstall Gitea?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    # Cancel the Gitea Installation
    ##################################################
    whiptail --title " INSTALL CANCELLED " --msgbox "Cancelling the uninstallation. Gitea was not removed." 0 0 --ok-button "OK"
    ##################################################
    # Exit Without Errors
    exit 0
fi
##################################################

##################################################
# Read the gitea-rpiz.config if it Exists and Extract the Gitea Working and Repository Directories
gitearpizConfigReader

##################################################
# Stop the Gitea Service
{ ##################################################
whiptailGaugeProgress 50 # Move Progress Gauge
sudo systemctl -q stop gitea; whiptailGaugeProgress 100
} | whiptail --gauge "\nStopping Gitea..." "${whiptailGaugeWindowSize[@]}" 0
##################################################

##################################################
TERM=ansi whiptail --title " REMOVING GITEA " --infobox "Removing Gitea..." 0 0
##################################################
# Move and Backup the Gitea app.ini
sudo mv -b /etc/gitea/app.ini "${gitearpizDir}"
# Remove the Gitea Directories
sudo rm -r /etc/gitea
sudo rm -r /usr/local/bin/gitea

##################################################
TERM=ansi whiptail --title " REMOVING SERVICE " --infobox "Removing the Gitea Service..." 0 0
##################################################
# Remove the Gitea Service
sudo rm /etc/systemd/system/gitea.service
# Reload systemd
sudo systemctl -q daemon-reload

##################################################
# Whiptail Confiration to Remove the 'git' User
if (whiptail --title " REMOVE GIT USER " --yesno "Remove the Git Server User 'git'\nand the 'git' user group?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    ##################################################
    TERM=ansi whiptail --title " REMOVING GIT USER " --infobox "Removing the Git Server User and User Group..." 0 0
    ##################################################
    sudo killall -u git -q
    sudo userdel -r git > /dev/null 2>&1 && groupdel git > /dev/null 2>&1
##################################################
else TERM=ansi whiptail --title " SKIPPING GIT USER " --infobox "Skipping the Git Server User and User Group..." 0 0; fi
##################################################

##################################################
# Whiptail Confiration to Remove the Gitea Working Directory
if (whiptail --title " REMOVE WORKING " --yesno "Remove the Gitea working directory?\nFound at: ${giteaDirectory}" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    ##################################################
    TERM=ansi whiptail --title " REMOVING WORKING " --infobox "Removing the Gitea working directory..." 0 0
    ##################################################
    sudo rm -r "$giteaDirectory"
##################################################
else TERM=ansi whiptail --title " SKIPPING WORKING " --infobox "Skipping the Gitea working directory..." 0 0; fi
##################################################

##################################################
# Whiptail Confiration to Remove the Gitea Repository Directory
if (whiptail --title " REMOVE REPOS " --yesno "Remove the Gitea repository directory?\nFound at: ${repositoriesDirectory}" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    ##################################################
    TERM=ansi whiptail --title " REMOVING REPOS " --infobox "Removing the Gitea repository directory..." 0 0
    ##################################################
    sudo rm -r "$repositoriesDirectory"
##################################################
else TERM=ansi whiptail --title " SKIPPING WORKING " --infobox "Skipping the Gitea repository directory..." 0 0; fi
##################################################

##################################################
TERM=ansi whiptail --title " REMOVING RPIZ CONFIG " --infobox "Removing the gitea-rpiz configuration..." 0 0
##################################################
# Remove the gitea-rpiz Configuration
sudo rm gitea-rpiz.config

# Finalization
##################################################
whiptail --title " UNINSTALLED GITEA " --msgbox "Successfully uninstalled Gitea." 0 0 --ok-button "OK"
##################################################

##################################################
# Clear the ANSI xterm Terminal
TERM=ansi whiptail --clear --infobox "Cleaning up." 0 0
##################################################
