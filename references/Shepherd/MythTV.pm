#
# Shepherd::MythTV library

my $version = '0.20';

# This module provides some library functions for Shepherd components,
# relieving them of the need to duplicate functionality.
#
# To use this library, components simply need to include the line:
#
#   use Shepherd::MythTV;
#
# To make a single quick query:
#   Shepherd::MythTV::query($sql)
# ... where $sql is an SQL statement. This will establish a database
# connection and close if following the query.
#
# If instead you'd like to make multiple queries, open and close the 
# DB connection yourself:
#   Shepherd::MythTV::open_connection();
#   while (...) {
#      Shepherd::MythTV::query($sql);
#   }
#   Shepherd::MythTV::close_connection();
#
# Shepherd::MythTV::open_connection() returns the $dbh object if
# successful, so you can manipulate connections yourself too.
#

package Shepherd::MythTV;

use DBI;
use XML::Simple;

my $dbh;
my $db;
my @tried;

sub find_database_settings_file
{
    my $cfgfile = shift;

    $cfgfile = &standard_mysql_locations unless ($cfgfile);

    foreach my $f (split(/:/,$cfgfile)) 
    {
	next if (grep ($f eq $_, @tried));
	return $f if ((-f $f) && (-r $f));
    }

    print "\nWARNING: Could not find valid MythTV mysql.txt config file!\n".
          "Looked in: $cfgfile\n";
    return undef;
}

sub standard_mysql_locations
{
    return "/etc/mythtv/config.xml".
	   ":/usr/local/share/mythtv/mysql.txt".
           ":/usr/share/mythtv/mysql.txt".
	   ":$ENV{HOME}/.mythtv/mysql.txt".
	   ":/home/mythtv/.mythtv/mysql.txt".
	   ":/root/.mythtv/mysql.txt".
	   ":/etc/mythtv/mysql.txt";
}

# Find MythTV database settings
# 
sub setup
{
    my $cfgfile = shift;

    $cfgfile = &find_database_settings_file() unless ($cfgfile);
    return unless ($cfgfile);

    print "Reading MythTV DB settings from: $cfgfile\n";
    $db->{cfgfile} = $cfgfile;

    if ($cfgfile =~ /\.xml$/)
    {
	my $xs = XML::Simple->new();
	my $xml = $xs->XMLin($cfgfile);

	my $fieldnames = { 
	    # Name we store => Name of field in config.xml
	    'DBName' => 'DatabaseName',
	    'DBHostName' => 'Host',
	    'DBUserName' => 'UserName',
	    'DBPassword' => 'Password',
	    'DBPort' => 'Port',
	    'DBPingHost' => 'PingHost',
	};

	foreach my $field (keys %$fieldnames)
	{
	    $db->{$field} = (
		# Format as described by:
		# http://code.mythtv.org/trac/browser/mythtv/mythtv/contrib/config_files/config.xml
		$xml->{'Database'}->{$fieldnames->{$field}}
		    or
		# Format that actually seems to be used
		$xml->{'UPnP'}->{'MythFrontend'}->{'DefaultBackend'}->{$field}
	    );
	}
    }
    else
    {
	unless (open(F,"<$cfgfile")) 
	{
	    print "ERROR: Couldn't read $cfgfile: $!\n";
	    return undef;
	}

	while (<F>) 
	{
	    chomp;
	    $db->{$1} = $2 if ($_ =~ /^(DB.*?)=(.*)/);
	}
	close(F);
    }

    return 1;
}

# 
# Send an SQL query to the MythTV DB. Will try standard locations to 
# find the MythTV mysql.txt file; if you want to specify a non-standard
# location, first call Shepherd::MythTV::setup($file_location), where
# $file_location is a colon-separated string of (potential) filenames.
#
# Note that data is returned in array form.
#
sub query
{
    my $sql = shift;

    my $leave_open = 1;
    unless ($dbh)
    {
	&open_connection or return undef;
	$leave_open = 0;
    }

    my @ret = $dbh->selectrow_array($sql);

    &close_connection unless ($leave_open);
    return @ret;
}

sub open_connection
{
    &setup() unless ($db);

    unless ($db->{DBName} and $db->{DBHostName} and $db->{DBUserName} and $db->{DBPassword})
    {
	print "ERROR: Missing essential DB connection info.\n";
	return undef;
    }

    my $counter = 0;
    while (!($dbh = DBI->connect(
		"dbi:mysql:database=".$db->{DBName}.":host=".$db->{DBHostName},
		$db->{DBUserName}, $db->{DBPassword})))
    {
	# Sanity check; should never be required but we don't want infinite loops here!
	last if ($counter++ > 10);

	push @tried, $db->{cfgfile};
	last unless (&setup);
    }
    unless ($dbh)
    {
	print "Couldn't connect to database $db->{DBName}.\n";
	return undef;
    }
    return $dbh;
}

sub close_connection
{
    $dbh->disconnect() if ($dbh);
    undef $dbh;
}

die "No DBI mysql support, please install!\n" if !grep /mysql/, DBI->available_drivers;

1;
