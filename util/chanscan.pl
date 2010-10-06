#!/usr/bin/perl

use strict;

use LWP::Simple;
use Data::Dumper;
use HTML::TreeBuilder;

use lib 'references';
use lib '../references';

use Shepherd::Common;

my $region_channels;
my $ua;
my $DATASOURCE = 'http://www.yourtv.com.au';
my $URL = "$DATASOURCE/guide/ajax/channels/ChannelsFta.aspx?region_id=";
my $DATASOURCE2 = 'http://au.tv.yahoo.com/tv-guide/';

&read_channels_list;

&setup_ua;

print "Checking online guide...\n\n";
print "Channels found to be not in the official list should almost always\n".
      "be added. Official channels not found online should probably be left\n".
      "alone, as that simply means the channel was not available in this\n".
      "particular datasource--it might be available via a different grabber.\n\n";

foreach my $region (sort { $a <=> $b } keys %$region_channels)
{
    printf "Region %3d: ", $region;

    my $content = &Shepherd::Common::get_url($URL . $region);

    my $tree = HTML::TreeBuilder->new_from_content($content);
    my $h3 = $tree->look_down('_tag' => 'h3');
    unless ($h3)
    {
	die "Couldn't find H3 in this:\n$content\n";
    }
    my $region_name = $h3->as_text();
    print "$region_name\n";
#    print "Channels: " . join(', ', @{$region_channels->{$region}}) . ".\n";


    my @yourtv_channels;
    foreach my $tag ($tree->look_down('_tag' => 'label'))
    {
	next if ($tag->attr('for') eq 'select-all-fta');
	my $chan = $tag->as_text();
	$chan =~ s/^\s+//;
	$chan =~ s/\(.*?\)//;
	$chan =~ s/\s+$//;

	next if (grep($chan eq $_, @yourtv_channels));

	push @yourtv_channels, $chan;
    }

    my @yahoo_channels;

    $content = &Shepherd::Common::get_url($DATASOURCE2 . $region . '/0/');
    $tree = HTML::TreeBuilder->new_from_content($content);
    foreach my $tag ($tree->look_down('_tag' => 'li', 'class' => 'row channel'))
    {
	my $h3 = $tag->look_down('_tag' => 'h3');
	my $chan = $h3->as_text();
#	print "Chan: $chan.\n";
	push @yahoo_channels, $chan;
    }

    my @matched_channels;
    foreach my $chan (@{$region_channels->{$region}})
    {
	if (grep($chan eq $_, @matched_channels))
	{
	    print " & \"$chan\": Duplicated in channel_list\n";
	    next;
	}
	my @a = grep ($chan ne $_, @yourtv_channels);
	my @b = grep($chan ne $_, @yahoo_channels);

	if (@a == @yourtv_channels and @b == @yahoo_channels)
	{
	    print " ? \"$chan\" unknown to both YourTV and Yahoo\n";
	}
	elsif (@a == @yourtv_channels)
	{
	    print " ? \"$chan\" unknown to YourTV\n";
	}
	elsif (@b == @yahoo_channels)
	{
	    print " ? \"$chan\" unknown to Yahoo\n";
	}
	@yourtv_channels = @a;
	@yahoo_channels = @b;
	push @matched_channels, $chan;
    }
    foreach my $chan (@yourtv_channels)
    {
	print " ! \"$chan\" in YourTV but not channels_list.\n";
    }

    foreach my $chan (@yahoo_channels)
    {
	print " ! \"$chan\" in Yahoo but not channels_list.\n";
    }

    sleep 1;
}

print "Done.\n";



sub setup_ua
{
  print "Refreshing UA.\n";

  if ($ua)
  {
     print "Sleeping...\n";
     sleep(5);
  }

  &Shepherd::Common::set_default('debug', 0);
  $ua = &Shepherd::Common::setup_ua( cookie_jar => 1 );
}

sub read_channels_list
{
    my $fn = 'references/channel_list/channel_list';
    unless (open (FN, 'channel_list') or open (FN, 'references/channel_list') or open(FN, '../references/channel_list'))
    {
	print "ERROR: Unable to open references/channel_list: $!!\n";
	return;
    }
    while (my $line = <FN>)
    {
	if ($line =~ /^(\d+):(.*)/)
	{
	    $region_channels->{$1} = [ split(/,/, $2) ];
	}
	last if ($line =~ /---migrate---/);
    }
    printf "Read in channels for %d regions.\n", scalar(keys(%$region_channels));
}

