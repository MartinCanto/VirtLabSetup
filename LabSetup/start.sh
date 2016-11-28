#!/bin/bash
# Joseph Martin Nov 2016

clear
cd /LabSetup/

httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
onlinemode=$(wget -q --tries=10 --timeout=20 -O - http://google.com > /dev/null && echo 0 || echo 1)
scriptreset=0
snapshot=0

if [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Online Mode Active and HTTP server not running'
	nohup python -m SimpleHTTPServer &>/dev/null &
	if [ -f /etc/yum.repos.d/LabSetup.repo ]
	then
		rm -R /etc/yum.repos.d/LabSetup.repo
		cp -R /etc/yum.repos.d.bak/yum.repos.d /etc/yum.repos.d/
		yum repolist
	fi
elif [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Online Mode Active and HTTP server is already running'
	if [ -f /etc/yum.repos.d/LabSetup.repo ]
	then
		rm -R /etc/yum.repos.d/LabSetup.repo
		cp -R /etc/yum.repos.d.bak/yum.repos.d/* /etc/yum.repos.d/ 
		yum repolist
	fi
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 1 ]]
then
	echo 'Offline Mode Active and HTTP server not running'
	nohup python -m SimpleHTTPServer &>/dev/null &
	if [ ! -f /etc/yum.repos.bak/ ] 
	then
		mkdir -p /etc/yum.repos.d.bak/
		cp -R /etc/yum.repos.d/ /etc/yum.repos.d.bak/
		rm -R /etc/yum.repos.d/*
		echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://127.0.0.1:8000/Packages\nenabled=1\ngpgcheck=0' >/etc/yum.repos.d/LabSetup.repo
	fi
elif [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 0 ]]
then
	echo 'Offline Mode Active and HTTP server is already running'
	if [ ! -f /etc/yum.repos.bak/ ] 
	then
		mkdir -p /etc/yum.repos.d.bak/
		cp -R /etc/yum.repos.d/ /etc/yum.repos.d.bak/
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

echo 'Setting file permissions'
chown -R $SUDO_USER: /var/lib/libvirt/
chown -R $SUDO_USER: /LabSetup/
chmod g+s /LabSetup/images/

echo 'Verifying installed domains'
if [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep nodea > /dev/null && virtstatus=0 || virtstatus=1
elif [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep nodeb > /dev/null && virtstatus=0 || virtstatus=1
elif [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep nodeac > /dev/null && virtstatus=0 || virtstatus=1
elif [[ $virtstatus -eq 0 ]]
then 
	virsh list --all | grep workstation > /dev/null && virtstatus=0 || virtstatus=1
fi

for i in {public,private,storage,storage2} 
do
	virsh net-list | grep $i > /dev/null && echo 'network '$i' found' || virsh net-create /LabSetup/virtnet/$i.xml
done

if [[ $virtstatus -eq 0 ]]
then
	for i in {nodea,nodeb,nodec,workstation} 
	do
		virsh start $i 2>/dev/null &
	done
fi

if [[ $virtstatus -eq 1 ]]
then
	scriptreset=1
	clear
	read -t 60 -p 'VMs are about to be created. Please restart script by clicking the desktop icon AFTER machines have finished and rebooted. Press ENTER to start the VM creation'
	virt-manager &  
	for i in {nodea,nodeb,nodec,workstation} 
	do
		virsh list | grep $i > /dev/null && echo 'node '$i' found' || virt-install --name $i --initrd-inject=/LabSetup/ks/$i/ks.cfg --extra-args="ks=file:/ks.cfg" --ram=1024 --vcpus=1 --location=/LabSetup/ISO/CentOS7.iso --os-variant=rhel7 --disk /LabSetup/images/$i.qcow2,size=15 -w network=private -w network=public -w network=storage -w network=storage2 --os-type=linux 2> /dev/null &
	done
	sleep 30
fi

if [[ $scriptreset -eq 1 ]]
then	
	exit 0
fi

virt-manager &

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
	virsh snapshot-list workstation | grep restore >/dev/null && snapshot=0 || snapshot=1
fi
echo "Verifying Fencing Agent"
if [[ $snapshot -eq 1 ]] && [ ! -f /etc/cluster/fence_xvm.key ]
then
	echo 'Installing fencing agent'	
	mkdir -p /etc/cluster 
	dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=1k count=4
	# fence_virtd -c
	cp /LabSetup/FV/fence_virt.conf /etc/fence_virt.conf
	systemctl enable fence_virtd.service 
	systemctl start fence_virtd.service 
fi

if [[ $snapshot -eq 1 ]]
then
	echo 'Setting Hosts File'
	grep nodea /etc/hosts >/dev/null && echo 'Hosts file verified' || echo -e '192.168.300.101 nodea.storage\n192.168.100.101 nodea.storage2\n192.168.200.101 nodea.private\n192.168.125.151 nodea.public\n192.168.100.102 nodeb.storage\n192.168.300.102 nodeb.storage2\n192.168.200.102 nodeb.private\n92.168.125.152 nodeb.public\n192.168.100.103 nodec.storage\n192.168.300.103 nodec.storage2\n192.168.200.103 nodec.private\n192.168.125.153 nodec.public\n192.168.100.104 workstation.storag\n192.168.300.104 workstation.storage2\n192.168.200.104 workstation.private\n192.168.125.150 workstation.public\n192.168.100.1 hypervisor.storage\n192.168.300.1 hypervisor.storage2\n192.168.200.1 hypervisor.private\n192.168.125.1 hypervisor.public'>>/etc/hosts
fi

if [[ $snapshot -eq 1 ]]
then
	clear
	echo 'Setting up ISCSI'
	systemctl enable target
	systemctl start target 
	firewall-cmd --permanent --add-port=3260/tcp
	firewall-cmd --reload 
	mkdir -p /srv/iscsi 
	dd if=/dev/zero of=/srv/iscsi/backingstore bs=1 count=0 seek=4G 
	targetcli /backstores/fileio create clusterstor /srv/iscsi/backingstore 
	targetcli /iscsi create iqn.2015-06.com.example:cluster 
	for i in {nodea,nodeb,nodec,workstation} 
	do	
		targetcli /iscsi/iqn.2015-06.com.example:cluster/tpg1/acls/ create iqn.2015-06.com.example:$i 
	done 
	targetcli iscsi/iqn.2015-06.com.example:cluster/tpg1/luns/ create /backstores/fileio/clusterstor
	echo "Starting Fencing Setup"
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private}
	do 
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i mkdir /etc/cluster/ 
	done
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
		sshpass -p "redhat" scp -oStrictHostKeyChecking=no /etc/cluster/fence_xvm.key root@$i:/etc/cluster/fence_xvm.key 
	done
	echo 'Copying Hosts File'
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
		sshpass -p redhat scp -oStrictHostKeyChecking=no /etc/hosts root@$i:/etc/hosts
	done
	echo "Setting Firewall"
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
	sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'firewall-cmd --zone=public --add-port=1229/tcp --permanent ; firewall-cmd --reload' 
	done
	echo "Setting up YUM Repo"
fi
if [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 0 ]] && [[ $snapshot -eq 1 ]]
	then
		for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'mkdir -p /etc/yum.repos.d.bak/;cp -r /etc/yum.repos.d/ /etc/yum.repos.d.bak/;rm /etc/yum.repos.d/*;echo -e [LabSetup]\nname=LabSetupRepo\nbaseurl=http://192.168.200.1:8000/Packages\nenabled=1\ngpgcheck=0>/etc/yum.repos.d/LabSetup.repo' 
	done
	
fi

if [[ $onlinemode -eq 0 ]] && [[ $httpstatus -eq 0 ]]
then
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
do 
	sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'rm /etc/yum.repos.d/LabSetup.repo;cp /etc/yum.repos.d.bak/yum.repos.d/* /etc/yum.repos.d/;yum repolist' 
done
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
do sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'yum repolist' 
done
fi

if [[ $onlinemode -eq 1 ]] && [[ $httpstatus -eq 0 ]]
then
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i "echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://192.168.200.1:8000/Packages\nenabled=1\ngpgcheck=0' >/etc/yum.repos.d/LabSetup.repo" 
	done
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private}
	do 
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'yum repolist' 
	done
	for i in {nodea.private,nodeb.private,nodec.private,workstation.private} 
	do 
		sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i 'yum update -y'
	done
fi


clear

if [[ $snapshot -eq 1 ]]
then
	virsh snapshot-create-as $i --name restore --description 'default snapshot created by VirtLab'
fi

if [[ $snapshot -eq 0 ]]
then
	echo 'Resetting Nodes'
	for i in {nodea,nodeb,nodec,workstation} 
	do
		virsh shutdown $i ; sleep 5 ;virsh snapshot-revert $i restore ; virsh start $i
	done
fi
echo -e '\nCompleted setup, you should have a icon on your desktop now that you can use to reset the environment.\nPlease run this icon before attempting to work with virtual machines'
echo -e '\nInstead of using the RedHat fencing agent, you will use fenc_virt, to test if nodes are connected type:\n"fence_xvm -o list"\n'
echo -e "\nWhen adding fencing agent use:\n'pcs stonith create Fencing fence_xvm ip_family=ipv4\nTest fencing by typing:\nfence_xvm -H nodea'"
read -p 'press ENTER to continue'
