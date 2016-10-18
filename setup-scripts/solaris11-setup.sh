#!/bin/bash

PROGNAME=$(basename $0)

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit cleanup 1
}

function cleanup {
  rm -Rf sshpass-1.05* format-commands.txt
  exit $1
}

DAEMON_USER=$1
PRODUCT=$2

if [[ $(id -u) -eq 0 ]]
then
  # install hard disk
  if ! cat /etc/vfstab | grep -qi c8t1d0s0
  then
    echo y | fdisk /dev/rdsk/c8t1d0s2
    (echo partition;echo 0;echo unassigned;echo wm;echo 0;echo 3913c;echo name;echo \"optspace\";echo label;echo q;echo q) > format-commands.txt
    format -f format-commands.txt -d c8t1d0
    echo y | newfs /dev/rdsk/c8t1d0s0
    fsck -y /dev/rdsk/c8t1d0s0
    
    # mount new hard disk
    
    mount /dev/dsk/c8t1d0s2 /opt
    
    echo '/dev/dsk/c8t1d0s0 /dev/rdsk/c8t1d0s0 /opt ufs 2 yes -' >> /etc/vfstab
    perl -pi -e s/micloudtmplsol11/`hostname`/g /etc/hosts
  fi
  
  # install sshpass
  
  if [ ! -f /usr/bin/sshpass ]
  then
    pkg install gcc-3
    export PATH=/usr/sfw/bin:$PATH
    
    wget http://gtb-binaryrepo01/installers/All%20Installers/Installer%2064bit/Solaris%20Installer/sshpass-1.05.tar.gz
    tar -zxvf sshpass-1.05.tar.gz
    cd sshpass-1.05
    ./configure
    make
    make install
    mv /usr/local/bin/sshpass /usr/bin
    cd ..
  fi
  
  if echo $PRODUCT | grep -qi "mpm"
  then
    MPM_HOME=/opt/mpm
    MPM_SHARE=$MPM_HOME/external
    
    mkdir -p ${MPM_HOME}
    chown -R ${DAEMON_USER}:staff ${MPM_HOME}
    
    mkdir -m =rwx,g+s ${MPM_SHARE}
    chown -R ${DAEMON_USER}:staff ${MPM_SHARE}
    
    # install and configure samba
    
    pkg install samba
    mv /etc/samba/smb.conf-example /etc/samba/smb.conf.original
  (echo "[global]\n\tnetbios name = `hostname`\n\tsecurity = user\n[mpm-externals]\n\tcomment = MPM External Folder\n\tpath = /opt/mpm/external\n\twritable = yes\n\tcreate mask = 0664\n\tdirectory mask = 0755\n\tvalid users = mpmqa\n";) > /etc/samba/smb.conf

    useradd mpmqa
    (echo Password1; echo Password1;) | smbpasswd -sa mpmqa
    svcadm enable samba
  elif echo $PRODUCT | grep -qi "ti"
  then
    mkdir -p ${TI_HOME}
    chown -R ${DAEMON_USER}:staff ${TI_HOME}
  else
    error_exit "$LINENO: 3rd argument wasn't known.."
  fi
  
  svccfg -s timezone:default setprop timezone/localtime= astring: Asia/Kuala_Lumpur
  svcadm refresh timezone:default
else
  error_exit "$LINENO: Did not get executed as root user..."
fi
cleanup 0

