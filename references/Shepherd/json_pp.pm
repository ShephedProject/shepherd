# this is a cut-down / modified version of CPAN's JSON::PP module from
# http://cpansearch.perl.org/src/MAKAMAKA/JSON-2.21/lib/JSON/PP.pm 
# (JSON::PP) by Makamaka Hannyaharamitu.
# All credits to the original author(s).  All bugs by Shepherd devs.
#
# this has had everything other than decode ripped out so as to make it a
# single standalone package (the original was multiple modules and dependent
# on perl version to choose module(s)).
# since we are working with australian tv guide data and shepherd's http
# fetch mechanisms we also assume the input data is already processed for
# UTF8 so that has been removed too.

package JSON::cut_down_PP;

use 5.005;
use strict;
use base qw(Exporter);
use overload;

use Carp ();
use B ();

$JSON::PP::VERSION = '2.27003';
@JSON::PP::EXPORT = qw(decode_json);

my $JSON; # cache

sub decode_json { # decode
    ($JSON ||= __PACKAGE__->new)->decode(@_);
}

sub new {
    my $class = shift;
    my $self  = {
        max_depth   => 512,
        max_size    => 0,
        indent      => 0,
        FLAGS       => 0,
        fallback      => sub { encode_error('Invalid value. JSON can only reference.') },
        indent_length => 3,
    };
    bless $self, $class;
}

sub decode {
    return $_[0]->PP_decode_json($_[1], 0x00000000);
}


sub decode_prefix {
    return $_[0]->PP_decode_json($_[1], 0x00000001);
}


# accessor

sub max_depth {
    my $max  = defined $_[1] ? $_[1] : 0x80000000;
    $_[0]->{max_depth} = $max;
    $_[0];
}

sub get_max_depth { $_[0]->{max_depth}; }

sub max_size {
    my $max  = defined $_[1] ? $_[1] : 0;
    $_[0]->{max_size} = $max;
    $_[0];
}

sub get_max_size { $_[0]->{max_size}; }

sub indent_length {
    if (!defined $_[1] or $_[1] > 15 or $_[1] < 0) {
        Carp::carp "The acceptable range of indent_length() is 0 to 15.";
    }
    else {
        $_[0]->{indent_length} = $_[1];
    }
    $_[0];
}

sub get_indent_length {
    $_[0]->{indent_length};
}

sub sort_by {
    $_[0]->{sort_by} = defined $_[1] ? $_[1] : 1;
    $_[0];
}


###############################

#
# JSON => Perl
#

