# DCMRemoteListener  

## Prerequisites  
1.) Install [Homebrew](https://brew.sh) if not already installed `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`  
2.) Update Homebrew `brew update`  
3.) Uninstall previous `libimobiledevice` versions `brew uninstall --ignore-dependencies libimobiledevice`  
4.) Uninstall previous `usbmuxd` versions `brew uninstall --ignore-dependencies usbmuxd`  
5.) Install latest `usbmuxd` `brew install --HEAD usbmuxd`  
6.) Remove old symbolic link for usbmuxd and recreate new one `brew unlink usbmuxd && brew link usbmuxd`  
7.) Install latest `libimobiledevice` `brew install --HEAD libimobiledevice`  
8.) Create new symbolic link for libimobiledevice and overwrite any existing ones `brew link --overwrite libimobiledevice`  
9.) Install `ideviceinstaller` `brew install ideviceinstaller`  
10.) Create new symbolic link for `ideviceinstaller` brew link --overwrite ideviceinstaller  
11.) sudo chmod -R 777 /var/db/lockdown/  

## Installation  
1.) Clone repository `git clone https://github.com/versx/DCMRemoteListener`  
2.) Install dependencies `npm install`  
3.) Install pm2 (optional) `npm install pm2 -g`  
4.) Copy example config file `cp config.example.json config.json`  
5.) Fill out `config.json`  
6.) Start the bot with `pm2 start listener.js` or `node listener.js` if not using pm2  

## Discord  
https://discordapp.com/invite/zZ9h9Xa  
