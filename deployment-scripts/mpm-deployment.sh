#!/bin/bash

PROGNAME=$(basename $0)

function error_exit {
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  cleanup 1
}

function wait_str {
  local file="$1"; shift
  local search_term="$1"; shift
  local wait_time="${1:-120}"; # 2 minutes as default timeout in units of seconds

  until grep -q "$search_term" $file || [ $(( wait_time-- )) -eq 0 ]; do sleep 1; done
  
  if [ $(( ++wait_time )) -gt 0 ]
  then
    return 0
  else
    echo "Timeout of ${1:-120} seconds was reached. Unable to find '$search_term' in '$file'"
    cat $file
    
    return 1
  fi
}

function wait_mpm_server {
  echo "Waiting for MPM server..."
  local server_log="$1"; shift
  local wait_time="$1"; shift

  wait_file "$server_log" 10 || { echo "MPM log file missing: '$server_log'"; return 1; }

  wait_str "$server_log" "Server started" "$wait_time"
}

function wait_file {
  local file="$1"; shift
  local wait_seconds="${1:-30}"; shift # 30 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 1; done

  ((++wait_seconds))
}

###########################################################
# Comment me...                                           #
###########################################################

DAEMON_USER=$1
BINARYREPO=$2
MPM_BINARY=$3
DATABASE=$4
FRESH_DATABASE=$5
WORKSPACE=$(pwd)

DEPLOYMENT_FOLDER=/opt/mpm/deployments/"$MPM_BINARY"
EXTERNAL_MPM_FOLDER="/opt/mpm/external/"

ANT_HOME=./apache-ant-1.9.6
PATH=$ANT_HOME/bin:$PATH
export ANT_HOME PATH

echo "PATH=$PATH"
echo "JAVA_HOME=$JAVA_HOME"

function cleanup {
  rm -Rf $DEPLOYMENT_FOLDER/mpm-6*.zip $DEPLOYMENT_FOLDER/autodeployment-qa-scripts/ $DEPLOYMENT_FOLDER/mpm-sql-runner.xml
  exit $1
}

trap cleanup HUP INT TERM


function liquibase_runner {
  local prop_file="$1"; shift
  local db_type="$1"; shift
  
  cp -f "$WORKSPACE/$prop_file" config/
  if $FRESH_DATABASE
  then
    ant -Denv.DATABASE=$DATABASE -f ../../mpm-sql-runner.xml -propertyfile config/"$prop_file" || error_exit "$LINENO: schema failed to drop"
    ./dbmaintain $db_type init || error_exit "$LINENO: failed to create schema"
    
    ant -Denv.DATABASE=$DATABASE -f ../../mpm-sql-runner.xml -propertyfile config/"$prop_file" run.qa.scripts || error_exit "$LINENO: failed to insert QA data scripts"
  else
    ./dbmaintain $db_type || error_exit "$LINENO: failed to update schema"
  fi
}

if [ -d $DEPLOYMENT_FOLDER ]
then
  rm -Rf $DEPLOYMENT_FOLDER/*
else
  mkdir -p $DEPLOYMENT_FOLDER
fi

cd $DEPLOYMENT_FOLDER
  scp $DAEMON_USER@$BINARYREPO:/mpm/"$MPM_BINARY/*" .  || error_exit "$LINENO: failed to copy ${MPM_BINARY} from ${BINARYREPO}"

  find . -type f -name mpm-6*.zip -exec unzip -q {} \; || error_exit "$LINENO: failed to unzip archive"

  cp -Rf $WORKSPACE/autodeployment-qa-scripts/ $WORKSPACE/mpm-sql-runner.xml .

  cd */configurations/repositories
  echo "Modifying MPM configurations...."
  
  find spring/ properties/ -type f -exec gawk -v host=$(hostname) -v ex=$EXTERNAL_MPM_FOLDER '{ a = gensub(/\\\\/, "/", "g"); b = gensub(/C:\//, ex, "g", a); c = gensub(/((.*?)host(Name)*(=|: ))(.*?)/, "\\1"host, "g", b); d = gensub(/(<property name=\"hostName\" value=\")(.*?)(\"\/>)/, "\\1"host"\\3", "g", c); print d >> FILENAME".tmp" }' {} +
  
  find $DEPLOYMENT_FOLDER/*/bin/ $DEPLOYMENT_FOLDER/autodeployment-qa-scripts/* -type f \( -name '*.properties' -o -name '*.sql' \) -exec gawk -F'\n' -v ex=$EXTERNAL_MPM_FOLDER '{ a = gensub(/(C|c):\\/, ex, "g"); b = gensub(/\\([a-zA-Z]{2,}|\{)/, "/\\1", "g", a);  print b > FILENAME".tmp" }' {} +

  find . $DEPLOYMENT_FOLDER/*/bin/ $DEPLOYMENT_FOLDER/autodeployment-qa-scripts/ -type f -name *.tmp -print | while IFS= read -r file; do mv $file ${file%.tmp}; done
  
  cd -
  
  cp -f $WORKSPACE/database*.properties */bin/
  
  cd */database-scripts
  chmod +x $ANT_HOME/bin/ant dbmaintain
  
  read -a elements -d ':' <<< ${DATABASE}
  case ${elements[0]} in
    oracle)
      liquibase_runner "oracle.properties" "oracle"
      ;;
    db2luw)
      liquibase_runner "db2_luw.properties" "db2luw"
      ;;
    mssql)
      liquibase_runner "sql-server.properties" "mssql"
      ;;
    db2i)
      liquibase_runner "iSeries.properties" "db2i"
      ;;
    *)
      error_exit "$LINENO: failed to determine database"
  esac
  cd -
  
  cd */bin
  
  chmod +x mpm
  ./mpm > /dev/null 2>&1 > /dev/null &
  wait_mpm_server "mpm.log" || error_exit "$LINENO: failed to start up server"
  echo "MPM ready for use...."
  cd -

cd -

cleanup 0
