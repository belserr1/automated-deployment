#!/bin/bash -x

###################################################################
# A simple script that accepts 4 arguments
#
# 1) the system user used to run the script
# 2) the credentials of the system user
# 3) the type Operating System to configure
# 4) the name of the jenkins job which is a collection of the scripts
#    to run
#
###################################################################

DAEMON_USER=$1
DAEMON_USER_PASSWORD=$2
OS=$3
JOB_NAME=$4
PRODUCT=$5

if echo $OS | grep -qi "redhat linux 6"
then
  sh /tmp/${JOB_NAME}/setup-scripts/rhel-setup.sh $DAEMON_USER $DAEMON_USER_PASSWORD '$OS' ${PRODUCT}
fi

if echo $OS | grep -qi "redhat linux 7"
then
  sudo su - root -c "sh /tmp/${JOB_NAME}/setup-scripts/rhel-setup.sh $DAEMON_USER $DAEMON_USER_PASSWORD '$OS' ${PRODUCT}"
fi

if echo $OS | grep -qi "solaris"
then
  echo $DAEMON_USER_PASSWORD | sudo -S su - root -c "sh /tmp/${JOB_NAME}/setup-scripts/solaris11-setup.sh ${DAEMON_USER} ${PRODUCT}"
fi

if echo $OS | grep -qi "windows"
then
  sh /tmp/${JOB_NAME}/setup-scripts/windows-setup.sh ${PRODUCT}
fi
