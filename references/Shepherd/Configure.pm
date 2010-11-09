#!/usr/bin/perl -w

package Shepherd::Configure;

my $version = '0.23';

use strict;
no strict 'refs';

use XMLTV;

my %REGIONS = 
    (
        63 => "NSW: Broken Hill",       66 => "NSW: Central Coast",     67 => "NSW: Griffith",
        69 => "NSW: Tamworth",  71 => "NSW: Wollongong",        73 => "NSW: Sydney",
        74 => "NT: Darwin",     75 => "QLD: Brisbane",  78 => "QLD: Gold Coast",
        79 => "QLD: Cairns",    81 => "SA: Adelaide",   82 => "SA: Renmark",
        83 => "SA: Riverland",  85 => "SA: South East SA",      86 => "SA: Spencer Gulf",
        88 => "TAS: Tasmania",  90 => "VIC: Ballarat",  93 => "VIC: Geelong",
        94 => "VIC: Melbourne", 95 => "VIC: Mildura/Sunraysia", 98 => "VIC: Gippsland",
        101 => "WA: Perth",     102 => "WA: Regional",  106 => "NSW: Remote and Central",
        107 => "SA: Remote and Central",        108 => "NT: Remote and Central",        114 => "QLD: Remote and Central",
        126 => "ACT: Canberra", 184 => "NSW: Newcastle",        253 => "QLD: Mackay",
        254 => "QLD: Rockhampton",      255 => "QLD: Sunshine Coast",   256 => "QLD: Toowoomba",
        257 => "QLD: Townsville",       258 => "QLD: Wide Bay", 259 => "NSW: Far South Coast",
        261 => "NSW: Lismore/Coffs Harbour",    262 => "NSW: Orange/Dubbo",     263 => "NSW: Taree/Port Macquarie",
        264 => "NSW: Wagga Wagga",      266 => "VIC: Bendigo",  267 => "VIC: Shepparton",
        268 => "VIC: Albury/Wodonga"
    );

# -----------------------------------------
# Subs: Configuration
# -----------------------------------------

sub configure
{
    if ($::opt->{configure} ne '1')
    {
	my $proggy = $::opt->{configure};
	print "\nAttempting to configure \"$proggy\".\n";

	unless ($::components->{$proggy})
	{
	    print "Unknown component: \"$proggy\".\n";
	    exit 0;
	}

	my $progtype = $::components->{$proggy}->{type};
	unless ($progtype eq 'grabber' or $progtype eq 'postprocessor'
		or $progtype eq 'reconciler')
	{
	    print "Cannot configure $progtype components.\n";
	    exit 0;
	}

	my $option_configure = (&::query_config($proggy, 'option_config') or '--configure');
	&::call_prog($proggy, &::query_filename($proggy, $progtype) . " $option_configure");

	exit 0;
    }
    print "\nConfiguring.\n\n" .
	  "Step 1: Region Selection\n\nSelect your region:\n";
    foreach (sort { $REGIONS{$a} cmp $REGIONS{$b} } keys %REGIONS)
    {
	printf(" (%3d) %s\n", $_, $REGIONS{$_});
    }
    $::region = &XMLTV::Ask::ask_choice("Enter region code:", ($::region || "94"),
			 keys %REGIONS);

    print "\nStep 2: Channel Selection\n\n";

    print "Shepherd offers two methods of channel selection: Guided and Advanced.\n".
          "Guided is easier; Advanced allows manual entering of XMLTV IDs.\n\n";

    my $guided = &XMLTV::Ask::ask_boolean("Would you like Guided channel selection?", 1);

    my $mchans = &configure_channels_guided if ($guided);
    &configure_channels_advanced unless ($mchans);

    print "\nStep 3: Transitioning\n\n".
	  "Would you like to transition seamlessly from your current grabber?\n\n".
	  "Different data sources can have different names for the same show. For\n".
	  "example, one grabber might call a show \"Spicks & Specks\" while another\n".
	  "calls it \"Spicks and Specks\". These differences can make MythTV think\n".
	  "they're actually different shows.\n\n".
	  ucfirst($::progname) . " is able to merge these differences so that it always\n".
	  "presents shows with a consistent name, no matter where it actually sourced\n".
	  "show data from. If you'd like, it can also rename shows so they're consistent\n".
	  "with whichever grabber you've been using until now.\n\n".
	  "The advantage of this is that you should get a smoother transition to\n".
	  ucfirst($::progname) . ", with no shows changing names and no need to re-create\n".
	  "any recording rules. The main disadvantage is that if your previous grabber\n".
	  "used an inferior data source -- i.e. it sometimes has typos or less\n".
	  "informative program names -- then you'll continue to see these.\n\n".
	  "If you were using one of the following grabbers previously AND you want\n".
	  ucfirst($::progname) . " to use that grabber's program names, select it here.\n\n";

    my $def = "Do not transition; just use best quality titles";
    my %transition = (	"ltd (aka tv_grab_au, versions 1,30, 1.40 or 1.41)" => 'yahoo7widget',
			"OzTivo" => 'oztivo',
			"Rex" => 'rex');
    my $defaulttrans = $def;
    foreach my $key (keys %transition) {
	$defaulttrans = $key if ((defined $::pref_title_source) && ($transition{$key} eq $::pref_title_source));
    }
    my $pref = &XMLTV::Ask::ask_choice("Transition from grabber?", $defaulttrans,
			  $def, keys %transition);
    $::pref_title_source = $transition{$pref};
    
    print "\n";
    &::show_channels if (!$mchans);
    &::show_mythtv_mappings($::debug, $mchans) if ($mchans);

    my $str = "Create configuration file";
    $str .= " and update MythTV" if ($mchans);
    unless(&XMLTV::Ask::ask_boolean("\n$str?", 1))
    {
	print "Aborting configuration.\n";
	exit 0;
    }

    &::write_config_file;
    &::write_channels_file;
    &update_mythtv_channels($mchans) if ($mchans);

    print "\nMythTV Integration\n\n".
          "If you run MythTV, Shepherd can register itself as the default grabber\n".
	  "and set your system to run it regularly to ensure up-to-date guide data.\n".
	  "This is generally easier than doing it yourself.\n\n";
    
    if (&XMLTV::Ask::ask_boolean("Would you like Shepherd to auto-configure MythTV?", 1))
    {
	&configure_mythtv;
    }

    print "Checking if any components require configuration.\n\n";
    &::check;

    print "Finished configuring.\n\n";

    &::status;

    print "\nShepherd is installed into $::CWD.\n\n";

    if (&XMLTV::Ask::ask_boolean("\nShepherd can (optionally) install channel icons.\nDo you wish to do this now?")) {
	&set_icons;
    }

    print "\nIf you wish to add/change channel icons in future, you can call Shepherd with:\n".
	  "    $::CWD/$::progname --set-icons\n\n";

    print "Done.\n";
    exit 0;
}

