#!/usr/bin/perl -w

use strict;
use Config::Properties;

&Initialize();

my $dbdriverFolder = "../lib";

my $db2luwDBName = &FormatSchemaName();
my $db2luwDBPort = "50000";

my $mssqlDBName = "M51Dev";
my $mssqlPort = "1433";

my $dbFile;
my $database;
my $hostname;
my $dbhost;

&Process();

sub Initialize() {
  my @params = split( /:/, $ARGV[0] );
  
  $hostname = $ARGV[1];
  $database = $params[0];
  $dbhost = $params[1];
  
  print "database: " . $database . "\ndbhost: " . $dbhost . "\n";
}

sub Process() {
  my $dburl = "";
  my $dbusername = "";
  my $dbpassword = "";
  
  if( $database eq "oracle" ) {
    $dburl = "jdbc:oracle:thin:@" . $dbhost . ":1521:mxmdev";
    $dbusername = "sys as sysdba";
    $dbpassword = "mpm";
    
    &CreateLiquibaseScript( "oracle.properties", $dburl, "ojdbc7.jar", $dbusername, $dbpassword );
    
    my $oracleCredentials = &FormatSchemaName();
    
    &CreateMPMDBScripts( $dburl, $oracleCredentials, $oracleCredentials );
  } elsif( $database eq "db2luw" ) {
    $dburl = "jdbc:db2://" . $dbhost . ":" . $db2luwDBPort . "/" . $db2luwDBName;
    $dbusername = "mpmadmin";
    $dbpassword = "Password99\$";
    
    &CreateLiquibaseScript( "db2_luw.properties", $dburl, "db2jcc4.jar", $dbusername, $dbpassword );
    &CreateMPMDBScripts( $dburl, $dbusername, $dbpassword );
  } elsif( $database eq "mssql" ) {
    $dburl = "jdbc:sqlserver://" . $dbhost . ":" . $mssqlPort . ";instanceName=" . $mssqlDBName;
    $dbusername = "M51Dev";
    $dbpassword = "123Kapiti";
    
    &CreateLiquibaseScript( "sql-server.properties", $dburl, "sqljdbc4.jar", $dbusername, $dbpassword  );
    
    my $mssqlCredentials = &FormatSchemaName();
    
    &CreateMPMDBScripts( $dburl, $mssqlCredentials, $mssqlCredentials );
  } elsif( $database eq "db2i" ) {
    $dburl = "jdbc:as400://" . $dbhost . "/" . &FormatSchemaName();
    $dbusername = "DB2ACCESS";
    $dbpassword = "DB2ACCESS";
    
    &CreateLiquibaseScript( "iSeries.properties", $dburl, "jt400.jar", $dbusername, $dbpassword );
    &CreateMPMDBScripts( $dburl, $dbusername, $dbpassword );
  } else {
    die "Error: The $database database machine could not be determined...\n $!";
  }
}

