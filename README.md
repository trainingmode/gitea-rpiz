# A painless [Gitea](https://gitea.io/) installation for Raspberry Pi Zero.

[![Codacy Security Scan](https://github.com/trainingmode/gitea-rpiz/actions/workflows/codacy-analysis.yml/badge.svg)](https://github.com/trainingmode/gitea-rpiz/actions/workflows/codacy-analysis.yml)

![gitea-rpiz_Demo](https://user-images.githubusercontent.com/52793789/127861891-2999d5ee-a5b9-412e-8a18-2c61feea1f0c.gif)

-----

# FAQs

## *Who is this for?*

Raspberry Pi Zero users that would like a quick and easy way to install a private, local Gitea server.

-----

# Features

- Streamlined Gitea installation with full compatibility for Raspberry Pi Zero running Raspberry Pi OS Buster.

- User-friendly [dialog-based](https://linux.die.net/man/1/whiptail) setup.

- Backup & Restore.

- Custom *readme*, *labels*, *license*, and *.gitignore* installer.

- Quick `gitea.service` Handler:

  - `start`, `restart`, and`stop` Gitea.

  - `enable` and `disable` Gitea on boot (enabled by default).

- Easily configure 18 Gitea `app.ini` settings, including:

  - *Repository*, *Server*, *Indexer*, *UI*, & more.

  - *Custom Editor.* Add/edit custom settings found in the [app.ini reference](https://github.com/go-gitea/gitea/blob/main/custom/conf/app.example.ini).

- Desktop/Menu launchers for the customizer, easy config, backup, restore, and `gitea.service` handler.

- Theme installer, including the Github-flavored [Teakettle Theme Suite](https://github.com/trainingmode/TeakettleThemes).

- Stylized [README.md templates](custom/README.md) for Gitea.

- Github-styled issue label set for Gitea.

- Gitea updater.

-----

# Guide

- If you encounter any problems, please [open an issue](https://github.com/trainingmode/gitea-rpiz/issues/new).

- Pro user? Check the [Quick Setup Guide](https://github.com/trainingmode/gitea-rpiz/wiki/Quick-Setup-Guide) for a concise guide.

## *Preparation*

- If you would like to use external storage, please ensure it is [mounted](https://www.raspberrypi.org/documentation/configuration/external-storage.md) to your needs before installing Gitea.

- Gitea will be installed to `/usr/local/bin/gitea/`. You can choose where to install the working `/gitea` and `/repositories` directories during setup.

## *Installation*

1. Download the setup scripts:

        sudo wget https://github.com/trainingmode/gitea-rpiz/releases/download/1.0/gitea-rpiz.zip
        sudo unzip gitea-rpiz.zip
        sudo rm gitea-rpiz.zip

2. Run the setup and follow the prompts:

        cd gitea-rpiz
        bash gitea-rpiz.sh

- A `gitea-rpiz.config` file will be created to store your `/gitea` and `/repositories` paths for customization and uninstallation. Update this config if you change these paths after installation without using gitea-rpiz.

- To serve Gitea using your Raspberry Pi's wireless capabilities, set up an [access point](https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md) and navigate to your static IP.

  - A static IP of `192.168.4.1` with Gitea HTTP port of `3000` would connect to http://192.168.4.1:3000/.

- You may remove gitea-rpiz at any time while Gitea is installed, as long as you preserve your `gitea-rpiz.config`. Simply redownload gitea-rpiz whenever you need it and replace the `gitea-rpiz.config`. Below is an example:

        GITEA_INSTALL_PATH=/mnt/MyDrive
        GITEA_REPO_PATH=/mnt/MyDrive/repositories

## *Customizer*

1. Run the setup and choose `custom`:

        bash gitea-rpiz.sh custom

- Custom labels, licenses, readmes, and gitignores can be freely named.

  - NOTE: Default licenses supplied by Gitea **do not** automatically fill with your profile info and require you  
  to update each license for each new repo. The gitea-rpiz license installer provides a license tag replacer.

- You can also install desktop/menu launchers:

        bash gitea-rpiz.sh custom launcher

  - Or create your own. Use a `customizerArg` (ex: `service`) for a specific utility:

    - Command:

          bash '/path/to your/gitea-rpiz/gitea-rpiz.sh' custom customizerArg

    - Working Directory:

          /path/to your/gitea-rpiz

## *Backup Gitea*

1. Run the Customizer and choose `backup`:

        bash gitea-rpiz.sh custom backup

- WARNING: DO NOT USE `./gitea backup`. Only use gitea-rpiz to backup. See the notes under [Restore Gitea](#restore-gitea).

## *Restore Gitea*

1. Run the Customizer and choose `restore`:

        bash gitea-rpiz.sh custom restore

- Please only restore backups created by gitea-rpiz. Current supported versions require manually backing up the working directory (avatars, attachments, etc.) to properly succeed. gitea-rpiz uses `./gogs backup` and handles the rest automatically. All data can be backed up and restored.

## *Uninstallation*

- If the working `/gitea` or `/repositories` directories were changed after installation without using gitea-rpiz, please update the `gitea-rpiz.config` prior to removal.

- The Gitea `app.ini` will be backed up to the gitea-rpiz working directory.

1. Run the uninstaller and follow the prompts:

        bash gitea-rpiz.sh remove

2. Remove gitea-rpiz:

        sudo rm -r "/path/to your/gitea-rpiz"

-----

# *Full Walkthrough*

Below is a walkthrough (no audio) demonstrating the installation, configuration, backup/restore, and uninstallation processes.

https://user-images.githubusercontent.com/52793789/127908512-2f685fd3-e337-48eb-ac78-5bc164872401.mp4

## Install

1. Download and unzip the scripts. (0:00)
2. Run the setup and install Gitea. (0:20)

## Configure

1. Configure basic settings. (6:19)
2. Install a custom license. (7:21)
3. Backup Gitea. (8:38)
4. Restore Gitea. (9:19)
5. Update Gitea. (9:58)

## Uninstall

1. Uninstall Gitea. (12:34)

-----

# Credits

The installation is based on the [Official Gitea Installation Guide](https://docs.gitea.io/en-us/install-from-binary/).
