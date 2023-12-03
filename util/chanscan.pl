#!/usr/bin/perl

use strict;

use LWP::Simple;
use Data::Dumper;
use HTML::TreeBuilder;
use JSON;
use Shepherd::json_pp;
use Data::Dumper;

use lib 'references';
use lib '../references';

use Shepherd::FreeviewHelper;
use Shepherd::Configure;

$| = 1;

use Shepherd::Common;

my $region_channels;
my $ua;
my $DATASOURCE_yourtv = 'https://www.yourtv.com.au/api/regions/%d/channels';

my $DATASOURCE_freeview = 'https://fvau-api-prod.switch.tv/content/v1/channels/region/%s?limit=100&offset=0&include_related=1&expand_related=full&related_entity_types=images';

#Channel name remaps that grabbers should be smart enough to handle (spaces mainly)
my %known_remaps = (
	"SBS VICELAND"    => "SBSVICELAND",
	"SBS VICELAND HD" => "SBSVICELANDHD",
	"ABC NEWS"        => "ABCNEWS",
	"ABC ME"          => "ABCME",
	"WIN GOLD"        => "WINGOLD",
	"7flix Prime"     => "7flixPrime",
	"Aboriginal TV"   => "AboriginalTV",
	"Tourism TV"      => "TourismTV",
	"Education TV"    => "EducationTV",
	"TDT HD"          => "TDTHD",
	"SCTV HD"         => "SCTVHD"
);

&read_channels_list;

&setup_ua;

print "Checking online guide...\n\n";
print "Channels found to be not in the official list should almost always\n" .
	"be added. Official channels not found online should probably be left\n" .
	"alone, as that simply means the channel was not available in this\n" .
	"particular datasource--it might be available via a different grabber.\n\n";

my %special_matches;

open(my $csv, ">", "channel_mappings.csv");
print $csv "Shepherd Channel,Rex Name,Freeview Name,Rex LCN,Freeview LCN\n\n";

