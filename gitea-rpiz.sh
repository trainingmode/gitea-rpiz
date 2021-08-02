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

# Extract the Input Arguments
setupOption="${1}"
customizerOption="${2}"

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
# Set the Whiptail Theme Color
whiptailCurrentThemeColor="green"
whiptailDarkTheme "$whiptailCurrentThemeColor"
####################################################
# Set the Whiptail Theme Size
whiptailGaugeWindowSize=(7 50) #"${whiptailGaugeWindowSize[@]}"

####################################################
####################################################
# S C R I P T
####################################################
####################################################

# Check if Gitea was Previously Installed
gitearpizInstalled="false"
gitearpizConfig="${gitearpizDir}/gitea-rpiz.config"
if [[ -e /usr/local/bin/gitea && -e "${gitearpizConfig}" ]]; then # The Gitea Binary and gitea-riz.config Exist
    # Flag gitea-rpiz as Installed on the Device
    gitearpizInstalled="true"; fi

##################################################
# Import the Input Setup Type Argument
if [[ -n "${setupOption}" ]]; then
    wmenuGiteaSetup="${setupOption}"

##################################################
else # No Setup Input Argument, Ask User for Desired Option
    giteaSetupTypeMenuList=("INSTALL" "Install Gitea for Raspberry Pi.") # Initialize the List of Options for No Gitea Install Found
    if [[ "$gitearpizInstalled" == "true" ]]; then
        # Setup Menu List Items for Gitea Install Found
        giteaSetupTypeMenuList=("CUSTOM" "Customize and configure Gitea." "REMOVE" "Remove Gitea from your device."); fi
    ##################################################
    # Gitea Setup for Raspberry Pi Zero v1.0
    ##################################################
    # Whiptail Menu for Gitea Setup
    wmenuGiteaSetup=$(
        whiptail --title " GITEA RPIZ v1.0 " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nHow would you like to setup Gitea?" 0 0 0 \
        "${giteaSetupTypeMenuList[@]}" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Exit the Gitea Setup
    if [[ $dialogExit != 0 ]]; then exit; fi
    ##################################################
    # Validate Response
    wmenuGiteaSetup="${wmenuGiteaSetup,,}" # Convert the Selected Menu Item to All Lowercase ,, Letters
fi

##################################################
if [[ "$wmenuGiteaSetup" == "install" ]]; then
    # Install Gitea
    bash gitea-rpiz-install.sh

elif [[ "$wmenuGiteaSetup" == "custom" ]]; then
    # Ensure Gitea was Previously Installed
    if [[ "$gitearpizInstalled" == "false" ]]; then
        # Attempting to Customized Gitea when Not Installed, Exit gitea-rpiz
        ##################################################
        whiptail --title " GITEA NOT FOUND " --msgbox "A previous gitea-rpiz installation\nwas not found.\n\nPlease install gitea-rpiz before\ncontinuing." 0 0 --ok-button "OK"
        ##################################################
        exit 0; fi # Exit Without Errors
    # Customize Gitea
    bash gitea-rpiz-custom.sh "${customizerOption}"

elif [[ "$wmenuGiteaSetup" == "remove" ]]; then
    # Ensure Gitea was Previously Installed
    if [[ "$gitearpizInstalled" == "false" ]]; then
        # Attempting to Uninstall Gitea when Not Installed, Exit gitea-rpiz
        ##################################################
        whiptail --title " GITEA NOT FOUND " --msgbox "A previous gitea-rpiz installation\nwas not found.\n\nPlease install gitea-rpiz before\ncontinuing." 0 0 --ok-button "OK"
        ##################################################
        exit 0; fi # Exit Without Errors
    # Uninstall Gitea
    bash gitea-rpiz-remove.sh

fi