{ # PARSE 

    my %escapes = ( #  by Jeremy Muhlich <jmuhlich [at] bitflood.org>
        b    => "\x8",
        t    => "\x9",
        n    => "\xA",
        f    => "\xC",
        r    => "\xD",
        '\\' => '\\',
        '"'  => '"',
        '/'  => '/',
    );

    my $text; # json data
    my $at;   # offset
    my $ch;   # 1chracter
    my $len;  # text length (changed according to UTF8 or NON UTF8)
    # INTERNAL
    my $depth;          # nest counter
    my $utf8_len;       # utf8 byte length
    # FLAGS
    my $utf8;           # must be utf8
    my $max_depth;      # max nest nubmer of objects and arrays
    my $max_size;
    my $relaxed;
    my $cb_object;
    my $cb_sk_object;

    my $F_HOOK;

    # $opt flag
    # 0x00000001 .... decode_prefix
    # 0x10000000 .... incr_parse

    sub PP_decode_json {
        my ($self, $opt); # $opt is an effective flag during this decode_json.

        ($self, $text, $opt) = @_;

        ($at, $ch, $depth) = (0, '', 0);

        if ( !defined $text or ref $text ) {
            decode_error("malformed JSON string, neither array, object, number, string or atom");
        }

        my $idx = $self->{PROPS};

        $len = length $text;

        ($max_depth, $max_size, $cb_object, $cb_sk_object, $F_HOOK)
             = @{$self}{qw/max_depth  max_size cb_object cb_sk_object F_HOOK/};

        if ($max_size > 1) {
            use bytes;
            my $bytes = length $text;
            decode_error(
                sprintf("attempted decode of JSON text of %s bytes size, but max_size is set to %s"
                    , $bytes, $max_size), 1
            ) if ($bytes > $max_size);
        }

        # Currently no effect
        # should use regexp
        my @octets = unpack('C4', $text);

        white(); # remove head white space

        my $valid_start = defined $ch; # Is there a first character for JSON structure?

        my $result = value();

        return undef if ( !$result && ( $opt & 0x10000000 ) ); # for incr_parse

        decode_error("malformed JSON string, neither array, object, number, string or atom") unless $valid_start;

        Carp::croak('something wrong.') if $len < $at; # we won't arrive here.

        my $consumed = defined $ch ? $at - 1 : $at; # consumed JSON text length

        white(); # remove tail white space

        if ( $ch ) {
            return ( $result, $consumed ) if ($opt & 0x00000001); # all right if decode_prefix
            decode_error("garbage after JSON object");
        }

        ( $opt & 0x00000001 ) ? ( $result, $consumed ) : $result;
    }


    sub next_chr {
        return $ch = undef if($at >= $len);
        $ch = substr($text, $at++, 1);
    }


    sub value {
        white();
        return          if(!defined $ch);
        return object() if($ch eq '{');
        return array()  if($ch eq '[');
        return string() if($ch eq '"');
        return number() if($ch =~ /[0-9]/ or $ch eq '-');
        return word();
    }

    sub string {
        my ($i, $s, $t, $u);

        $s = ''; # basically UTF8 flag on

        if($ch eq '"') {
            OUTER: while( defined(next_chr()) ){

                if($ch eq '"') {
                    next_chr();

                    return $s;
                }
                elsif($ch eq '\\'){
                    next_chr();
                    if(exists $escapes{$ch}){
                        $s .= $escapes{$ch};
                    }
                    else{
                        $s .= $ch;
                    }
                }
                else{
                    $s .= $ch;
                }
            }
        }

        decode_error("unexpected end of string while parsing JSON string");
    }


    sub white {
        while( defined $ch  ){
            if($ch le ' '){
                next_chr();
            }
            elsif($ch eq '/'){
                next_chr();
                if(defined $ch and $ch eq '/'){
                    1 while(defined(next_chr()) and $ch ne "\n" and $ch ne "\r");
                }
                elsif(defined $ch and $ch eq '*'){
                    next_chr();
                    while(1){
                        if(defined $ch){
                            if($ch eq '*'){
                                if(defined(next_chr()) and $ch eq '/'){
                                    next_chr();
                                    last;
                                }
                            }
                            else{
                                next_chr();
                            }
                        }
                        else{
                            decode_error("Unterminated comment");
                        }
                    }
                    next;
                }
                else{
                    $at--;
                    decode_error("malformed JSON string, neither array, object, number, string or atom");
                }
            }
            else{
                if ($relaxed and $ch eq '#') { # correctly?
                    pos($text) = $at;
                    $text =~ /\G([^\n]*(?:\r\n|\r|\n|$))/g;
                    $at = pos($text);
                    next_chr;
                    next;
                }

                last;
            }
        }
    }


    sub array {
        my $a  = [];

        decode_error('json text or perl structure exceeds maximum nesting level (max_depth set too low?)')
                                                    if (++$depth > $max_depth);

        next_chr();
        white();

        if(defined $ch and $ch eq ']'){
            --$depth;
            next_chr();
            return $a;
        }
        else {
            while(defined($ch)){
                push @$a, value();

                white();

                if (!defined $ch) {
                    last;
                }

                if($ch eq ']'){
                    --$depth;
                    next_chr();
                    return $a;
                }

                if($ch ne ','){
                    last;
                }

                next_chr();
                white();

                if ($relaxed and $ch eq ']') {
                    --$depth;
                    next_chr();
                    return $a;
                }

            }
        }

        decode_error(", or ] expected while parsing array");
    }


    sub object {
        my $o = {};
        my $k;

        decode_error('json text or perl structure exceeds maximum nesting level (max_depth set too low?)')
                                                if (++$depth > $max_depth);
        next_chr();
        white();

        if(defined $ch and $ch eq '}'){
            --$depth;
            next_chr();
            if ($F_HOOK) {
                return _json_object_hook($o);
            }
            return $o;
        }
        else {
            while (defined $ch) {
                $k = string();
                white();

                if(!defined $ch or $ch ne ':'){
                    $at--;
                    decode_error("':' expected");
                }

                next_chr();
                $o->{$k} = value();
                white();

                last if (!defined $ch);

                if($ch eq '}'){
                    --$depth;
                    next_chr();
                    if ($F_HOOK) {
                        return _json_object_hook($o);
                    }
                    return $o;
                }

                if($ch ne ','){
                    last;
                }

                next_chr();
                white();

                if ($relaxed and $ch eq '}') {
                    --$depth;
                    next_chr();
                    if ($F_HOOK) {
                        return _json_object_hook($o);
                    }
                    return $o;
                }

            }

        }

        $at--;
        decode_error(", or } expected while parsing object/hash");
    }


    sub bareKey { # doesn't strictly follow Standard ECMA-262 3rd Edition
        my $key;
        while($ch =~ /[^\x00-\x23\x25-\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F]/){
            $key .= $ch;
            next_chr();
        }
        return $key;
    }


    sub word {
        my $word =  substr($text,$at-1,4);

        if($word eq 'true'){
            $at += 3;
            next_chr;
            return $JSON::PP::true;
        }
        elsif($word eq 'null'){
            $at += 3;
            next_chr;
            return undef;
        }
        elsif($word eq 'fals'){
            $at += 3;
            if(substr($text,$at,1) eq 'e'){
                $at++;
                next_chr;
                return $JSON::PP::false;
            }
        }

        $at--; # for decode_error report

        decode_error("'null' expected")  if ($word =~ /^n/);
        decode_error("'true' expected")  if ($word =~ /^t/);
        decode_error("'false' expected") if ($word =~ /^f/);
        decode_error("malformed JSON string, neither array, object, number, string or atom");
    }


    sub number {
        my $n    = '';
        my $v;

        # According to RFC4627, hex or oct digts are invalid.
        if($ch eq '0'){
            my $peek = substr($text,$at,1);
            my $hex  = $peek =~ /[xX]/; # 0 or 1

            if($hex){
                decode_error("malformed number (leading zero must not be followed by another digit)");
                ($n) = ( substr($text, $at+1) =~ /^([0-9a-fA-F]+)/);
            }
            else{ # oct
                ($n) = ( substr($text, $at) =~ /^([0-7]+)/);
                if (defined $n and length $n > 1) {
                    decode_error("malformed number (leading zero must not be followed by another digit)");
                }
            }

            if(defined $n and length($n)){
                if (!$hex and length($n) == 1) {
                   decode_error("malformed number (leading zero must not be followed by another digit)");
                }
                $at += length($n) + $hex;
                next_chr;
                return $hex ? hex($n) : oct($n);
            }
        }

        if($ch eq '-'){
            $n = '-';
            next_chr;
            if (!defined $ch or $ch !~ /\d/) {
                decode_error("malformed number (no digits after initial minus)");
            }
        }

        while(defined $ch and $ch =~ /\d/){
            $n .= $ch;
            next_chr;
        }

        if(defined $ch and $ch eq '.'){
            $n .= '.';

            next_chr;
            if (!defined $ch or $ch !~ /\d/) {
                decode_error("malformed number (no digits after decimal point)");
            }
            else {
                $n .= $ch;
            }

            while(defined(next_chr) and $ch =~ /\d/){
                $n .= $ch;
            }
        }

        if(defined $ch and ($ch eq 'e' or $ch eq 'E')){
            $n .= $ch;
            next_chr;

            if(defined($ch) and ($ch eq '+' or $ch eq '-')){
                $n .= $ch;
                next_chr;
                if (!defined $ch or $ch =~ /\D/) {
                    decode_error("malformed number (no digits after exp sign)");
                }
                $n .= $ch;
            }
            elsif(defined($ch) and $ch =~ /\d/){
                $n .= $ch;
            }
            else {
                decode_error("malformed number (no digits after exp sign)");
            }

            while(defined(next_chr) and $ch =~ /\d/){
                $n .= $ch;
            }

        }

        $v .= $n;

        return 0+$v;
    }


    sub decode_error {
        my $error  = shift;
        my $no_rep = shift;
        my $str    = defined $text ? substr($text, $at) : '';
        my $mess   = '';

        for my $c ( unpack( 'C*', $str ) ) { # emulate pv_uni_display() ?
            $mess .=  $c == 0x07 ? '\a'
                    : $c == 0x09 ? '\t'
                    : $c == 0x0a ? '\n'
                    : $c == 0x0d ? '\r'
                    : $c == 0x0c ? '\f'
                    : $c <  0x20 ? sprintf('\x{%x}', $c)
                    : $c == 0x5c ? '\\\\'
                    : $c <  0x80 ? chr($c)
                    : sprintf('\x{%x}', $c)
                    ;
            if ( length $mess >= 20 ) {
                $mess .= '...';
                last;
            }
        }

        unless ( length $mess ) {
            $mess = '(end of string)';
        }

        Carp::croak (
            $no_rep ? "$error" : "$error, at character offset $at (before \"$mess\")"
        );

    }


    sub _json_object_hook {
        my $o    = $_[0];
        my @ks = keys %{$o};

        if ( $cb_sk_object and @ks == 1 and exists $cb_sk_object->{ $ks[0] } and ref $cb_sk_object->{ $ks[0] } ) {
            my @val = $cb_sk_object->{ $ks[0] }->( $o->{$ks[0]} );
            if (@val == 1) {
                return $val[0];
            }
        }

        my @val = $cb_object->($o) if ($cb_object);
        if (@val == 0 or @val > 1) {
            return $o;
        }
        else {
            return $val[0];
        }
    }


} # PARSE