sub CreateMPMDBScripts() {
  my $file = "database.properties";
  my $archiveFile = "database-archive.properties";
  
  my $dburl = $_[0];
  my $dbusername = $_[1];
  my $dbpassword = $_[2];
  
  my $props = Config::Properties->new(wrap => 0);

  open my $fh, '>', $file
    or die "unable to open $file\n $!";

  open my $fhArchive, '>', $archiveFile
    or die "unable to open $archiveFile\n $!";
  
  $props = &SetProperty( $props, "spring.jta.enabled", "false" );
  $props = &SetProperty( $props, "datasource.init", "false" );
  $props = &SetProperty( $props, "datasource.testOnStartup", "false" );
  $props = &SetProperty( $props, "jdbc.datasourceName", "jdbc/MessageManagerDB" );
  $props = &SetProperty( $props, "jdbc.datasourceNameNoXA", "jdbc/MessageManagerDataSourceNoXA" );
  
  if( $database eq "oracle" ) {
    $props = &SetProperty( $props, "jdbc.driverName", "oracle.jdbc.xa.client.OracleXADataSource" );
    $props = &SetProperty( $props, "jdbc.nonXADriverName", "oracle.jdbc.xa.client.OracleXADataSource" );
    $props = &SetProperty( $props, "jdbc.validationQuery", "SELECT 1 FROM DUAL" );
    
    $props = &SetProperty( $props, "jdbc.url", $dburl );
    $props = &SetProperty( $props, "jdbc.username", $dbusername );
    $props = &SetProperty( $props, "jdbc.password", $dbpassword );
    
  } elsif( $database eq "db2luw" ) {
    $props = &SetProperty( $props, "jdbc.driverName", "com.ibm.db2.jcc.DB2XADataSource" );
    $props = &SetProperty( $props, "jdbc.nonXADriverName", "com.ibm.db2.jcc.DB2XADataSource" );
    $props = &SetProperty( $props, "jdbc.validationQuery", "SELECT 1 FROM SYSIBM.SYSDUMMY1" );
    
    $props = &SetProperty( $props, "jdbc.server", $dbhost );
    $props = &SetProperty( $props, "jdbc.databaseName", $db2luwDBName );
    $props = &SetProperty( $props, "jdbc.port", $db2luwDBPort );
    $props = &SetProperty( $props, "jdbc.schema", &FormatSchemaName() );
    $props = &SetProperty( $props, "jdbc.username", $dbusername );
    $props = &SetProperty( $props, "jdbc.password", $dbpassword );
    
  } elsif( $database eq "mssql" ) {
    $props = &SetProperty( $props, "jdbc.driverName", "com.microsoft.sqlserver.jdbc.SQLServerXADataSource" );
    $props = &SetProperty( $props, "jdbc.nonXADriverName", "com.microsoft.sqlserver.jdbc.SQLServerXADataSource" );
    $props = &SetProperty( $props, "jdbc.validationQuery", "SELECT 1" );
    
    $props = &SetProperty( $props, "jdbc.server", $dbhost );
    $props = &SetProperty( $props, "jdbc.databaseName", $mssqlDBName );
    $props = &SetProperty( $props, "jdbc.port", $mssqlPort );
    $props = &SetProperty( $props, "jdbc.url", $dburl );
    $props = &SetProperty( $props, "jdbc.username", $dbusername );
    $props = &SetProperty( $props, "jdbc.password", $dbpassword );
    
  } elsif( $database eq "db2i" ) {
    $props = &SetProperty( $props, "jdbc.driverName", "com.ibm.as400.access.AS400JDBCXADataSource" );
    $props = &SetProperty( $props, "jdbc.nonXADriverName", "com.ibm.as400.access.AS400JDBCXADataSource" );
    $props = &SetProperty( $props, "jdbc.validationQuery", "SELECT 1 FROM SYSIBM.SYSDUMMY1" );
    
    $props = &SetProperty( $props, "jdbc.server", $dbhost );
    $props = &SetProperty( $props, "jdbc.databaseName", &FormatSchemaName() );
    $props = &SetProperty( $props, "jdbc.username", $dbusername );
    $props = &SetProperty( $props, "jdbc.password", $dbpassword );
    
  } else {
    die "Error: The $database database machine could not be determined...\n $!";
  }
  
  $props = &SetProperty( $props, "jdbc.defaultAutoCommit", "false" );
  $props = &SetProperty( $props, "jdbc.accessToUnderlyingConnectionAllowed", "true" );
  $props = &SetProperty( $props, "jdbc.initialSize", "5" );
  $props = &SetProperty( $props, "jdbc.maxActive", "10" );
  $props = &SetProperty( $props, "jdbc.maxIdle", "-1" );
  $props = &SetProperty( $props, "jdbc.maxWait", "1800" );
  $props = &SetProperty( $props, "jdbc.testOnBorrow", "true" );
  $props = &SetProperty( $props, "jdbc.testOnReturn", "false" );
  $props = &SetProperty( $props, "jdbc.testWhileIdle", "false" );
  $props = &SetProperty( $props, "jdbc.timeBetweenEvictionRunsMillis", "-1" );
  $props = &SetProperty( $props, "jdbc.numTestsPerEvictionRun", "3" );
  $props = &SetProperty( $props, "jdbc.minEvictableIdleTimeMillis", "1800000" );
  
  $props->format( '%s=%s' );
  $props->store( $fh );
  
  if( $database eq "oracle" or $database eq "mssql" ) {
    $props = &SetProperty( $props, "jdbc.username", $dbusername . "A" );
    $props = &SetProperty( $props, "jdbc.password", $dbpassword . "A" );
  }
  
  if( $database eq "db2luw" ) {
    $props = &SetProperty( $props, "jdbc.schema", &FormatSchemaName() . "A" );
  }
  
  $props->store( $fhArchive );
  
}