sub configure_channels_guided
{
    my $mythids = &::retrieve_mythtv_channels;
    unless ($mythids)
    {
	print "\nUnable to retrieve list of MythTV channels.\n" .
	      "Guided channel selection is not available, now using Advanced.\n";
	return undef;
    }
       
    print "\n* Guided Channel Selection *\n";

    print "\nHigh Definition TV (HDTV)\n".
          "Most Australian TV networks broadcast at least some\n".
          "programmes in HDTV each week, but for the most part\n".
          "either upsample SD to HD or play a rolling demonstration\n".
          "HD clip when they don't have the programme in HD format.\n\n".
          "If you have a HDTV capable system and are interested in\n".
          "having Shepherd's postprocessors populate HDTV content\n".
          "then Shepherd will need to know the XMLTV IDs for the HD\n".
          "channels also.  HD related SD channels are required.\n",
          "The 7HD, Nine HD and One HD channels are populated\n",
          "with programs from the first related SD channel.\n",
          "$::wiki/FAQ#MyhighdefinitionHDchannelsaremissingprograms\n\n";
    my $want_hdtv = &XMLTV::Ask::ask_boolean("Do you have High-Definition (HDTV)?");

    my (@channellist, @hd_channellist, @paytv_channellist);

    @channellist = sort &::read_official_channels($::region);
    $::channels = { };
    $::opt_channels = { };
    foreach (@channellist)
    {
	$::channels->{$_} = undef;
    }

    if ($want_hdtv)
    {
	@hd_channellist = grep(!/ABC2|ABC1|SBS News|31/i, @channellist);

	#limit to ones in $channels (don't know so can't) and if 7HD remove 7HD and first 7 (don't know so do anyway)
	foreach my $hdchannel (keys %$::hd_to_sds) {
		@hd_channellist = grep(!/^$hdchannel$/i, @hd_channellist);
		my $oldlength = scalar @hd_channellist;
		foreach my $sdchannel (@{$::hd_to_sds->{$hdchannel}}) {
			@hd_channellist = grep(!/^$sdchannel$/i, @hd_channellist);
			if ($oldlength != scalar @hd_channellist) { # removed first
				print "'$hdchannel' is going to be populated from '$sdchannel'\n";
				last;
			}
		}
	}

	foreach (@hd_channellist)
	{
	    $_.='HD';
	    $::opt_channels->{$_} = undef;
	}
    }

    my $want_paytv = &XMLTV::Ask::ask_boolean("\nDo you have PayTV?");
    if ($want_paytv)
    {
	$want_paytv = &XMLTV::Ask::ask_choice("Which PayTV provider do you have?", 
	                         $::want_paytv_channels || "Foxtel", 
				 ("Foxtel", "SelecTV"));
	$::want_paytv_channels = $want_paytv;
	@paytv_channellist = &::read_official_channels($want_paytv);
	foreach (@paytv_channellist)
	{
	    $::opt_channels->{$_} = undef;
	}
    }
    else
    {
	$::want_paytv_channels = undef;
    }

    my @sdchannels = (@channellist, @hd_channellist);
    my @allchannels = (@sdchannels, @paytv_channellist);
    my @paytvchannels = ((undef) x scalar(@sdchannels), (@paytv_channellist));

    printf "\nYour MythTV has %d channels. Shepherd offers %d channels of guide\n".
           "data for %s (%d free-to-air, %d HDTV, %d Pay-TV).\n\n".
	   "Please associate each MythTV channel with a Shepherd guide data\n".
	   "channel.\n\n",
	   scalar(@$mythids),
	   scalar(@allchannels),
	   $REGIONS{$::region},
	   scalar(@channellist), 
	   scalar(@hd_channellist), 
	   scalar(@paytv_channellist);
    
    my $display_mode = 0;
    foreach my $mch (@$mythids)
    {
	my @table = $display_mode ? @paytvchannels : @sdchannels;
	if ($want_paytv)
	{
	    push @table, ($display_mode ? 'f:(Free to Air channel)' : 'p:(Pay TV channel)' );
	}

	&guided_configure_table(@table);

	my $longname = $mch->{name};
	$longname .= " ($mch->{callsign})" if ($mch->{callsign} and lc($mch->{callsign}) ne lc($longname));

	my $default_str = "";
	my $default_index = 0;
	my $guide_index = 0;

	# Determine if the current xmltvid for the channel in the database
	# corresponds to a shephed channel, and if it does, offer that as
	# the default.

	foreach (@table)
	{
	    my $guide_xmltvid = $allchannels[$guide_index];
	    if ($_ and $guide_xmltvid)
	    {
		$guide_xmltvid = lc "$guide_xmltvid.shepherd.au";
		$guide_xmltvid =~ s/ //g;

		if ($guide_xmltvid eq $mch->{xmltvid})
		{
		    $default_index = $guide_index;
		}
	    }

	    $guide_index++;
	}

	if ($default_index == 0)
	{
	    my $munged_callsign = &munge($mch->{callsign});
	    my $munged_name = &munge($mch->{name});

	    ++$default_index until
	    munge($table[$default_index]) eq $munged_callsign or
	    munge($table[$default_index]) eq $munged_name or
	    $default_index > $#table;
	}

	if ($default_index > $#table)
	{
	    $default_str = "0 (no guide)";
	    $default_index = 0;
	}
	else
	{
	    $default_str = "$table[$default_index]";
	    $default_index++;
	    $default_str = "$default_index ($default_str)"
	}

	my $channum = $mch->{channum} || '-';
	printf "MythTV channel %s: %s [default=%s] ? ",
               $channum,
	       $longname,
	       $default_str;
	my $inp = <STDIN>;
	chomp $inp;
	if ($inp eq '?')
	{
	    # TODO: &guided_configure_help;
	    redo;
	}
	elsif ($inp eq 'f')
	{
	    $display_mode = 0;
	    redo;
	}
	elsif ($inp eq 'p')
	{
	    $display_mode = 1;
	    redo;
	}

	if ($inp eq "")
	{
	    $inp = "$default_index";
	}

	if ($inp =~ /\d+/)
	{
	    my $xmltvid = '';
	    if ($inp == 0)
	    {
		print "$mch->{name} -> (no guide data)\n";
	    }
	    else
	    {
		$inp--;
		my $target = $allchannels[$inp];
		unless ($target)
		{
		    print "Unknown #: $inp\n";
		    redo;
		}
		$xmltvid = lc "$target.shepherd.au";
		$xmltvid =~ s/ //g;
		if ($inp < @channellist)
		{
		    $::channels->{$target} = $xmltvid;
		}
		else
		{
		    $::opt_channels->{$target} = $xmltvid;
		}
		print "$mch->{name} -> $allchannels[$inp].\n";
	    }
	    $mch->{xmltvid} = $xmltvid;
	}
	else
	{
	    print "Unknown selection. Please try again.\n";
	    redo;
	}
    }

    foreach (keys %$::opt_channels)
    {
	if (defined $::opt_channels->{$_} && $_ =~ /HD$/) {
	    my $sd = $_;
	    $sd =~ s/HD$//;
	    if (!defined $::channels->{$sd}) {
		print "No corresponding SD channel for a HD channel.  '$_' needs '$sd'.  Please try again.\n";
		exit;
	    }
	}
    }

    foreach (keys %$::channels)
    {
	delete $::channels->{$_} unless defined $::channels->{$_};
    }
    foreach (keys %$::opt_channels)
    {
	delete $::opt_channels->{$_} unless defined $::opt_channels->{$_};
    }

    &::show_mythtv_mappings($::debug, $mythids);

    print "\nIf you proceed to the end of configuration, Shepherd will\n" .
          "write these channel mappings to MythTV.\n\n";

    exit unless (&XMLTV::Ask::ask_boolean("Is this table correct? ", 1));

    return $mythids;
}

sub guided_configure_table
{
    my @chs;
    my $skip = 0;
    foreach (@_)
    {
	if (defined $_)
	{
	    push @chs, $_;
	}
	else
	{
	    $skip++;
	}
    }

    @chs = ('(no guide)', @chs);

    my $half = int(scalar(@chs) / 2);
    $half++ if (scalar(@chs) % 2);
    
    my $i = 0;
    my $n;
    my $str = '';
    while ($i < $half)
    {
	$n = $i;
	$n += $skip if ($n);
	my $selection = &guided_configure_table_entry($chs[$i], $n);
	$n += $skip if (!$n);
	$selection .= &guided_configure_table_entry($chs[$i+$half], $n+$half) if ($i + $half < @chs);
	$str .= "$selection\n";
	$i++;
    }
    print "Guide data sources:\n$str";
}

sub guided_configure_table_entry
{
    my ($entry, $num) = @_;
    if ($entry =~ /^(\w):(.*)/)
    {
	$num = $1;
	$entry = $2;
    }
    return sprintf "(%2s) %-30s", $num, $entry;
}

sub configure_channels_advanced
{
    my @channellist = &::read_official_channels($::region);
    
    $::channels = channel_selection("Free to Air", ".free.au", $::channels, @channellist);
    &::check_channel_xmltvids;

    my $old_opt_channels = $::opt_channels;
    print "\nHigh Definition TV (HDTV)\n".
          "Most Australian TV networks broadcast at least some\n".
          "programmes in HDTV each week, but for the most part\n".
          "either upsample SD to HD or play a rolling demonstration\n".
          "HD clip when they don't have the programme in HD format.\n\n".
          "If you have a HDTV capable system and are interested in\n".
          "having Shepherd's postprocessors populate HDTV content\n".
          "then Shepherd will need to know the XMLTV IDs for the HD\n".
          "channels also.  HD related SD channels are required.\n",
          "The 7HD, Nine HD and One HD channels are populated\n",
          "with programs from the first related SD channel.\n",
          "$::wiki/FAQ#MyhighdefinitionHDchannelsaremissingprograms\n";
    if (&XMLTV::Ask::ask_boolean("\nDo you wish to include HDTV channels?")) 
    {
        #limit to ones in $channels and if 7HD remove 7HD and first 7
        my @hd_channellist = grep(!/ABC2|TEN|SBS TWO|31/i, keys %$::channels);

	foreach my $hdchannel (keys %$::hd_to_sds) {
		my $oldlength = scalar @hd_channellist;
		@hd_channellist = grep(!/^$hdchannel$/i, @hd_channellist);
		next if ($oldlength == scalar @hd_channellist); # didn't remove
		$oldlength = scalar @hd_channellist;
		foreach my $sdchannel (@{$::hd_to_sds->{$hdchannel}}) {
			@hd_channellist = grep(!/^$sdchannel$/i, @hd_channellist);
			if ($oldlength != scalar @hd_channellist) { # removed first
				print "'$hdchannel' is going to be populated from '$sdchannel'\n";
				last;
			}
		}
	}

        foreach (@hd_channellist)
        {
            $_ .= "HD";
        }

        $::opt_channels = channel_selection("HDTV", ".hd.free.au", $old_opt_channels, @hd_channellist);
        &::check_channel_xmltvids;
    }
    else
    {
        $::opt_channels = { };
    }

    if (&XMLTV::Ask::ask_boolean("\nDo you wish to include PayTV (e.g. Foxtel, SelecTV) channels?", defined $::want_paytv_channels))
    {
        $::want_paytv_channels = &XMLTV::Ask::ask_choice("Which PayTV provider?", $::want_paytv_channels || "Foxtel", ("Foxtel", "SelecTV"));
        my @paytv_channellist = &::read_official_channels($::want_paytv_channels);
        my $paytv = channel_selection("Pay TV", ".paytv.au", $old_opt_channels, @paytv_channellist);
        if (keys %$paytv) {
            $::opt_channels = { %$::opt_channels, %$paytv };
        } else {
            $::want_paytv_channels = undef;
        }
        &::check_channel_xmltvids;
    }
    else
    {
        $::want_paytv_channels = undef;
    }
}

# Sourced from YourTV
sub fetch_regions
{
    my ($reg, $shh) = @_;

    &::log("Fetching free-to-air region information...\n") unless ($shh);

    # Download list
    my $ua = LWP::UserAgent->new();
    $ua->env_proxy;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322');
    $ua->cookie_jar({});
    $ua->get('http://www.yourtv.com.au');
    my $response = $ua->get('http://www.yourtv.com.au/?');

    my $page = $response->content;
    die "Unable to download region list page" if ($response->is_error());

    die "Unable to parse region list" if (!($page =~ /<select[^>]*fta_region_id[^>]*>(.*?)<\/select>/is));
    my $regions = $1;

    my %regions;
    while ($regions =~ /value.*?(\d+).*?>(.*?)(<|$)/sg) {
	my ($num, $name) = ($1, $2);
	$name =~ s/^\s+//s;
	$name =~ s/\s+$//s;
	$name =~ s/\s+/ /gs;
	$name =~ s/ -/:/;

	$regions{$num} = $name;
	#printf "Downloaded %d %s\n", $num, $name;
    }

    my %REGIONSLOCAL = %REGIONS;
    my %regionslocal = %regions;
    foreach my $num (keys %regionslocal) {
	#printf "Checking %d %s\n", $num, $regions{$num};
	if (!defined($REGIONSLOCAL{$num}) || $REGIONS{$num} ne $regions{$num}) {
		#printf "Missing %d %s\n", $num, $regions{$num};
	} else {
		delete $REGIONSLOCAL{$num};
		delete $regionslocal{$num};
	}
    }

    if ((scalar(keys %REGIONSLOCAL) != 0) || (scalar(keys %regionslocal) != 0)) {
	print "old regions not matched:\n";
	foreach (sort { $REGIONSLOCAL{$a} cmp $REGIONSLOCAL{$b} } keys %REGIONSLOCAL) {
		printf(" %3d %s\n", $_, $REGIONSLOCAL{$_});
	}
	print "new regions not matched:\n";
	foreach (sort { $regionslocal{$a} cmp $regionslocal{$b} } keys %regionslocal) {
		printf(" %3d %s\n", $_, $regionslocal{$_});
	}
	print "new region list:\n";
	my $count = 0;
	print "\tmy %REGIONS = (";
	foreach (sort { $a <=> $b } keys %regions) {
		if ($count%3 == 0) {
			print"\n\t\t";
		} else {
			print"\t";
		}
		printf('%d => "%s",', $_, $regions{$_});
		$count+=1;
	}
	print ");\n";
    }
}

# Sourced from YourTV
sub fetch_channels
{
    my ($reg, $shh) = @_;

    &::log("Fetching free-to-air channel information...\n") unless ($shh);

    # Download list
    my $ua = LWP::UserAgent->new();
    $ua->env_proxy;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322');
    $ua->cookie_jar({});
    $ua->get('http://www.yourtv.com.au');
    my $response = $ua->get('http://www.yourtv.com.au/profile/ajax.cfm?action=channels&region_id='.$reg);

    my $page = $response->content;
    die "Unable to download channel list" if ($response->is_error());

    # Rules for Station Names:
    # Station names are comprised of the channel name (eg "Seven") and an
    # optional regional qualifier in brackets (eg "(Cairns/Rockhampton)").
    # Station names shall not contain a regional qualifer unless
    # necessary to distinguish between identical channel names in
    # the same region; in this case, a regional qualifier shall always
    # be included. In the absence of anything better, the region name 
    # (eg "NSW: Regional NSW") is used as the regional qualifier.
    my (@channellist, $clist, $cn, $rq);
    while ($page =~ /<label for="venue_id.*?>(.*?)<\/label>/sg)
    {
	my $channel = $1;
	$channel =~ s/\s{2,}//g;
	if ($channel =~ /(.*) (\(.*\))/)
	{
	    ($cn, $rq) = ($1, $2);
	}
	else
	{
	    $cn = $channel;
	    $rq = '';
	}
	# Is there already a channel with this name?
	if ($clist->{$cn})
	{
	    # Set regional qualifier for existing station if not already set
	    if (@{$clist->{$cn}} == 1 and $clist->{$cn}[0] eq '')
	    {
		$clist->{$cn} = [ "(".$REGIONS{$reg}.")" ];
	    }
	    $rq = $REGIONS{$reg} if ($rq eq '');
	    die "Bad channel list in region $reg!" if (grep($rq eq $_, @{$clist->{$cn}}));
	    push @{$clist->{$cn}}, $rq; 
	}
	else
	{
	    $clist->{$cn} = [ $rq ];
	}
    }
    foreach $cn (keys %$clist)
    {
	if (@{$clist->{$cn}} == 1)
	{
	    push @channellist, $cn;
	}
	else
	{
	    foreach $rq (@{$clist->{$cn}})
	    {
		push @channellist, "$cn $rq";
	    }
	}
    }
    return @channellist;
}

sub fetch_channels_foxtel   # web parsing broken (http://www.foxtel.com.au/discover/channels/default.htm wrong format)
{
    my $shh = shift;
    &::log("Fetching PayTV channel information...\n") unless ($shh);

    my $ua = LWP::UserAgent->new();
    $ua->env_proxy;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322');
    $ua->cookie_jar({});
    my $response = $ua->get('http://www.foxtel.com.au/channel/lineup.html');

    my $page = $response->content;
    die "Unable to download channel list" if ($response->is_error());

    my @channellist;
    while ($page =~ /<option value="\/channel\/.*?>(.*?)<\/option>/sg)
    {
	my $ch = $1;
	$ch =~ s/[ \t()\[\]\+\.\-]//g;	# remove special chars
	$ch =~ s/(&amp;|&)/and/g;	# &amp; to and
	$ch =~ s|[/,].*||;		# and deleting after / or ,

	push @channellist,$ch;
    }

    return @channellist;
}

sub fetch_channels_selectv   # web parsing broken
{
    my $shh = shift;
    &::log("Fetching PayTV channel information...\n") unless ($shh);

    my $ua = LWP::UserAgent->new();
    $ua->env_proxy;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322');
    $ua->cookie_jar({});
    my $response = $ua->get('http://www.selectv.com/go/tv-guide');

    my $page = $response->content;
    die "Unable to download channel list" if ($response->is_error());

    my @channellist;
    while ($page =~ /<option value=".*?">(.*?)<\/option>/sg)
    {
	my $ch = $1;
	$ch =~ s/[ \t()\[\]\+\.\-]//g;	# remove special chars
	$ch =~ s/(&amp;|&)/and/g;	# &amp; to and
	$ch =~ s|[/,].*||;		# and deleting after / or ,

	# also in selectv_website
	my %SelecTV_to_Foxtel = (
		"AnimalPlanet" => "AnimalPlanet",
		"AntennaGreek" => "AntennaGreek",		# SelecTV only
		"BBCWorld" => "BBCWorldNews",
		"CartoonNetwork" => "CartoonNetwork",
		"CNNI" => "CNN",				# rename
		"DiscoveryScience" => "DiscoveryScience",
		"DiscoveryHomeandHealth" => "DiscoveryHealth",	# rename
		"DiscoveryTravelandLiving" => "DiscoveryTravel",# rename
		"DiscoveryRealTime" => "DiscoveryRealTime",	# SelecTV and OzTivo
		"E!Entertainment" => "E!Entertainment",
		"ERTGreek" => "ERTGreek",			# SelecTV only
		"Eurosport" => "Eurosport",			# SelecTV and OzTivo
		"FashionTV" => "FashionTV",
		"MovieExtra" => "MOVIEEXTRA",			# rename
		"MovieGreats" => "MOVIEGREATS",			# rename
		"MovieOne" => "MOVIEONE",			# rename
		"MovieTwo" => "MOVIETWO",			# rename
		"MTV" => "MTV",
		"NatGeoAdventure" => "NatGeoAdventure",
		"NationalGeographic" => "NationalGeographic",
		"Ovation" => "Ovation",
		"SkyRacing" => "SkyRacing",
		"TurnerClassicMovies" => "TCM",			# rename
		"TVChileSpanish" => "TVChileSpanish",		# SelecTV and OzTivo
		"TVE" => "TVE",					# SelecTV and OzTivo
		"VH1" => "VH1",
	);
	print " Unknown channel: $ch\n" if !exists($SelecTV_to_Foxtel{$ch});
	$ch = $SelecTV_to_Foxtel{$ch} if $SelecTV_to_Foxtel{$ch};

	push @channellist,$ch;
    }

    return @channellist;
}

# Channel Selection (advanced/manual entering of XMLTV IDs)
#
# We try to help users match XMLTV IDs to their MythTV installation.
# We also try to make all the defaults match what they selected last
# time, if they're re-running configure.
sub channel_selection
{
    my ($type, $default_tail, $old_channels, @channellist) = @_;

    my $mythids = &::retrieve_mythtv_channels;

    my %mhash;
    foreach my $ch (@$mythids)
    {
	$mhash{$ch->{'xmltvid'}} = $ch;
    }

    print "\nYour region has " . scalar(@channellist) . " $type channels:\n " .
          join(', ', @channellist) . ".\n\n";

    my $newchannels = {};
    my $line;
    my $c = 1;
    print "\nEach channel you want guide data for needs a unique XMLTV ID. You can type\n".
          "in an ID of your choice, or press ENTER to accept the suggested [default],\n".
	  "or type in \"n\" to skip this channel.\n\n".
	  "Please don't subscribe to unneeded channels.\n\n".
	  "$type Channels:\n";
    foreach my $ch (@channellist)
    {
        my $default;
        my $status = "new";

        # Ideally, keep what they assigned last time.
        if ($old_channels->{$ch})
        {
            $status = "previously configured";
            $default = $old_channels->{$ch};
        }
        # If it looks like a channel in MythTV, suggest that.
        elsif ($mhash{$ch})
        {
            $default = $mhash{$ch}->{xmltvid};
        }
        # Otherwise make up a name
        else
        {
            $default = lc($ch);          # make a default id by lower-casing
            $default =~ s/[ \t()]//g;   # removing whitespace and parens
            $default =~ s|[/,].*||;     # and deleting after / or ,
            $default .= $default_tail;  # and tack on something like ".free.au".
        }

        printf "(%2d/%2d) \"%s\" (%s)\n", $c, scalar(@channellist), $ch, $status;

	# Notify user if we found a matching MythTV channel
        if ($mhash{$ch})
        {
	    my $channum = $mhash{$ch}->{channum} || '-';
            printf "        Looks like MythTV channel #%s: \"%s\" (%s)\n",
                   $channum,
                   $mhash{$ch}->{name},
                   $mhash{$ch}->{callsign};
            if ($default ne $mhash{$ch}->{xmltvid})
            {
                printf "        Current ID is \"%s\" but MythTV Ch #%s is \"%s\"\n",
                    $default, $channum, $mhash{$ch}->{xmltvid};
            }
        }

	# Don't subscribe by default when user has configured previously
	# and ignored this channel, or if it's a FTA Channel 31 variant.
	if ($status eq 'new' and keys %$old_channels)
	{        
	    print "        If subscribing, suggest \"$default\".\n";
	    $default = "";
	}

        $line = &XMLTV::Ask::ask("        [$default] ? ");
        $line =~ s/\s//g;

	# Some users think they can enter 'y' to accept default
	if (lc($line) eq 'y' or lc($line) eq 'yes')
	{
	    if ($default)
	    {
		$newchannels->{$ch} = $default;
	    }
	    else
	    {
		print "No default value: please enter an XMLTV ID of your choice.\n";
		redo;
	    }
	}
	elsif ($line ne 'n' and ($line =~ /\w/ or $default))
	{
	    $newchannels->{$ch} = $line || $default;
	}

	# Check XMLTV ID is unique
	foreach (keys %$newchannels)
	{
	    next if ($_ eq $ch);
	    if ($newchannels->{$_} and $newchannels->{$ch} and $newchannels->{$_} eq $newchannels->{$ch})
	    {
		print "ERROR: You have entered identical XMLTV IDs for $ch and $_ (\"$newchannels->{$_}\"). Exiting.\n";
		exit;
	    }
	}
	$c++;
    }
    printf "\nYou are subscribing to %d %s channels:\n",
           scalar(keys %$newchannels), $type;
    print "* $_ -> $newchannels->{$_}\n" for sort keys %$newchannels;

    my @not = grep (!$newchannels->{$_}, @channellist);
    printf "\nYou are not subscribing to %d other channel%s: %s.\n",
           scalar(@not), (@not > 1 ? 's' :''), join(', ', @not)
           if (@not);
   return $newchannels;
}

sub update_mythtv_channels
{
    my $mchans = shift;
    eval
    {
	use lib 'references';
	require Shepherd::MythTV;

	my $dbh = &Shepherd::MythTV::open_connection;
	exit unless ($dbh);
	my $sth = $dbh->prepare("UPDATE channel SET xmltvid = ? WHERE name = ? AND channum = ? ");
	foreach my $mch (@$mchans)
	{
	    $sth->execute($mch->{xmltvid}, $mch->{name}, $mch->{channum});
	}
	&Shepherd::MythTV::close_connection;
	&::log("Successfully updated MythTV channels.\n");
    };
    if ($@)
    {
	&::log("Error trying to access MythTV database: $@\n");
	return undef;
    }
}

# ------------------------------
# -   List Channel Names       -
# ------------------------------
#
# This does a web lookup rather than reading the official 
# channels_list reference.
sub list_chan_names
{
    printf "Select your region:\n";
    printf(" (%3d) %s\n", 0, 'All regions (including PayTV and does regions check)');

    foreach (sort { $REGIONS{$a} cmp $REGIONS{$b} } keys %REGIONS) {
        printf(" (%3d) %s\n", $_, $REGIONS{$_});
    }
    my $reg = &XMLTV::Ask::ask_choice("Enter region code:", ($::region || "94"),
                         '0', keys %REGIONS);

    if (!$reg)
    {
        &fetch_regions;

        print "\nListing channels for all regions:\n";

        my @rchans = &fetch_channels_foxtel;
        printf "\nFoxtel:%s\n", join (',', @rchans);
        list_chan_names_diff("Foxtel", @rchans);
        print "\n Use to update channel_list and foxtel_swf.conf (remove ACC from foxtel_swf.conf and check mapping to foxtel in oztivo)\n";
        print " Remove from above Channel7Adelaide,Channel7Brisbane,Channel7Melbourne,Channel7Perth,Channel7Sydney\n\n";

        @rchans = &fetch_channels_selectv;
        printf "\nSelecTV:%s\n", join (',', @rchans);
        list_chan_names_diff("SelecTV", @rchans);
        print "\n Use to update channel_list and selectv_website.conf (check mapping to foxtel in shepherd and selectv_website, and check oztivo mapping)\n\n";

        my $channel_support_exceptions = '';
        foreach my $id (sort { scalar($a) <=> scalar($b) } keys %REGIONS)
        {
            my @rchans = fetch_channels($id, 1);
            printf "%s:%s\n", $id, join(',', @rchans);
            my $cse = list_chan_names_diff($id, @rchans);
            $channel_support_exceptions = "$channel_support_exceptions $cse"
                    if $cse;
            sleep 1;
        }

        print "\n\'channel_support_exceptions\' => \'$channel_support_exceptions\',\n";

        return;
    }

    printf "\nChannels for region %d (%s) are as follows:\n\t%s\n\n",
                $reg, $REGIONS{$reg}, join("\n\t",fetch_channels($reg));
}

sub list_chan_names_diff
{
    my $id = shift;
    my @rchans = @_;

    my @ochans = &::read_official_channels($id);
    my $line = '';
    my $channel_support_exceptions = '';

    my $count = scalar(@rchans);
    foreach my $chan (@ochans) {
        @rchans = grep($chan ne $_, @rchans);
        if ($count == scalar(@rchans)) { # didn't find
            $line = "$line-$chan,";
            $chan =~ s/ /_/g;
            if ($channel_support_exceptions) {
                $channel_support_exceptions = "$channel_support_exceptions,$chan";
            } else {
                $channel_support_exceptions = "$chan";
            }
        } else {
            $count = scalar(@rchans);
        }
    }
    foreach my $chan (@rchans) { # didn't remove
        $line = "$line+$chan,";
    }
    if ($line) {
        print " difference: $line\n";
    }

    $channel_support_exceptions = "$id:-$channel_support_exceptions"
            if $channel_support_exceptions;

    return $channel_support_exceptions;
}

# ------------------------------
# -   MythTV Integration       -
# ------------------------------
#
#

sub configure_mythtv
{
    &::log("\nConfiguring MythTV...\n\n" .
	   "This will:\n".
	   "1. Create a symbolic link to Shepherd from tv_grab_au\n".
           "2. Register Shepherd with MythTV as the default grabber\n".
	   "3. Turn off MythTV-driven scheduling of guide data updates\n".
	   "4. Create a cron job to periodically run Shepherd.\n\n");

    # Check existence of symlink

    my $me = "$::CWD/applications/shepherd/shepherd";

    &::log("Setting up symlink...\n");

    my $mapped = 0;
    my $symlink;
    my @delete_me;
    foreach my $path (split/:/, $ENV{PATH})
    {
	my $tv_grab_au = "$path/tv_grab_au";

	# Figure out an appropriate symlink.
	# (We'll use /usr/bin/tv_grab_au, but only if 
	# /usr/bin/ is in PATH.)
	$symlink = $tv_grab_au unless ($symlink && $symlink eq '/usr/bin/tv_grab_au');

	if (-e $tv_grab_au)
	{
	    if (-l $tv_grab_au)
	    {
		my $link = readlink($tv_grab_au);
		if ($link and $link eq $me)
		{
		    &::log("Symlink $tv_grab_au is correctly mapped to $me.\n");
		    $mapped = $tv_grab_au;
		    last;
		}
	    }
	    push @delete_me, $tv_grab_au;
	}
    }

    &::log("\n");

    if (!$mapped or @delete_me)
    {
	if (@delete_me)
	{
	    &::log("\nShepherd would like to DELETE the following file(s):\n\n");
	    system ("ls -l --color @delete_me");
	    &::log("\n");
	}
	if (!$mapped)
	{
	    &::log("Shepherd would like to CREATE the following symlink:\n\n".
		" $symlink -> $me\n\n");
	}

	my $response = &XMLTV::Ask::ask_boolean(
	    ucfirst(
		($mapped ? '' : ( 'create symlink ' . (@delete_me ? 'and ' : ''))) .
		(@delete_me ? 'delete ' . scalar(@delete_me) . ' file(s)' : '')) .
	    '?', 1);
	unless ($response)
	{
	    &::log("Aborting.\n");
	    return;
	}

	system("sudo rm @delete_me") if (@delete_me);
	system("sudo ln -s $me $symlink") unless ($mapped);
    }

    &::log("Symlink established:\n");
    system("ls -l --color `which tv_grab_au`");
    &::log("\n");

    # 2. Insert 'tv_grab_au' into mythconverg -> videosource

    &::log("Registering Shepherd as tv_grab_au with MythTV.\n\n");

    # No eval because I want to bomb out if this fails:
    # no point creating cron jobs if they won't work.
    use lib 'references';
    require Shepherd::MythTV;

    my $dbh = &Shepherd::MythTV::open_connection();
    return unless ($dbh);
    $dbh->do("UPDATE videosource SET xmltvgrabber='tv_grab_au'") 
        || die "Error updating MythTV database: ".$dbh->errstr;

    &::log("Ok. Turning off MythTV-scheduled guide data updates...\n");
    $dbh->do("UPDATE settings SET data='0' WHERE value='MythFillEnabled'")
	|| &::log("Warning: Unable to check/update MythFillEnabled setting: ".$dbh->errstr.".\n");

    &Shepherd::MythTV::close_connection;

    &::log("MythTV database updated.\n\n");

    # 3. Create cron job

    &::log("Creating cron job...\n\n");
    my $oldcronfile = "$::CWD/cron.bak";

    my $cmd = "crontab -l > $oldcronfile";

    # Response codes: 0==success, 1==empty cron, other==failure
    my $response = (system($cmd) >> 8);
    my $no_permission = 1 if ($response > 1);

    # Some systems (Gentoo) only allow root to run crontab
    if ($no_permission)
    {
	&::log("Error code $response from crontab command; trying again with root permission...\n");
	$cmd = "sudo crontab -u `whoami` -l > $oldcronfile";
	$response = (system($cmd) >> 8);
	if ($response > 1)
	{
	    &::log("Error code $response from crontab. Aborting.\n");
	    return;
	}
	&::log("OK: seemed to work.\n\n");
    }

    my $newcron = '';
    my $oldcron = '';
    if (open (OLDCRON, $oldcronfile))
    {
	while (my $line = <OLDCRON>)
	{
	    $oldcron .= $line;
	    $newcron .= $line unless ($line =~ /mythfilldatabase/);
	}
	close OLDCRON;
    }

    my $mythfilldatabase = `which mythfilldatabase`;
    unless ($mythfilldatabase)
    {
	&::log("WARNING! Unable to locate \"mythfilldatabase\". (Is MythTV installed?)\n".
	       "Proceeding anyway, but cron job may not work.\n\n");
	$mythfilldatabase = 'mythfilldatabase';
    }
    chomp $mythfilldatabase;

    my $minute = ((localtime)[1] + 2) % 60;
    my $job = "$minute * * * * nice $mythfilldatabase --graboptions '--daily'\n";

    $newcron .= $job;

    my $newcronfile = "$::CWD/cron.new";
    open (NEWCRON, ">$newcronfile")
	or die "Unable to open $newcronfile: $!";
    print NEWCRON $newcron;
    close NEWCRON;

    if ($response)
    {
	&::log("Shepherd believes you currently have no crontab, and would\n".
	    "like to set your crontab to:\n");
    }
    else
    {
	&::log("Shepherd would like to replace this:\n\n$oldcron\n" .
	    "... with this:\n");
    }
    &::log("\n$newcron\n");
    unless (&XMLTV::Ask::ask_boolean("Set your crontab as displayed above?", 1))
    {
	&::log("Aborting.\n");
	return;
    }

    $cmd = "crontab $newcronfile";
    $cmd = "sudo $cmd -u `whoami`" if ($no_permission);
    system($cmd) and &::log("Failed?\n");

    &::log("Done.\n");

    if (&XMLTV::Ask::ask_boolean("Would you like to see your symlink " .
	    "and cron job?", 1))
    {
	my $cmd = "ls -l --color `which tv_grab_au`";
	&::log("\n" . '$ ' . $cmd . "\n");
	system($cmd);

	$cmd = "crontab -l";
	$cmd = "sudo $cmd -u `whoami`" if ($no_permission);
	&::log("\n" . '$ ' . $cmd . "\n");
	system($cmd);
    }

    &::log("\nSuccessfully configured MythTV.\n\n".
           "Your system will run mythfilldatabase on the $minute" . 
	   "th minute of every hour,\n" .
           "which will trigger Shepherd (as tv_grab_au) with the --daily option.\n");
}


# Convert callsigns and channel names for matching.
sub munge
{
    my $ret = $_[0];

    # Convert to upercase.

    $ret = uc($ret);

    # Substitute numbers for words.

    $ret =~s/12/TWELVE/g;
    $ret =~s/11/ELEVEN/g;
    $ret =~s/10/TEN/g;
    $ret =~s/9/NINE/g;
    $ret =~s/8/EIGHT/g;
    $ret =~s/7/SEVEN/g;
    $ret =~s/6/SIX/g;
    $ret =~s/5/FIVE/g;
    $ret =~s/4/FOUR/g;
    $ret =~s/3/THREE/g;
    $ret =~s/2/TWO/g;
    $ret =~s/1/ONE/g;
    $ret =~s/0/ZERO/g;

    # Ignore "Digital"

    $ret =~s/DIGITAL//g;

    # Remove white space.

    $ret =~s/[[:space:]]+//g;

    # Make HDTV equivalent to HD

    $ret =~s/HDTV/HD/g;

    # Remove any non alphabetics.

    $ret =~s/[^A-Z]//g;

    return $ret;
}


# ------------------------------
# -   Icons                    -
# ------------------------------

sub set_icons
{
    print "\n\nPopulating Channel Icons.\n\n";

    eval
    {
        use lib 'references';
        require Shepherd::MythTV;

        my $dbh = &Shepherd::MythTV::open_connection;
        exit unless ($dbh);

	-d "$::CWD/icons" or mkdir "$::CWD/icons" or die "Cannot create directory $::CWD/icons: $!";

	# fetch icon styles
	print "Contacted database.\n\nFetching icon styles ... ";
	my $icon_styles = &::fetch_file('http://www.whuffy.com/shepherd/logo_list.txt');
	exit 1 unless ($icon_styles);

	print "Done\n\n".
	      "There are (typically) multiple themes available for each channel.\n".
	      "For each channel you will be asked which theme graphic you'd like for\n".
	      "each channel icon\n".
	      "Aesthetically, you probably want all channel graphics sourced from a single\n".
	      "theme, but you can choose individual graphics for each if you choose.\n\n".
	      "The following themes are available. Please browse the URL of each theme\n".
	      "to see if you like the general style:\n\n".
	      " Theme Name       Theme Description              Theme Preview URL\n".
	      " ---------------- ------------------------------ ------------------------------\n";

	my $t;

	foreach my $line (split/\n/,$icon_styles) {
	    $line =~ s/\t/    /g;
	    if ($line =~ /^THEME\s{2,}(\S+)\s{2,}(.*)\s{2,}(.*)$/) {
		my ($theme_name, $theme_desc, $theme_preview_url) = ($1, $2, $3, $4);
		printf " %-16s %-30s %s\n",$theme_name,$theme_desc,$theme_preview_url;
	    } elsif ($line =~ /^ICON\s+(.*?)\s{2,}(.*?)\s{2,}(.*)$/) {
		my ($ch, $ch_theme, $url) = ($1, $2, $3);
		my $themename = "$ch_theme [$url]";
		$t->{ch}->{$ch}->{themes}->{$themename}->{url} = $url;

		$t->{ch}->{$ch}->{themes}->{$themename}->{fname} = $ch_theme."_".$ch;
		if ($url =~ /\/([a-zA-Z0-9\.\_]+)$/) {
		    $t->{ch}->{$ch}->{themes}->{$themename}->{fname} = $ch_theme."_".$1;
		}

		$t->{ch}->{$ch}->{first_theme} = $themename if (!defined $t->{ch}->{$ch}->{first_theme});
		$t->{ch}->{$ch}->{count}++;
	    }
	}

	print "\nFor each channel, choose the icon theme you would like to use:\n";
	foreach my $ch (sort keys %{($t->{ch})}) {
	    next if ((!defined $::channels->{$ch}) && (!defined $::opt_channels->{$ch}));
	    my $xmlid = $::channels->{$ch};
	    $xmlid = $::opt_channels->{$ch} if (defined $::opt_channels->{$ch});

	    printf "\n\n$ch: [%s]\n",$xmlid;

	    # verify that channel is in database
	    my ($chan_id,$curr_icon) = $dbh->selectrow_array("SELECT chanid,icon FROM channel WHERE xmltvid LIKE '".$xmlid."'");
	    if (!$chan_id) {
		print "  Skipped - not in channels database.\n";
		next;
	    } else {
		print "Icon currently set to: $curr_icon\n";
	    }

	    # let user choose the icon theme they want. if there is only one choice, choose it for them
	    my $chosen_theme = "";
	    if (($t->{ch}->{$ch}->{count} == 1) && ($curr_icon eq "none")) {
		$chosen_theme = $t->{ch}->{$ch}->{first_theme};
		print "Only one theme and icon not currently set, using: $chosen_theme\n";
	    } else {
		$chosen_theme = &XMLTV::Ask::ask_choice("Choose theme:",
		    ($curr_icon eq "none" ? $t->{ch}->{$ch}->{first_theme} : "current icon ($curr_icon)"),
		    "current icon ($curr_icon)", "none",
		    sort keys %{($t->{ch}->{$ch}->{themes})});
	    }

	    if (($chosen_theme ne "") && ($chosen_theme !~ /^current/)) {
		my $fname;
		if ($chosen_theme eq "none") {
		    $fname = "none";
		} else {
		    # always re-fetch icons even if we already had them.
		    # this simplifies the case if a download was corrupt.
		    my $url = $t->{ch}->{$ch}->{themes}->{$chosen_theme}->{url};
		    $fname = "$::CWD/icons/".$t->{ch}->{$ch}->{themes}->{$chosen_theme}->{fname};

		    print "Fetching $url .. ";
		    if (!(&::fetch_file($url, $fname, 1))) {
			print "Failed.\n";
			next;
		    }
		    print "done.\n";
		}

		# update database
		print "Updating database to $fname .. ";
		$dbh->do("UPDATE channel SET icon='".$fname."' WHERE chanid LIKE $chan_id") ||
		die "could not update database channel icon: ".$dbh->errstr;
		print "done.\n";
	    }
	}

	print "\n\nAll done.\n".
	      "You will need to restart both mythbackend and mythfrontend for any icon changes to appear.\n\n";

        &Shepherd::MythTV::close_connection;
        &::log("Successfully set MythTV icons.\n");
    };
    if ($@)
    {
        &::log("Error trying to access MythTV database: $@\n");
        return undef;
    }
}



1;
