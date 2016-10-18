#!/bin/bash

PROGNAME=$(basename $0)
find . -type f -name "*.sh" -exec chmod +x {} +

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

echo "Begin jenkins-starter script..."

BINARYREPO_USER=cmreadmin
BINARYREPO=gtb-binaryrepo01

OS=$1
MACHINENAME=$2

USERNAME=nouser
PASSWORD=nopassword

if echo $OS | grep -qi "windows"
then
  USERNAME=${MACHINENAME^^}+Administrator
  PASSWORD=GTB@dmin1
elif echo $OS | grep -qi "redhat linux 6"
then
  USERNAME=cmreadmin
  PASSWORD=tradein1
elif echo $OS | grep -qi "redhat linux 7"
then
  USERNAME=micloud
  PASSWORD=misys123
elif echo $OS | grep -qi "solaris"
then
  USERNAME=micloud
  PASSWORD=misys123
  MACHINENAME=${MACHINENAME^^}
else
  error_exit "$LINENO: cannot determine OS parameter: $OS"
fi

function ssh_configuration {
  SSHUSER_HOST=$USERNAME@$MACHINENAME
  export SSHPASS=$PASSWORD
  
  sshpass -e scp -o StrictHostKeyChecking=no ${JENKINS_HOME}/.ssh/id_rsa.pub ${SSHUSER_HOST}:~/
  sshpass -e ssh ${SSHUSER_HOST} 'cat id_rsa.pub >> .ssh/authorized_keys;chmod 600 .ssh/authorized_keys;rm -f id_rsa.pub'
  sshpass -e scp -r ${WORKSPACE} ${SSHUSER_HOST}:~/
}

trap 'echo $PROGNAME ending...' HUP INT TERM

if [ "x"$VM_SETUP != "x" ]
then
  echo "Begin VM_SETUP..."
  PRODUCT=$3
  
  if echo $OS | grep -qi "redhat linux 6"
  then
    SSHUSER_HOST=root@$MACHINENAME
    SSHPASS=misys123
  else
    SSHUSER_HOST=$USERNAME@$MACHINENAME
    SSHPASS=$PASSWORD
  fi
  export SSHPASS

  sshpass -e scp -o StrictHostKeyChecking=no ${JENKINS_HOME}/.ssh/id_rsa.pub ${SSHUSER_HOST}:~/
  sshpass -e ssh ${SSHUSER_HOST} 'if [ ! -d ~/.ssh ]; then mkdir ~/.ssh; fi; cat id_rsa.pub >> .ssh/authorized_keys;chmod 600 .ssh/authorized_keys;rm -f id_rsa.pub'
  sshpass -e scp -r ${WORKSPACE} ${SSHUSER_HOST}:/tmp
  sshpass -e ssh ${SSHUSER_HOST} "/tmp/${JOB_NAME}/./vm-setup.sh ${USERNAME} ${PASSWORD} '${OS}' ${JOB_NAME} ${PRODUCT};rm -Rf /tmp/${JOB_NAME}"
fi

if [ "x"$TI_DEPLOYMENT != "x" ]
then

  if [ -z "$4" ]
  then
    error_exit "$LINENO: an APPSERVER must be provided"
  fi

  if [ -z "$5" ]
  then
    error_exit "$LINENO: a DATABASE must be provided"
  fi

  if [ -z "$6" ]
  then
    error_exit "$LINENO: a FBCC option must be provided"
  fi
  
  echo "Begin TI_DEPLOYMENT..."
  
  BINARY_FOLDER=${3:-dailybuild/2.8.0/`date +%Y%m%d`}
  APPSERVER=$4
  DATABASE=$5
  FBCC=$6
  
  perl ti-propertyfile-generator.pl "$APPSERVER" "$DATABASE" "$MACHINENAME" "$OS" "$FBCC" || error_exit "$LINENO: failed to generate assembly scripts"
  ssh_configuration
  
  sshpass -e ssh ${SSHUSER_HOST} "pushd ${JOB_NAME};./deployment.sh '${BINARYREPO_USER}' tradein1 '${BINARY_FOLDER}' '${BINARYREPO}' 'ti';popd;rm -Rf ${JOB_NAME}"
fi

