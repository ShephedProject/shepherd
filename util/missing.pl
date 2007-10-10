#!/usr/bin/perl

# Call with a "MISSING_DATA" string and it prints out the gaps in nice
# human-readable form.
#
# EG:
# $ ./missing.pl ABC:1171112400-1171198799,1171198800-1171232399
# Channel: ABC
# - Sun Feb 11 00:00:00 2007 - Sun Feb 11 23:59:59 2007 (1440 mins)
# - Mon Feb 12 00:00:00 2007 - Mon Feb 12 09:19:59 2007 (560 mins)

my $ch;
foreach (@ARGV)
{
    foreach my $bit (split /:/)
    {
	if ($bit =~ /-/)
	{
	    foreach my $gap (split (/,/, $bit))
	    {
		if ($gap =~ /(\d+)-(\d+)/)
		{
		    printf "- %s - %s (%d mins)\n",
			   localtime($1).'', localtime($2).'',
			   int((($2 - $1)/60)+0.1);
		}
		else
		{
		    die "What's this? $gap";
		}
	    }
	}
	else
	{
	    $ch = $bit;
	    print "Channel: $ch\n";
	}
    }
}

