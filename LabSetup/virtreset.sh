#!/bin/bash
rp= sudo virsh snapshot-list nodea | grep restore | awk '{print $1}'
cd /LabSetup/

if ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null
then
	echo 'HTTP service running, script will continue.'
else
	echo -e 'HTTPS service not running\nRestarting HTTP for repos\n'
	nohup python -m SimpleHTTPServer &>/dev/null &
	chown -R $SUDO_USER: /var/lib/libvirt/
	chown -R $SUDO_USER: /LabSetup/
	chmod g+s /LabSetup/images/
	bash /LabSetup/start.sh	 
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
 
virsh shutdown nodea
sleep 2
virsh shutdown nodeb
sleep 2
virsh shutdown nodec
sleep 2
virsh shutdown workstation
sleep 2
echo "Restoring Snapshots"
virsh snapshot-revert nodea restore
sleep 1
virsh snapshot-revert nodeb restore
sleep 1
virsh snapshot-revert nodeb restore
sleep 1
virsh snapshot-revert workstation restore
sleep 1
echo "Starting Nodes"
virsh start nodea
sleep 2
virsh start nodeb
sleep 2
virsh start nodec
sleep 2
virsh start workstation
sleep 10
echo "Installing SSH Keys"
yum -q list installed sshpass &>/dev/null && echo "sshpass already installed skipping install" || sudo yum install sshpass -y --nogpgcheck;
read -p -t 60 'Open a shell and create a ssh key by typing: ssh-keygen Then press ENTER to continue this script.'
sleep 5
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do sshpass -p redhat ssh-copy-id root@$i ; done
sleep 1
echo "Starting Fencing Setup"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do ssh -q root@$i mkdir /etc/cluster/ ; done
sleep 1
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do scp /etc/cluster/fence_xvm.key root@$i:/etc/cluster/fence_xvm.key ; done
sleep 1
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do scp /etc/hosts root@$i:/etc/hosts ; done
sleep 2
echo "Setting Firewall"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do ssh -q root@$i 'firewall-cmd --zone=public --add-port=1229/tcp --permanent ; firewall-cmd --reload' ; done
sleep 2
echo "Setting up YUM Repo"
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do scp http://192.168.200.1:8000/Repo/192.168.200.1.repo root@$i:/etc/yum.repos.d/192.168.200.1.repo ; done
for i in {nodea.private,nodeb.private,nodec.private,workstation.private} ; do ssh -q root@$i 'yum repolist' ; done
clear
echo -e '\nCompleted setup, you should have a icon on your desktop now that you can use to reset the environment.\nPlease run this icon before attempting to work with virtual machines'
echo -e '\nInstead of using the RedHat fencing agent, you will use fenc_virt, to test if nodes are connected type:\n"fence_xvm -o list"\n'
echo -e "\nWhen adding fencing agent use:\n'pcs stonith create Fencing fence_xvm ip_family=ipv4\nTest fencing by typing:\nfence_virt nodea'"
print -p 'press ENTER to continue'