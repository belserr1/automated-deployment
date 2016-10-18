#!/bin/bash

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

echo "Begin ti-deployment script..."

DAEMON_USER=$1
BINARYREPO=$2
TI_BINARY=$3
PACKAGE_SOFTWARE=/opt/tiplus2/deployments/package_software
PROPERTY_FOLDER=`pwd`

echo "DAEMON_USER@BINARYREPO=$DAEMON_USER@$BINARYREPO"
echo "TI_BINARY=$TI_BINARY"

if [ ! -d $PACKAGE_SOFTWARE ]
then
  echo "Setting up tiplus2 folder in /opt"

  mkdir -p $PACKAGE_SOFTWARE
  mkdir -p /opt/tiplus2/deployments/autodeploy
  mkdir -p /opt/tiplus2/csv/import
  mkdir -p /opt/tiplus2/csv/export
  mkdir -p /opt/tiplus2/translations
fi

DEPLOYMENT_FOLDER=$PACKAGE_SOFTWARE/$TI_BINARY
if [ -d "$DEPLOYMENT_FOLDER" ]
then
  rm -Rf "$DEPLOYMENT_FOLDER"/*
else
  mkdir -p "$DEPLOYMENT_FOLDER"
fi

cd "$DEPLOYMENT_FOLDER"
scp "$DAEMON_USER@$BINARYREPO:/ti/'$TI_BINARY'/*" .

NEW_PACKAGE=`find "$DEPLOYMENT_FOLDER" -type f -name FBTI*.zip`

if [ ! -z $NEW_PACKAGE ]
then
  echo "Extracting `basename $NEW_PACKAGE` ..."
  unzip -q $NEW_PACKAGE && rm -f $NEW_PACKAGE
else
  echo "Extracting software.zip ..."
  unzip -q software.zip && rm -f software.zip
fi

cp -f $PROPERTY_FOLDER/*.properties software/configuration

cd software

chmod +x build.sh lib/apache-ant/bin/ant

ANT_HOME=./lib/apache-ant
PATH=$ANT_HOME/bin:$PATH
export ANT_HOME PATH

echo "PATH=$PATH"
echo "JAVA_HOME=$JAVA_HOME"
echo "ant.version=`ant -version`"

./build.sh

cd ..

echo "Deploying the binary to the application server..."

APPSERVER=`egrep "appserver.(weblogic|websphere|jboss)=yes" software/configuration/global.configuration.properties | cut -d "." -f 2 | cut -d "=" -f 1`

echo "APPSERVER to deploy to=$APPSERVER"
if [ ! -z $APPSERVER ]
then
  if [ $APPSERVER == "weblogic" ]
  then
    cp $PROPERTY_FOLDER/weblogicUpgradeTI.wlst .
    sh /opt/bea1036/wlserver_10.3/common/bin/wlst.sh weblogicUpgradeTI.wlst weblogic weblogic1 `hostname` tiplus2-zone1 tiplus2-global global zone1 ./software/applications/deploy
    rm -f weblogicUpgradeTI.wlst
  fi
  
  if [ $APPSERVER == "websphere" ]
  then
    WSADMIN=wsadmin.sh
    SCRIPT_FOLDER=$PROPERTY_FOLDER
    if uname -a | grep "Cygwin"
    then
      WSADMIN=wsadmin.bat
      SCRIPT_FOLDER=C:/cygwin64$PROPERTY_FOLDER
    fi
    cp $PROPERTY_FOLDER/websphereUpgradeTI.py .
    /opt/ibm/webSphere/appServer/profiles/AppSrv01/bin/./$WSADMIN -f websphereUpgradeTI.py "$SCRIPT_FOLDER" ./software/applications/deploy tiplus2-zone1 tiplus2-global global zone1
    rm -f websphereUpgradeTI.py
  fi
  
  if [ $APPSERVER == "jboss" ]
  then
    if grep -q projectVersion=2.5 software/applications/assembly/tiplus2-zone1/WAR/META-INF/buildInfo.properties
    then
      sh /opt/jboss-5.1.0.GA/bin/zone-jboss-auto stop
      sh /opt/jboss-5.1.0.GA/bin/global-jboss-auto stop
      sleep 30
      
      cp -f software/applications/deploy/tiplus2-global.ear /opt/jboss-5.1.0.GA/server/global/deploy
      cp -f software/applications/deploy/tiplus2-zone1.ear /opt/jboss-5.1.0.GA/server/zone1/deploy
      sleep 15
      
      sh /opt/jboss-5.1.0.GA/bin/global-jboss-auto start
      sleep 45
      
      sh /opt/jboss-5.1.0.GA/bin/zone-jboss-auto start
      sleep 90
    else
      JBOSS7_COMMAND="/opt/jboss-eap-6.4/bin/jboss-cli.sh --user=jbossadmin --password=jboss@123 --timeout=90000 -c --commands"
      
      sh $JBOSS7_COMMAND="deploy $DEPLOYMENT_FOLDER/software/applications/deploy/tiplus2-global.ear --force=true","deploy $DEPLOYMENT_FOLDER/software/applications/deploy/tiplus2-zone1.ear --force=true"
      sleep 60
      
      sh $JBOSS7_COMMAND="reload --host=master"
    fi
  fi
  
  if [ $? != "0" ]
  then
    error_exit "$LINENO: failed to start up server"
  fi
fi

