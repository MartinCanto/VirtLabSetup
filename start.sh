#!/bin/bash
# Lab on a Stick Setup
# Joseph Martin Nov 2016
# ln -s Packages/ /home/$USER/Documents/

if [ ! -f /LabSetup/start.bs ]
then
	cp -r ./LabSetup /LabSetup
	chown -R $SUDO_USER: /LabSetup/
	chmod -R 7775 /LabSetup/
	chmod +x /LabSetup/start.sh
fi

if [ ! -f /home/$SUDO_USER/Desktop/VIRTMGR.desktop ]
then
	echo "Creating VM reset Shortcut"	
	cp /LabSetup/VIRTMGR.desktop /home/$SUDO_USER/Desktop/VIRTMGR.desktop
	chown $SUDO_USER: /home/$SUDO_USER/Desktop/VIRTMGR.desktop	
	chmod 774 /home/$SUDO_USER/Desktop/VIRTMGR.desktop
else
	echo "Shortcut already created"
fi

echo -p 'Use the Icon that is on your desktop to setup your new environment.'
