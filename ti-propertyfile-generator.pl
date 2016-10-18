#!/usr/bin/perl -w

use strict;
use Config::Properties;

my $globalFile;
my $jndiFile;
my $tiplus2File;
my $appserver;
my $database;
my $dbhost;
my $hostname;
my $os;
my $fbcc;

&Initialize();
&Process();

sub Initialize() {
  $globalFile = "global.configuration.properties";
  $jndiFile = "jndi.resource.locator.properties";
  $tiplus2File = "tiplus2.configuration.properties";
  
  my @params = split( /:/, $ARGV[1] );
  $database = $params[0];
  $dbhost = $params[1];
  
  $appserver = $ARGV[0];
  $hostname = $ARGV[2];
  $os = $ARGV[3];
  $fbcc = $ARGV[4];

  print "appserver=" . $appserver . "\ndatabase=" . $database . "\ndbhost=" . $dbhost . "\nhostname=" . $hostname . "\n"

}

sub Process {
  print "Entering Configuration Property File Process...\n";

  &CreateGlobalProperties();
  &CreateJNDIProperties();
  &CreateTiplus2Properties();

  print "Exiting Configuration Property File Process...\n";
}

sub CreateGlobalProperties() {
  my $props = Config::Properties->new;

  open my $fh, '>', $globalFile
    or die "unable to open $globalFile";

  $props = &SetProperty( $props, 'GlobalId', 'global' );

  &ChooseAppServer( $props );

  &ChooseDatabase( $props );

  $props = &SetProperty( $props, 'global.app.name', 'tiplus2-global' );
  $props = &SetProperty( $props, 'GlobalAppContext', 'tiplus2-global' );

  &SetGlobalURL( $props );

  $props = &SetProperty( $props, 'GlobalSchema', &FormatSchemaName() . "G" );
  $props = &SetProperty( $props, 'security.cas', 'yes' );

  &SetGlobalCASURL( $props );

  $props = &SetProperty( $props, 'JMXPrimaryHost', $hostname );
  $props = &SetProperty( $props, 'JMXSecondaryHost', '' );

  if( $appserver =~ /jboss7/i ) {
    $props = &SetProperty( $props, 'JMXGlobalPort', '4448' );
    $props = &SetProperty( $props, 'JMXProtocol', 'remoting-jmx' );
  } else {
    $props = &SetProperty( $props, 'JMXGlobalPort', '6999' );
    $props = &SetProperty( $props, 'JMXProtocol', 'rmi' );
  }

  $props = &SetProperty( $props, 'ShowSummaryErrorDetails', 'false' );
  $props = &SetProperty( $props, 'framework.exception.handler', 'framework.exception.handler.plain' );
  $props = &SetProperty( $props, 'global.processing.enabled', 'true' );

  $props->format( '%s=%s' );
  $props->store( $fh );

}

sub CreateTiplus2Properties() {
  my $props = Config::Properties->new;

  open my $fh, '>', $tiplus2File
    or die "unable to open $tiplus2File";

  $props = &SetProperty( $props, 'DeploymentId', 'TI1' );
  $props = &SetProperty( $props, 'ZoneId', 'ZONE1' );
  $props = &SetProperty( $props, 'tiplus2.app.name', 'tiplus2-zone1' );
  $props = &SetProperty( $props, 'TIPlus2AppContext', 'tiplus2-zone1' );
  
  &SetAPIStubs( $props );
  &SetZoneCASURL( $props );
  &SetCustomisation( $props );
  
  $props = &SetProperty( $props, 'JMXZonePortStart', '6101' );
  $props = &SetProperty( $props, 'JMXZonePortEnd', '6111' );
  $props = &SetProperty( $props, 'DefaultServiceUser', 'SUPERVISOR' );
  $props = &SetProperty( $props, 'DefaultEODUser', 'SUPERVISOR' );
  $props = &SetProperty( $props, 'ShowUserID', 'false' );
  
  my $rootFolder = '/';
  if( $os =~ /windows/i ) {
    $rootFolder = "C:/cygwin64/";
  }
  
  if( $fbcc ne "none" ) {
    &SetFBCCInterface( $props );
  }
  
  $props = &SetProperty( $props, 'csv.import.dir', $rootFolder . 'opt/tiplus2/csv/import' );
  $props = &SetProperty( $props, 'csv.export.dir', $rootFolder . 'opt/tiplus2/csv/export' );
  $props = &SetProperty( $props, 'translation.location', $rootFolder . 'opt/tiplus2/translations' );
  $props = &SetProperty( $props, 'framework.exception.handler', 'framework.exception.handler.plain' );
  $props = &SetProperty( $props, 'override.monitor.period', '60' );
  $props = &SetProperty( $props, 'override.transfer.postpone.period', '90' );

  $props->format( '%s=%s' );
  $props->store( $fh );

}

