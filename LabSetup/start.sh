#!/bin/bash
# Lab on a Stick Setup
# Joseph Martin Nov 2016
rp= sudo virsh snapshot-list nodea | grep restore | awk '{print $1}'
cd /LabSetup/

if ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null
then
	echo 'HTTP service running, script will continue.'
else
	echo -e 'HTTPS service not running\nRestarting HTTP for repos\n'
	nohup python -m SimpleHTTPServer &>/dev/null &
fi

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
if [ ! -f /LabSetup/images/nodec.qcow2 ]
then
	echo 'Setting file permissions'
	chown -R $SUDO_USER: /var/lib/libvirt/
	chown -R $SUDO_USER: /LabSetup/
	chmod g+s /LabSetup/images/
	chown $SUDO_USER: /var/lib/libvirt
	
	echo 'Installing Virtual Networking'
	virsh net-create /LabSetup/virtnet/public.xml 
	virsh net-create /LabSetup/virtnet/private.xml 
	virsh net-create /LabSetup/virtnet/storage.xml
	virt-manager &
	virt-install --name nodea --initrd-inject=/LabSetup/ks/nodea/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodea.qcow2,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	virt-install --name nodeb --initrd-inject=/LabSetup/ks/nodeb/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodeb.qcow2,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	virt-install --name nodec --initrd-inject=/LabSetup/ks/nodec/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/nodec.qcow2,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	virt-install --name workstation --initrd-inject=/LabSetup/ks/workstation/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=768 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/workstation.qcow2,size=8 -w network=private -w network=public -w network=storage --os-type=linux 2> /dev/null &
	clear
	read -t 1200 -p "Please wait for all Machines to be finished, Then press ENTER to create default snapshots. If you do not wait then it may take longer to reload the lab. Once ready press ENTER to continue"
	echo " ";
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

if [ ! -f /LabSetup/images/workstation.img ]
then
	bash /LabSetup/start.sh 
fi

if [ $rp>="restore" ] ; 
then 
	virsh snapshot-create-as restore --domain nodea
	virsh snapshot-create-as restore --domain nodeb
	virsh snapshot-create-as restore --domain nodec
	virsh snapshot-create-as restore --domain workstation
fi

echo 'Resetting Nodes'
virsh shutdown nodea
virsh shutdown nodeb
virsh shutdown nodec
virsh shutdown workstation
echo "Restoring Snapshots"
virsh snapshot-revert nodea restore
virsh snapshot-revert nodeb restore
virsh snapshot-revert nodeb restore
virsh snapshot-revert workstation restore
echo "Starting Nodes"
virsh start nodea
virsh start nodeb
virsh start nodec
virsh start workstation
sleep 15
echo "Installing SSH Keys"
yum -q list installed sshpass &>/dev/null && echo "sshpass already installed skipping install" || sudo yum install sshpass -y --nogpgcheck;
sleep 5
# for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" ssh-copy-id root@$i ; done
echo "Starting Fencing Setup"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i mkdir /etc/cluster/ ; done
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" scp /etc/cluster/fence_xvm.key root@$i:/etc/cluster/fence_xvm.key ; done
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" scp /etc/hosts root@$i:/etc/hosts ; done
echo "Setting Firewall"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'firewall-cmd --zone=public --add-port=1229/tcp --permanent ; firewall-cmd --reload' ; done
echo "Setting up YUM Repo"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" scp http://192.168.200.1:8000/Repo/192.168.200.1.repo root@$i:/etc/yum.repos.d/192.168.200.1.repo ; done
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'yum repolist' ; done
clear

echo -e '\nCompleted setup, you should have a icon on your desktop now that you can use to reset the environment.\nPlease run this icon before attempting to work with virtual machines'
echo -e '\nInstead of using the RedHat fencing agent, you will use fenc_virt, to test if nodes are connected type:\n"fence_xvm -o list"\n'
echo -e "\nWhen adding fencing agent use:\n'pcs stonith create Fencing fence_xvm ip_family=ipv4\nTest fencing by typing:\nfence_virt nodea'"
print -p 'press ENTER to continue'