###############################
# Utilities
#

BEGIN {
    eval 'require Scalar::Util';
    unless($@){
        *JSON::PP::blessed = \&Scalar::Util::blessed;
    }
    else{ # This code is from Sclar::Util.
        # warn $@;
        eval 'sub UNIVERSAL::a_sub_not_likely_to_be_here { ref($_[0]) }';
        *JSON::PP::blessed = sub {
            local($@, $SIG{__DIE__}, $SIG{__WARN__});
            ref($_[0]) ? eval { $_[0]->a_sub_not_likely_to_be_here } : undef;
        };
    }
}


# shamely copied and modified from JSON::XS code.

$JSON::PP::true  = do { bless \(my $dummy = 1), "JSON::PP::Boolean" };
$JSON::PP::false = do { bless \(my $dummy = 0), "JSON::PP::Boolean" };

sub is_bool { defined $_[0] and UNIVERSAL::isa($_[0], "JSON::PP::Boolean"); }

sub true  { $JSON::PP::true  }
sub false { $JSON::PP::false }
sub null  { undef; }

###############################

package JSON::PP::Boolean;


use overload (
   "0+"     => sub { ${$_[0]} },
   "++"     => sub { $_[0] = ${$_[0]} + 1 },
   "--"     => sub { $_[0] = ${$_[0]} - 1 },
   fallback => 1,
);


