#!/usr/bin/perl
#
# Shepherd::Common library

my $version = '0.30';

#
# This module provides some library functions for Shepherd components,
# relieving them of the need to duplicate functionality.
#
# To use this library, components simply need to include the line:
#
#   use Shepherd::Common;

package Shepherd::Common;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use Compress::Zlib;
use Storable;
use Data::Dumper;
use POSIX qw(strftime mktime);
use Getopt::Long;

my $gmt_offset;
my $ua;
my $socks_ip, my $socks_port;
my %defaults;
my $prev_referer = "";
my ($last_request, $last_failed_request) = (0, 0);

sub program_begin
{
	my ($oo, $program_name, $version_number, $stats) = @_;
	my $o = $$oo;

	$o->{program_name}	= $program_name;
	$o->{version_number}	= $version_number;
	$o->{script_start_time}	= time;

	$o->{offset}		= 0			if !defined $o->{offset};
	$o->{days}		= 7			if !defined $o->{days};
	$o->{outputfile}	= "output.xmltv"	if !defined $o->{outputfile};
	$o->{cache_file}	= $program_name.".storable.cache" if !defined $o->{cache_file};
	$o->{lang}		= "en"			if !defined $o->{lang};
	$o->{region}		= 75			if !defined $o->{region};

	GetOptions(
		'log-http'	=> \$o->{log_http},
		'region=i'	=> \$o->{region},
		'days=i'	=> \$o->{days},
		'offset=i'	=> \$o->{offset},
		'timezone=s'	=> \$o->{timezone},
		'channels_file=s' => \$o->{channels_file},
		'gaps_file=s'	=> \$o->{gaps_file},
		'output=s'	=> \$o->{outputfile},
		'cache-file=s'	=> \$o->{cache_file},
		'fast'		=> \$o->{fast},
		'no-cache'	=> \$o->{no_cache},
		'no-details'	=> \$o->{no_details},
		'debug+'	=> \$o->{debug},
		'all_channels'	=> \$o->{all_channels},
		'warper'	=> \$o->{warper},
		'lang=s'	=> \$o->{lang},
		'obfuscate'	=> \$o->{obfuscate},
		'anonsocks=s'	=> \$o->{anon_socks},
		'help'		=> \$o->{help},
		'verbose'	=> \$o->{help},
		'version'	=> \$o->{version},
		'ready'		=> \$o->{version},
		'v'		=> \$o->{version});

	if ($o->{version}) {
		Shepherd::Common::log(sprintf "%s v%s",$o->{program_name},$o->{version_number});
		exit(0);
	}

	&help($o) if ($o->{help});

	Shepherd::Common::log(sprintf "%s v%s going to %sgrab %d days%s of data into %s (%s%s%s)",
		$o->{program_name}, $o->{version_number},
		(defined $o->{gaps_file} ? "micro-gap " : ""),
		$o->{days},
		($o->{offset} ? " (skipping first $o->{offset} days)" : ""),
		$o->{outputfile},
		(defined $o->{fast} ? "with haste" : "slowly"),
		(defined $o->{anon_socks} ? ", via multiple endpoints" : ""),
		(defined $o->{warper} ? ", anonymously" : ""),
		(defined $o->{no_details} ? ", without details" : ", with details"),
		(defined $o->{no_cache} ? ", without caching" : ", with caching"));


	Shepherd::Common::set_default("debug", (defined $o->{debug} ? 2 : 0));
	Shepherd::Common::set_default("webwarper", 1) if (defined $o->{warper});
	Shepherd::Common::set_default("squid", 1) if (defined $o->{obfuscate});
	Shepherd::Common::set_default("referer", "last");
	Shepherd::Common::set_default("delay" => "0-4") if (!defined $o->{fast} && !defined $o->{debug});
	Shepherd::Common::set_default("retry_delay", 10);
	Shepherd::Common::set_default(stats => $stats);
	Shepherd::Common::setup_socks($o->{anon_socks}) if (defined $o->{anon_socks});

	$$oo = $o;
}

