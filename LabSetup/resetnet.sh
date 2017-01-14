#!/bin/bash
# Joseph Martin Dec 2016

nodes=$(ls -C /LabSetup/ks)
virtnets=$(ls -C /LabSetup/virtnet)
httpstatus=$(ps ax | grep -v grep | grep SimpleHTTPServer > /dev/null && echo 0 || echo 1)
cd /LabSetup/
virt-manager &

for i in $nodes 
do
	virsh list --all | grep $i | grep running > /dev/null && echo 'Domain '$i 'is currently running' && virsh shutdown $i && sleep 3 || echo 'Node '$i 'down' 2>/dev/null &
	sleep 3
done

echo 'Creating networks if needed'
for i in ${virtnets//.xml}
do
	virsh net-list | grep $i > /dev/null && virsh net-destroy $i || echo 'Network '$i' not found'
	sleep 3
	virsh net-list | grep $i > /dev/null && echo 'network '$i' found' || virsh net-create /LabSetup/virtnet/$i.xml
	sleep 10 
done

echo 'Checking Virtual Machine status and starting VMs'
for i in $nodes 
do
	virsh start $i 2>/dev/null &
	sleep 10
done

if [[ $httpstatus -eq 1 ]]
then
	echo 'Starting HTTP Server'
	nohup python -m SimpleHTTPServer &>/dev/null &
	sleep 3 
fi

echo "YUM Repo setup"
for i in $nodes
do 
	sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public "rm /etc/yum.repos.d/*;echo -e '[LabSetup]\nname=LabSetupRepo\nbaseurl=http://classroom.example.com:8000/Packages\nenabled=1\ngpgcheck=0'>/etc/yum.repos.d/LabSetup.repo"
	sleep 3  
done

for i in $nodes 
do 
	echo 'Updating yum repolist'
	sshpass -p "redhat" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$i.public 'yum repolist ; reboot'
	sleep 3 	
done
