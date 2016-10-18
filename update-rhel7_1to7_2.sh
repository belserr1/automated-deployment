#!/bin/bash -e
#SSH Pass
sshpass -p 'misys123' ssh -o StrictHostKeyChecking=no root@$MACHINENAME bash -c "

cd /etc/yum.repos.d
wget -c gtb-binaryrepo01/installers/devops/installer64bit/rheldvd.repo

yum clean all
yum repolist
yum -y update

shutdown -r 1 "Rebooting in one minute"
"