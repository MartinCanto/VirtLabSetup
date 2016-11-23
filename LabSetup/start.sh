#!/bin/bash
# Lab on a Stick Setup
# Joseph Martin Nov 2016

if [ ! -f /etc/yum.repos.d/127.0.0.1.repo ]
then
	mkdir -p /etc/yum.repos.d.bak/
	cp -r /etc/yum.repos.d/ /etc/yum.repos.d.bak/
	rm /etc/yum.repos.d/*
	yum-config-manager --add-repo=http://127.0.0.1:8000/Packages
	yum repolist
	yum  
	yum install -y --nogpgcheck virt-viewer.x86_64 virt-manager.noarch virt-install.noarch targetcli.noarch NetworkManager-wifi.x86_64 fence-virt.x86_64 sshpass
fi

clear
if [ ! -f /LabSetup/ISO/CentOS7.iso ]
then	
	echo 'Createing base image'
	if [ ! -f /LabSetup/ISO/CentOS7.iso ]
	then 
		read -p 'please put the CD in the CDROM' 
		dd if=/dev/sr0 of=/LabSetup/images/CentOS7.iso		 
	else 
		echo -e 'Image already local.'
	fi

fi
sleep 5
if [ ! -f /LabSetup/images/workstation.img ]
then
	virsh net-create /LabSetup/virtnet/public.xml 
	virsh net-create /LabSetup/virtnet/private.xml 
	virsh net-create /LabSetup/virtnet/storage.xml
	virt-manager &
	sleep 10 
	virt-install --name nodea --initrd-inject=/LabSetup/ks/nodea/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodea.img,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	sleep 10
	virt-install --name nodeb --initrd-inject=/LabSetup/ks/nodeb/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodeb.img,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	sleep 10
	virt-install --name nodec --initrd-inject=/LabSetup/ks/nodec/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodec.img,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	sleep 10
	virt-install --name workstation --initrd-inject=/LabSetup/ks/workstation/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/workstation.img,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	clear
	read -t 1200 -p "Please wait for all Machines to be finished, Then press ENTER to create default snapshots. If you do not wait then it may take longer to reload the lab. Once ready press ENTER to continue"
	echo " ";
	echo "Creating Snapshots"
	virsh snapshot-create-as nodea restore
	virsh snapshot-create-as nodeb restore
	virsh snapshot-create-as nodec restore
	virsh snapshot-create-as workstation restore
	cp /LabSetup/virtnet/hosts /etc/hosts
fi

yum -q list installed fence-virtd &>/dev/null && echo "Fencing Agent already installed skipping install" || yum install fence-virt fence-virtd fence-virtd-libvirt fence-virtd-multicast -y --nogpgcheck ;

if [ ! -f /etc/cluster/fence_xvm.key ]
then
	echo 'Installing fencing agent'	
	mkdir -p /etc/cluster 
	dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=1k count=4
	# fence_virtd -c
	cp /LabSetup/FV/fence_virt.conf /etc/fence_virt.conf
	systemctl enable fence_virtd.service 
	systemctl start fence_virtd.service 
else
	echo "Fencing Agent Already Configured"
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

clear

if [ -f /etc/yum.repos.d/127.0.0.1_8000_Packages.repo ]
then
	cp /etc/yum.repos.d.bak/yum.repos.d/* /etc/yum.repos.d/
	rm /etc/yum.repos.d/127.0.0.1_8000_Packages.repo
	yum repolist
fi

if [ ! -f /srv/iscsi/backingstore ]
then
	systemctl enable target
	systemctl start target 
	firewall-cmd --permanent --add-port=3260/tcp
	firewall-cmd --reload 
	mkdir -p /srv/iscsi 
	dd if=/dev/zero of=/srv/iscsi/backingstore bs=1 count=0 seek=4G 
	targetcli /backstores/fileio create clusterstor /srv/iscsi/backingstore 
	targetcli /iscsi create iqn.2015-06.com.example:cluster 
	targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodea 
	targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodeb 
	targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:nodec 
	targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:noded 
	targetcli iscsi/iqn.2015-06.com.example:cluster/tpg1/luns/ create /backstores/fileio/clusterstor
fi

clear
echo -e '\nCompleted setup, you should have a icon on your desktop now that you can use to reset the environment.\nPlease run this icon before attempting to work with virtual machines'
echo -e 'Instead of using the RedHat fencing agent, you will use fenc_virt, to test if nodes are connected type:\n"fence_xvm -o list"\n'
echo -e "\nWhen adding fencing agent use:\npcs stonith create Fencing fence_xvm ip_family=ipv4\nTest fencing by typing:\nfence_virt nodea'"