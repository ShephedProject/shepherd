package Shepherd::FreeviewHelper;
use strict;

#shep regions to "region" url param
our %SHEP_ID_TO_STATE = (
	73  => "region_nsw_sydney",
	94  => "region_vic_melbourne",
	75  => "region_qld_brisbane",
	81  => "region_sa_adelaide",
	101 => "region_wa_perth",
	126 => "region_nsw_canberra",
	88  => "region_tas_hobart",
	#74  => "Darwin",
	#63  => "Broken Hill",
	#66  => "Central Coast",
	#261 => "Coffs Harbour",
	#67  => "Griffith",
	184 => "region_nsw_newcastle",
	262 => "region_nsw_orange_dubbo_wagga",
	#106 => "Remote and Central NSW",
	#259 => "South Coast",
	69  => "region_nsw_tamworth",
	263 => "region_nsw_taree",
	264 => "region_nsw_orange_dubbo_wagga",
	71  => "region_nsw_wollongong",
	108 => "region_nt_regional",
	79  => "region_qld_cairns",
	78  => "region_qld_goldcoast",
	253 => "region_qld_mackay",
	#114 => "Remote and Central QLD",
	254 => "region_qld_rockhampton",
	#255 => "Sunshine Coast",
	256 => "region_qld_toowoomba",
	257 => "region_qld_townsville",
	258 => "region_qld_widebay",
	107 => "region_sa_regional",
	#83  => "Riverland",
	#85  => "South East SA",
	#86  => "Spencer Gulf",
	268 => "region_vic_albury",
	90  => "region_vic_ballarat",
	266 => "region_vic_bendigo",
	#93  => "Geelong",
	98  => "region_vic_gippsland",
	#95  => "Mildura/Sunraysia",
	267 => "region_vic_shepparton",
	102 => "region_wa_regional_wa",
	#82  => "Port Augusta"
);

#service names to shep channel names where differ
our %SERVICE_NAME_TO_SHEP = (
	"Channel 9"           => "Nine",
	'ABC NEWS'            => "ABCNEWS",
	'ABC ME'              => "ABCME",
	'SBS VICELAND'        => 'SBSVICELAND',
	'SBS VICELAND HD'     => 'SBSVICELANDHD',
	'TVSN Shopping'       => 'TVSN',
	'SCTV Darwin'         => "SCTV",
	'DDT10'               => 'DDT',
	'ABC2 / KIDS'         => 'ABC COMEDY/ABC KIDS',
	'ABC COMEDY/ABC Kids' => 'ABC COMEDY/ABC KIDS',
	'C31'                 => 'Channel 31',
	'sctv'                => 'SCTV',
	'GOLD'                => 'WINGOLD',
	'NINE'                => 'Nine',
	'7Flix Prime'         => '7flixPrime',
	'9GEM'                => '9Gem',
	'SC 7mate'            => '7mate',
	'7TWO Central'        => '7TWO',
	'ONE'                 => '10 Bold',
	'TEN'                 => '10',
	'TEN HD'              => '10 HD',
	'ELEVEN'              => '10 Peach',
	'7'                   => 'Seven',
	'Food Network'        => 'SBS Food'
);

our %channel_code_to_shep = (
	"Channel 9"           => "Nine",
	'ABC NEWS'            => "ABCNEWS",
	'ABC ME'              => "ABCME",
	'SBS VICELAND'        => 'SBSVICELAND',
	'SBS VICELAND HD'     => 'SBSVICELANDHD',
	'TEN'                 => '10',
	'TEN HD'              => '10 HD',
	'ABC COMEDY/ABC Kids' => 'ABC COMEDY/ABC KIDS',
);

#old code, only used by chanscan, to fix
sub map_service {
	my $svc = shift;
	my $channel = $svc->{'@service_name'};
	#remove some suffixes
	$channel =~ s/ (NT|QLD|NSW|VIC|ACT|TAS|Toowoomba|SA|South East SA|WA|Mid NC|Coffs Harbour|Coffs|Canberra|Shepparton|Mildura|Wollongong|New Eng|Tamworth|Cairns|Orange|Albury|Port Macquarie|Taree|Wide Bay|Tas|Hobart|Mackay|Gippsland|Sunshine Coast|Gold Coast|Gold C|Ballarat|Townsville|Batemans Bay|South Coast|Newc|Newcastle|Bendigo|Cent C|Central C|Rockhampton|Wagga Wagga|Wagga|Griffith|Adel|SA Lox|Lox|Central - South|Central - North|Darwin|Broken Hill|Port Lincoln|Perth|Sydney|Melbourne|Brisbane|Adelaide)$//;
	#check if we have a static remap
	$channel = $SERVICE_NAME_TO_SHEP{$channel} if (defined $SERVICE_NAME_TO_SHEP{$channel});

	return $channel;
}

sub clean_channel_name {
	my $channel = shift;
    $channel =~ s/^\s+|\s+$//g;#trim leading/trailing whitespace because Freeview is sometimes poor quality
	$channel =~ s/ (NT|QLD|NSW|VIC|ACT|TAS|Toowoomba|SA|South East SA|WA|Mid NC|Coffs Harbour|Coffs|Canberra|Shepparton|Mildura|Wollongong|New Eng|Tamworth|Cairns|Orange|Albury|Port Macquarie|Taree|Wide Bay|Tas|Hobart|Mackay|Gippsland|Sunshine Coast|Gold Coast|Gold C|Ballarat|Townsville|Batemans Bay|South Coast|Newc|Newcastle|Bendigo|Cent C|Central C|Rockhampton|Wagga Wagga|Wagga|Griffith|Adel|SA Lox|Lox|Central - South|Central - North|Darwin|Broken Hill|Port Lincoln|Perth|Sydney|Melbourne|Brisbane|Adelaide)$//;

	$channel = $channel_code_to_shep{$channel} if (defined$channel_code_to_shep{$channel});

	return $channel;
}

1;
