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

if [[ "$TASK" != "reboot" ]] && [[ "$TASK" != "reopen" ]] && [[ "$TASK" != "update" ]] && [[ "$TASK" != "pogo_version" ]]
then
	echo Unsupported task: $TASK
	exit
fi

for D in $DEVICES
do
	IP=$(nslookup $D $DNS | grep Address | tail -1 | awk '{print $2}')
	echo Connecting to $D at $IP to $TASK
	adb connect $IP
	sleep 3
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
	fi
	sleep 3
	adb disconnect $IP
done

