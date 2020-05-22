# DCMRemoteListener  

## Prerequisites  
1.) Install [Homebrew](https://brew.sh) if not already installed `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`  
2.) Update Homebrew `brew update`  
3.) Uninstall previous `libimobiledevice` versions `brew uninstall --ignore-dependencies libimobiledevice`  
4.) Uninstall previous `usbmuxd` versions `brew uninstall --ignore-dependencies usbmuxd`  
5.) Uninstall previous `libplist` versions `brew uninstall --ignore-dependencies libplist`  
6.) Install latest `usbmuxd` `brew install --HEAD usbmuxd`  
7.) Install latest `libplist` `brew install --HEAD libplist`   
8.) Install latest `libimobiledevice` `brew install --HEAD libimobiledevice`  
9.) Install `ideviceinstaller` `brew install ideviceinstaller`  
10.) Install `ios-deploy` `brew install ios-deploy`  

## Installation  
1.) Clone repository `git clone https://github.com/versx/DCMRemoteListener`  
2.) Install dependencies `npm install`  
3.) Install pm2 (optional) `npm install pm2 -g`  
4.) Copy example config file `cp config.example.json config.json`  
5.) Fill out `config.json`  
  * Name is to identify the listener uniquely.
  * Port is the listening port, defaults to 6542.
  * Domain (i.e. `http://10.0.0.2:9991` or `https://dcm.domain.com`) is the DeviceConfigManager domain that will be sending the reboot request, otherwise set to `*` to accept from all hosts.

6.) Start the bot with `pm2 start listener.js` or `node listener.js` if not using pm2  

## Discord  
https://discordapp.com/invite/zZ9h9Xa  
