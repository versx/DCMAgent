#!/bin/bash

# Get all text from the input with $@
# Get the frist word with $1 for the task
# Get the second word with $2 for the DNS server
# Remove those from the text so we have the device list
TEXT=$@
TASK=$1
DNS=$2
DEVICES=${TEXT//$TASK/}
DEVICES=${DEVICES//$DNS/}

if [[ "$TASK" != "reboot" ]] && \
   [[ "$TASK" != "reopen_atlas" ]] && \
   [[ "$TASK" != "reopen_gc" ]] && \
   [[ "$TASK" != "update" ]] && \
   [[ "$TASK" != "pogo_version" ]] && \
   [[ "$TASK" != "tail_logs" ]] && \
   [[ "$TASK" != "cron" ]] && \
   [[ "$TASK" != "follow_atlas" ]] && \
   [[ "$TASK" != "clear_logs" ]] && \
   [[ "$TASK" != "playstore" ]] && \
   [[ "$TASK" != "jb_respring" ]] && \
   [[ "$TASK" != "jb_reboot" ]] && \
   [[ "$TASK" != "temp" ]] && \
   [[ "$TASK" != "proxy_disable" ]]
then
    echo Unsupported task: $TASK.
    exit 1
fi

# Set a return code so we don't break the loop with exits
RETURNCODE=0

for D in $DEVICES
do
    # Check the DNS server for IP
    IP=$(nslookup $D $DNS | grep Address | tail -1 | awk '{print $2}')
    # If that has # in it, then no address was found.
    if [[ "$IP" == *"#"* ]]
    then
        # Try to look in the local leases
        IP=$(cat /var/db/dhcpd_leases | grep -A 1 -e $D | tail -1 | awk -F '=' '{print $2}')
        # If the IP is blank, exit
        if [[ "$IP" == "" ]]
        then 
            echo "IP could not be found for $D"
            RETURNCODE=`expr $RETURNCODE + 1`;continue
        fi
    fi
    echo Connecting to $D at $IP to $TASK.
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        adb connect $IP
        if [ $? -gt 0 ]; then echo "ADB connect command failed; exiting." ; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        sleep 3
    else
        # Get the UUID/ECID from json
        DATA=$(cat devices.json | grep -e $D | tail -1)
        UUID=$(echo $DATA | cut -d \" -f 8)
        ECID=$(echo $DATA | cut -d \" -f 12)
    fi
    
    if [[ "$TASK" = 'reopen_atlas' ]]
    then
        adb -s $IP shell su -c 'am force-stop com.nianticlabs.pokemongo && am force-stop com.pokemod.atlas && am startservice com.pokemod.atlas/com.pokemod.atlas.services.MappingService'
    elif [[ "$TASK" = 'reopen_gc' ]]
    then
        adb -s $IP shell su -c 'am force-stop com.nianticlabs.pokemongo && am force-stop com.gocheats.launcher'
        adb -s $IP shell su -c 'rm -rf /data/data/com.nianticlabs.pokemongo/cache/*'
        adb -s $IP shell -tt 'monkey -p com.gocheats.launcher 1'
    elif [[ "$TASK" = 'reboot' ]]
    then
        adb -s $IP reboot
    elif [[ "$TASK" = 'temp' ]]
    then
        adb -s $IP shell 'var=$(cat /sys/class/thermal/thermal_zone0/temp) && cel=$(( $var / 1000 )) && fah=$((( $cel * 9 / 5 ) + 32 )) && echo The temperature is $cel\C/$fah\F'
    elif [[ "$TASK" = 'update' ]]
    then
        adb -s $IP shell su -c "./system/bin/atlas.sh -ua &"
    elif [[ "$TASK" = 'pogo_version' ]]
    then
        adb -s $IP shell su -c 'tac /data/local/tmp/atlas.log | grep -m 1 Using'
    elif [[ "$TASK" = 'tail_logs' ]]
    then
        echo ""
        echo Tailing atlas.log
        # We can just tail the last x lines to see what was going on
        adb -s $IP shell su -c '/sbin/.magisk/busybox/tail -20 /data/local/tmp/atlas.log'
        # Use the aconf log
        echo ""
        echo Tailing aconf.log
        adb -s $IP shell su -c '/sbin/.magisk/busybox/tail -20 /sdcard/aconf.log'
        # Use the aconf log
        echo ""
        echo Tailing emagisk.log
        adb -s $IP shell su -c '/sbin/.magisk/busybox/tail -20 /data/local/tmp/emagisk.log'
    elif [[ "$TASK" = 'follow_atlas' ]]
    then
        # You can use the busybox tail to follow but stopping it requires ctrl+c that kills the script without disconnecting
        echo ""
        echo "Tailing atlas.log (Press Ctrl+C to end)"
        adb -s $IP shell su -c '/sbin/.magisk/busybox/tail -f /data/local/tmp/atlas.log'
    elif [[ "$TASK" = 'clear_logs' ]]
    then
        echo Clearing atlas.log
        adb -s $IP shell su -c 'echo > /data/local/tmp/atlas.log'
        echo Clearing aconf.log
        adb -s $IP shell su -c 'echo > /sdcard/aconf.log'
        echo Clearing emagisk.log
        adb -s $IP shell su -c 'echo > /data/local/tmp/emagisk.log'
    elif [[ "$TASK" = 'cron' ]]
    then
        adb -s $IP push ping_test.sh /data/local/tmp/
        adb -s $IP shell su -c 'mount -o remount,rw /system && mount -o remount,rw /system/etc/init.d || true && mkdir /data/local/tmp/crontabs/ && touch /data/local/tmp/crontabs/root && echo "40 * * * * /data/local/tmp/ping_test.sh" > /data/local/tmp/crontabs/root'
        adb -s $IP shell su -c 'mount -o remount,rw /system && mount -o remount,rw /system/etc/init.d || true && touch /data/local/tmp/55cron && chmod +x /data/local/tmp/55cron && echo "#!/system/bin/sh\ncrond -b" > /data/local/tmp/55cron'
        adb -s $IP shell su -c 'mv /data/local/tmp/crontabs /system/etc/crontabs'
        adb -s $IP shell su -c 'mv /data/local/tmp/55cron /system/etc/init.d/55cron'
        adb -s $IP shell su -c 'reboot'
    elif [[ "$TASK" = 'playstore' ]]
    then
        adb -s $IP shell su -c 'pm enable com.android.vending'
        adb -s $IP shell su -c 'reboot'
    elif [[ "$TASK" = 'jb_respring' ]]
    then
        # Remove the SAM profile. We won't error/exit in case the profile wasn't applied
        cfgutil -e $ECID -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode > /dev/null 2>&1
        # Replace the SAM profile. We won't error/exit here because SSH will let us know if it fails
        cfgutil -e $ECID -K org.der -C org.crt install-profile sam_clock.mobileconfig > /dev/null 2>&1
        if [ $? = 0 ]; then echo 'SAM profile successfully replaced.'; sleep 5; else 'Could not replace the SAM profile.'; fi
        # This requires the target device to have your public SSH key in the authorized_keys file
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$IP -tt "killall kernbypass; if [ $? -gt 0 ]; then echo 'kernbypass not found'; else echo 'kernbypass killed'; fi; sleep 10; sbreload; if [ $? -gt 0 ]; then echo 'failed to reload springboard';else echo 'springboard reloaded'; fi"
        if [ $? -gt 0 ]; then echo 'Unable to SSH to device. Probably blocked by kernbypass.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        # Remove the SAM profile. We won't error/exit in case the profile wasn't applied
        cfgutil -e $ECID -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode > /dev/null 2>&1
        # Reapply the SAM profile
        cfgutil -e $ECID -K org.der -C org.crt install-profile sam_pogo.mobileconfig > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to apply SAM profile.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; else echo 'SAM profile applied. Completed the JB respring.'; fi
    elif [[ "$TASK" = 'jb_reboot' ]]
    then
        # Check if the UIC_Jailbreaker is installed; else we quit
        ls -l ~/UIC_Jailbreaker > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to locate ~/UIC_Jailbreaker. It may not be installed.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        # Reboot the device
        idevicediagnostics -u $UUID restart
        if [ $? -gt 0 ]; then echo 'Unable to restart device. It may not be connected.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        # Check until it is online again
        echo 'Waiting until the device is online.'; sleep 20; count=0
        until idevicename -u $UUID > /dev/null 2>&1 || [ ! $count -lt 10 ]; do sleep 6; count=`expr $count + 1`; done
        # If the idevicename attempts were maxed, exit because we cannot connect
        if [ $count -gt 9 ]; then echo 'Failed to query device. It may not be connected.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        echo $D 'is online again. Removing SAM profile.'
        # Remove the SAM profile. We won't error/exit in case the profile wasn't applied
        cfgutil -e $ECID -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode > /dev/null 2>&1
        if [ $? = 0 ]; then echo 'SAM profile successfully removed.'; else echo 'Could not remove SAM profile. Probably not applied.'; fi
        # Launch the UIC Jailbreaker. We won't error/exit because of false failures when we respring
        echo 'Launching the UIC Jailbreaker. This will take 2 minutes.'; sleep 2
        # Unlock the keychain using an env var if you want to.
        #security unlock-keychain -p $DMKEY login.keychain > /dev/null
        # Check if the template exists and make it if it doesn't
        ls -l DerivedData/Template/ > /dev/null 2>&1
        if [ $? -gt 0 ]
        then
            TEXT=""
            TEXT=$(xcodebuild build-for-testing -workspace ~/UIC_Jailbreaker/UIC_Jailbreaker.xcworkspace -scheme UIC_Jailbreaker -destination generic/platform=iOS -derivedDataPath ./DerivedData/Template 2>&1)
            if [[ $TEXT == *"errSecInternalComponent"* ]]; then echo "The keystore is locked! Run 'security unlock-keychain login.keychain'"; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        fi
        rm -rf DerivedData/$UUID && cp -r DerivedData/Template/ DerivedData/$UUID
        TEXT=""
        TEXT=$(xcodebuild test-without-building -workspace ~/UIC_Jailbreaker/UIC_Jailbreaker.xcworkspace -scheme UIC_Jailbreaker -destination id=$UUID -destination-timeout 200 -derivedDataPath ./DerivedData/$UUID name=$D 2>&1)
        if [ $? -gt 0 ]; then echo 'xcodebuild failed tests but it could be a false failure. Continuing.'; else echo 'Closing the unc0ver app.'; fi
        rm -rf DerivedData/$UUID
        if [[ $TEXT == *"errSecInternalComponent"* ]]; then echo "The keystore is locked! Run 'security unlock-keychain login.keychain'"; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        # Wait for respring and check for SSH access or fail after 10 attempts
        echo 'Waiting for the respring to finish and the SSH server to come up.'; sleep 10; count=0
        until ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$IP -t "ls" > /dev/null 2>&1 || [ ! $count -lt 10 ]; do sleep 5; count=`expr $count + 1`; done
        # If the SSH attempts were maxed, that means we did not have a successful rooting check. Reroot the device
        if [ $count -gt 9 ]; then echo 'Failed to SSH to device. JB probably failed to apply.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; fi
        # Link config.json to the game directory if the game was updated. I could only get gc to work with unc0ver jb if the gc config was in the game folder. 
        echo 'Checking if config.json is in pogo root.'
        # Move it out of the GC folder and into the Home directory because duplicate config files cause read errors
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$IP -t "mv /var/mobile/Application\ Support/GoCheats/config.json ~/config.json" > /dev/null 2>&1
        # Copy it from the Home directory into the game root.
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$IP -t "cp ~/config.json /var/containers/Bundle/Application/*/PokmonGO.app/" > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to copy config.json to the game folder.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; else echo 'Successfully copied config.json to the game folder.'; fi
        # Reapply the SAM profile
        echo 'Applying SAM profile.'; sleep 2 && cfgutil -e $ECID -K org.der -C org.crt install-profile sam_pogo.mobileconfig > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to apply SAM profile.'; RETURNCODE=`expr $RETURNCODE + 1`;continue; else echo 'SAM profile applied. Completed the JB reboot.'; fi
    elif [[ "$TASK" = 'proxy_disable' ]]
    then
        adb -s $IP shell su -c 'settings put global http_proxy :0'
        adb -s $IP shell su -c 'am broadcast -a android.intent.action.PROXY_CHANGE'
    fi
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        sleep 3
        adb disconnect $IP
    fi
done
exit $RETURNCODE
