#!/bin/bash

PROGNAME=$(basename $0)

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

DAEMON_USER=$1
DAEMON_USER_PASSWORD=$2
OS=$3
PRODUCT=$4

VERSION=6
if echo $OS | grep -qi "redhat linux 7"
then
  VERSION=7
  LV="root"
  RESIZE2FS="xfs_growfs"
  
  timedatectl set-timezone Asia/Kuala_Lumpur
fi

if ! cat /etc/passwd | grep -qi $DAEMON_USER
then
  # create a sudoer
  useradd $DAEMON_USER
  (echo $DAEMON_USER_PASSWORD;echo $DAEMON_USER_PASSWORD) | passwd $DAEMON_USER
  VISUDO_COMMAND="$DAEMON_USER ALL=(ALL) NOPASSWD:       ALL"
  echo $VISUDO_COMMAND >> /etc/sudoers
fi

# install sshpass

if [ ! -f /usr/bin/sshpass ]
then
  wget http://gtb-binaryrepo01/installers/All%20Installers/Installer%2064bit/Linux/sshpass-1.05-1.el6.x86_64.rpm || error_exit "$LINENO: failed to find sshpass utility in repo"
  rpm -ivh sshpass-1.05-1.el6.x86_64.rpm || error_exit "$LINENO: failed to install sshpass"
  rm -f sshpass-1.05-1.el6.x86_64.rpm

fi

if ! pvscan | grep -qi sdb
then
  VG_NAME="`vgdisplay | grep "VG Name" | cut -d " " -f19`"

  # configure fdisk partition:

  (echo n;echo p;echo 1;echo;echo;echo t;echo 8e;echo w;) | fdisk /dev/sdb

  # configure vg:

  pvcreate /dev/sdb1
  vgextend ${VG_NAME} /dev/sdb1
  lvextend -l +100%FREE /dev/${VG_NAME}/${LV:-"lv_root"}
  lvm vgchange -a y
  ${RESIZE2FS:-"resize2fs"} /dev/${VG_NAME}/${LV:-"lv_root"}
fi

if echo $PRODUCT | grep -qi "mpm"
then
  MPM_HOME=/opt/mpm
  MPM_SHARE=${MPM_HOME}/external
  
  mkdir -p ${MPM_HOME}
  chown -R ${DAEMON_USER}:${DAEMON_USER} ${MPM_HOME}
  
  mkdir -m =rwx,g+s ${MPM_SHARE}
  chown -R ${DAEMON_USER}:${DAEMON_USER} ${MPM_SHARE}
  chcon -Rt samba_share_t ${MPM_SHARE}
    
  # install and configure samba
  (echo [centos]; echo -e 'name=CentOS $releasever - $basearch'; echo "baseurl=http://ftp.heanet.ie/pub/centos/$VERSION/os/"'$basearch/'; echo enabled=1; echo gpgcheck=0; echo;) > /etc/yum.repos.d/centos.repo
  
  yum install -y samba samba-client || error_exit "$LINENO: samba packages not found in repo"
  
  mv /etc/samba/smb.conf /etc/samba/smb.conf.original
  (echo -e "[global]\n\tnetbios name = `hostname`\n\tsecurity = user\n[mpm-externals]\n\tcomment = MPM External Folder\n\tpath = /opt/mpm/external\n\twritable = yes\n\tcreate mask = 0664\n\tdirectory mask = 0755\n\tvalid users = mpmqa\n";) > /etc/samba/smb.conf

  useradd mpmqa -G $DAEMON_USER -s /sbin/nologin
  (echo Password1; echo Password1;) | smbpasswd -sa mpmqa

  if [ $VERSION = "7" ]
  then
    systemctl enable smb.service
    systemctl enable nmb.service
    systemctl restart smb.service
    systemctl restart nmb.service
    
    firewall-cmd --permanent --zone=public --add-service=samba
    firewall-cmd --reload
  else
    lokkit --service=samba --update
    chkconfig smb on
    service smb start
  fi
elif echo $PRODUCT | grep -qi "ti"
then
    TI_HOME=/opt/tiplus2
    mkdir -p ${TI_HOME}
    chown -R ${DAEMON_USER}:${DAEMON_USER} ${TI_HOME}
elif echo $PRODUCT | grep -qi "ticc"
then
    TICC_HOME=/opt/ticc
	MCH_HOME=/opt/mch
	TOMCAT_HOME=/opt/tomcat
    mkdir -p ${TI_HOME}
	mkdir -p ${MCH_HOME}
	mkdir -p ${TOMCAT_HOME}
    chown -R ${DAEMON_USER}:${DAEMON_USER} ${TI_HOME}
	chown -R ${DAEMON_USER}:${DAEMON_USER} ${MCH_HOME}
	chown -R ${DAEMON_USER}:${DAEMON_USER} ${TOMCAT_HOME}
else
    error_exit "$LINENO: 3rd argument wasn't known.."
fi

