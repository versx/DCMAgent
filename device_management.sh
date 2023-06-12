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
   [[ "$TASK" != "jb_respring" ]]
then
	echo Unsupported task: $TASK
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
            echo "IP could not be found"
            exit 1
        fi
    fi
    echo Connecting to $D at $IP to $TASK
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        adb connect $IP
        if [ $? -gt 0 ]; then echo "ADB connect command failed; exiting" ; exit 1; fi
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
        if [ $? -gt 0 ]; then echo 'Unable to SSH to device. Probably blocked by kernbypass'; exit 1; fi
    fi
    # Skip this if it is an iPhone command
    if [[ "$TASK" != "jb_"* ]]
    then
        sleep 3
        adb disconnect $IP
    fi
done