if [ "x"$MPM_DEPLOYMENT != "x" ]
then

  if [ -z "$4" ]
  then
    error_exit "$LINENO: a DATABASE must be provided"
  fi
  
  echo "Begin MPM_DEPLOYMENT..."
  
  BINARY_FOLDER=${3:-dailybuild/FBPM6.0/`date +%Y%m%d`}
  DATABASE=$4
  FRESH_DATABASE=$5
  
  perl mpm-propertyfile-generator.pl "$DATABASE" "$MACHINENAME" || error_exit "$LINENO: failed to generate database scripts"
  ssh_configuration
  
  sshpass -e ssh ${SSHUSER_HOST} "pushd ${JOB_NAME};./deployment.sh '${BINARYREPO_USER}' tradein1 '${BINARY_FOLDER}' '${BINARYREPO}' 'mpm' '${DATABASE}' '${FRESH_DATABASE}';popd;rm -Rf ${JOB_NAME}"
fi

if [ "x"$TI_SETUP != "x" ]
then
  echo "Begin TI_SETUP..."
  
  BINARY_FOLDER=${3:-dailybuild/2.8.0/`date +%Y%m%d`}
  DEPLOYMENT_FOLDER="/opt/tiplus2/deployments/package_software/'${BINARY_FOLDER}'"
  MAPS_FOLDER="/ti/ga/TI Plus 2 G.2.1 Release/MAPS-1.6"
  
  SSHUSER_HOST=$USERNAME@$MACHINENAME
  export SSHPASS=$PASSWORD

  echo "Copying templates archive from machine..."

  sshpass -e scp -o StrictHostKeyChecking=no ${SSHUSER_HOST}:"'${DEPLOYMENT_FOLDER}'/configurations/fbti/templates/templates-html.zip" ${WORKSPACE}/templates.zip
  
  if [ "$?" -ne "0" ]
  then
  
    SSHUSER_HOST=$BINARYREPO_USER@$BINARYREPO
    export SSHPASS=tradein1
    
    if [ $DEPLOY_CONFIG = "maps" ]
    then
      sshpass -e scp -o StrictHostKeyChecking=no ${SSHUSER_HOST}:"'${MAPS_FOLDER}'/templates.zip" ${WORKSPACE}
    else
      echo "Copying tiodds archive from repo..."
    
      sshpass -e scp -o StrictHostKeyChecking=no ${SSHUSER_HOST}:"/ti/'${BINARY_FOLDER}'/tiodds.zip" ${WORKSPACE}
    
      cd "${WORKSPACE}"
      unzip tiodds.zip -d tiodds
      cp tiodds/ti/templates/templates-html.zip templates.zip
      rm -Rf tiodds*
      cd -
    fi
  fi
  
  if [ ! -f $WORKSPACE/templates.zip ]
  then
    error_exit "$LINENO: no document templates were found"
  fi
  
  if [ $DEPLOY_CONFIG != "none" ]
  then
    echo "Copying CSV templates to import folder..."
    
    CSV_IMPORT_FOLDER=/opt/tiplus2/csv/import
    SSHUSER_HOST=$USERNAME@$MACHINENAME
    export SSHPASS=$PASSWORD
  
    sshpass -e ssh -o StrictHostKeyChecking=no ${SSHUSER_HOST} "rm -f '${CSV_IMPORT_FOLDER}'/*"
    sshpass -e ssh -o StrictHostKeyChecking=no ${SSHUSER_HOST} "mv '${DEPLOYMENT_FOLDER}'/configurations/fbti/csv/* '${CSV_IMPORT_FOLDER}'"
    
    if [ "$?" -ne "0" ]
    then
      if [ $DEPLOY_CONFIG = "maps" ]
      then
      wget http://${BINARYREPO}/ti/ga/TI%20Plus%202%20G.2.1%20Release/MAPS-1.6/csv.zip || error_exit "$LINENO: configuration files not found"
      
      sshpass -e scp -o StrictHostKeyChecking=no csv.zip ${SSHUSER_HOST}:"'${DEPLOYMENT_FOLDER}'/csv-maps.zip"
      sshpass -e ssh ${SSHUSER_HOST} "unzip '${DEPLOYMENT_FOLDER}'/csv-maps.zip -d ${CSV_IMPORT_FOLDER}"
      else
        sshpass -e ssh -o StrictHostKeyChecking=no ${SSHUSER_HOST} "unzip '${DEPLOYMENT_FOLDER}'/csv.zip -d ${CSV_IMPORT_FOLDER};mv ${CSV_IMPORT_FOLDER}/csv/* ${CSV_IMPORT_FOLDER}; rm -Rf ${CSV_IMPORT_FOLDER}/csv;"
      fi
    fi
  fi
  
fi