sub help
{
	my $o = shift;

	print<<EOF
$o->{program_name} v$o->{version_number}

options are as follows:
	--help			show these help options
	--days=N		fetch 'n' days of data (default: $o->{days})
	--output=file		send xml output to file (default: "$o->{outputfile}")
	--no-cache		don't use a cache to optimize (reduce) number of web queries
	--no-details		don't fetch detailed descriptions (default: do)
	--cache-file=file	where to store cache (default "$o->{cache_file}")
	--fast			don't run slow - get data as quick as you can - not recommended
	--anonsocks=(ip:port)	use SOCKS4A server at (ip):(port) (for Tor: recommended)

	--debug			increase debug level
	--warper		fetch data using WebWarper web anonymizer service
	--obfuscate		pretend to be a proxy servicing multiple clients
	--lang=[s]		set language of xmltv output data (default $o->{lang})

	--channels_file=file	where to get channel data from
	--gaps_file=file	micro-fetch gaps only
	--region=N		set region for where to collect data from (default: $o->{region})

EOF
;

	exit(0);
}

sub read_channels
{
	my ($o, @supported_channels) = @_;

	die "No channel file specified, see --help for instructions.\n", if (!$o->{channels_file});

	my ($channels, $opt_channels);
	if (-r $o->{channels_file}) {
		local (@ARGV, $/) = ($o->{channels_file});
		no warnings 'all'; eval <>; die "$@" if $@;
	} else {
		die "Channels file $o->{channels_file} could not be read: $!\n";
	}

	if (@supported_channels > 0) {
		my $found = 0;
		foreach (@supported_channels) {
			if (exists $channels->{$_} || exists $opt_channels->{$_}) {
				$found = 1;
				last;
			}
		}
		die "No supported channels found. (channels:".
				join(",", keys %$channels).", opt_channels:".
				join(",", keys %$opt_channels).")\n"
				if ($found != 1);
	}

	my $gaps;
	if (defined $o->{gaps_file}) {
		if (-r $o->{gaps_file}) {
			local (@ARGV, $/) = ($o->{gaps_file});
			no warnings 'all'; eval <>; die "$@" if $@;
		} else {
			die "Gaps file $o->{gaps_file} could not be read: $!\n";
		}

		if (@supported_channels > 0) {
			my $found = 0;
			foreach (@supported_channels) {
				if (exists $gaps->{$_}) {
					$found = 1;
					last;
				}
			}
			die "No supported channels in gaps file found. (channels:".
					join(",", keys %$gaps).")\n"
					if ($found != 1);
		}


	}

	return ($channels, $opt_channels, $gaps);
}

sub program_end
{
	my ($o, %stats) = @_;
	printf "STATS: %s v%s completed in %d seconds",
			$o->{program_name}, $o->{version_number}, (time - $o->{script_start_time});
	foreach my $key (sort keys %stats) {
		printf ", %d %s",$stats{$key},$key;
	}
	printf "\n";
}