###############################

package JSON::PP::IncrParser;

use strict;

use constant INCR_M_WS   => 0; # initial whitespace skipping
use constant INCR_M_STR  => 1; # inside string
use constant INCR_M_BS   => 2; # inside backslash
use constant INCR_M_JSON => 3; # outside anything, count nesting
use constant INCR_M_C0   => 4;
use constant INCR_M_C1   => 5;

$JSON::PP::IncrParser::VERSION = '1.01';

my $unpack_format = $] < 5.006 ? 'C*' : 'U*';

sub new {
    my ( $class ) = @_;

    bless {
        incr_nest    => 0,
        incr_text    => undef,
        incr_parsing => 0,
        incr_p       => 0,
    }, $class;
}


sub incr_parse {
    my ( $self, $coder, $text ) = @_;

    $self->{incr_text} = '' unless ( defined $self->{incr_text} );

    if ( defined $text ) {
        $self->{incr_text} .= $text;
    }


    my $max_size = $coder->get_max_size;

    if ( defined wantarray ) {

        $self->{incr_mode} = INCR_M_WS;

        if ( wantarray ) {
            my @ret;

            $self->{incr_parsing} = 1;

            do {
                push @ret, $self->_incr_parse( $coder, $self->{incr_text} );

                unless ( !$self->{incr_nest} and $self->{incr_mode} == INCR_M_JSON ) {
                    $self->{incr_mode} = INCR_M_WS;
                }

            } until ( !$self->{incr_text} );

            $self->{incr_parsing} = 0;

            return @ret;
        }
        else { # in scalar context
            $self->{incr_parsing} = 1;
            my $obj = $self->_incr_parse( $coder, $self->{incr_text} );
            $self->{incr_parsing} = 0 if defined $obj; # pointed by Martin J. Evans
            return $obj ? $obj : undef; # $obj is an empty string, parsing was completed.
        }

    }

}


