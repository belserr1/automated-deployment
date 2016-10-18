#!/bin/bash

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit cleanup 1
}

function cleanup {
  rm -Rf sshpass-1.05*
  exit $1
}

PRODUCT=$1

# install sshpass
if [ ! -f /usr/bin/sshpass ]
then
  wget http://gtb-binaryrepo01/installers/All%20Installers/Installer%2064bit/Solaris%20Installer/sshpass-1.05.tar.gz
  tar -zxvf sshpass-1.05.tar.gz
  cd sshpass-1.05
  ./configure
  make
  make install
  mv /usr/local/bin/sshpass /usr/bin
  cd ..
else
  echo "sshpass already installed..."
  which sshpass
fi

if echo $PRODUCT | grep -qi "mpm"
then
  MPM_HOME=/opt/mpm
  MPM_SHARE=${MPM_HOME}/external
  MPM_EXTERNAL=C:\\cygwin64$(echo ${MPM_SHARE} | tr '/' '\\')
  
  mkdir ${MPM_SHARE}
  
  # share a folder
  
  net user mpmqa Password1 /add /passwordchg:no /expires:never /times:all
  WMIC USERACCOUNT WHERE "Name='mpmqa'" SET PasswordExpires=FALSE
  
  net share mpm-externals=${MPM_EXTERNAL} /UNLIMITED /GRANT:mpmqa,FULL
  
  icacls "${MPM_EXTERNAL}" /grant:r Everyone:\(OI\)\(CI\)\(IO\)\(F\) /T
  
elif echo $PRODUCT | grep -qi "ti"
then
  mkdir /opt/tiplus2
else
  error_exit "$LINENO: 3rd argument wasn't known.."
fi

cleanup 0