sub CreateLiquibaseScript() {
  my $file = $_[0];
  
  my $jdbcurl = $_[1];
  my $dbdriver = $_[2];
  my $username = $_[3];
  my $password = $_[4];
  
  my $props = Config::Properties->new(wrap => 0);

  open my $fh, '>', $file
    or die "unable to open $file\n $!";
  
  $props = &SetProperty( $props, "classpath", $dbdriverFolder . "/" . $dbdriver );
  $props = &SetProperty( $props, "username", $username );
  $props = &SetProperty( $props, "password", $password );
  
  if( $database eq "oracle" ) {
    $props = &SetProperty( $props, "data.files.root", &GetOracleDataFileRootLocation() );
  }
  
  if( $database eq "db2i" ) {
    $props = &SetProperty( $props, "databaseClass", "liquibase.ext.db2i.database.DB2iDatabase" );
  }
  
  $props = &SetProperty( $props, "mainUrl", $jdbcurl );
  
  if( $database ne "db2i" ) {
    $props = &SetProperty( $props, "archiveUrl", $jdbcurl );
  } else {
    $props = &SetProperty( $props, "archiveUrl", $jdbcurl . "A" );
  }
  
  &SetDefaultLiquibaseProperties ( $props );
  
  $props->format( '%s: %s' );
  $props->store( $fh );
}

sub GetOracleDataFileRootLocation() {
  my $dbservermachine = lc $dbhost;
  my $rtn = "";
  if( $dbservermachine eq "mancswpam0010" ) {
    $rtn = "C:/OracleDB/oradata";
  } else {
      $rtn = "C:/oracle/oradata";
  }
}

