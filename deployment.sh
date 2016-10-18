#!/bin/bash

PROGNAME=$(basename $0)

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

###################################################################
#
# This script is used for the following:
# 1) Upon the first use within the VM, this script will provide its
#    ssh public key to the binary repository for ssh authorization
# 2) Upon the first use within the VM, this script will create the nessacary
#    external folders on the file system
# 3) This script will then securely copy the binary over to the
#    VM and assemble it using the property files generated from
#    the initial script
# 4) Finally it will deploy decide which product to deploy
#
#
###################################################################

BINARYREPO_USER="$1"
BINARY="$3"
BINARYREPO="$4"
PRODUCT=$5

export SSHPASS="$2"
KEYS=$(sshpass -e ssh $BINARYREPO_USER@$BINARYREPO 'cat .ssh/authorized_keys')

if ! echo "$KEYS" | grep -qi $(hostname)
then
  echo "Setting public key in binary repo..."
  
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

  sshpass -e scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub $BINARYREPO_USER@$BINARYREPO:~/
  sshpass -e ssh $BINARYREPO_USER@$BINARYREPO 'cat id_rsa.pub >> .ssh/authorized_keys;rm -f id_rsa.pub'
fi

trap 'echo $(basename $0) ending...' HUP INT TERM

if echo $PRODUCT | grep -qi "ti"
then
  echo "Found ti-deployment..."
  deployment-scripts/./ti-deployment.sh "$BINARYREPO_USER" "$BINARYREPO" "$BINARY"
fi

if echo $PRODUCT | grep -qi "mpm"
then
  DATABASE=$6
  FRESH_DATABASE=$7
  MPM_PID=""
  
  if uname -a | grep -qi "Cygwin"
  then
    MPM_PID=$(wmic process get ProcessID, Commandline | awk '/[D]efaultServer/{print $11}')
  else
    MPM_PID=$(ps auxww | awk '/[D]efaultServer/{print $2}')
  fi
  
  echo "MPM_PID=$MPM_PID"
  if [ ! "x$MPM_PID" = "x" ]
  then
    if uname -a | grep -i "Cygwin"
    then
      taskkill /pid $MPM_PID /f || error_exit "$LINENO: failed to shutdown MPM"
    else
      kill -9 $MPM_PID || error_exit "$LINENO: failed to shutdown MPM"
    fi
  else
    echo "MPM is not running...."
  fi
  
  deployment-scripts/./mpm-deployment.sh "$BINARYREPO_USER" "$BINARYREPO" "$BINARY" "$DATABASE" "$FRESH_DATABASE"
fi