sub _incr_parse {
    my ( $self, $coder, $text, $skip ) = @_;
    my $p = $self->{incr_p};
    my $restore = $p;

    my @obj;
    my $len = length $text;

    if ( $self->{incr_mode} == INCR_M_WS ) {
        while ( $len > $p ) {
            my $s = substr( $text, $p, 1 );
            $p++ and next if ( 0x20 >= unpack($unpack_format, $s) );
            $self->{incr_mode} = INCR_M_JSON;
            last;
       }
    }

    while ( $len > $p ) {
        my $s = substr( $text, $p++, 1 );

        if ( $s eq '"' ) {
            if ( $self->{incr_mode} != INCR_M_STR  ) {
                $self->{incr_mode} = INCR_M_STR;
            }
            else {
                $self->{incr_mode} = INCR_M_JSON;
                unless ( $self->{incr_nest} ) {
                    last;
                }
            }
        }

        if ( $self->{incr_mode} == INCR_M_JSON ) {

            if ( $s eq '[' or $s eq '{' ) {
                if ( ++$self->{incr_nest} > $coder->get_max_depth ) {
                    Carp::croak('json text or perl structure exceeds maximum nesting level (max_depth set too low?)');
                }
            }
            elsif ( $s eq ']' or $s eq '}' ) {
                last if ( --$self->{incr_nest} <= 0 );
            }
            elsif ( $s eq '#' ) {
                while ( $len > $p ) {
                    last if substr( $text, $p++, 1 ) eq "\n";
                }
            }

        }

    }

    $self->{incr_p} = $p;

    return if ( $self->{incr_mode} == INCR_M_JSON and $self->{incr_nest} > 0 );

    return '' unless ( length substr( $self->{incr_text}, 0, $p ) );

    local $Carp::CarpLevel = 2;

    $self->{incr_p} = $restore;
    $self->{incr_c} = $p;

    my ( $obj, $tail ) = $coder->PP_decode_json( substr( $self->{incr_text}, 0, $p ), 0x10000001 );

    $self->{incr_text} = substr( $self->{incr_text}, $p );
    $self->{incr_p} = 0;

    return $obj or '';
}


sub incr_text {
    if ( $_[0]->{incr_parsing} ) {
        Carp::croak("incr_text can not be called when the incremental parser already started parsing");
    }
    $_[0]->{incr_text};
}


sub incr_skip {
    my $self  = shift;
    $self->{incr_text} = substr( $self->{incr_text}, $self->{incr_c} );
    $self->{incr_p} = 0;
}


sub incr_reset {
    my $self = shift;
    $self->{incr_text}    = undef;
    $self->{incr_p}       = 0;
    $self->{incr_mode}    = 0;
    $self->{incr_nest}    = 0;
    $self->{incr_parsing} = 0;
}

###############################


1;