foreach my $region (sort {$a <=> $b} keys %$region_channels) {
	printf "Region %3d (%s): \n", $region, Shepherd::Configure::get_region_name($region);
	printf $csv "Region %3d: \n", $region;

    my %known_channels;
    foreach my $chan (@{$region_channels->{$region}})
    {
        $known_channels{$chan} = 1;
    }

	my $yourtv_url = sprintf $DATASOURCE_yourtv, $region;

	my $content = &Shepherd::Common::get_url($yourtv_url);
	unless ($content) {
		die "Couldn't retrive $yourtv_url successfully";
	}
	my $yourtv_data = JSON::decode_json($content);
	my @yourtv_channels;
	my %yourtv_by_lcn;

	foreach my $chandata (@{$yourtv_data}) {
		if (defined $chandata->{name}) {
			my $name = Shepherd::Common::translate_channel_name($chandata->{name}, \%known_channels);
			$name = $known_remaps{$name} if defined $known_remaps{$name};
			push @yourtv_channels, { 'name'=>$name, 'lcn'=> $chandata->{number} };
			$yourtv_by_lcn{$chandata->{number}} = $name;
		}
	}

	my @freeview_channels;
	my %freeview_by_lcn;
	if (!defined($Shepherd::FreeviewHelper::SHEP_ID_TO_STATE{$region})){
		#print "Region $region unsupported in freeview!\n";
	} else {
		my $freeview_url = sprintf $DATASOURCE_freeview, $Shepherd::FreeviewHelper::SHEP_ID_TO_STATE{$region};
		$content = &Shepherd::Common::get_url($freeview_url);
		if ($content) {
			my $freeview_data = JSON::cut_down_PP::decode_json($content);

			foreach my $chandata (@{$freeview_data->{data}}) {
				if (defined $chandata->{channel_name}) {
					my $mapped_name = Shepherd::FreeviewHelper::clean_channel_name($chandata->{channel_name});

					push @freeview_channels, { 'name' => $mapped_name, 'lcn' => $chandata->{lcn} };
					$freeview_by_lcn{$chandata->{lcn}} = $mapped_name;
				}
				else {
					die "no channel name";
				}
			}
		}
	}

	my @matched_channels;
	my %region_mappings;
	foreach my $chan (@{$region_channels->{$region}}) {
		if (grep ($chan eq $_, @matched_channels)) {
			print " & \"$chan\": Duplicated in channel_list\n";
			next;
		}
		my @a = grep ($chan ne $_->{name}, @yourtv_channels);
		my @b = grep ($chan ne $_->{name}, @freeview_channels);

		my @matched_yourtv = grep ($chan eq $_->{name}, @yourtv_channels);
		my @matched_freeview = grep (lc $chan eq lc $_->{name}, @freeview_channels);

		printf $csv '"%s","%s","%s","%s","%s"'."\n", $chan, join(', ', map($_->{name}, @matched_yourtv)), join(', ', map($_->{name}, @matched_freeview)), join(', ', map($_->{lcn}, @matched_yourtv)), join(', ', map($_->{lcn}, @matched_freeview));

		$region_mappings{$chan}->{yourtv} = join(', ', map($_->{name}, @matched_yourtv));

		$region_mappings{$chan}->{freeview} = join(', ', map($_->{name}, @matched_freeview));

		if (@a == @yourtv_channels and @b == @freeview_channels) {
			print " ? \"$chan\" unknown to both YourTV and Freeview\n";
		}
		elsif (@a == @yourtv_channels) {
			print " ? \"$chan\" unknown to YourTV\n";
			foreach my $freeview_chan (@freeview_channels){
				if ($freeview_chan->{name} eq $chan && defined $yourtv_by_lcn{$freeview_chan->{lcn}}){
					print "\texists as ch $freeview_chan->{lcn} \"".$yourtv_by_lcn{$freeview_chan->{lcn}}."\" based on Freeview match\n";
					$special_matches{yourtv}->{$region}->{$yourtv_by_lcn{$freeview_chan->{lcn}}} = $chan;
					@a = grep ($yourtv_by_lcn{$freeview_chan->{lcn}} ne $_->{name}, @a);
					last;
				}
			}
		}
		elsif (defined($Shepherd::FreeviewHelper::SHEP_ID_TO_STATE{$region}) && @b == @freeview_channels) {
			#moved inside the loop as FV is missing lots in regional, only print if we can find an LCN match
            #print " ? \"$chan\" unknown to Freeview\n";
			foreach my $yourtv_chan (@yourtv_channels){
				if ($yourtv_chan->{name} eq $chan && defined $freeview_by_lcn{$yourtv_chan->{lcn}}){
                    print " ? \"$chan\" unknown to Freeview\n";
					print "\texists as \"".$freeview_by_lcn{$yourtv_chan->{lcn}}."\" based on YourTV match\n";
					$special_matches{freeview}->{$region}->{$freeview_by_lcn{$yourtv_chan->{lcn}}} = $chan;
					@b = grep ($freeview_by_lcn{$yourtv_chan->{lcn}} ne $_->{name}, @b);
					last;
				}
			}
		}
		@yourtv_channels = @a;
		@freeview_channels = @b;
		push @matched_channels, $chan;
	}
	foreach my $chan (@yourtv_channels) {
		print " ! \"$chan->{name}\" in YourTV but not channels_list.\n";
	}

	foreach my $chan (@freeview_channels) {
		print " ! \"$chan->{name}\" in Freeview but not channels_list.\n";
        my $translated_channel_name = Shepherd::Common::translate_channel_name($chan, \%known_channels);
        if ($known_channels{$translated_channel_name}){
            print "\tWARN: exists as \"".$translated_channel_name."\" in common fun\n";
        }
	}

	print $csv "\n";
	sleep 1;
}

print "Done.\n";

print Dumper(\%special_matches);
close $csv;


sub setup_ua {
	print "Refreshing UA.\n";

	if ($ua) {
		print "Sleeping...\n";
		sleep(5);
	}

	&Shepherd::Common::set_default('debug', 0);
	$ua = &Shepherd::Common::setup_ua(cookie_jar => 1);
}

sub read_channels_list {
	my $fn = 'references/channel_list/channel_list';
	unless (open(FN, 'channel_list') or open(FN, 'references/channel_list') or open(FN, '../references/channel_list')) {
		print "ERROR: Unable to open references/channel_list: $!!\n";
		return;
	}
	while (my $line = <FN>) {
		if ($line =~ /^(\d+):(.*)/) {
			$region_channels->{$1} = [ split(/,/, $2) ];
		}
		last if ($line =~ /---migrate---/);
	}
	printf "Read in channels for %d regions.\n", scalar(keys(%$region_channels));
}
