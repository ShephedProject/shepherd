#!/usr/bin/perl

use strict;

use LWP::Simple;
use Data::Dumper;
use HTML::TreeBuilder;
use JSON;

use lib 'references';
use lib '../references';

$| = 1;

use Shepherd::Common;

my $region_channels;
my $ua;
my $DATASOURCE_yourtv = 'https://www.yourtv.com.au/api/regions/%d/channels';

my $DATASOURCE_yahoo = 'https://y7mobile.query.yahoo.com/v1/tv-guide/schedule?region=%d&network=0&grouping=channel&channel_offset=%d';

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

foreach my $region (sort {$a <=> $b} keys %$region_channels) {
	printf "Region %3d: \n", $region;

	my $yourtv_url = sprintf $DATASOURCE_yourtv, $region;

	my $content = &Shepherd::Common::get_url($yourtv_url);
	unless ($content) {
		die "Couldn't retrive $yourtv_url successfully";
	}
	my $yourtv_data = JSON::decode_json($content);
	my @yourtv_channels;

	foreach my $chandata (@{$yourtv_data}) {
		if (defined $chandata->{name}) {
			my $name = $chandata->{name};
			$name = $known_remaps{$name} if defined $known_remaps{$name};
			push @yourtv_channels, $name;
		}
	}

	my @yahoo_channels;
	my @yahoo_urls = (sprintf $DATASOURCE_yahoo, $region, 0);

	foreach my $yahoo_url (@yahoo_urls) {
		$content = &Shepherd::Common::get_url($yahoo_url);
		unless ($content) {
			die "Couldn't retrive $yahoo_url successfully";
		}
		my $yahoo_data = JSON::decode_json($content);

		unless (defined $yahoo_data->{schedule}->{result}->[0]->{channels}) {
			die "yahoo channel list not found";
		}

		foreach my $chanid (keys %{$yahoo_data->{schedule}->{result}->[0]->{channels}}) {
			if (defined $yahoo_data->{schedule}->{result}->[0]->{channels}->{$chanid}->{name}) {
				my $name = $yahoo_data->{schedule}->{result}->[0]->{channels}->{$chanid}->{name};
				$name = $known_remaps{$name} if defined $known_remaps{$name};
				push @yahoo_channels, $name;
			}
		}

		if (defined $yahoo_data->{schedule}->{result}->[0]->{pagination}->{down}){
			push @yahoo_urls, sprintf $DATASOURCE_yahoo, $region, $yahoo_data->{schedule}->{result}->[0]->{pagination}->{down}->{params}->{channel_offset};
		}
	}

	my @matched_channels;
	foreach my $chan (@{$region_channels->{$region}}) {
		if (grep ($chan eq $_, @matched_channels)) {
			print " & \"$chan\": Duplicated in channel_list\n";
			next;
		}
		my @a = grep ($chan ne $_, @yourtv_channels);
		my @b = grep ($chan ne $_, @yahoo_channels);

		if (@a == @yourtv_channels and @b == @yahoo_channels) {
			print " ? \"$chan\" unknown to both YourTV and Yahoo\n";
		}
		elsif (@a == @yourtv_channels) {
			print " ? \"$chan\" unknown to YourTV\n";
		}
		elsif (@b == @yahoo_channels) {
			print " ? \"$chan\" unknown to Yahoo\n";
		}
		@yourtv_channels = @a;
		@yahoo_channels = @b;
		push @matched_channels, $chan;
	}
	foreach my $chan (@yourtv_channels) {
		print " ! \"$chan\" in YourTV but not channels_list.\n";
	}

	foreach my $chan (@yahoo_channels) {
		print " ! \"$chan\" in Yahoo but not channels_list.\n";
	}

	sleep 1;
}

print "Done.\n";



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