##########################################################################
# get_url
#
# Simple version:
# $content = Shepherd::Common::get_url('http://www.example.com');
# 
# Or send a hash of options:
# $content = Shepherd::Common::get_url(url => 'http://www.example.com',
#                                      retries => 0, retry_delay => 60);
# 
# May also call in list context for more status info (see below):
# @response = Shepherd::Common::get_url(url => 'http://www.example.com',
#                                       fake => 0, debug => 5);
#
# Takes a hash of options. Only 'url' is required; all others are optional:
#   url           : The URL to fetch
#   method        : GET, POST or HEAD (default: GET, unless sent 'postvars')
#   mirror        : stores into the given filename, updating only when non-existing or newer
#   postvars      : variables to send in a POST (default: <none>)
#   retries       : # of times to try to fetch URL (default: 2)
#   delay         : seconds to sleep between fetches (default: 0)
#   retry_delay   : seconds to sleep between failed fetches (default: 10)
#   webwarper     : whether to use webwarper (default: 0)
#   referer       : what to set 'Referer' string to (default: <none>)
#   ua            : a LWP::UserAgent object (default: <will create new one>)
#   fake          : fake User Agent to imitate a random browser (default: 1)
#   squid         : obfuscate IP by imitating Squid proxy (default: 0)
#   gzip          : GZip compression support (default: 1)
#   headers       : ref to array of any additional headers (default: <none>)
#   debug         : set debug level; 0 = silent, 5 = noisy (default: 1)
#   stats         : reference to stats hash (see below)
# 
# If called in list context, returns an array:
# 0. content (string)
# 1. success (boolean: 1 indicates success)
# 2. status/error_message (string)
# 3. bytes fetched (integer)
# 4. seconds_slept_for (integer)
# 5. number of failed attempts (integer)
# 6. HTTP::Response object
#
# If called in scalar context, returns the content downloaded, or undef if 
# the download failed (which includes getting things like 401 pages).
#
# 'stats'
# If sent a reference as an arg to 'stats' (eg: stats => \%stats), will
# populate with statistics for:
#   slept_for           Number of seconds spent sleeping
#   bytes_fetched       Number of bytes downloaded
#   failed_requests     Number of failed attempted downloads
#   successful_requests Number of pages sucessfully downloaded
# If any of these fields already exist, they will be modified, not
# overwritten -- so you can send along your existing stats hash and
# it won't be reset, just added to.
#
# 'delay' and 'retry_delay'
# This library tracks how long it has been since the last request
# and makes sure not to launch a new request more often than every X
# seconds. The time to sleep can be specified either as an integer
# (EG: delay => 10) or a string range (EG: delay => "1-5"), in which
# case a random integer is chosen from that range. Upon failure,
# we will sleep for 'retry_delay' if that is specified; otherwise
# for 'delay'.
#
# It makes sense to set many/most of these variables once only via the
# set_default() or set_defaults() functions. EG:
#   Shepherd::Common::set_defaults( stats => \%stats, delay => "5-10");
#
sub get_url
{
    my %cnf;
    if (@_ == 1)
    {
	$cnf{url} = shift;
    }
    else
    {
	%cnf = @_;
    }

    # App defaults
    foreach my $k (keys %defaults) {
	$cnf{$k} = $defaults{$k} unless (defined $cnf{$k});
    }

    # Defaults
    $cnf{method} = 'GET' unless (defined $cnf{method});
    $cnf{retries} = 2 unless (defined $cnf{retries});
    $cnf{fake} = 1 unless (defined $cnf{fake});
    $cnf{gzip} = 1 unless (defined $cnf{gzip});
    $cnf{delay} = 0 unless (defined $cnf{delay});
    $cnf{retry_delay} = 10 unless (defined $cnf{retry_delay} or $cnf{delay});
    $cnf{debug} = 1 unless (defined $cnf{debug});

    $this_url = $cnf{url};

    # User Agent
    $ua = $cnf{ua} if ($cnf{ua});
    &setup_ua(%cnf) unless (ref $ua);

    # Webwarper
    if ($cnf{webwarper})
    {
	$cnf{url} =~ s#^http://#http://webwarper.net/ww/#;
	print "Using WebWarper.\n" if ($cnf{debug} > 2);
    }

    # Method
    my $request;
    if ($cnf{method} eq "HEAD") 
    {
	$request = HEAD $cnf{url};
    }
    elsif ($cnf{method} eq "POST" or $cnf{postvars}) 
    {
	$request = POST $cnf{url}, Content => $cnf{postvars};
    }
    else
    {
	$request = GET $cnf{url};
    }

    # GZip Compression
    $request->header('Accept-Encoding' => 'gzip') unless (!$cnf{gzip});

    # Referer
    if (defined $cnf{referer})
    {
	if ($cnf{referer} eq "last")
	{
	    $request->header('Referer' => $prev_referer) if ($prev_referer ne "");
	} else {
	    $request->header('Referer' => $cnf{referer});
	}
    }

    # Squid IP masking
    if ($cnf{squid})
    {
	my $randomaddr = sprintf "203.%d.%d.%d",rand(255),rand(255),(rand(254)+1);
	$request->header('Via' => '1.0 proxy:81 (Squid/2.3.STABLE3)');
	$request->header('X-Forwarded-For' => $randomaddr);
    }

    # Don't print out passwords
    my $urlname = $cnf{url};
    $urlname =~ s/:[^:]+@/:********@/g;

    # Additional Headers
    if ($cnf{headers})
    {
        foreach my $additional_header (@{$cnf{headers}})
        {
            my ($header, $value) = split(/: /,$additional_header);
            $request->header($header, $value);
        }
    }

    if ($cnf{debug} > 4)
    {
	print "Prepared request: " . Dumper($request) . "\n";
    }

    # Sleep if less than specified delay since last request
    my $slept_for = check_delay(\%cnf);

    # Fetch!
    my $response;
    my $success;
    my $failures = 0;
    my $bytes;
    for (0 .. $cnf{retries}) 
    {
	if ($cnf{debug})
	{
	    print "Fetching $urlname";
	    printf "%s...\n",
	           ($cnf{debug} > 1 ? " (attempt ".($failures+1)." of ".($cnf{retries}+1).")" : '');
	}

	if (not $cnf{mirror}) {
	    $response = $ua->request($request);
	} else {
	    $response = mirror($ua, $request, $cnf{mirror}); # use our mirror
	}
	$last_request = time;
	if ($cnf{debug} > 2)
	{
	    print "Response: " . $response->status_line . "\n";
	}

	$bytes = do { use bytes; length($response->content) };
	$bytes = 0 if ($cnf{mirror} && !$response->is_success && !$response->is_error);
	add_stat('bytes', $bytes, $cnf{stats});

	$success = 1 unless ($response->is_error);
	last if ($success);

	$success = 0;	# Make it boolean, not an empty string
	$failures++;
	$last_failed_request = time;
	add_stat('failed_requests', 1, $cnf{stats});
	print "Attempt $failures failed to fetch $urlname\n";
	if ($failures <= $cnf{retries})
	{
	    $slept_for += check_delay(\%cnf, 'retry_delay');
	}
	else
	{
	    print "Failed to retrieve $urlname: " . $response->status_line . "\n";
	}
    }

    if ($response->header('Content-Encoding') && 
	$response->header('Content-Encoding') eq 'gzip') 
    {
	$response->content(Compress::Zlib::memGunzip($response->content));
    }

    if ($success)
    {
	add_stat('successful_requests', 1, $cnf{stats});
	if ($cnf{debug})
	{
	    printf "Successfully fetched %s.\n",
               ($bytes >= 1024 ? (int($bytes/1024) . " KB") : "$bytes bytes");
	}
    }

    # Record last URL we fetched
    $prev_referer = $this_url;

    # If called in list context, return all our goodies
    if (wantarray)
    {
	return ($response->content,
	        $success,
		$response->status_line,
		$bytes,
		$slept_for,
		$failures,
		$response);
    }

    # If called in scalar context, just return content or undef
    return $response->content if ($success);
    return undef;
}