sub CreateJNDIProperties() {
  my $props = Config::Properties->new;

  open my $fh, '>', $jndiFile
    or die "unable to open $jndiFile";


  if( $appserver =~ /jboss[\d]+/  ) {
    $props = &SetProperty( $props, 'jndi.pattern', 'java:/${category}/${name}' );
    $props = &SetProperty( $props, 'jndi.jms.QueueConnectionFactory', 'java:/JmsXA' );
  } else {
    $props = &SetProperty( $props, 'jndi.pattern', '${category}/${name}' );
  }

  $props->format( '%s=%s' );
  $props->store( $fh );
}

sub SetProperty {
  my $properties = $_[0];
  my $key = $_[1];
  my $value = $_[2];

  $properties->setProperty( $key, $value );

  return $properties;
}

sub ChooseAppServer() {
  my $props = $_[0];

  if( $appserver =~ /weblogic/i ) {
    $props = &SetProperty( $props, 'appserver.weblogic', 'yes' );
  } elsif( $appserver =~ /websphere/i ) {
    $props = &SetProperty( $props, 'appserver.websphere', 'yes' );
  } elsif( $appserver =~ /jboss5/i ) {
    $props = &SetProperty( $props, 'appserver.jboss', 'yes' );
  } elsif( $appserver =~ /jboss7/i ) {
    $props = &SetProperty( $props, 'appserver.jboss', 'yes' );
    $props = &SetProperty( $props, 'appserver.jee6', 'yes' );
  } else {
    die "Error: An APPSERVER must be chosen\n $!";
  }

}

sub ChooseDatabase() {
  my $props = $_[0];

  if( $database =~ /oracle/i ) {
    $props = &SetProperty( $props, 'database.oracle', 'yes' );
  } elsif( $database =~ /db2/i ) {
    $props = &SetProperty( $props, 'database.db2', 'yes' );
  } elsif( $database =~ /mysql/i ) {
    $props = &SetProperty( $props, 'database.mysql', 'yes' );
  } else {
    die "Error: A DATABASE must be chosen\n $!";
  }
}

sub SetGlobalURL() {
  my $props = $_[0];

  if( $appserver =~ /weblogic/i ) {
    $props = &SetProperty( $props, 'GlobalURL', 'http://' . $hostname . ':7011/tiplus2-global' );
  } elsif( $appserver =~ /websphere/i ) {
    $props = &SetProperty( $props, 'GlobalURL', 'http://' . $hostname . ':9080/tiplus2-global' );
  } elsif( $appserver =~ /jboss[\d]+/ ) {
    $props = &SetProperty( $props, 'GlobalURL', 'http://' . $hostname . ':8080/tiplus2-global' );
  } else {
    die "Error: An APPSERVER must be chosen\n $!";
  }
}

sub SetGlobalCASURL() {
  my $props = $_[0];

  if( $appserver =~ /weblogic/i ) {
    $props = &SetProperty( $props, 'security.cas.server.url', 'https://' . $hostname . ':7012/tiplus2-global' );
    $props = &SetProperty( $props, 'security.cas.global.service', 'https://' . $hostname . ':7012/tiplus2-global' );
  } elsif( $appserver =~ /websphere/i ) {
    $props = &SetProperty( $props, 'security.cas.server.url', 'https://' . $hostname . ':9443/tiplus2-global' );
    $props = &SetProperty( $props, 'security.cas.global.service', 'https://' . $hostname . ':9443/tiplus2-global' );
  } elsif( $appserver =~ /jboss[\d]+/ ) {
    $props = &SetProperty( $props, 'security.cas.server.url', 'https://' . $hostname . ':8443/tiplus2-global' );
    $props = &SetProperty( $props, 'security.cas.global.service', 'https://' . $hostname . ':8443/tiplus2-global' );
  } else {
    die "Error: An APPSERVER must be chosen\n $!";
  }
}

sub SetAPIStubs() {
  my $props = $_[0];
  
  $props = &SetProperty( $props, 'service.access.apistubs', 'yes' );
  if( $database =~ /oracle/i ) {
    $props = &SetProperty( $props, 'service.access.apistubs.db.url', 'jdbc:oracle:thin:@' . $dbhost . ":1521:" . &GetDatabaseName() );
  } elsif( $database =~ /db2/i ) {
    $props = &SetProperty( $props, 'service.access.apistubs.db.url', 'jdbc:db2://' . $dbhost . ":50000/" . &GetDatabaseName() );
  } elsif( $database =~ /mysql/i ) {
    $props = &SetProperty( $props, 'service.access.apistubs.db.url', 'jdbc:mysql://' . $dbhost . ":3306/" . &GetDatabaseName() );
  } else {
    die "Error: A DATABASE must be chosen\n $!";
  }
  
  $props = &SetProperty( $props, 'service.access.apistubs.db.user', &FormatSchemaName() . "Z1" );
  if( $database =~ /db2/i ) {
    $props = &SetProperty( $props, 'service.access.apistubs.db.password', '12Kapiti' );
  } else {
    $props = &SetProperty( $props, 'service.access.apistubs.db.password', &FormatSchemaName() . "Z1" );
  }
  $props = &SetProperty( $props, 'service.access.apistubs.db.schema', &FormatSchemaName() . "Z1" );
  
}

