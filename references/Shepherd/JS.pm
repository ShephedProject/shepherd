#
# Shepherd::JS library
#
# This module provides some library functions for Shepherd components,
# relieving them of the need to duplicate functionality.
#
# To use this library, components simply need to include the line:
#
#   use Shepherd::JS;

package Shepherd::JS;

use JavaScript;

my $version = '0.2';

my $jsc;
my $debug = 0;

sub setup 
{
    my ($url, $d) = @_;

    $debug = 1 if ($d);
    print "Initializing JavaScript interpreter.\n" if ($debug);
    $jsc = new JavaScript::Runtime->create_context();
    if ($debug)
    {
	$jsc->set_error_handler( sub { print "JavaScript error: @_\n"; } );
    }
    else
    {
	$jsc->set_error_handler( sub { } );
    }
    $jsc->eval(qq{
	var doc = '';
	function Location() { this.href  = '$url'; }
	function Document() { this.write = function(x) { doc += x; } }
	function Window()   { this.___ww = 0 }
	location = new Location;
	document = new Document;
	window   = new Window;
    });
}

sub read
{
    my ($data, $d) = @_;

    $debug = 1 if ($d);
    print "Reading JavaScript.\n" if ($debug);

    $data =~ s{<script (type|language)="?(text/)?javascript"?[^>]*>(.*?)</script>}{&eval_js($3)}isge;

    $data;
}

sub eval_js
{
    my $x = shift;

    &setup unless ($jsc);
    $jsc->eval(qq{ doc = '' });
    $jsc->eval($x);
    $jsc->eval(qq{ doc }) || '';
}

1;
