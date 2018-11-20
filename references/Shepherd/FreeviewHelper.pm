package Shepherd::FreeviewHelper;
use strict;

#shep regions to "state" url param
our %SHEP_ID_TO_STATE = (
	73 => "Sydney",
	94 => "Melbourne",
	75 => "Brisbane",
	81 => "Adelaide",
	101 => "Perth",
	126 => "Canberra",
	88 => "Hobart",
	74 => "Darwin",
	63 => "Broken Hill",
	66 => "Central Coast",
	261 => "Coffs Harbour",
	67 => "Griffith",
	184 => "Newcastle",
	262 => "Orange/Dubbo",
	106 => "Remote and Central NSW",
	259 => "South Coast",
	69 => "Tamworth",
	263 => "Taree/Port Macquarie",
	264 => "Wagga Wagga",
	71 => "Wollongong",
	108 => "Regional NT",
	79 => "Cairns",
	78 => "Gold Coast",
	253 => "Mackay",
	114 => "Remote and Central QLD",
	254 => "Rockhampton",
	255 => "Sunshine Coast",
	256 => "Toowoomba",
	257 => "Townsville",
	258 => "Wide Bay",
	107 => "Remote and Central SA",
	83 => "Riverland",
	85 => "South East SA",
	86 => "Spencer Gulf",
	268 => "Albury/Wodonga",
	90 => "Ballarat",
	266 => "Bendigo",
	93 => "Geelong",
	98 => "Gippsland",
	95 => "Mildura/Sunraysia",
	267 => "Shepparton",
	102 => "Regional WA"
);

#service names to shep channel names where differ
our %SERVICE_NAME_TO_SHEP = (
	"Channel 9"       => "Nine",
	'ABC NEWS'        => "ABCNEWS",
	'ABC ME'          => "ABCME",
	'SBS VICELAND'    => 'SBSVICELAND',
	'SBS VICELAND HD' => 'SBSVICELANDHD',
	'TVSN Shopping'   => 'TVSN',
	'SCTV Darwin'     => "SCTV",
	'DDT10'           => 'DDT',
	'ABC2 / KIDS'     => 'ABC COMEDY/ABC KIDS',
	'C31'             => 'Channel 31',
	'sctv'            => 'SCTV',
	'GOLD'            => 'WINGOLD',
	'NINE'            => 'Nine',
	'7Flix Prime'     => '7flixPrime',
	'9GEM'            => '9Gem',
	'SC 7mate'        => '7mate',
	'7TWO Central'    => '7TWO',
	'ONE'             => '10 Boss',
	'TEN'             => '10',
	'TEN HD'          => '10 HD',
	'ELEVEN'          => '10 Peach'
);

sub map_service {
	my $svc = shift;
	my $channel = $svc->{'@service_name'};
	#remove some suffixes
	$channel =~ s/ (NT|QLD|NSW|VIC|ACT|TAS|Toowoomba|SA|South East SA|WA|Mid NC|Coffs Harbour|Coffs|Canberra|Shepparton|Mildura|Wollongong|New Eng|Tamworth|Cairns|Orange|Albury|Port Macquarie|Taree|Wide Bay|Tas|Hobart|Mackay|Gippsland|Sunshine Coast|Gold Coast|Gold C|Ballarat|Townsville|Batemans Bay|South Coast|Newc|Newcastle|Bendigo|Cent C|Central C|Rockhampton|Wagga Wagga|Wagga|Griffith|Adel|SA Lox|Lox)$//;
	#check if we have a static remap
	$channel = $SERVICE_NAME_TO_SHEP{$channel} if (defined $SERVICE_NAME_TO_SHEP{$channel});

	return $channel;
}

1;