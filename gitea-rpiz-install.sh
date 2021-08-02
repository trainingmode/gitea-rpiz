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
##################################################
# S C R I P T
##################################################
##################################################

##################################################
# Check for a Previous Gitea Installation
giteaAppIni="/etc/gitea/app.ini" # The Gitea Recommended Configuration File Path
giteaAppDir="/usr/local/bin/gitea" # The Gitea Recommended Installation Directory
giteaAppPath="/usr/local/bin/gitea/gitea" # The Gitea Recommended Executable Path
if [[ -e "${giteaAppPath}" ]]; then
    ##################################################
    # Whiptail Confiration to Continue Installation
    if (! whiptail --title " GITEA DETECTED " --yesno "A previous installation was detected at:\n${giteaAppDir}\nWould you like to continue installing Gitea?" 0 0 --defaultno --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Cancel the Gitea Installation
        ##################################################
        whiptail --title " INSTALL CANCELLED " --msgbox "Gitea installation cancelled." 0 0 --ok-button "OK"
        ##################################################
        # Exit Without Errors
        exit 0
    fi
    ##################################################
fi

##################################################
# Download Gitea Version Tags
##################################################

# Allow Global Read/Write Privileges for the gitea-rpiz Directory (Ensures Gitea Version Tags can be Downloaded)
sudo chmod 777 "${gitearpizDir}"

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
    exit 1; fi # Exit With Errors

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
wmenuGiteaInstallVersions=() # Initialize the Menu List of All Published Gitea Versions
validGiteaInstallTags="false" # Initialize Whether or Not the Gitea Version Tags were Properly Downloaded (By Checking if the 1.14.3 Tag Exists)
for giteaVersionPublished in "${giteaVersionsPublished[@]}"; do # Cycle Through and Add Each Version Tag as a Menu Item
    # List Item: [version] [version-binary-name]
    wmenuGiteaInstallVersions+=("${giteaVersionPublished}" "gitea-${giteaVersionPublished}-linux-arm-6")
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
    exit 1; fi # Exit with Errors

##################################################
# Gitea Installer for Raspberry Pi Zero
##################################################
# Whiptail Menu for Gitea Installation
wmenuGiteaInstall=$(
    whiptail --title " GITEA RPIZ " --ok-button "OK" --cancel-button "EXIT" \
    --menu "\nPlease choose the version of Gitea to install." 0 0 0 \
    "${wmenuGiteaInstallVersions[@]}" \
3>&2 2>&1 1>&3 ) dialogExit=$? ##################
# Whiptail Dialog Canceled, Exit the Gitea Installation
if [[ $dialogExit != 0 ]]; then exit; fi
##################################################

##################################################
# Download the Specified Gitea Version
##################################################

# Move to the Gitea Application Directory
pushd "$(dirname "${giteaAppDir}")" > /dev/null 2>&1 || return
while true; do
    ##################################################
    TERM=ansi whiptail --title " DOWNLOADING GITEA ${wmenuGiteaInstall} " --infobox "Downloading Gitea version ${wmenuGiteaInstall}..." 0 0
    ##################################################
    # Download the Specified Gitea Version
    sudo wget -O gitea "https://dl.gitea.io/gitea/${wmenuGiteaInstall}/gitea-${wmenuGiteaInstall}-linux-arm-6"
    # Mark the Gitea Binary as Executable
    sudo chmod +x gitea
    # Make the 'git' User the Owner of the Gitea Binary
    sudo chown git:git gitea

    ##################################################
    # Ensure the Gitea Binary was Downloaded
    if [[ -e "${giteaAppDir}" ]]; then break # Gitea Downloaded Successfully, Continue Installation
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
# Return to the gitea-rpiz Directory
popd > /dev/null 2>&1 || return

##################################################
# Create the 'git' User
##################################################
# Create the default Git Server User or Repair the Working Group for the Git Server User
if id "git" &>/dev/null; then # Check if the User 'git' Exists
    # User 'git' Exists
    ##################################################
    TERM=ansi whiptail --title " GIT USER EXISTS " --infobox "Git Server User 'git' already exists on this Raspberry Pi." 0 0
    ##################################################
    # Check if the 'git' Working Group Exists
    if getent group 'git'; then
        ##################################################
        TERM=ansi whiptail --title " GIT GROUP EXISTS " --infobox "Git Server User 'git' already in the 'git' working group." 0 0
        ##################################################
    else
        ##################################################
        # Whiptail Confiration to Repair the Working Group for the Git Server User
        if ( whiptail --title " WRONG GIT USER GROUP " --yesno "To properly complete the Gitea installation,\nthe 'git' user must be in the 'git' group.\n\nWould you like to repair the 'git' user's working group?\nThis will kill all active processes used by 'git'." 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            ##################################################
            TERM=ansi whiptail --title " CREATING GIT GROUP " --infobox "Adding the 'git' User Group..." 0 0
            ##################################################
            sudo groupadd git > /dev/null 2>&1
            ##################################################
            TERM=ansi whiptail --title " REPAIRING GIT USER " --infobox "Repairing the 'git' User's Working Group..." 0 0
            ##################################################
            sudo usermod -g git git > /dev/null 2>&1
            ##################################################
            TERM=ansi whiptail --title " REPAIRING GIT USER " --infobox "Terminating All Processes Running as 'git' User..." 0 0
            ##################################################
            killall -u git > /dev/null 2>&1
        # Cancel the Gitea Installation
        ##################################################
        else whiptail --title " INSTALL CANCELLED " --msgbox "Gitea installation cancelled." 0 0 --ok-button "OK"
        ##################################################
            # Exit Without Errors
            exit 0; fi
        ##################################################
    fi
else # User 'git' Does Not Exist
    ##################################################
    TERM=ansi whiptail --title " CREATING GIT USER " --infobox "Creating the Git Server User 'git'..." 0 0
    ##################################################
    sudo adduser \
		   --system \
		   --shell /bin/bash \
		   --gecos 'Gitea Git Server' \
		   --group \
		   --disabled-password \
		   --home /home/git \
		   git > /dev/null 2>&1

    # Create a Password for the git User
    ##################################################
    # Whiptail Confiration to Continue Installation
    if (whiptail --title " USER PASSWORD " --yesno "Create a password for the 'git' user?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
        # Create a Password for 'git'  User
        sudo passwd git
        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "User password created." 0 0
        ##################################################
    fi
fi

##################################################
# Opens a Whiptail dialog to ask for a file path,
# confirm it's existence, and ask to create the
# folder if it does not exist.
# [titleText] The title of the Whiptail dialog.
# [descriptionText] The description for the Whiptail dialog.
#   -d | Dialog with checks for directory paths.
#   -c [cancelButtonText] | The text for the cancel button.
#   -u [pathOwner] | The user that owns the path.
# Returns: [path] The user specified path.
whiptailInputPathCreateReturn="" # Initialize the Function Return
whiptailInputPathCreate() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    # cflag="" cflag="-${flag}";
    # dflag="" dflag="-${flag}";
    # uflag="" uflag="-${flag}";
    cancelButtonText="EXIT"
    isDirectory="false"
    pathOwner=""
    while getopts "c:du:" flag; do
        case "${flag}" in
            c) cancelButtonText="${OPTARG}" ;;
            d) isDirectory="true" ;;
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
    whiptailInputPath=""
    while true; do # Loop Until a Valid Readme File is Entered
        # Specify the Readme Filepath
        ##################################################
        # Whiptail Input for Directory Path
        whiptailInputDialogPath=$(whiptail --title " ${1} " --ok-button "OK" --cancel-button "${cancelButtonText}" \
            --inputbox "\n${2}" 0 0 "${whiptailInputPath}" \
            3>&1 1>&2 2>&3 ) dialogExit=$? ###############
        # Whiptail Dialog Canceled, Reset the Customizer Back to Start
        if [[ $dialogExit != 0 ]]; then exit; fi
        ##################################################
        # Store the Input File Path
        whiptailInputPath="${whiptailInputDialogPath}"

        ##################################################
        if [[ ! -e "${whiptailInputPath}" ]]; then
            ##################################################
            # Whiptail Confiration to Create Path
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
# Ask to Use External Storage
##################################################
giteaInstallPath="/var/lib" # Initialize the Default Gitea Recommended Installation Directory
giteaRepoPath="/home/git/repositories" # Initialize the Default Gitea Repositories Directory
##################################################
# Create the Gitea Working Directory
if (whiptail --title " EXTERNAL STORAGE " --yesno "Would you like to use external storage?\nPlease set this up now to direct Gitea to the correct locations." 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    ##################################################
    # Whiptail Input Path Dialog for the External Storage Path
    whiptailInputPathCreate -d "EXTERNAL STORAGE" "Please enter the full path to your desired Gitea root directory.\nThe /gitea and /repositories folders will be created there.\n  - /gitea is the Gitea working folder.\n  - /repositories stores git repositories.\n| EXAMPLE: /mnt/MyDrive"
    giteaInstallPath="${whiptailInputPathCreateReturn}" # Extract the Function Output
    ##################################################

    # Create the Gitea Repositories Directories and Make the 'git' User the Owner
    giteaRepoPath="${giteaInstallPath}/repositories"
    sudo mkdir -p "${giteaRepoPath}"
    sudo chown git:git "${giteaRepoPath}"

# Not Using External Storage, Create the Default Gitea Repositories Directory
else sudo -H -u git mkdir "${giteaRepoPath}"; fi
##################################################

##################################################
TERM=ansi whiptail --title " CREATING GITEA DIRECTORIES " --infobox "Create the required directories..." 0 0
##################################################
# Create the Required Directories
sudo mkdir -p "${giteaInstallPath}"/gitea/{custom,data,log}
sudo chown -R git:git "${giteaInstallPath}"/gitea/
sudo chmod -R 755 "${giteaInstallPath}"/gitea/ #750
sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea

##################################################
# Create the Gitea Service
##################################################
TERM=ansi whiptail --title " CREATING GITEA SERVICE " --infobox "Creating the Gitea Service..." 0 0
##################################################
# Create the gitea.service File and Properly Inject the Specified Gitea Installation Directory
echo "[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
###
# Don't forget to add the database service dependencies
###
#
#Wants=mysql.service
#After=mysql.service
#
#Wants=mariadb.service
#After=mariadb.service
#
#Wants=postgresql.service
#After=postgresql.service
#
#Wants=memcached.service
#After=memcached.service
#
#Wants=redis.service
#After=redis.service
#
###
# If using socket activation for main http/s
###
#
#After=gitea.main.socket
#Requires=gitea.main.socket
#
###
# (You can also provide gitea an http fallback and/or ssh socket too)
#
# An example of /etc/systemd/system/gitea.main.socket
###
##
## [Unit]
## Description=Gitea Web Socket
## PartOf=gitea.service
##
## [Socket]
## Service=gitea.service
## ListenStream=<some_port>
## NoDelay=true
##
## [Install]
## WantedBy=sockets.target
##
###

[Service]
# Modify these two values and uncomment them if you have
# repos with lots of files and get an HTTP error 500 because
# of that
###
#LimitMEMLOCK=infinity
#LimitNOFILE=65535
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=${giteaInstallPath}/gitea/
# If using Unix socket: tells systemd to create the /run/gitea folder, which will contain the gitea.sock file
# (manually creating /run/gitea doesn't work, because it would not persist across reboots)
#RuntimeDirectory=gitea
ExecStart=${giteaAppDir} web --config ${giteaAppIni}
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=${giteaInstallPath}/gitea
# If you install Git to directory prefix other than default PATH (which happens
# for example if you install other versions of Git side-to-side with
# distribution version), uncomment below line and add that prefix to PATH
# Don't forget to place git-lfs binary on the PATH below if you want to enable
# Git LFS support
#Environment=PATH=/path/to/git/bin:/bin:/sbin:/usr/bin:/usr/sbin
# If you want to bind Gitea to a port below 1024, uncomment
# the two values below, or use socket activation to pass Gitea its ports as above
###
#CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_BIND_SERVICE
###

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/gitea.service > /dev/null 2>&1
##################################################
TERM=ansi whiptail --title " ENABLING GITEA SERVICE " --infobox "Enabling and starting the gitea.service..." 0 0
##################################################
# Enable and Start the gitea.service
sudo systemctl enable gitea --now
##################################################
# Clear the ANSI xterm Terminal
TERM=ansi whiptail --clear --infobox "Gitea service is enabled and running." 0 0
##################################################

##################################################
# Gitea Web Setup
##################################################
# Extract the Raspberry Pi IP Address (No Spaces)
ipAddress="$(hostname -I | tr -d ' ')" # Trim All Spaces
# Wait Until User Complete the Gitea Web Setup
while true; do
    ##################################################
    # Whiptail Confiration to Continue Installation
    if (! whiptail --title " GITEA WEB SETUP " --yesno "Setup Gitea by going to http://$ipAddress:3000/ in a browser.\nNote: Gitea may take 20-30 seconds to start.\n\n- Database Type: SQLite3\n- Repository Root Path: ${giteaRepoPath}\n- Git LFS Root Path: ${giteaRepoPath}/.lfs\n\nSelect CONTINUE after setting up Gitea." 0 0 --yes-button "OK" --no-button "CONTINUE" 3>&1 1>&2 2>&3); then
        # Web Setup Completed, Continue the Gitea Installation
        break
    fi
    ##################################################
done

##################################################
TERM=ansi whiptail --title " MOVING GITEA EXECUTABLE " --infobox "Moving the Gitea executable into its own folder..." 0 0
##################################################
# Stop Gitea to Move the Binary File
sudo systemctl stop gitea
# Create the Gitea Application Directory, Tag as Temp to Prevent Confilcting Names
sudo mkdir -p "${giteaAppDir}Temp"
# Move the Gitea Binary to the Gitea Application Directory
sudo mv "${giteaAppDir}" "${giteaAppDir}Temp/"
# Rename the Gitea Application Directory to the Original Name
sudo mv "${giteaAppDir}Temp" "${giteaAppDir}"
##################################################
# Change the Executable Path in the gitea.service
sudo sed -i 's|ExecStart='"${giteaAppDir}"' web|ExecStart='"${giteaAppPath}"' web|' /etc/systemd/system/gitea.service
# Reload systemd
sudo systemctl -q daemon-reload
# Make the 'git' User the Owner of the Gitea Installation Directory and Binary
sudo chown -R git:git ${giteaAppDir}
sudo chown git:git ${giteaAppPath}
# Start Gitea
sudo systemctl start gitea
# Regenerate git-hooks
sudo -u git "${giteaAppPath}" -c "${giteaAppIni}" admin regenerate hooks > /dev/null 2>&1

##################################################
TERM=ansi whiptail --title " APPLYING DEFAULT CONFIGURATION " --infobox "Applying the default Gitea configuration..." 0 0
##################################################
# Initialize the Default Gitea Configuration
##################################################
function editConfigAppIni() {
    # Extract the Input Tags and Config Setting Value
    headerTag="${1}"
    configTag="${2}"
    configValue="${3}"
    # Insert '\' Escaping Backslashes Before the '[]' Brackets for the Match Pattern
    headerTagMatch="\\${headerTag:0:${#headerTag}-1}\\${headerTag:${#headerTag}-1}"

    # Search the app.ini Line by Line
    foundHeaderTag="false"
    foundConfigTag="false"
    foundLineIndex=0 # The Current Line Index
    while IFS=, read -r readline; do
        # Increment the Current Line Index
        ((++foundLineIndex))
        # Search for the Configuration Tag
        if [[ $foundHeaderTag == "true" ]]; then
            if [[ "${readline}" == *"${configTag}"* ]]; then
                # Flag that the Config Tag was Found
                foundConfigTag="true"
                # Stop Reading the app.ini and Return the Results
                break
            fi
        # Search for the Header Tag
        else
            if [[ "${readline}" == *"${headerTag}"* ]]; then
                # Flag that the Header was Found and to Begin Searching for the Config
                foundHeaderTag="true"
            fi
        fi
    done < <(sudo cat "${giteaAppIni}")

    # Edit the app.ini if the Config Tag was Found
    if [[ $foundConfigTag == "true" ]]; then
        # Replace the Entire Line Configuration at the Line Index Found
        sudo sed -i ''"${foundLineIndex}"'s|^'"${configTag}"'.*|'"${configTag}"' = '"${configValue}"'|' "${giteaAppIni}"
    # The Config Tag was Not Found, Add the Config
    else
        # Add the Config Tag Below the Header Tag
        if [[ $foundHeaderTag == "true" ]]; then
            # Insert the Config Tag Below the Header Tag
            sudo sed -i '/^'"${headerTagMatch}"'.*/a '"${configTag}"' = '"${configValue}"'' "${giteaAppIni}"
        # The Config Tag was Not Found, Add Both the Header and Config Tags
        else
            # Add the Header Tag to the End of the app.ini
            sudo sed -i -e '$a\\n'"${headerTag}"'' "${giteaAppIni}" # Add a Newline and the Header Tag to the End of the app.ini
            # Add the Config Tag to the End of the app.ini
            sudo sed -i -e '$a\'"${configTag}"' = '"${configValue}"'' "${giteaAppIni}" # Add the Config Tag to the End of the app.ini
        fi
    fi
}
##################################################
# Allow Write Privileges for the app.ini
sudo chmod 777 "${giteaAppIni}"
sudo chown root:root "${giteaAppIni}"
# Set the Default Branch Label as "main"
editConfigAppIni '[repository]' "DEFAULT_BRANCH" "main"
##################################################
# Enable the gitea-rpiz Midnight and Gitnight Themes
editConfigAppIni '[ui]' "THEMES"        "gitea,arc-green,gitday,gitnight"
editConfigAppIni '[ui]' "DEFAULT_THEME" "gitday"
##################################################
# Enable the Indexer
editConfigAppIni '[indexer]' "REPO_INDEXER_ENABLED" "true"
editConfigAppIni '[indexer]' "REPO_INDEXER_PATH"    "indexers/repos.bleve"
editConfigAppIni '[indexer]' "UPDATE_BUFFER_LEN"    "20"
editConfigAppIni '[indexer]' "MAX_FILE_SIZE"        "1048576"

##################################################
# Install the Gitday and Gitnight Themes
gitearpizThemesDir="${gitearpizDir}/custom/themes"
giteaCustomThemesDir="${giteaInstallPath}/gitea/custom/public/css"
giteaCustomImagesDir="${giteaInstallPath}/gitea/custom/public/img"
sudo mkdir -p "${giteaCustomThemesDir}"
sudo cp "${gitearpizThemesDir}/theme-gitday.css"   "${giteaCustomThemesDir}"
sudo cp "${gitearpizThemesDir}/theme-gitnight.css" "${giteaCustomThemesDir}"
# Install the spaceboy3000 Gitea Logo
sudo mkdir -p "${giteaCustomImagesDir}"
sudo cp "${gitearpizThemesDir}/img/logo.svg" "${giteaCustomImagesDir}"

##################################################
# Whiptail Confiration for Extended Configuration
if (whiptail --title " EXTENDED CONFIG " --yesno "Would you like to apply the extended\ngitea-rpiz configuration to Gitea?\n\nThis will increase file upload limits,\ninstall all Teakettle theme colors, and\ninstall the custom Github label set." 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
    ##################################################
    TERM=ansi whiptail --title " APPLYING EXTENDED CONFIGURATION " --infobox "Applying the extended Gitea configuration..." 0 0
    ##################################################
    # Install All Teakettle Theme Color Variations
    sudo cp "${gitearpizThemesDir}/theme-fullblack.css"    "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-deepsea.css"      "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-fullblack.css"    "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-chaitea.css"      "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-cherry.css"       "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-dreamy.css"       "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-dulce.css"        "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-berry.css"        "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-derryrose.css"    "${giteaCustomThemesDir}"
    sudo cp "${gitearpizThemesDir}/theme-biluochuntea.css" "${giteaCustomThemesDir}"

    ##################################################
    # Install the Custom Github Label Set
    giteaCustomLabelsPath="${giteaInstallPath}/gitea/custom/options/label" # Intialize the Local Path to the Custom Labels Directory
    if [[ ! -d "${giteaCustomLabelsPath}" ]]; then # Ensure the Gitea Custom Labels Folder Exists
	    sudo mkdir -p "${giteaCustomLabelsPath}"; fi # Custom Labels Folder Does Not Exist, Create the Folder
    # Copy the Custom Github Label Set into the Gitea Custom Labels Directory
    sudo cp "${gitearpizDir}/custom/Github Labels" "${giteaCustomLabelsPath}" > /dev/null 2>&1

    ##################################################
    # Install the Custom gitea-rpiz Readme Set
    giteaCustomReadmePath="${giteaInstallPath}/gitea/custom/options/readme" # Intialize the Local Path to the Custom Readme Directory
    if [[ ! -d "${giteaCustomReadmePath}" ]]; then # Ensure the Gitea Custom Readme Folder Exists
        sudo mkdir -p "${giteaCustomReadmePath}"; fi # Custom Readme Folder Does Not Exist, Create the Folder
    # Copy the Custom gitea-rpiz Readme Set into the Gitea Custom Readmes Directory
    sudo cp "${gitearpizDir}/custom/README.md"       "${giteaCustomReadmePath}" > /dev/null 2>&1
    sudo cp "${gitearpizDir}/custom/README_basic.md" "${giteaCustomReadmePath}" > /dev/null 2>&1
    sudo cp "${gitearpizDir}/custom/README_setup.md" "${giteaCustomReadmePath}" > /dev/null 2>&1

    ##################################################
    # Extended Repository Configuration
    editConfigAppIni '[repository]' "PREFERRED_LICENSES" "MIT License,MIT"
    # Extended Repository Uploads Configuration
    editConfigAppIni '[repository.upload]' "MAX_SIZE" "2500"
    editConfigAppIni '[repository.upload]' "MAX_FILES" "999"
    # Extended Attachments Configuration
    editConfigAppIni '[attachment]' "MAX_SIZE" "1000"
    editConfigAppIni '[attachment]' "MAX_FILES" "999"
    # Extended UI Configuration
    editConfigAppIni '[ui]' "THEMES" "gitday,gitnight,berry,biluochuntea,chaitea,cherry,deepsea,derryrose,dreamy,dulce,fullblack"

    ##################################################
    # Write the gitea-rpiz Customizer Desktop Launcher File
    giteaDesktopLauncherName="Gitea Customizer"
    giteaDesktopLauncherComment="Configure Gitea for Raspberry Pi Zero"
    giteaDesktopLauncherExec='bash "gitea-rpiz-custom.sh"'
    giteaDesktopLauncherIcon="${giteaInstallPath}/gitea/custom/public/img/logo.svg"
    giteaDesktopLauncherFile="gitea-rpiz-custom.desktop"
    ##################################################
    giteaDesktopLauncherCategory="Gitea;"
    giteaDesktopLauncherType="Application"
    giteaDesktopLauncherTerminal="true"
    giteaDesktopLauncherNoDisplay="false"
    giteaDesktopLauncherHidden="false"
    giteaDesktopLauncherWorkingPath="${gitearpizDir}" # Extract the Current gitea-rpiz Working Directory
    giteaDesktopLauncherPath="/home/pi/Desktop"
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
    ##################################################
    # Rename the Launcher File to the Launcher Name After Installing to the Desktop
    sudo mv "${giteaDesktopLauncherPath}/${giteaDesktopLauncherFile}" "${giteaDesktopLauncherPath}/${giteaDesktopLauncherName}"
fi
##################################################

##################################################
# Finalization
##################################################

##################################################
# Remove Write Privileges After the Gitea Web Setup Completes
sudo chown git:git "${giteaAppIni}"
sudo chmod 640 "${giteaAppIni}"
sudo chmod 750 /etc/gitea

##################################################
TERM=ansi whiptail --title " RESTARTING GITEA " --infobox "Restarting Gitea to apply changes made during setup..." 0 0
##################################################
# Restart Gitea to Update Changes Made During Setup
sudo systemctl -q stop gitea && sudo systemctl -q start gitea

##################################################
# Save the Installation Configuration
##################################################
TERM=ansi whiptail --title " SAVING GITEA RPIZ CONFIG " --infobox "Saving the installation configuration to gitea-rpiz.config..." 0 0
##################################################
# Write the gitea-rpiz.config File
echo -e "GITEA_INSTALL_PATH=${giteaInstallPath}\nGITEA_REPO_PATH=${giteaRepoPath}" | sudo tee gitea-rpiz.config > /dev/null 2>&1
##################################################
# Clear the ANSI xterm Terminal
TERM=ansi whiptail --clear --infobox "Gitea service is enabled and running." 0 0
##################################################

##################################################
whiptail --title " INSTALLED GITEA $wmenuGiteaInstall " --msgbox "Gitea installation complete!\n\nPlease replace \"localhost\" with '$ipAddress'\nin your browser to login to Gitea.\n\nNote: Gitea may take 20-30 seconds to start." 0 0 --ok-button "OK" 3>&1 1>&2 2>&3
##################################################
