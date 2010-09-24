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
    my $region_name = $tree->look_down('_tag' => 'h3')->as_text();
    print "$region_name\n";
    foreach my $tag ($tree->look_down('_tag' => 'label'))
    {
	next if ($tag->attr('for') eq 'select-all-fta');
	my $chan = $tag->as_text();
	$chan =~ s/^\s+//;
	$chan =~ s/\(.*?\)//;
	$chan =~ s/\s+$//;

	my @a = grep ($chan ne $_, @{$region_channels->{$region}});
	if (@a == @{$region_channels->{$region}})
	{
	    print " ! Channel \"$chan\" not in official channel_list\n";
	}
	else
	{
	    # Channel OK: in both lists
	    $region_channels->{$region} = [ @a ];
	}
    }
    foreach my $chan (@{$region_channels->{$region}})
    {
	print " ? Official channel \"$chan\" not in online guide.\n";
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

