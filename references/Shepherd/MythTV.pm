#
# Shepherd::MythTV library

my $version = '0.32';

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

use strict;
use warnings;

use DBI;
use XML::Simple;

my $dbh;
my $db;
my @tried;

#
# Find MythTV database settings
# 
sub setup
{
    my $cfgfile = shift;

    my @settings_files = (( $cfgfile ) or (  
	"$ENV{HOME}/.mythtv/config.xml",
	"/etc/mythtv/config.xml",
	"/usr/local/share/mythtv/mysql.txt",
	"/usr/share/mythtv/mysql.txt",
	"$ENV{HOME}/.mythtv/mysql.txt",
	"/home/mythtv/.mythtv/mysql.txt",
	"/root/.mythtv/mysql.txt",
	"/etc/mythtv/mysql.txt",
    ));

    local *F;
    my $success = 0;
    foreach $cfgfile (@settings_files)
    {
	next if (grep ($_ eq $cfgfile, @tried));
	print "Looking for MythTV DB connection info in $cfgfile.\n";
	next unless (-f $cfgfile);

	if ($cfgfile =~ /\.xml$/)
	{
	    my $xs = XML::Simple->new();
	    my $xml = eval { $xs->XMLin($cfgfile) };
	    if ($@)
	    {
		print "Error from XML::Simple: $@\n";
	    }
	    next unless (ref $xml);

	    if ($xml)
	    {
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
	}
	elsif (open(F,$cfgfile)) 
	{
	    while (<F>) 
	    {
		chomp;
		$db->{$1} = $2 if ($_ =~ /^(DB.*?)=(.*)/);
	    }
	    close(F);
	}
	if ($db->{DBName} and $db->{DBHostName} and $db->{DBUserName} and $db->{DBPassword})
	{
	    $success = 1;
	    $db->{cfgfile} = $cfgfile;
	    print "Using MythTV DB settings from: $cfgfile\n";
	    last;
	}
	else
	{
	    $db = { };
	}
    }

    unless ($success)
    {
	print "ERROR: Could not find info to establish database connection to MythTV.\n";
	return undef;
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