sub GetDatabaseName() {
  my $rtn = "";
  
  if( $database =~ /oracle/i ) {
    $rtn = "TIPLUS2QA";
  } elsif( $database =~ /db2/i ) {
    $rtn = "TIP2QA";
  } elsif( $database =~ /mysql/i ) {
    $rtn =  &FormatSchemaName() . "Z1";
  } else {
    die "Error: A DATABASE must be chosen\n $!";
  }
  
  return $rtn;
}

sub SetCustomisation() {
  my $props = $_[0];
  
  $props = &SetProperty( $props, 'ui.customisation.show.page.context', 'false' );
  $props = &SetProperty( $props, 'ui.customisation.literals.file', 'file:///C:/translate/literals_example.xml' );
  $props = &SetProperty( $props, 'ui.customisation.literals.reload', '15000' );
  $props = &SetProperty( $props, 'ui.customisation.fragments.file', 'file:///C:/translate/GuiExtendedFeatures_example.xml' );
  $props = &SetProperty( $props, 'ui.customisation.fragments.merge', 'yes' );
  $props = &SetProperty( $props, 'ui.customisation.fragments.reload', '15000' );
  
}

sub SetZoneCASURL() {
  my $props = $_[0];

  if( $appserver =~ /weblogic/i ) {
    $props = &SetProperty( $props, 'security.cas.zone.service', 'https://' . $hostname . ':8012/tiplus2-zone1' );
  } elsif( $appserver =~ /websphere/i ) {
    $props = &SetProperty( $props, 'security.cas.zone.service', 'https://' . $hostname . ':9444/tiplus2-zone1' );
  } elsif( $appserver =~ /jboss[\d]+/ ) {
    $props = &SetProperty( $props, 'security.cas.zone.service', 'https://' . $hostname . ':8543/tiplus2-zone1' );
  } else {
    die "Error: An APPSERVER must be chosen\n $!";
  }
}

sub SetFBCCInterface() {
  my $props = $_[0];
  
    $props = &SetProperty( $props, 'service.access.jms', 'yes' );
  if( $fbcc eq "tpi" ) {
    $props = &SetProperty( $props, 'service.access.jms.tpi', 'yes' );
    $props = &SetProperty( $props, 'service.access.jms.tpi.systems', 'TPIMTPZ1' );
    $props = &SetProperty( $props, 'service.access.jms.tpi.client.services', '' );
    
    if( $appserver =~ /weblogic/i ) {
      $props = &SetProperty( $props, 'service.access.jms.tpi.xa', 'no' );
    } else {
      $props = &SetProperty( $props, 'service.access.jms.tpi.xa', 'yes' );
    }
    
  } elsif( $fbcc eq "ticc" ) {
    $props = &SetProperty( $props, 'service.access.jms.ticc', 'yes' );
    $props = &SetProperty( $props, 'service.access.jms.ticc.systems', 'TICCFBCCZ1' );
    $props = &SetProperty( $props, 'service.access.jms.ticc.client.services', '' );
    
    if( $appserver =~ /weblogic/i ) {
      $props = &SetProperty( $props, 'service.access.jms.ticc.xa', 'no' );
    } else {
      $props = &SetProperty( $props, 'service.access.jms.ticc.xa', 'yes' );
    }
    
  } else {
    die "Error: An APPSERVER must be chosen\n $!";
  }
}

sub FormatSchemaName() {
  my $rtn = "";
  
  my $machineIncrement = "";
  my $hostnamePrefix = "";
  my $hostnamePrefixSearch = "(MAN(C|V)(SW|SS|SL)(IS|MANTI|TIFIX|TIQA|TIPLUS))";
  
  if($hostname =~ /$hostnamePrefixSearch/i) {
    $hostnamePrefix = $1;
    $machineIncrement = substr($hostname, length($1), length($hostname));

    if(lc $4 eq "manti") {
      $rtn = $3 . "ti" . ($machineIncrement+=0);
    } else {
      $rtn = $4 . ($machineIncrement+=0);
    }
  } else {
    print "Invalid hostname entered";
    die;
  }

  return uc $rtn;
}


