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
   [[ "$TASK" != "reopen" ]] && \
   [[ "$TASK" != "update" ]] && \
   [[ "$TASK" != "pogo_version" ]] && \
   [[ "$TASK" != "tail_logs" ]] && \
   [[ "$TASK" != "cron" ]] && \
   [[ "$TASK" != "follow_atlas" ]] && \
   [[ "$TASK" != "clear_logs" ]] && \
   [[ "$TASK" != "jb_respring" ]] && \
   [[ "$TASK" != "jb_reboot" ]]
then
	echo Unsupported task: $TASK.
	exit 1
fi

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
            echo "IP could not be found."
            exit 1
        fi
    fi
    echo Connecting to $D at $IP to $TASK.
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        adb connect $IP
        if [ $? -gt 0 ]; then echo "ADB connect command failed; exiting." ; exit 1; fi
        sleep 3
    fi
    
	if [[ "$TASK" = 'reopen' ]]
	then
		adb -s $IP shell su -c 'am force-stop com.nianticlabs.pokemongo && am force-stop com.pokemod.atlas && am startservice com.pokemod.atlas/com.pokemod.atlas.services.MappingService'
	elif [[ "$TASK" = 'reboot' ]]
	then
		adb -s $IP shell su -c 'reboot'
	elif [[ "$TASK" = 'update' ]]
	then
		adb -s $IP shell su -c "./system/bin/atlas.sh -ua"
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
	elif [[ "$TASK" = 'jb_respring' ]]
	then
        # This requires the target device to have your public SSH key in the authorized_keys file
        ssh root@$IP -t "killall kernbypass; if [ $? -gt 0 ]; then echo 'kernbypass not found'; else echo 'kernbypass killed'; fi; sleep 10; sbreload; if [ $? -gt 0 ]; then echo 'failed to reload springboard';else echo 'springboard reloaded'; fi"
        if [ $? -gt 0 ]; then echo 'Unable to SSH to device. Probably blocked by kernbypass.'; exit 1; fi
	elif [[ "$TASK" = 'jb_reboot' ]]
	then
        # Get the UUID/ECID from json
        DATA=$(cat devices.json | grep -e $D | tail -1)
        UUID=$(echo $DATA | cut -d \" -f 8)
        ECID=$(echo $DATA | cut -d \" -f 12)
        # Check if the UIC_Jailbreaker is installed; else we quit
        ls -l ~/UIC_Jailbreaker > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to locate ~/UIC_Jailbreaker. It may not be connected.'; exit 1; fi
        # Reboot the device
        idevicediagnostics -u $UUID restart
        if [ $? -gt 0 ]; then echo 'Unable to restart device. It may not be connected.'; exit 1; fi
        # Check until it is online again
        echo 'Waiting until the device is online.'; sleep 20
        until idevicename -u $UUID > /dev/null 2>&1; do sleep 5; done
        echo $D 'is online again. Removing SAM profile.'
        # Remove the SAM profile. We won't error/exit in case the profile wasn't applied
        cfgutil -e $ECID -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode > /dev/null 2>&1
        if [ $? = 0 ]; then echo 'SAM profile successfully removed.'; else 'Could not remove SAM profile. Probably not applied.'; fi
        # Launch the UIC Jailbreaker. We won't error/exit because of false failures when we respring
        echo 'Launching the UIC Jailbreaker. This will take 2 minutes.'; sleep 2
        # Check if the template exists and make it if it doesn't
        ls -l DerivedData/Template/ > /dev/null 2>&1
        if [ $? -gt 0 ]; then xcodebuild build-for-testing -workspace ~/UIC_Jailbreaker/UIC_Jailbreaker.xcworkspace -scheme UIC_Jailbreaker -destination generic/platform=iOS -derivedDataPath ./DerivedData/Template > /dev/null 2>&1; fi
        rm -rf DerivedData/$UUID && cp -r DerivedData/Template/ DerivedData/$UUID
        xcodebuild test-without-building -workspace ~/UIC_Jailbreaker/UIC_Jailbreaker.xcworkspace -scheme UIC_Jailbreaker -destination id=$UUID -destination-timeout 200 -derivedDataPath ./DerivedData/$UUID name=$D > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'xcodebuild failed tests but it could be a false failure. Continuing.'; else echo 'Closing the unc0ver app.'; fi
        rm -rf DerivedData/$UUID
        # Wait for respring and check for SSH access or fail after 10 attempts
        echo 'Waiting for the respring to finish and the SSH server to come up.'; sleep 10; count=0
        until ssh -o ConnectTimeout=5 root@$IP -t "ls" > /dev/null 2>&1 || [ ! $count -lt 10 ]; do sleep 5; count=`expr $count + 1`; done
        # If the SSH attempts were maxed, that means we did not have a successful rooting check. Reroot the device
        if [ $count -gt 9 ]; then echo 'Failed to SSH to device. JB probably failed to apply.'; exit 1; fi
        # Link config.json to the game directory if the game was updated. I could only get gc to work with unc0ver jb if the gc config was in the game folder. 
        echo 'Checking if config.json is in pogo root.'
        # Move it out of the GC folder and into the Home directory because duplicate config files cause read errors
        ssh root@$IP -t "mv /var/mobile/Application\ Support/GoCheats/config.json ~/config.json" > /dev/null 2>&1
        # Copy it from the Home directory into the game root.
        ssh root@$IP -t "cp ~/config.json /var/containers/Bundle/Application/*/PokmonGO.app/" > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to copy config.json to the game folder.'; exit 1; else echo 'Successfully copied config.json to the game folder.'; fi
        # Reapply the SAM profile
        echo 'Applying SAM profile.'; sleep 2 && cfgutil -e $ECID -K org.der -C org.crt install-profile sam_pogo.mobileconfig > /dev/null 2>&1
        if [ $? -gt 0 ]; then echo 'Unable to apply SAM profile.'; exit 1; else echo 'SAM profile applied. Completed the JB reboot.'; fi
    fi
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        sleep 3
        adb disconnect $IP
    fi
done
