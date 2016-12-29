#!/bin/bash
# Joseph Martin Dec 2016
#
# repos still need to be setup dynamically
clear
cd /LabSetup/

# variable declarations
# if any required packages then add to them to the reqpackages variable
reqpackages='virt-viewer virt-manager virt-install bash-completion libvirt NetworkManager-wifi sshpass'
erm=
httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
nodes=$(ls -C /LabSetup/ks)
memsize=$((`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`/$(echo $nodes | wc -w)))
onlinemode=$(wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null && echo 0 || echo 1)
scriptreset=0
snapshot=0
verification=0
virtnet=""
virtnets=$(ls -C /LabSetup/virtnet)
virtrepos=$(ls -C /LabSetup/Packages)
# end variable declarations

echo -------------------------------------------------------
echo 'Verifying current state of machine and HTTP server'
if [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Starting HTTP Server'
	nohup python -m SimpleHTTPServer &>/dev/null &
	httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
	sleep 3 
	echo 'Online Mode Active and HTTP server not running'
	for i in $virtrepos
	do
		if [ ! -f /etc/yum.repos.d/$i.repo ]
		then
			rm -R /etc/yum.repos.d/$i.repo
			cp -R /etc/yum.repos.d.bak/* /etc/yum.repos.d/
			yum repolist
		fi
	done
elif [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Online Mode Active and HTTP server is already running'
	for i in $virtrepos
	do
		if [ ! -f /etc/yum.repos.d/$i.repo ]
		then
			rm -R /etc/yum.repos.d/$i.repo
			cp -R /etc/yum.repos.d.bak/* /etc/yum.repos.d/
			yum repolist
		fi
	done
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Offline Mode Active and HTTP server not running'
	echo 'Starting HTTP Server'
	nohup python -m SimpleHTTPServer &>/dev/null &
	httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
	sleep 3
	for i in $virtrepos
	do 
		if [ ! -f /etc/yum.repos.d/$i.repo ]
		then
			if [ ! -f /etc/yum.repos.d.bak/$i.repo ]
			then
				mkdir /etc/yum.repos.d.bak/
				cp -R /etc/yum.repos.d/* /etc/yum.repos.d.bak/
				rm -R /etc/yum.repos.d/*
			fi
		for i in $virtrepos ; do createrepo /LabSetup/Packages/$i/Packages ; echo -e '['$i']\nname='$i'\nbaseurl=http://127.0.0.1:8000/Packages/'$i'/Packages\nenabled=1\ngpgcheck=0'>/etc/yum.repos.d/$i.repo ; done
		fi	
	done
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Offline Mode Active and HTTP server is already running'
	for i in $virtrepos
	do
		if [ ! -f /etc/yum.repos.d/$i.repo ]
		then
			if [ ! -f /etc/yum.repos.d.bak/$i.repo ]
			then
				mkdir /etc/yum.repos.d.bak/
				cp -R /etc/yum.repos.d/* /etc/yum.repos.d.bak/
				rm -R /etc/yum.repos.d/*
			fi
			for i in $virtrepos ; do createrepo /LabSetup/Packages/$i/Packages ;  echo -e '['$i']\nname='$i'\nbaseurl=http://127.0.0.1:8000/Packages/'$i'/Packages\nenabled=1\ngpgcheck=0'>/etc/yum.repos.d/$i.repo ; done
		fi	
	done
fi
echo -------------------------------------------------------
echo 'Installing required packages'
for i in $reqpackages 
do 
	if ! rpm -qa | grep -qw $i
	then 
		yum install -y --nogpgcheck $i  
	fi 
done
	 	
echo -------------------------------------------------------
echo 'Creating networks if needed'
for i in ${virtnets//.xml}
do
	virsh net-list | grep $i > /dev/null && echo 'network '$i' found' || virsh net-create /LabSetup/virtnet/$i.xml
	sleep 10 
done

echo -------------------------------------------------------
echo 'Verifying installed domains'

for i in $nodes
do
	if [[ $virtstatus -eq 0 ]]
	then 
		virsh list --all | grep $i > /dev/null && virtstatus=0 || virtstatus=1
	fi
done
echo 'virtstatus='$virtstatus
echo -------------------------------------------------------
echo 'Checking Virtual Machine status and starting VMs if needed'
if [[ $virtstatus -eq 0 ]]
then
	for i in $nodes 
	do
		virsh list --all | grep $i | grep running > /dev/null && echo 'Domain '$i' is currently running' || virsh start $i 2>/dev/null &
		sleep 5
	done
fi

echo -------------------------------------------------------
echo 'Generating hosts file dynamically'
if [ ! -f /LabSetup/hosts ]
then
	for vnodes in $(ls -C /LabSetup/ks) ; do for vips in $( cat /LabSetup/ks/$vnodes/ks.cfg | grep '\-\-ip=' | awk '{print $5}') ; do echo $(for nets in ${vips//--ip=} ; do echo ${vips//--ip=} $vnodes"."$(for net in $(ls -C /LabSetup/virtnet) ; do grep $(echo $nets | cut -d "." -f1-3) /LabSetup/virtnet/$net > /dev/null && echo ${net//.xml}' '$vnodes ; done) ; done) ; done ; done > /LabSetup/hosts
	cat /LabSetup/hosts >> /etc/hosts
fi

echo -------------------------------------------------------
if [[ $virtstatus -eq 1 ]]
then
	scriptreset=1 
	for i in ${virtnets//.xml} ; do virtnet=$virtnet" -w network="$i ; done
	read -t 60 -p 'VMs are about to be created. Please restart script by clicking the desktop icon AFTER machines have finished and rebooted. Press ENTER to start the VM creation'
	virt-manager &  
	for i in $nodes 
	do
		virsh list | grep $i > /dev/null && echo 'node '$i' found' || virt-install --name $i --initrd-inject=/LabSetup/ks/$i/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=$(($memsize/1024)) --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/$i.qcow2,size=15$virtnet --os-type=linux 2> /dev/null &
	sleep 10
	done
	sleep 60
fi
echo -------------------------------------------------------

if [[ $scriptreset -eq 1 ]]
then	
	exit 0
fi
echo -------------------------------------------------------
echo -------------------------------------------------------
echo 'Done with prelim checks'
echo -------------------------------------------------------
echo 'Starting Setup'
echo -------------------------------------------------------
echo -------------------------------------------------------
echo 'Setting file permissions'
chown -R ${SUDO_USER:-$USER}: /var/lib/libvirt/
chown -R ${SUDO_USER:-$USER}: /LabSetup/
chmod g+s /LabSetup/images/


echo 'Starting Virt-Manager'
virt-manager &
echo -------------------------------------------------------
echo 'Checking for snapshot status'
if [[ $snapshot -eq 0 ]]
then
	for i in $nodes
	do
		if [[ $snapshot -eq 0 ]]
		then
		virsh snapshot-list $i | grep restore >/dev/null && snapshot=0 || snapshot=1
		fi
	done
fi
echo -------------------------------------------------------
if [[ $snapshot -eq 1 ]]
then
	echo -------------------------------------------------------
	echo "YUM Repo setup"
	for i in $nodes
 	do 
		for repos in $virtrepos ; 
		do 
			sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i "mkdir -p /etc/yum.repos.d.bak/ ; cp -r /etc/yum.repos.d/ /etc/yum.repos.d.bak/ ; rm /etc/yum.repos.d/* ; echo -e '[$virtrepos]\nname=LabSetupRepo\nbaseurl=http://192.168.0.1:8000/Packages\'$virtrepos'\nenabled=1\ngpgcheck=0'>/etc/yum.repos.d/LabSetup.repo"
		sleep 3
		if [[ $? -ne 0 ]]
		then
			erm=$erm"\nError YUM Repo setup $i"
			verification=1
		fi
		done
	done
	echo -------------------------------------------------------
	echo "Generating Hosts File"
	for i in $nodes
	do
		cat '/LabSetup/hosts' | sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i "cat >> /etc/hosts"
	done
	for i in $nodes
	do 
		echo -------------------------------------------------------		
		echo 'Updating yum repolist'
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'yum repolist'
		if [[ $? -ne 0 ]]
		then
			erm=$erm"\nError updating yum $i"
			verification=1
		fi
	done
fi

if [[ $httpstatus -eq 1 ]]
then
	echo -------------------------------------------------------
	read -p 'Error with HTTP Server, please restart script'
	exit 1
fi
echo -------------------------------------------------------
echo 'Checking if default snapshot created, if not then creating'
if [[ $snapshot -eq 1 ]] && [[ $verification -eq 0 ]]
then
	for i in $nodes
	do
		virsh snapshot-create-as $i --name restore --description 'default snapshot created by VirtLab'
	done
fi

if [[ $snapshot -eq 0 ]]
then
	echo -------------------------------------------------------
	echo 'Resetting Nodes'
	for i in $nodes 
	do
		virsh snapshot-revert $i restore ; sleep 5
			if [[ $? -ne 0 ]]
			then
				erm=$erm"\nError Restoring Node $i"
				verification=1
			fi
	done
fi
echo -------------------------------------------------------
echo -e '\n\n'
echo -------------------------------------------------------
if [[ $verification -eq 0 ]]	
then
	echo ******************************************************
	echo -e 'Setup is now completed!'	

	read -p 'press ENTER to continue'
fi
if [[ $verification -eq 1 ]]	
then
	echo -e 'Error\nError\nError'
	echo -e '\n'$erm'\n'
	read -p 'Error in script, please close and restart machine then try running again.'
fi