# our mirror uses a $request object and returns content
sub mirror
{
    my($self, $request, $file) = @_;

    if (-e $file) {
	my($mtime) = (stat($file))[9];
	if($mtime) {
	    $request->header('If-Modified-Since' =>
			     HTTP::Date::time2str($mtime));
	}
    }
    my $tmpfile = "$file-$$";

    my $response = $self->request($request, $tmpfile);
    if ($response->is_success) {

	my $file_length = (stat($tmpfile))[7];
	my($content_length) = $response->header('Content-length');

	if (defined $content_length and $file_length < $content_length) {
	    unlink($tmpfile);
	    die "Transfer truncated: " .
		"only $file_length out of $content_length bytes received\n";
	}
	elsif (defined $content_length and $file_length > $content_length) {
	    unlink($tmpfile);
	    die "Content-length mismatch: " .
		"expected $content_length bytes, got $file_length\n";
	}
	else {
	    # OK
	    if (-e $file) {
		# Some dosish systems fail to rename if the target exists
		chmod 0777, $file;
		unlink $file;
	    }
	    rename($tmpfile, $file) or
		die "Cannot rename '$tmpfile' to '$file': $!\n";

	    if (my $lm = $response->last_modified) {
		# make sure the file has the same last modification time
		utime $lm, $lm, $file;
	    }
	}
    }
    else {
	unlink($tmpfile);
    }

    if (!$response->is_error) {
	open(FILE, $file) || die "Can't read $file: $!";
	my @lines = <FILE>;
	close FILE;
	$response->content(join(' ',@lines));
    }

    return $response;
}

# Sleep if it's been less than the specified min. seconds since our
# last request.
sub check_delay
{
    my ($cnf, $type) = @_;

    my $delay = (($type and defined $cnf->{$type}) ? $cnf->{$type} : $cnf->{delay});
    if ($delay =~ /(\d+)-(\d+)/)
    {
	$delay = int($1 + rand($2 - $1) + 0.5);
    }
    $delay -= time - (($type and $type eq 'retry_delay') ? $last_failed_request : $last_request);
    return 0 unless ($delay > 0);
    print "Sleeping for $delay seconds...\n" if ($cnf->{debug});
    sleep $delay;
    add_stat('slept_for', $delay, $cnf->{stats});
    return $delay;
}

sub add_stat
{
    my ($name, $val, $statref) = @_;
    if (ref $statref)
    {
	if ($statref->{$name})
	{
	    $statref->{$name} += $val;
	}
	else
	{
	    $statref->{$name} = $val;
	}
    }
}

