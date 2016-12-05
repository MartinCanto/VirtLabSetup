#!/bin/bash
# Joseph Martin Nov 2016

clear
cd /LabSetup/
memsize=$((`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`/7))
httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
onlinemode=$(wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null && echo 0 || echo 1)
scriptreset=0
snapshot=0
verification=0
erm=""

if [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Starting HTTP Server'
	nohup python -m SimpleHTTPServer &>/dev/null &
	httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
	sleep 3 
	echo 'Online Mode Active and HTTP server not running'
	if [[ ! -f /LabSetup/Packages/repodata/repomd.xml ]]
	then	
		mkdir /LabSetup/Packages		
		repotrack -p /LabSetup/Packages/ bash-completion libvirt fence-agents-all fence-virtd-multicast fence-virtd fence-virtd-libvirt fence-virtd-serial virt-viewer virt-manager virt-install targetcli NetworkManager-wifi fence-virt sshpass pcs iscsi-initiator-utils device-mapper-multipath lvm2-cluster gf2-utils
		sleep 3 
		createrepo /LabSetup/Packages/
		sleep 3 
	fi
	if [ -f /etc/yum.repos.d/LabSetup.repo ]
	then
		rm -R /etc/yum.repos.d/LabSetup.repo
		cp -R /etc/yum.repos.d.bak/* /etc/yum.repos.d/
		yum repolist
	fi
elif [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Online Mode Active and HTTP server is already running'
	if [[ ! -f /LabSetup/Packages/repodata/repomd.xml ]]
	then	
		mkdir /LabSetup/Packages
		repotrack -p /LabSetup/Packages/ bash-completion libvirt fence-agents-all fence-virtd-multicast fence-virtd fence-virtd-libvirt fence-virtd-serial virt-viewer virt-manager virt-install targetcli NetworkManager-wifi fence-virt sshpass pcs iscsi-initiator-utils device-mapper-multipath lvm2-cluster gf2-utils
		sleep 3 
		createrepo /LabSetup/Packages/
		sleep 3 
	fi
	if [ -f /etc/yum.repos.d/LabSetup.repo ]
	then
		rm -R /etc/yum.repos.d/LabSetup.repo
		cp -R /etc/yum.repos.d.bak/* /etc/yum.repos.d/ 
		yum repolist
	fi
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Offline Mode Active and HTTP server not running'
	echo 'Starting HTTP Server'
	nohup python -m SimpleHTTPServer &>/dev/null &
	httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
	sleep 3 
	if [ ! -f /etc/yum.repos.d/LabSetup.repo ] 
	then
		mkdir /etc/yum.repos.d.bak/
		cp -R /etc/yum.repos.d/* /etc/yum.repos.d.bak/
		rm -R /etc/yum.repos.d/*
		echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://127.0.0.1:8000/Packages\nenabled=1\ngpgcheck=0' >/etc/yum.repos.d/LabSetup.repo
	fi
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Offline Mode Active and HTTP server is already running'
	if [ ! -f /etc/yum.repos.d/LabSetup.repo ] 
	then
		mkdir /etc/yum.repos.d.bak/
		cp -R /etc/yum.repos.d/* /etc/yum.repos.d.bak/
		rm -R /etc/yum.repos.d/*
		echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://127.0.0.1:8000/Packages\nenabled=1\ngpgcheck=0' >/etc/yum.repos.d/LabSetup.repo
	fi
fi
	 	
for i in {fence-agents-all,fence-virtd-multicast,fence-virtd,fence-virtd-libvirt,fence-virtd-serial,virt-viewer,virt-manager,virt-install,targetcli,NetworkManager-wifi,fence-virt,sshpass} 
do 
	if ! rpm -qa | grep -qw $i
	then 
		yum install -y --nogpgcheck $i  
	fi 
done
echo 'Done with prelim checks'
echo -------------------------------------------------------
echo 'Starting Setup'
echo -------------------------------------------------------
echo 'Verifying if ISO is already created'
if [ ! -f /LabSetup/ISO/CentOS7.iso ]
then	
	echo 'Createing base image'
	if [ ! -f /LabSetup/ISO/CentOS7.iso ]
	then 
		read -p 'please put the CD in the CDROM' 
		dd if=/dev/sr0 of=/LabSetup/images/CentOS7.iso		 
	else 
		echo -e '\nImage already local.\n'
	fi

fi
echo -------------------------------------------------------
echo 'Setting file permissions'
chown -R ${SUDO_USER:-$USER}: /var/lib/libvirt/
chown -R ${SUDO_USER:-$USER}: /LabSetup/
chmod g+s /LabSetup/images/
echo -------------------------------------------------------
echo 'Verifying installed domains'
if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep 'nodea' > /dev/null && virtstatus=0 || virtstatus=1
fi

if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep 'nodeb' > /dev/null && virtstatus=0 || virtstatus=1
fi

if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep 'nodec' > /dev/null && virtstatus=0 || virtstatus=1
fi

if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep 'noded' > /dev/null && virtstatus=0 || virtstatus=1
fi

if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep 'workstation' > /dev/null && virtstatus=0 || virtstatus=1
fi
echo -------------------------------------------------------
for i in {PRIVATE,PUBLIC,STORAGE1,STORAGE2} 
do
	virsh net-list | grep $i > /dev/null && echo 'network '$i' found' || virsh net-create /LabSetup/virtnet/$i.xml
	sleep 10 
done
echo -------------------------------------------------------
echo 'Checking Virtual Machine status and starting VMs if needed'
if [[ $virtstatus -eq 0 ]]
then
	for i in {nodea,nodeb,nodec,noded,workstation} 
	do
		virsh list --all | grep $i | grep running > /dev/null && echo 'Domain '$i' is currently running' || virsh start $i 2>/dev/null &
		sleep 5
	done
fi
echo -------------------------------------------------------
if [[ $virtstatus -eq 1 ]]
then
	scriptreset=1
	echo 'Setting Hypervisor Firewall'
	firewall-cmd --permanent --add-port=3260/tcp
	firewall-cmd --permanent --add-port=8000/tcp
	firewall-cmd --permanent --add-port=1229/udp
	firewall-cmd --permanent --add-port=1229/tcp
	firewall-cmd --reload
	sleep 30 
	read -t 60 -p 'VMs are about to be created. Please restart script by clicking the desktop icon AFTER machines have finished and rebooted. Press ENTER to start the VM creation'
	virt-manager &  
	for i in {nodea,nodeb,nodec,noded,workstation} 
	do
		virsh list | grep $i > /dev/null && echo 'node '$i' found' || virt-install --name $i --initrd-inject=/LabSetup/ks/$i/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=$(($memsize/1024)) --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/$i.qcow2,size=15 -w network=PRIVATE -w network=PUBLIC -w network=STORAGE1 -w network=STORAGE2 -w network=default --os-type=linux 2> /dev/null &
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
echo 'Starting Virt-Manager'
virt-manager &
echo -------------------------------------------------------
echo 'Checking for snapshot status'
if [[ $snapshot -eq 0 ]]
then
	virsh snapshot-list nodea | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
if [[ $snapshot -eq 0 ]]
then
	virsh snapshot-list nodeb | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
if [[ $snapshot -eq 0 ]]
then
	virsh snapshot-list nodec | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
if [[ $snapshot -eq 0 ]]
then
	virsh snapshot-list noded | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
if [[ $snapshot -eq 0 ]]
then
	virsh snapshot-list workstation | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
echo -------------------------------------------------------
echo "Verifying Fencing Agent"
if [[ $snapshot -eq 1 ]] 
then
	echo -------------------------------------------------------
	echo 'Installing fencing agent'	
	mkdir -p /etc/cluster
	cp /LabSetup/FV/fence_xvm.key /etc/cluster/fence_xvm.key
	chown -R student: /etc/cluster/
	sleep 3 
	if [[ $? -ne 0 ]]
	then
		erm=$erm"\nError Installing Fencing Agent"
		verification=1
	fi
fi
echo -------------------------------------------------------
echo 'Verifying fenceing key is created'
echo 'Creating /etc/cluster on nodes if needed'
if [[ $snapshot -eq 1 ]] 
then
	for i in {nodea,nodeb,nodec,noded,workstation}
	do 
		sshpass -p redhat ssh -q nodea.public [[ ! -f /etc/cluster/fence_xvm.key ]] && echo 'fence_xvm.key folder exists on '$i || sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public 'mkdir /etc/cluster/'
		echo -------------------------------------------------------	
		echo "Copying Cluster Key if needed"
		sshpass -p redhat ssh -q nodea.public [[! -f /etc/cluster/fence_xvm.key ]] && echo 'fence_xvm.key file exists on '$i || sshpass -p "redhat" scp -oStrictHostKeyChecking=no /LabSetup/FV/fence_xvm.key root@$i.public:/etc/cluster/fence_xvm.key
		sleep 3 
		if [[ $? -ne 0 ]]
		then
			erm=$erm"\nError Copying Cluster Key $i"
			verification=1
		fi
		echo -------------------------------------------------------
		echo 'Setting firewall on nodes'
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public 'firewall-cmd --zone=public --add-port=1229/tcp --permanent ; firewall-cmd --reload'
		sleep 3 
		if [[ $? -ne 0 ]]
		then
			erm=$erm"\nError Setting Firewall on $i"
			verification=1
		fi
	done
	echo -------------------------------------------------------
	sleep 3
	echo 'Enabling fence_virtd.service' 
	systemctl enable fence_virtd.service
	sleep 3 
	if [[ $? -ne 0 ]]
	then
		erm=$erm"\nError Enabling fence_virtd.service $i"
		verification=1
	fi
	echo -------------------------------------------------------
	sleep 3
	echo 'Copying fence_virt.conf to hosts'
	cp /LabSetup/FV/fence_virt.conf /etc/fence_virt.conf
	sleep 3 
	if [[ $? -ne 0 ]]
	then
		erm=$erm"\nError Copying fence_virt.conf to $i"
		verification=1
	fi
	echo -------------------------------------------------------
	sleep 3
	echo 'Starting fence_virtd.service'
 	systemctl start fence_virtd.service
	sleep 3 
	if [[ $? -ne 0 ]]
	then
		erm=$erm"\nError Starting fence_virtd.service $i"
		verification=1
	fi
fi
echo -------------------------------------------------------
echo 'Generating Hosts File'
if [[ $snapshot -eq 1 ]]
then
	echo 'Setting Hosts File'
	grep nodea /etc/hosts >/dev/null && echo 'Hosts file verified for nodea' || echo -e '192.168.0.10 nodea.private.example.com\n172.25.2.10 nodea.public nodea\n192.168.1.10 nodea.storage1.example.com\n192.168.2.10 nodea.storage2.example.com'>>/etc/hosts
	grep nodeb /etc/hosts >/dev/null && echo 'Hosts file verified for nodeb' || echo -e '192.168.0.11 nodeb.private.example.com\n172.25.2.11 nodeb.public nodeb\n192.168.1.11 nodeb.storage1.example.com\n192.168.2.11 nodeb.storage2.example.com'>>/etc/hosts
	grep nodec /etc/hosts >/dev/null && echo 'Hosts file verified for nodec' || echo -e '192.168.0.12 nodec.private.example.com\n172.25.2.12 nodec.public nodec\n192.168.1.12 nodec.storage1.example.com\n192.168.2.12 nodec.storage2.example.com' >>/etc/hosts
	grep noded /etc/hosts >/dev/null && echo 'Hosts file verified for noded' || echo -e '192.168.0.13 noded.private.example.com\n172.25.2.13 noded.public noded\n192.168.1.13 noded.storage1.example.com\n192.168.2.13 noded.storage2.example.com' >>/etc/hosts
	grep workstation /etc/hosts >/dev/null && echo 'Hosts file verified for workstation' || echo -e '192.168.0.9 workstation.private.example.com\n172.25.2.9 workstation.public workstation\n192.168.1.9 workstation.storage1.example.com\n192.168.2.9 workstation.storage2.example.com' >>/etc/hosts
	grep hypervisor /etc/hosts >/dev/null && echo 'Hosts file verified for hypervisor' || echo -e '192.168.0.1 hypervisor.public.com\n172.25.1.1 hypervisor.private.com classroom.example.com\n192.168.1.1 hypervisor.storage1.example.com\n192.168.2.1 hypervisor.storage2.example.com'>>/etc/hosts
	sleep 5
fi
echo -------------------------------------------------------
echo 'Checking for ISCSI'
if [[ $snapshot -eq 1 ]]
then
	echo " ">/root/.ssh/known_hosts
	echo " ">/$SUDO_USER/.ssh/known_hosts
	echo 'Copying Hosts File'
	for i in {nodea,nodeb,nodec,noded,workstation}
	do 
		sshpass -p redhat scp -oStrictHostKeyChecking=no /etc/hosts root@$i.public:/etc/hosts
	sleep 3 
		if [[ $? -ne 0 ]]
		then
			erm=$erm"\nError Copying Hosts file $i"
			verification=1
		fi
		sleep 3
	done
fi
echo -------------------------------------------------------
echo "YUM Repo setup"
if [[ $snapshot -eq 1 ]]
	then
		for i in {nodea,nodeb,nodec,noded,workstation}
	 	do 
			sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public "mkdir -p /etc/yum.repos.d.bak/;cp -r /etc/yum.repos.d/ /etc/yum.repos.d.bak/;rm /etc/yum.repos.d/*;echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://192.168.0.1:8000/Packages\nenabled=1\ngpgcheck=0'>/etc/yum.repos.d/LabSetup.repo"
			sleep 3   
			if [[ $? -ne 0 ]]
			then
				erm=$erm"\nError YUM Repo setup $i"
				verification=1
			fi
		done
		for i in {nodea,nodeb,nodec,noded,workstation}
		do
			echo -------------------------------------------------------
			echo 'Creating LabSetup repo on guests'
			sshpass -p redhat ssh -q root@$i.public [[ -f /etc/yum.repos.d/LabSetup.repo ]] && echo 'REPO file exists on '$i || sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public "echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://192.168.0.1:8000/Packages\nenabled=1\ngpgcheck=0' >/etc/yum.repos.d/LabSetup.repo"
			sleep 3 
		done
		for i in {nodea,nodeb,nodec,noded,workstation} 
		do 
			echo -------------------------------------------------------		
			echo 'Updating yum repolist'
			sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public 'yum repolist'
			if [[ $? -ne 0 ]]
			then
				erm=$erm"\nError updating yum $i"
				verification=1
			fi
		done
		echo -------------------------------------------------------	
		echo 'Setting up ISCSI on workstation.public'
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@workstation.public 'yum install -y targetcli ; systemctl enable target ; systemctl start target ; firewall-cmd --permanent --add-port=3260/tcp ; firewall-cmd --reload ; mkdir -p /srv/iscsi ; dd if=/dev/zero of=/srv/iscsi/backingstore bs=1 count=0 seek=4G ; targetcli /backstores/fileio create clusterstor /srv/iscsi/backingstore ; targetcli /iscsi create iqn.2015-06.com.example:cluster ; targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodea ; targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodeb ; targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodec ; targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:noded ; targetcli iscsi/iqn.2015-06.com.example:cluster/tpg1/luns/ create /backstores/fileio/clusterstor' 
			if [[ $? -ne 0 ]]
			then
				erm=$erm"\nError in Script $i setting up ISCSI"
#				verification=1
			fi 
		sleep 3
elif [[ $httpstatus -eq 1 ]]
then
	echo -------------------------------------------------------
	read -p 'Error with HTTP Server, please restart script'
	exit 1
fi
echo -------------------------------------------------------
echo 'Checking if default snapshot created, if not then creating'
if [[ $snapshot -eq 1 ]] && [[ $verification -eq 0 ]]
then
	for i in {nodea,nodeb,nodec,noded,workstation}
	do
		virsh snapshot-create-as $i --name restore --description 'default snapshot created by VirtLab'
	done
fi

if [[ $snapshot -eq 0 ]]
then
	echo -------------------------------------------------------
	echo 'Resetting Nodes'
	for i in {nodea,nodeb,nodec,noded,workstation} 
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
	echo -e '\nInstead of using the RedHat fencing agent, you will use fenc_virt, to test if nodes are connected type:\n"fence_xvm -o list"\n'
	echo -e "\nWhen adding fencing agent use:\n'pcs stonith create Fencing fence_xvm ip_family=ipv4'\nTest fencing by typing:\n'fence_xvm -H nodea'"
	read -p 'press ENTER to continue'
else
	echo -e 'Error\nError\nError'
	echo -e '\n'$erm'\n'
	read -p 'Error in script, please close and restart machine then try running again.'
fi
