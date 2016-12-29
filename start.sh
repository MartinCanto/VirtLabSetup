#!/bin/bash
# Lab on a Stick Setup
# Joseph Martin Nov 2016
# github https://github.com/MartinCanto/VirtLabSetup.git
# ln -s Packages/ /home/$USER/Documents/

if [ -f /LabSetup/start.sh ]
then
	rm -r /LabSetup/
fi

if [ ! -f /LabSetup/start.sh ]
then
	cp -r ./LabSetup /LabSetup
	chown -R ${SUDO_USER:-$USER}: /LabSetup/
	chmod -R 7775 /LabSetup/
	chmod +x /LabSetup/start.sh
	chmod +x /LabSetup/reset.sh
fi

if [ ! -f /home/${SUDO_USER:-$USER}/Desktop/VirtEnvSetup.desktop ] || [ ! -f /home/${SUDO_USER:-$USER}/Desktop/VirtNetReset.desktop ]
then
	echo "Creating VM reset Shortcuts"
	echo -e '#!/usr/bin/env xdg-open\n[Desktop Entry]\nVersion=6.0\nName=VirtLab Network Reset V6\nComment=Reset VM Networks\nExec=gnome-terminal -e "sudo bash /LabSetup/resetnet.sh"\nTerminal=false\nType=Application\nCategories=Application;' >/home/${SUDO_USER:-$USER}/Desktop/VirtNetReset.desktop
	echo -e '#!/usr/bin/env xdg-open\n[Desktop Entry]\nVersion=6.0\nName=VirtLab Environment Reset V6\nComment=Reset VM machines \nExec=gnome-terminal -e "sudo bash /LabSetup/start.sh"\nTerminal=false\nType=Application\nCategories=Application;' >/home/${SUDO_USER:-$USER}/Desktop/VirtEnvSetup.desktop
	chown ${SUDO_USER:-$USER}: /home/${SUDO_USER:-$USER}/Desktop/VirtEnvSetup.desktop	
	chmod 774 /home/${SUDO_USER:-$USER}/Desktop/VirtEnvSetup.desktop
	chown ${SUDO_USER:-$USER}: /home/${SUDO_USER:-$USER}/Desktop/VirtNetReset.desktop	
	chmod 774 /home/${SUDO_USER:-$USER}/Desktop/VirtNetReset.desktop
else
	echo "Shortcuts already created"
fi
clear
read -p 'Use the Icon that is on your desktop to setup your new environment.'