# Creates a user-agent object to be used for all future get_url() calls.
sub setup_ua
{
    my %cnf = @_;
    $cnf{debug} = 1 if (!defined $cnf{debug});

    print "Establishing user agent.\n" if ($cnf{debug} > 3);

    $ua = LWP::UserAgent->new( keep_alive => 1 );
    $ua->env_proxy();

    my @agent_list = (
	'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.3) Gecko/20070309 Firefox/2.0.0.3',
	'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.11) Gecko/20070312 Firefox/1.5.0.11',
	'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-GB; rv:1.8.1.3) Gecko/20070309 Firefox/2.0.0.3',
	'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.3) Gecko/20061201 Firefox/2.0.0.3 (Ubuntu-feisty)',
	'Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.8.1.3) Gecko/20070309 Firefox/2.0.0.3',
	'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)',
	'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)',
	'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322)',
	'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)',
	'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/85.8.5 (KHTML, like Gecko) Safari/85.8.1',
	'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.7.6) Gecko/20050512 Firefox',
	'Opera/9.10 (X11; Linux i686; U; en)',
	'Opera/9.10 (Windows NT 5.2; U; en)',
	'Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)',
	'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/412 (KHTML, like Gecko) Safari/412',
	'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-us) AppleWebKit/418.9 (KHTML, like Gecko) Safari/419.3',
	'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; fr) AppleWebKit/418.9 (KHTML, like Gecko) Safari/419.3'
    );

    my $agent = ($cnf{fake} ? $agent_list[int(rand($#agent_list+1))] : ($cnf{agent} ? $cnf{agent} : 'Shepherd'));
    $ua->agent($agent);
		
    print "User Agent string set to \"" . $ua->agent() . "\".\n" if ($cnf{debug} > 3); 

    $ua->cookie_jar({}) if (defined $cnf{cookie_jar});

    push @{ $ua->requests_redirectable }, 'POST';

    return $ua;
}

##########################################################################
# helper routine to set default settings so they don't need to be passed
# in every time

# EG: Shepherd::Common::set_default("squid", 1)
sub set_default
{
	my ($name, $value) = @_;
	$value = 0 if ($name eq 'debug' and !defined $value);
	$defaults{$name} = $value;
}

# EG: Shepherd::Common::set_defaults( squid => 1, retries => 2)
sub set_defaults
{
    my %h = @_;
    foreach (keys %h)
    {
	set_default($_, $h{$_});
    }
}

##########################################################################
# descend a structure and clean up various things, including stripping
# leading/trailing spaces in strings, translations of html stuff etc
#   -- taken & modified from Michael 'Immir' Smith's excellent tv_grab_au

sub cleanup {
    my $x = shift;
    my %amp = ( nbsp => ' ', qw{ amp & lt < gt > apos ' quot " } );

    if    (ref $x eq "REF")   { cleanup($_) }
    elsif (ref $x eq "HASH")  { cleanup(\$_) for values %$x }
    elsif (ref $x eq "ARRAY") { cleanup(\$_) for @$x }
    elsif (defined $$x) {
	$$x =~ s/&(#(\d+)|(.*?));/ $2 ? chr($2) : $amp{$3}||' ' /eg;
	$$x =~ s/[^\x20-\x7f\x0a]/ /g;
	$$x =~ s/(^\s+|\s+$)//g;
    }
}


##########################################################################
# strptime type date parsing - BUT - if no timezone is present, treat
# time as being in localtime rather than the various other perl
# implementation which treat it as being in UTC/GMT

sub parse_xmltv_date
{
    my $datestring = shift;
    my @t; # 0=sec,1=min,2=hour,3=day,4=month,5=year,6=wday,7=yday,8=isdst
    my $tz_offset = 0;

    # work out GMT offset - we only do this once
    if (!$gmt_offset) {
	my $tzstring = strftime("%z", localtime(time));

	$gmt_offset = (60*60) * int(substr($tzstring,1,2));     # hr
	$gmt_offset += (60 * int(substr($tzstring,3,2)));       # min
	$gmt_offset *= -1 if (substr($tzstring,0,1) eq "-");    # +/-
    }

    if ($datestring =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/) {
	($t[5],$t[4],$t[3],$t[2],$t[1],$t[0]) = (int($1)-1900,int($2)-1,int($3),int($4),int($5),0);
	($t[6],$t[7],$t[8]) = (-1,-1,-1);

	# if input data has a timezone offset, then offset by that
	if ($datestring =~ /\+(\d{2})(\d{2})/) {
	    $tz_offset = $gmt_offset - (($1*(60*60)) + ($2*60));
	} elsif ($datestring =~ /\-(\d{2})(\d{2})/) {
	    $tz_offset = $gmt_offset + (($1*(60*60)) + ($2*60));
	}

	my $e = mktime(@t);
	return ($e+$tz_offset) if ($e > 1);
    }
    return undef;
}

##########################################################################
# setup SOCKS proxy override for LWP and test that it works

sub setup_socks
{
    $socks_server = shift;
    ($socks_ip,$socks_port) = split(/:/,$socks_server);

    use LWP::Protocol::http;
    my $orig_new_socket = \&LWP::Protocol::http::_new_socket;

    # override LWP::Protocol::http's _new_socket method with our own
    local($^W) = 0;
    *LWP::Protocol::http::_new_socket = \&socks_new_socket;

    # test that it works
    my $data = &get_url(url => "http://www.google.com/", retries => 10);
    return 1 if (($data) && ($data =~ /Google/i));

    # failed
    *LWP::Protocol::http::_new_socket = $orig_new_socket;
    return 0;
}

##############################################################################
# our own SOCKS4Aified version of LWP::Protocol::http::_new_socket

sub socks_new_socket
{
    my($self, $host, $port, $timeout) = @_;

    $socks_ip = "127.0.0.1" if (!defined $socks_ip);
    $socks_port = "9050" if (!defined $socks_port);

    local($^W) = 0;  # IO::Socket::INET can be noisy
    my $sock = $self->socket_class->new(
	PeerAddr => $socks_ip,
	PeerPort => $socks_port,
	Proto    => 'tcp');

    unless ($sock) {
	# IO::Socket::INET leaves additional error messages in $@
	$@ =~ s/^.*?: //;
	printf "Can't connect to $host:$port ($@)\n";
	return undef;
    }

    # perl 5.005's IO::Socket does not have the blocking method.
    eval { $sock->blocking(0); };

    # establish connectivity with socks server - SOCKS4A protocol
    print { $sock } pack("CCnN", 0x04, 0x01, $port, 1) . (pack 'x') . $host . (pack 'x');

    my $received = "";
    my $timeout_time = time + $timeout;
    while ($sock->sysread($received, 8) && (length($received) < 8) ) {
	select(undef, undef, undef, 0.25);
	last if ($timeout_time < time);
    }

    if ($timeout_time < time) {
	printf "Timeout ($timeout) while connecting via SOCKS server\n";
	return $sock;
    }

    my ($null_byte, $req_status, $port_num, $ip_addr) = unpack('CCnN',$received);
    printf "Connection via SOCKS4A server rejected or failed\n" if ($req_status == 0x5b);
    printf "Connection via SOCKS4A server because client is not running identd\n" if ($req_status == 0x5c);
    printf "Connection via SOCKS4A server because client's identd could not confirm the user\n" if ($req_status == 0x5d);

    $sock;
}

##########################################################################

sub urlify
{
    my $str = shift;
    $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
    $str =~ s/%20/+/g;
    $str =~ s/%2D/-/g;
    return $str;
}

##############################################################################

sub translate_category
{
    my $genre = shift;
    my %translation = (
        'Sport' => 'sports',
        'Soap Opera' => 'Soap',
        'Science and Technology' => 'Science/Nature',
        'Real Life' => 'Reality',
        'Cartoon' => 'Animation',
        'Family' => 'Children',
        'Murder' => 'Crime' );
    return $translation{$genre} if defined $translation{$genre};
    return $genre;
}

##########################################################################

# if no category then guess from title for Sport, News, Infomercial
# translates the words in category
# types (final,premiere,return,live) are prepend to category
# types (movie,sports,series,tvshow) are appended to category list
sub generate_category
{
    my ($title, $category, %type) = @_;

    $type{sports} = 1 if ($title && $title=~/(^|\W)Sports?(\W|$)/i);
    $type{sports} = 1 if ($category && $category=~/(^|\W)Sports?(\W|$)/i);

    if ($category) {
        if ($category eq "movie") {
            $category = "Movie";
            $type{movie} = 1;
        } elsif ($category eq "sports") {
            $category = "Sports";
            $type{sports} = 1;
        } elsif ($category eq "series") {
            $category = "Series";
            $type{series} = 1;
        } elsif ($category eq "tvshow") {
            $category = "TVShow";
            $type{tvshow} = 1;
        }
        $category =~ s/Soap Opera/Soap/ig;
        $category =~ s/Science and Technology/Science\/Nature/ig;
        $category =~ s/Real Life/Reality/ig;
        $category =~ s/Cartoon/Animation/ig;
        $category =~ s/Family/Children/ig;
        $category =~ s/Murder/Crime/ig;
    } else { # !$category
        if ($title) {
            if ($title=~/(^|\W)News(\W|$)/i) {
                $category = "News";
            } elsif ($title=~/(^|\W)Infomercials?(\W|$)/i) {
                $category = "Infotainment";
            }
        }
        if (!$category) {
            if ($type{movie}) {
                $category = "Movie";
            } elsif ($type{sports}) {
                $category = "Sports";
            } elsif ($type{series}) {
                $category = "Series";
            } elsif ($type{tvshow}) {
               $category = "TVShow";
            }
        }
    }

    $category = "" if (!$category);
    $category = "Live $category" if ($type{live});
    $category = "Return $category" if ($type{return});
    $category = "Premiere $category" if ($type{premiere});
    $category = "Final $category" if ($type{final});
    $category =~ s/^\s*(.*?)\s*$/$1/;

    my @result;
    @result = [ $category, "en"] if $category;
    push(@result, [ "movie"  ]) if $type{movie};
    push(@result, [ "sports" ]) if $type{sports};
    push(@result, [ "series" ]) if $type{series};
    push(@result, [ "tvshow" ]) if $type{tvshow};

    return @result;
}

##########################################################################

# (Adult Themes)
# (Some Violence, Adult Themes, Supernatural Themes)
# (Drug References, Adult Themes)
# (Very Coarse Language, Sexual References, Drug References, Adult Themes, Nudity)
# (Some Violence)
# (Drug Use, Strong Adult Themes)
# (Some Violence, Adult Themes)
# (Some Coarse Language)
# (Sexual References)
# (Mild Coarse Language, Sexual References)
# (Sex Scenes, Adult Themes, Supernatural Themes)
# (Adult Themes, Medical Procedures)
## (Qualifying - Sat)
sub subrating
{
  my $string = shift || "";

  my @subrating;
  push(@subrating, "v") if $string =~ /Violence/i;
  push(@subrating, "l") if $string =~ /Language/i;
  push(@subrating, "s") if $string =~ /Sex/i;
  push(@subrating, "d") if $string =~ /Drug/i;
  push(@subrating, "a") if $string =~ /Adult/i;
  push(@subrating, "n") if $string =~ /Nudity/i;
  push(@subrating, "h") if $string =~ /Horror|Supernatural/i;
  push(@subrating, "m") if $string =~ /Medical/i;

  return join(",",@subrating);
}

##########################################################################

sub log
{
	my ($entry) = @_;
	printf "%s\n",$entry;
}

##########################################################################

sub print_stats
{
	my ($progname, $version, $script_start_time, %stats) = @_;
	my $now = time;
	printf "STATS: %s v%s completed in %d seconds",
	  $progname, $version, ($now-$script_start_time);
	foreach my $key (sort keys %stats) {
		printf ", %d %s",$stats{$key},$key;
	}
	printf "\n";
}

##########################################################################
# given a duration (seconds), return it in a pretty "{days}d{hr}h{min}m" string
# and indication of whether the duration is over its threshold or not

sub pretty_duration
{
    my ($d,$crit) = @_;
    my $s = "";
    $s .= sprintf "%dd",int($d / (60*60*24)) if ($d >= (60*60*24));
    $s .= sprintf "%dh",int(($d % (60*60*24)) / (60*60)) if ($d > (60*60));
    $s .= sprintf "%dm",int(($d % (60*60)) / 60) if ($d > 60);
    $s .= sprintf "%ds",int($d % 60) if ($d > 0);
    $s .= "[!]" if ((defined $crit) && ($d > $crit));
    return $s;
}

##########################################################################
# pass $filename as reference to allow new names
# unwritable and unreadable caches are ignored and new filename returned
# broken caches are ignored and over written

sub read_cache
{
    my ($filename) = shift;

    my ($store, $filenametmp, $count) = ({}, $filename, 0);
    $filenametmp = $$filename if ref($filename);
    while (1) {
        if (-e $filenametmp && !(-r $filenametmp && -w $filenametmp)) {
            &log("WARNING: Cache file $filenametmp exists but not readable and writeable.");
        } else {
            if (-e $filenametmp) {
                eval { $store = Storable::retrieve($filenametmp); };
                &log("WARNING: Unable to read cache from file $filenametmp: $@") if ($@);
            } else {
                &log("WARNING: No cache file $filenametmp have to fetch all details.");
            }
            $store = {} if !ref($store);
            eval { Storable::store($store, $filenametmp); };
            if ($@) {
                &log("WARNING: Unable to write cache to file $filenametmp: $@");
            } else {
                last;
            }
        }
        if ((!ref($filename)) || $count > 2) {
            die("ERROR: Shepherd::Common::read_cache($filenametmp) Can't find or create readable and writeable cache.");
        }
        $filenametmp = $$filename . "." . $count++;
    }
    $$filename = $filenametmp if ref($filename);

    return $store;
}

##########################################################################
# wont die when can't write

sub write_cache
{
    my ($filename, $store) = @_;
    eval { Storable::store($store, $filename); };
    &log("WARNING: Unable to write cache to file $filename: $@") if ($@);
}

##########################################################################

# Convert yyyymmddhhmmss +hhmm format to calendar time.
# Use $zone to override with true timezone name. eg. ':localtime', ':Australia/Sydney', ':UTC'.
# Use $default_zone to set a zone when none if found in $xmltv. Defaults to localtime.
# Returns $time in UTC and $z is its zone.
# eg. my @timez = xmltvtimez("200706021800 +1100", ":Australia/Sydney");
sub xmltvtimez {
    my ($xmltv, $zone, $default_zone) = @_;

    my ($Y, $M, $D, $h, $m, $s, $z) =
            $xmltv =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})? ?([+-]\d{4})?/ or
            die "Can't interprete xmltvtime \"$xmltv\".";

    $z = $zone || ( $z ? "aus$z" : $default_zone ); 

    local %ENV;
    if (defined $z and $z !~ "local") { $ENV{TZ} = $z; POSIX::tzset(); }
    my $time = POSIX::mktime($s?$s:0,$m,$h,$D,$M-1,$Y-1900,0,0,0) or
            die "Can't mktime from xmltvtime \"$xmltv\".";
    if (defined $z and $z !~ "local") { local %ENV; POSIX::tzset(); }

    return ($time, $z);
}

# Move to a different timezone.
#$timez[1] = ":localtime";          # Move to local time
#$timez[1] = ":Australia/Sydney";   # Move to Australia/Sydney time
#$timez[1] = ":UTC";                # Move to utc time
#$timez[1] = "utc+0000";            # Move to utc time

# Convert calendar time to yyyymmddhhmmss +hhmm format.
# $time is in UTC and $z is its zone.  Changing $z moves to a new timezone.
# eg. print timezxmltv(@timez);
# eg. print timezxmltv($time);  # Defaults to localtime.
sub timezxmltv {
    my ($time, $z) = @_;

    local %ENV;
    if (defined $z and $z !~ "local") { $ENV{TZ} = $z; POSIX::tzset(); }
        my $xmltv = POSIX::strftime("%Y%m%d%H%M%S %z", localtime($time));
    if (defined $z and $z !~ "local") { local %ENV; POSIX::tzset();  }

    return $xmltv;
}

# Show it all works ok.
sub testxmltvtimez {
  print POSIX::strftime("%Y%m%d%H%M%S %z\t\t\tStart time\n\n", localtime());

  my $str = "200706022000";
  my @timez = xmltvtimez($str);
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\t\tOriginal time\n";
  @timez = xmltvtimez("$str", ":UTC");
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\tOverride with utc\n";
  @timez = xmltvtimez("$str", ":Australia/Sydney");
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\tOverride with Australia/Sydney\n\n";

  @timez = xmltvtimez($str);
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\t\tOriginal time\n";
  $timez[1] = ":UTC";
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\tMove to utc time\n";
  $timez[1] = ":localtime";
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\tMove to local time\n";
  $timez[1] = "utc+0000";
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\t\tMove to utc time\n";
  $timez[1] = ":Australia/Sydney";
  print timezxmltv(@timez) . " " . ($timez[1] || "") . "\tMove to Australia/Sydney\n";

  print POSIX::strftime("\n%Y%m%d%H%M%S %z\t\t\tEnd time.\n", localtime());
}

##########################################################################

1;