sub SetDefaultLiquibaseProperties() {
  my $props = $_[0];
  my $schema = &FormatSchemaName();
  
  $props = &SetProperty( $props, "default.hostid", "MPM" );
  
  if( $database eq "oracle" ) {
  
    $props = &SetProperty( $props, "instance.name", "mxmdev" );
    $props = &SetProperty( $props, "main.schema", $schema );
    $props = &SetProperty( $props, "archive.schema", $schema . "A" );
    $props = &SetProperty( $props, "tablespace.data", $schema . "_DATA" );
    $props = &SetProperty( $props, "tablespace.index", $schema . "_IDX" );
    $props = &SetProperty( $props, "tablespace.arc.data", $schema . "A_DATA" );
    $props = &SetProperty( $props, "tablespace.arc.index", $schema . "A_IDX" );
    $props = &SetProperty( $props, "tablespace.temp", $schema . "TEMP" );
    $props = &SetProperty( $props, "logLevel", "debug" );
    $props = &SetProperty( $props, "driver", "oracle.jdbc.OracleDriver" );
    
    $props = &SetProperty( $props, "procs.table.name", "SYS.ALL_OBJECTS" );
    $props = &SetProperty( $props, "procs.schema.column.name", "OWNER" );
    $props = &SetProperty( $props, "procs.proc.column.name", "OBJECT_NAME" );
    
  } elsif( $database eq "db2luw" ) {
  
    $props = &SetProperty( $props, "instance.name", $db2luwDBName );
    $props = &SetProperty( $props, "main.schema", $schema );
    $props = &SetProperty( $props, "archive.schema", $schema . "A" );
    $props = &SetProperty( $props, "tablespace.data", $schema . "_DATA" );
    $props = &SetProperty( $props, "tablespace.index", $schema . "_IDX" );
    $props = &SetProperty( $props, "tablespace.long", $schema . "_LONG" );
    $props = &SetProperty( $props, "tablespace.arc.data", $schema . "A_DATA" );
    $props = &SetProperty( $props, "tablespace.arc.index", $schema . "A_IDX" );
    $props = &SetProperty( $props, "tablespace.arc.long", $schema . "A_LONG" );
    $props = &SetProperty( $props, "logLevel", "debug" );
    $props = &SetProperty( $props, "driver", "com.ibm.db2.jcc.DB2Driver" );
    
    $props = &SetProperty( $props, "procs.table.name", "SYSCAT.PROCEDURES" );
    $props = &SetProperty( $props, "procs.schema.column.name", "PROCSCHEMA" );
    $props = &SetProperty( $props, "procs.proc.column.name", "PROCNAME" );
    
  } elsif( $database eq "mssql" ) {
  
    $props = &SetProperty( $props, "instance.name", "M51Dev" );
    $props = &SetProperty( $props, "instance.archive.name", "M51Dev" );
    $props = &SetProperty( $props, "main.schema", $schema );
    $props = &SetProperty( $props, "archive.schema", $schema . "A" );
    $props = &SetProperty( $props, "logLevel", "debug" );
    $props = &SetProperty( $props, "driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver" );
    $props = &SetProperty( $props, "tablespace.data", "PRIMARY" );
    $props = &SetProperty( $props, "tablespace.index", "PRIMARY" );
    $props = &SetProperty( $props, "tablespace.arc.data", "PRIMARY" );
    $props = &SetProperty( $props, "tablespace.arc.index", "PRIMARY" );
    
    $props = &SetProperty( $props, "procs.table.name", "sys.procedures p join sys.schemas s on p.schema_id = s.schema_id" );
    $props = &SetProperty( $props, "procs.schema.column.name", "s.name" );
    $props = &SetProperty( $props, "procs.proc.column.name", "p.name" );
    
  } elsif( $database eq "db2i" ) {
  
    $props = &SetProperty( $props, "logLevel", "debug" );
    $props = &SetProperty( $props, "main.schema", $schema );
    $props = &SetProperty( $props, "archive.schema", $schema . "A" );
    $props = &SetProperty( $props, "driver", "com.ibm.as400.access.AS400JDBCDriver" );
    
    $props = &SetProperty( $props, "procs.table.name", "qsys2.sysprocs" );
    $props = &SetProperty( $props, "procs.schema.column.name", "specific_schema" );
    $props = &SetProperty( $props, "procs.proc.column.name", "routine_name" );
    
  } else {
    die "Error: The $database database machine could not be determined...\n $!";
  }
}

sub SetProperty {
  my $properties = $_[0];
  my $key = $_[1];
  my $value = $_[2];

  $properties->setProperty( $key, $value );

  return $properties;
}

sub FormatSchemaName() {
  my $rtn = "";
  
  my $machineIncrement = "";
  my $hostnamePrefix = "";
  my $hostnamePrefixSearch = "(MANC(SW|SS|SL)(PAM|IS))";
  
  if($hostname =~ /$hostnamePrefixSearch/i) {
    $hostnamePrefix = $1;
    $machineIncrement = substr($hostname, length($1), length($hostname));

    $rtn = "MPM" . $2 . ($machineIncrement+=0);
  } else {
    die "Invalid hostname entered [$hostname]...\n $!";
  }

  return uc $rtn;
}
