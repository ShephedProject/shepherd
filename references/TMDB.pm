#repack of http://search.cpan.org/dist/TMDB/lib/TMDB.pm
#modified to use Shepherd::json_pp
package TMDB;

#######################
# LOAD MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# VERSION
#######################
our $VERSION = '1.2.1';

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(session);

#######################
# PUBLIC METHODS
#######################

## ====================
## CONSTRUCTOR
## ====================
sub new {
	my ( $class, @args ) = @_;
	my $self = {};
	bless $self, $class;

	# Init Session
	$self->{session} = TMDB::Session->new(@args);
	return $self;
} ## end sub new

## ====================
## TMDB OBJECTS
## ====================
sub collection {
	return TMDB::Collection->new(
		session => shift->session,
		@_
	);
} ## end sub collection
sub company { return TMDB::Company->new( session => shift->session, @_ ); }
sub config { return TMDB::Config->new( session => shift->session, @_ ); }
sub genre { return TMDB::Genre->new( session => shift->session, @_ ); }
sub movie { return TMDB::Movie->new( session => shift->session, @_ ); }
sub tv { return TMDB::TV->new( session => shift->session, @_ ); }
sub person { return TMDB::Person->new( session => shift->session, @_ ); }
sub search { return TMDB::Search->new( session => shift->session, @_ ); }

#######################

package TMDB::Collection;


#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type => SCALAR,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## INFO
## ====================
sub info {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'collection/' . $self->id(),
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub info

## ====================
## VERSION
## ====================
sub version {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method       => 'collection/' . $self->id(),
			want_headers => 1,
		}
	) or return;
	my $version = $response->{etag} || q();
	$version =~ s{"}{}gx;
	return $version;
} ## end sub version

## ====================
## INFO HELPERS
## ====================

# All titles
sub titles { return shift->_parse_parts('title'); }

# Title IDs
sub ids { return shift->_parse_parts('id'); }

#######################
# PRIVATE METHODS
#######################


sub _parse_parts {
	my $self  = shift;
	my $key   = shift;
	my $info  = $self->info();
	my $parts = $info ? $info->{parts} : [];
	my @stuff;
	foreach my $part (@$parts) {
		next unless $part->{$key};
		push @stuff, $part->{$key};
	} ## end foreach my $part (@$parts)
	return @stuff if wantarray;
	return \@stuff;
} ## end sub _parse_parts

#######################

package TMDB::Company;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type => SCALAR,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## INFO
## ====================
sub info {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'company/' . $self->id(),
		}
	);
} ## end sub info

## ====================
## VERSION
## ====================
sub version {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method       => 'company/' . $self->id(),
			want_headers => 1,
		}
	) or return;
	my $version = $response->{etag} || q();
	$version =~ s{"}{}gx;
	return $version;
} ## end sub version

## ====================
## MOVIES
## ====================
sub movies {
	my ( $self, $max_pages ) = @_;
	return $self->session->paginate_results(
		{
			method    => 'company/' . $self->id() . '/movies',
			max_pages => $max_pages,
		}
	);
} ## end sub movies

## ====================
## INFO HELPERS
## ====================

# Name
sub name {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{name} || q();
} ## end sub name

# Logo
sub logo {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{logo_path} || q();
} ## end sub logo

# Image
sub image { return shift->logo(); }

#######################

package TMDB::Config;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Params::Validate qw(validate_with :types);
use Object::Tiny qw(
	session
	config
	change_keys
	img_backdrop_sizes
	img_base_url
	img_secure_base_url
	img_poster_sizes
	img_profile_sizes
	img_logo_sizes
	img_default_size
);


#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			img_default_size => {
				type     => SCALAR,
				optional => 1,
				default  => 'original',
			},
		},
	);

	my $self = $class->SUPER::new(%opts);

	my $config = $self->session->talk( { method => 'configuration' } ) || {};
	$self->{config}             = $config;
	$self->{img_backdrop_sizes} = $config->{images}->{backdrop_sizes} || [];
	$self->{img_poster_sizes}   = $config->{images}->{poster_sizes} || [];
	$self->{img_profile_sizes}  = $config->{images}->{profile_sizes} || [];
	$self->{img_logo_sizes}     = $config->{images}->{logo_sizes} || [];
	$self->{img_base_url}       = $config->{images}->{base_url} || q();
	$self->{img_secure_base_url}
		= $config->{images}->{secure_base_url} || q();
	$self->{change_keys} = $config->{change_keys} || [];

	return $self;
} ## end sub new

#######################

package TMDB::Genre;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type     => SCALAR,
				optional => 1,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## LIST
## ====================
sub list {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method => 'genre/list',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
	return unless $response;

	my $genres;
	$genres = $response->{genres} || [];
	return @$genres if wantarray;
	return $genres;
} ## end sub list

## ====================
## MOVIES
## ====================
sub movies {
	my ( $self, $max_pages ) = @_;
	return unless $self->id();
	return $self->session->paginate_results(
		{
			method    => 'genre/' . $self->id() . '/movies',
			max_pages => $max_pages,
			params    => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub movies

#######################

package TMDB::Movie;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);
use Locale::Codes::Country qw(all_country_codes);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type => SCALAR,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## INFO
## ====================
sub info {
	my $self   = shift;
	my $params = {};
	$params->{language} = $self->session->lang if $self->session->lang;
	my $info = $self->session->talk(
		{
			method => 'movie/' . $self->id,
			params => $params
		}
	);
	return unless $info;
	$self->{id} = $info->{id};  # Reset TMDB ID
	return $info;
} ## end sub info

## ====================
## ALTERNATIVE TITLES
## ====================
sub alternative_titles {
	my $self    = shift;
	my $country = shift;

	# Valid Country codes
	if ($country) {
		my %valid_country_codes
			= map { $_ => 1 } all_country_codes('alpha-2');
		$country = uc $country;
		return unless $valid_country_codes{$country};
	} ## end if ($country)

	my $args = {
		method => 'movie/' . $self->id() . '/alternative_titles',
		params => {},
	};
	$args->{params}->{country} = $country if $country;

	my $response = $self->session->talk($args);
	my $titles = $response->{titles} || [];

	return @$titles if wantarray;
	return $titles;
} ## end sub alternative_titles

## ====================
## CAST
## ====================
sub cast {
	my $self     = shift;
	my $response = $self->_cast();
	my $cast     = $response->{cast} || [];
	return @$cast if wantarray;
	return $cast;
} ## end sub cast

## ====================
## CREW
## ====================
sub crew {
	my $self     = shift;
	my $response = $self->_cast();
	my $crew     = $response->{crew} || [];
	return @$crew if wantarray;
	return $crew;
} ## end sub crew

## ====================
## IMAGES
## ====================
sub images {
	my $self   = shift;
	my $params = {};
	$params->{lang} = $self->session->lang if $self->session->lang;
	return $self->session->talk(
		{
			method => 'movie/' . $self->id() . '/images',
			params => $params
		}
	);
} ## end sub images

## ====================
## KEYWORDS
## ====================
sub keywords {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'movie/' . $self->id() . '/keywords' } );
	my $keywords_dump = $response->{keywords} || [];
	my @keywords;
	foreach (@$keywords_dump) { push @keywords, $_->{name}; }
	return @keywords if wantarray;
	return \@keywords;
} ## end sub keywords

## ====================
## RELEASES
## ====================
sub releases {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'movie/' . $self->id() . '/releases' } );
	my $countries = $response->{countries} || [];
	return @$countries if wantarray;
	return $countries;
} ## end sub releases

## ====================
## TRAILERS
## ====================
sub trailers {
	my $self = shift;
	return $self->session->talk(
		{ method => 'movie/' . $self->id() . '/trailers' } );
} ## end sub trailers

## ====================
## TRANSLATIONS
## ====================
sub translations {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'movie/' . $self->id() . '/translations' } );
	my $translations = $response->{translations} || [];
	return @$translations if wantarray;
	return $translations;
} ## end sub translations

## ====================
## SIMILAR MOVIES
## ====================
sub similar {
	my ( $self, $max_pages ) = @_;
	return $self->session->paginate_results(
		{
			method    => 'movie/' . $self->id() . '/similar_movies',
			max_pages => $max_pages,
			params    => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub similar
sub similar_movies { return shift->similar(@_); }

## ====================
## LISTS
## ====================
sub lists {
	my ( $self, $max_pages ) = @_;
	return $self->session->paginate_results(
		{
			method    => 'movie/' . $self->id() . '/lists',
			max_pages => $max_pages,
			params    => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub lists

## ====================
## REVIEWS
## ====================
sub reviews {
	my ( $self, $max_pages ) = @_;
	return $self->session->paginate_results(
		{
			method    => 'movie/' . $self->id() . '/reviews',
			max_pages => $max_pages,
			params    => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub reviews

## ====================
## CHANGES
## ====================
sub changes {
	my ( $self, @args ) = @_;
	my %options = validate_with(
		params => [@args],
		spec   => {
			start_date => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
			end_date => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
		},
	);

	my $changes = $self->session->talk(
		{
			method => 'movie/' . $self->id() . '/changes',
			params => {
				(
					$options{start_date}
						? ( start_date => $options{start_date} )
						: ()
				), (
				$options{end_date} ? ( end_date => $options{end_date} )
					: ()
			),
			},
		}
	);

	return unless defined $changes;
	return unless exists $changes->{changes};
	return @{ $changes->{changes} } if wantarray;
	return $changes->{changes};
} ## end sub changes

## ====================
## VERSION
## ====================
sub version {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method       => 'movie/' . $self->id(),
			want_headers => 1,
		}
	) or return;
	my $version = $response->{etag} || q();
	$version =~ s{"}{}gx;
	return $version;
} ## end sub version

## ====================
## INFO HELPERS
## ====================

# Title
sub title {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{title} || q();
} ## end sub title

# Release Year
sub year {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	my $full_date = $info->{release_date} || q();
	return unless $full_date;
	my ($year) = split( /\-/, $full_date );
	return $year;
} ## end sub year

# Tagline
sub tagline {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{tagline} || q();
} ## end sub tagline

# Overview
sub overview {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{overview} || q();
} ## end sub overview

# IMDB ID
sub imdb_id {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{imdb_id} || q();
} ## end sub imdb_id

# Description
sub description { return shift->overview(); }

# Collection
sub collection {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{belongs_to_collection}->{id} || q();
} ## end sub collection

# Genres
sub genres {
	my $self = shift;
	my $info = $self->info();
	return unless $info;
	my @genres;
	if ( exists $info->{genres} ) {
		foreach ( @{ $info->{genres} } ) { push @genres, $_->{name}; }
	}

	return @genres if wantarray;
	return \@genres;
} ## end sub genres

# Homepage
sub homepage {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{homepage} || q();
} ## end sub homepage

# Studios
sub studios {
	my $self = shift;
	my $info = $self->info();
	return unless $info;
	my @studios;
	if ( exists $info->{production_companies} ) {
		foreach ( @{ $info->{production_companies} } ) {
			push @studios, $_->{name};
		}
	} ## end if ( exists $info->{production_companies...})

	return @studios if wantarray;
	return \@studios;
} ## end sub studios

## ====================
## CAST/CREW HELPERS
## ====================

# Actor names
sub actors {
	my $self = shift;
	my @cast = $self->cast();
	my @names;
	foreach (@cast) { push @names, $_->{name}; }
	return @names if wantarray;
	return \@names;
} ## end sub actors

# Crew member names
sub director           { return shift->_crew_names('Director'); }
sub producer           { return shift->_crew_names('Producer'); }
sub executive_producer { return shift->_crew_names('Executive Producer'); }
sub writer { return shift->_crew_names('Screenplay|Writer|Author|Novel'); }

## ====================
## IMAGE HELPERS
## ====================

# Poster
sub poster {
	my $self = shift;
	my $info = $self->info();
	return unless $info;
	return $info->{poster_path} || q();
} ## end sub poster

# Posters
sub posters {
	my $self     = shift;
	my $response = $self->images();
	return unless $response;
	my $posters = $response->{posters} || [];
	return $self->_image_urls($posters);
} ## end sub posters

# Backdrop
sub backdrop {
	my $self = shift;
	my $info = $self->info();
	return unless $info;
	return $info->{backdrop_path} || q();
} ## end sub backdrop

# Backdrops
sub backdrops {
	my $self     = shift;
	my $response = $self->images();
	return unless $response;
	my $backdrops = $response->{backdrops} || [];
	return $self->_image_urls($backdrops);
} ## end sub backdrops

## ====================
## TRAILER HELPERS
## ====================
sub trailers_youtube {
	my $self     = shift;
	my $trailers = $self->trailers();
	my @urls;
	my $yt_tmp = $trailers->{youtube} || [];
	foreach (@$yt_tmp) {
		push @urls, 'http://youtu.be/' . $_->{source};
	}
	return @urls if wantarray;
	return \@urls;
} ## end sub trailers_youtube

#######################
# PRIVATE METHODS
#######################

## ====================
## CAST
## ====================
sub _cast {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'movie/' . $self->id() . '/casts',
		}
	);
} ## end sub _cast

## ====================
## CREW NAMES
## ====================
sub _crew_names {
	my $self = shift;
	my $job  = shift;

	my @names;
	my @crew = $self->crew();
	foreach (@crew) {
		push @names, $_->{name} if ( $_->{job} =~ m{$job}xi );
	}

	return @names if wantarray;
	return \@names;
} ## end sub _crew_names

## ====================
## IMAGE URLS
## ====================
sub _image_urls {
	my $self   = shift;
	my $images = shift;
	my @urls;
	foreach (@$images) {
		push @urls, $_->{file_path};
	}
	return @urls if wantarray;
	return \@urls;
} ## end sub _image_urls

#######################

package TMDB::Person;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type => SCALAR,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## INFO
## ====================
sub info {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'person/' . $self->id(),
		}
	);
} ## end sub info

## ====================
## CREDITS
## ====================
sub credits {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'person/' . $self->id() . '/credits',
		}
	);
} ## end sub credits

## ====================
## IMAGES
## ====================
sub images {
	my $self     = shift;
	my $response = $self->session->talk(
		{
			method => 'person/' . $self->id() . '/images',
		}
	);
	return $response->{profiles} || [];
} ## end sub images

## ====================
## VERSION
## ====================
sub version {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method       => 'person/' . $self->id(),
			want_headers => 1,
		}
	) or return;
	my $version = $response->{etag} || q();
	$version =~ s{"}{}gx;
	return $version;
} ## end sub version

## ====================
## INFO HELPERS
## ====================

# Name
sub name {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{name} || q();
} ## end sub name

# Alternative names
sub aka {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	my @aka = $info->{also_known_as} || [];
	return @aka if wantarray;
	return \@aka;
} ## end sub aka

# Bio
sub bio {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{biography} || q();
} ## end sub bio

# Image
sub image {
	my ($self) = @_;
	my $info = $self->info();
	return unless $info;
	return $info->{profile_path} || q();
} ## end sub image

## ====================
## CREDIT HELPERS
## ====================

# Acted in
sub starred_in {
	my $self = shift;
	my $movies = $self->credits()->{cast} || [];
	my @names;
	foreach (@$movies) { push @names, $_->{title}; }
	return @names if wantarray;
	return \@names;
} ## end sub starred_in

# Crew member
sub directed           { return shift->_crew_names('Director'); }
sub produced           { return shift->_crew_names('Producer'); }
sub executive_produced { return shift->_crew_names('Executive Producer'); }
sub wrote { return shift->_crew_names('Author|Novel|Screenplay|Writer'); }

#######################
# PRIVATE METHODS
#######################

## ====================
## CREW NAMES
## ====================
sub _crew_names {
	my $self = shift;
	my $job  = shift;

	my @names;
	my $crew = $self->credits()->{crew} || [];
	foreach (@$crew) {
		push @names, $_->{title} if ( $_->{job} =~ m{$job}xi );
	}

	return @names if wantarray;
	return \@names;
} ## end sub _crew_names

#######################

package TMDB::Search;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Params::Validate qw(validate_with :types);
use Object::Tiny qw(session include_adult max_pages);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			include_adult => {
				type      => SCALAR,
				optional  => 1,
				default   => 'false',
				callbacks => {
					'valid flag' =>
						sub { lc $_[0] eq 'true' or lc $_[0] eq 'false' }
				},
			},
			max_pages => {
				type      => SCALAR,
				optional  => 1,
				default   => 1,
				callbacks => {
					'integer' => sub { $_[0] =~ m{\d+} },
				},
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## Search Movies
## ====================
sub movie {
	my ( $self, $string ) = @_;

	# Get Year
	my $year;
	if ( $string =~ m{.+\((\d{4})\)$} ) {
		$year = $1;
		$string =~ s{\($year\)$}{};
	} ## end if ( $string =~ m{.+\((\d{4})\)$})

	# Trim
	$string =~ s{(?:^\s+)|(?:\s+$)}{};

	# Search
	my $params = {
		query         => $string,
		include_adult => $self->include_adult,
	};
	$params->{language} = $self->session->lang if $self->session->lang;
	$params->{year} = $year if $year;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/movie',
			params => $params,
		}
	);
} ## end sub movie

## ====================
## Search TV Shows
## ====================
sub tv {
	my ( $self, $string ) = @_;

	# Get Year
	my $year;
	if ( $string =~ m{.+\((\d{4})\)$} ) {
		$year = $1;
		$string =~ s{\($year\)$}{};
	} ## end if ( $string =~ m{.+\((\d{4})\)$})

	# Trim
	$string =~ s{(?:^\s+)|(?:\s+$)}{};

	# Search
	my $params = {
		query         => $string,
		include_adult => $self->include_adult,
	};
	$params->{language} = $self->session->lang if $self->session->lang;
	$params->{year} = $year if $year;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/tv',
			params => $params,
		}
	);
} ## end sub tv

## ====================
## Search Person
## ====================
sub person {
	my ( $self, $string ) = @_;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/person',
			params => {
				query => $string,
			},
		}
	);
} ## end sub person

## ====================
## Search Companies
## ====================
sub company {
	my ( $self, $string ) = @_;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/company',
			params => {
				query => $string,
			},
		}
	);
} ## end sub company

## ====================
## Search Lists
## ====================
sub list {
	my ( $self, $string ) = @_;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/list',
			params => {
				query => $string,
			},
		}
	);
} ## end sub list

## ====================
## Search Keywords
## ====================
sub keyword {
	my ( $self, $string ) = @_;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/keyword',
			params => {
				query => $string,
			},
		}
	);
} ## end sub keyword

## ====================
## Search Collection
## ====================
sub collection {
	my ( $self, $string ) = @_;

	warn "DEBUG: Searching for $string\n" if $self->session->debug;
	return $self->_search(
		{
			method => 'search/collection',
			params => {
				query => $string,
			},
		}
	);
} ## end sub collection

## ====================
## LISTS
## ====================

# Latest
sub latest { return shift->session->talk( { method => 'movie/latest', } ); }

# Upcoming
sub upcoming {
	my ($self) = @_;
	return $self->_search(
		{
			method => 'movie/upcoming',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub upcoming

# Now Playing
sub now_playing {
	my ($self) = @_;
	return $self->_search(
		{
			method => 'movie/now-playing',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub now_playing

# Popular
sub popular {
	my ($self) = @_;
	return $self->_search(
		{
			method => 'movie/popular',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub popular

# Top rated
sub top_rated {
	my ($self) = @_;
	return $self->_search(
		{
			method => 'movie/top-rated',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub top_rated

# Popular People
sub popular_people {
	my ($self) = @_;
	return $self->_search(
		{
			method => 'person/popular',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub popular_people

# Latest Person
sub latest_person {
	return shift->session->talk(
		{
			method => 'person/latest',
		}
	);
} ## end sub latest_person

#######################
# DISCOVER
#######################
sub discover {
	my ( $self, @args ) = @_;
	my %options = validate_with(
		params => [@args],
		spec   => {
			sort_by => {
				type      => SCALAR,
				optional  => 1,
				default   => 'popularity.asc',
				callbacks => {
					'valid flag' => sub {
						( lc $_[0] eq 'vote_average.desc' )
							or ( lc $_[0] eq 'vote_average.asc' )
							or ( lc $_[0] eq 'release_date.desc' )
							or ( lc $_[0] eq 'release_date.asc' )
							or ( lc $_[0] eq 'popularity.desc' )
							or ( lc $_[0] eq 'popularity.asc' );
					},
				},
			},
			year => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}$/
			},
			primary_release_year => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}$/
			},
			'release_date.gte' => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
			'release_date.lte' => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
			'vote_count.gte' => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d+$/
			},
			'vote_average.gte' => {
				type      => SCALAR,
				optional  => 1,
				regex     => qr/^\d{1,2}\.\d{1,}$/,
				callbacks => {
					average => sub { $_[0] <= 10 },
				},
			},
			with_genres => {
				type     => SCALAR,
				optional => 1,
			},
			with_companies => {
				type     => SCALAR,
				optional => 1,
			},
		},
	);

	return $self->_search(
		{
			method => 'discover/movie',
			params => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
				include_adult => $self->include_adult,
				%options,
			},
		}
	);

} ## end sub discover

#######################
# FIND
#######################
sub find {
	my ( $self, @args ) = @_;
	my %options = validate_with(
		params => [@args],
		spec   => {
			id => {
				type => SCALAR,
			},
			source => {
				type => SCALAR,
			},
		},
	);

	return $self->session->talk(
		{
			method => 'find/' . $options{id},
			params => {
				external_source => $options{source},
				language        => $self->session->lang
					? $self->session->lang
					: undef,
			}
		}
	);
} ## end sub find

#######################
# PRIVATE METHODS
#######################

## ====================
## Search
## ====================
sub _search {
	my $self = shift;
	my $args = shift;
	$args->{max_pages} = $self->max_pages();
	return $self->session->paginate_results($args);
} ## end sub _search

#######################

package TMDB::Session;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Shepherd::json_pp;
use Encode qw();
use HTTP::Tiny qw();
use Params::Validate qw(validate_with :types);
use Locale::Codes::Language qw(all_language_codes);
use Object::Tiny qw(apikey apiurl lang debug client encoder json);

#######################
# PACKAGE VARIABLES
#######################

# Valid language codes
my %valid_lang_codes = map { $_ => 1 } all_language_codes('alpha-2');

# Default Headers
my $default_headers = {
	'Accept'       => 'application/json',
	'Content-Type' => 'application/json',
};

# Default User Agent
my $default_ua = 'perl-tmdb-client';

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			apikey => {
				type => SCALAR,
			},
			apiurl => {
				type     => SCALAR,
				optional => 1,
				default  => 'https://api.themoviedb.org/3',
			},
			lang => {
				type      => SCALAR,
				optional  => 1,
				callbacks => {
					'valid language code' =>
						sub { $valid_lang_codes{ lc $_[0] } },
				},
			},
			client => {
				type     => OBJECT,
				isa      => 'HTTP::Tiny',
				optional => 1,
				default  => HTTP::Tiny->new(
					agent           => $default_ua,
					default_headers => $default_headers,
				),
			},
			encoder => {
				type     => OBJECT,
				isa      => 'URI::Encode',
				optional => 1,
				default  => URI::Encode->new(),
			},
			json => {
				type     => OBJECT,
				can      => [qw(decode)],
				optional => 1,
				default  => JSON::cut_down_PP->new(),
			},
			debug => {
				type     => BOOLEAN,
				optional => 1,
				default  => 0,
			},
		},
	);

	$opts{lang} = lc $opts{lang} if $opts{lang};
	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## Talk
## ====================
sub talk {
	my ( $self, $args ) = @_;

	# Build Call
	my $url
		= $self->apiurl . '/' . $args->{method} . '?api_key=' . $self->apikey;
	if ( $args->{params} ) {
		foreach
		my $param ( sort { lc $a cmp lc $b } keys %{ $args->{params} } )
		{
			next unless defined $args->{params}->{$param};
			$url .= "&${param}=" . $args->{params}->{$param};
		} ## end foreach my $param ( sort { ...})
	} ## end if ( $args->{params} )

	# Encode
	$url = $self->encoder->encode($url);

	# Talk
	warn "DEBUG: GET -> $url\n" if $self->debug;
	my $response = $self->client->get($url);

	# Debug
	if ( $self->debug ) {
		warn "DEBUG: Got a successful response\n" if $response->{success};
		warn "DEBUG: Got Status -> $response->{status}\n";
		warn "DEBUG: Got Reason -> $response->{reason}\n"
			if $response->{reason};
		warn "DEBUG: Got Content -> $response->{content}\n"
			if $response->{content};
	} ## end if ( $self->debug )

	# Return
	return unless $self->_check_status($response);
	if ( $args->{want_headers} and exists $response->{headers} ) {

		# Return headers only
		return $response->{headers};
	} ## end if ( $args->{want_headers...})
	return unless $response->{content};  # Blank Content
	return $self->json->decode(
		Encode::decode( 'utf-8-strict', $response->{content} ) ); # Real Response
} ## end sub talk

## ====================
## PAGINATE RESULTS
## ====================
sub paginate_results {
	my ( $self, $args ) = @_;

	my $response = $self->talk($args);
	my $results = $response->{results} || [];

	# Paginate
	if (    $response->{page}
		and $response->{total_pages}
		and ( $response->{total_pages} > $response->{page} ) )
	{
		my $page_limit = $args->{max_pages} || '1';
		my $current_page = $response->{page};
		while ($page_limit) {
			last if ( $current_page == $page_limit );
			$current_page++;
			$args->{params}->{page} = $current_page;
			my $next_page = $self->talk($args);
			push @$results, @{ $next_page->{results} },;
			last if ( $next_page->{page} == $next_page->{total_pages} );
			$page_limit--;
		} ## end while ($page_limit)
	} ## end if ( $response->{page}...)

	# Done
	return @$results if wantarray;
	return $results;
} ## end sub paginate_results

#######################
# INTERNAL
#######################

# Check Response status
sub _check_status {
	my ( $self, $response ) = @_;

	if ( $response->{success} ) {
		return 1;
	}

	if ( $response->{content} ) {
		my ( $code, $message );
		my $ok = eval {

			my $status = $self->json->decode(
				Encode::decode( 'utf-8-strict', $response->{content} ) );

			$code    = $status->{status_code};
			$message = $status->{status_message};

			1;
		};

		if ( $ok and $code and $message ) {
			carp sprintf( 'TMDB API Error (%s): %s', $code, $message );
		}
	} ## end if ( $response->{content...})

	return;
} ## end sub _check_status

#######################

package TMDB::TV;

#######################
# LOAD CORE MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);

#######################
# LOAD CPAN MODULES
#######################
use Object::Tiny qw(id session);
use Params::Validate qw(validate_with :types);
use Locale::Codes::Country qw(all_country_codes);

#######################
# PUBLIC METHODS
#######################

## ====================
## Constructor
## ====================
sub new {
	my $class = shift;
	my %opts  = validate_with(
		params => \@_,
		spec   => {
			session => {
				type => OBJECT,
				isa  => 'TMDB::Session',
			},
			id => {
				type => SCALAR,
			},
		},
	);

	my $self = $class->SUPER::new(%opts);
	return $self;
} ## end sub new

## ====================
## INFO
## ====================
sub info {
	my $self   = shift;
	my $params = {};
	$params->{language} = $self->session->lang if $self->session->lang;
	my $info = $self->session->talk(
		{
			method => 'tv/' . $self->id,
			params => $params
		}
	);
	return unless $info;
	$self->{id} = $info->{id};  # Reset TMDB ID
	return $info;
} ## end sub info

## ====================
## ALTERNATIVE TITLES
## ====================
sub alternative_titles {
	my $self    = shift;
	my $country = shift;

	# Valid Country codes
	if ($country) {
		my %valid_country_codes
			= map { $_ => 1 } all_country_codes('alpha-2');
		$country = uc $country;
		return unless $valid_country_codes{$country};
	} ## end if ($country)

	my $args = {
		method => 'tv/' . $self->id() . '/alternative_titles',
		params => {},
	};
	$args->{params}->{country} = $country if $country;

	my $response = $self->session->talk($args);
	my $titles = $response->{results} || [];

	return @$titles if wantarray;
	return $titles;
} ## end sub alternative_titles

## ====================
## CAST
## ====================
sub cast {
	my $self     = shift;
	my $response = $self->_credits();
	my $cast     = $response->{cast} || [];
	return @$cast if wantarray;
	return $cast;
} ## end sub cast

## ====================
## CREW
## ====================
sub crew {
	my $self     = shift;
	my $response = $self->_credits();
	my $crew     = $response->{crew} || [];
	return @$crew if wantarray;
	return $crew;
} ## end sub crew

## ====================
## IMAGES
## ====================
sub images {
	my $self   = shift;
	my $params = {};
	$params->{lang} = $self->session->lang if $self->session->lang;
	return $self->session->talk(
		{
			method => 'tv/' . $self->id() . '/images',
			params => $params
		}
	);
} ## end sub images

## ====================
## VIDEOS
## ====================
sub videos {
	my $self = shift;
	my $response
		= $self->session->talk( { method => 'tv/' . $self->id() . '/videos' } );
	my $videos = $response->{results} || [];

	return @$videos if wantarray;
	return $videos;

} ## end sub videos

## ====================
## KEYWORDS
## ====================
sub keywords {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'tv/' . $self->id() . '/keywords' } );
	my $keywords_dump = $response->{results} || [];
	my @keywords;
	foreach (@$keywords_dump) { push @keywords, $_->{name}; }
	return @keywords if wantarray;
	return \@keywords;
} ## end sub keywords

## ====================
## TRANSLATIONS
## ====================
sub translations {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'tv/' . $self->id() . '/translations' } );
	my $translations = $response->{translations} || [];
	return @$translations if wantarray;
	return $translations;
} ## end sub translations

## ====================
## SIMILAR TV SHOWS
## ====================
sub similar {
	my ( $self, $max_pages ) = @_;
	return $self->session->paginate_results(
		{
			method    => 'tv/' . $self->id() . '/similar',
			max_pages => $max_pages,
			params    => {
				language => $self->session->lang
					? $self->session->lang
					: undef,
			},
		}
	);
} ## end sub similar

## ====================
## CONTENT RATING
## ====================
sub content_ratings {
	my $self     = shift;
	my $response = $self->session->talk(
		{ method => 'tv/' . $self->id() . '/content_ratings' } );
	my $content_ratings = $response->{results} || [];
	return @$content_ratings if wantarray;
	return $content_ratings;
} ## end sub content_ratings

## ====================
## SEASON
## ====================
sub season {
	my $self   = shift;
	my $season = shift;
	return $self->session->talk(
		{ method => 'tv/' . $self->id() . '/season/' . $season } );
} ## end sub season

## ====================
## EPISODE
## ====================
sub episode {
	my $self    = shift;
	my $season  = shift;
	my $episode = shift;
	return $self->session->talk(
		{
			method => 'tv/'
				. $self->id()
				. '/season/'
				. $season
				. '/episode/'
				. $episode
		}
	);
} ## end sub episode

## ====================
## CHANGES
## ====================
sub changes {
	my ( $self, @args ) = @_;
	my %options = validate_with(
		params => [@args],
		spec   => {
			start_date => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
			end_date => {
				type     => SCALAR,
				optional => 1,
				regex    => qr/^\d{4}\-\d{2}\-\d{2}$/
			},
		},
	);

	my $changes = $self->session->talk(
		{
			method => 'tv/' . $self->id() . '/changes',
			params => {
				(
					$options{start_date}
						? ( start_date => $options{start_date} )
						: ()
				), (
				$options{end_date} ? ( end_date => $options{end_date} )
					: ()
			),
			},
		}
	);

	return unless defined $changes;
	return unless exists $changes->{changes};
	return @{ $changes->{changes} } if wantarray;
	return $changes->{changes};
} ## end sub changes

## ====================
## VERSION
## ====================
sub version {
	my ($self) = @_;
	my $response = $self->session->talk(
		{
			method       => 'tv/' . $self->id(),
			want_headers => 1,
		}
	) or return;
	my $version = $response->{etag} || q();
	$version =~ s{"}{}gx;
	return $version;
} ## end sub version

#######################
# PRIVATE METHODS
#######################

## ====================
## CREDITS
## ====================
sub _credits {
	my $self = shift;
	return $self->session->talk(
		{
			method => 'tv/' . $self->id() . '/credits',
		}
	);
} ## end sub _credits

#######################
package URI::Encode;

#######################
# LOAD MODULES
#######################
use strict;
use warnings FATAL => 'all';

use 5.008001;
use Encode qw();
use Carp qw(croak carp);

#######################
# VERSION
#######################
our $VERSION = '1.1.1';

#######################
# EXPORT
#######################
#use base qw(Exporter);
#our (@EXPORT_OK);

#@EXPORT_OK = qw(uri_encode uri_decode);

#######################
# SETTINGS
#######################

# Reserved characters
my $reserved_re
	= qr{([^a-zA-Z0-9\-\_\.\~\!\*\'\(\)\;\:\@\&\=\+\$\,\/\?\#\[\]\%])}x;

# Un-reserved characters
my $unreserved_re = qr{([^a-zA-Z0-9\Q-_.~\E\%])}x;

# Encoded character set
my $encoded_chars = qr{%([a-fA-F0-9]{2})}x;

#######################
# CONSTRUCTOR
#######################
sub new {
	my ( $class, @in ) = @_;

	# Check Input
	my $defaults = {

		#   this module, unlike URI::Escape,
		#   does not encode reserved characters
		encode_reserved => 0,

		#   Allow Double encoding?
		#   defaults to YES
		double_encode => 1,
	};

	my $input = {};
	if   ( ref $in[0] eq 'HASH' ) { $input = $in[0]; }
	else                          { $input = {@in}; }

	# Set options
	my $options = {

		# Defaults
		%{$defaults},

		# Input
		%{$input},

		# Encoding Map
		enc_map =>
			{ ( map { chr($_) => sprintf( "%%%02X", $_ ) } ( 0 ... 255 ) ) },

		# Decoding Map
		dec_map =>
			{ ( map { sprintf( "%02X", $_ ) => chr($_) } ( 0 ... 255 ) ), },
	};

	# Return
	my $self = bless $options, $class;
	return $self;
} ## end sub new

#######################
# ENCODE
#######################
sub encode {
	my ( $self, $data, $options ) = @_;

	# Check for data
	# Allow to be '0'
	return unless defined $data;

	my $enc_res       = $self->{encode_reserved};
	my $double_encode = $self->{double_encode};

	if ( defined $options ) {
		if ( ref $options eq 'HASH' ) {
			$enc_res = $options->{encode_reserved}
				if exists $options->{encode_reserved};
			$double_encode = $options->{double_encode}
				if exists $options->{double_encode};
		} ## end if ( ref $options eq 'HASH')
		else {
			$enc_res = $options;
		}
	} ## end if ( defined $options )

	# UTF-8 encode
	$data = Encode::encode( 'utf-8-strict', $data );

	# Encode a literal '%'
	if ($double_encode) { $data =~ s{(\%)}{$self->_get_encoded_char($1)}gex; }
	else { $data =~ s{(\%)(.*)}{$self->_encode_literal_percent($1, $2)}gex; }

	# Percent Encode
	if ($enc_res) {
		$data =~ s{$unreserved_re}{$self->_get_encoded_char($1)}gex;
	}
	else {
		$data =~ s{$reserved_re}{$self->_get_encoded_char($1)}gex;
	}

	# Done
	return $data;
} ## end sub encode

#######################
# DECODE
#######################
sub decode {
	my ( $self, $data ) = @_;

	# Check for data
	# Allow to be '0'
	return unless defined $data;

	# Percent Decode
	$data =~ s{$encoded_chars}{ $self->_get_decoded_char($1) }gex;

	return $data;
} ## end sub decode

#######################
# EXPORTED FUNCTIONS
#######################

# Encoder
sub uri_encode { return __PACKAGE__->new()->encode(@_); }

# Decoder
sub uri_decode { return __PACKAGE__->new()->decode(@_); }

#######################
# INTERNAL
#######################


sub _get_encoded_char {
	my ( $self, $char ) = @_;
	return $self->{enc_map}->{$char} if exists $self->{enc_map}->{$char};
	return $char;
} ## end sub _get_encoded_char


sub _encode_literal_percent {
	my ( $self, $char, $post ) = @_;

	return $self->_get_encoded_char($char) if not defined $post;

	my $return_char;
	if ( $post =~ m{^([a-fA-F0-9]{2})}x ) {
		if ( exists $self->{dec_map}->{$1} ) {
			$return_char = join( '', $char, $post );
		}
	} ## end if ( $post =~ m{^([a-fA-F0-9]{2})}x)

	$return_char ||= join( '', $self->_get_encoded_char($char), $post );
	return $return_char;
} ## end sub _encode_literal_percent


sub _get_decoded_char {
	my ( $self, $char ) = @_;
	return $self->{dec_map}->{ uc($char) }
		if exists $self->{dec_map}->{ uc($char) };
	return $char;
} ## end sub _get_decoded_char

#######################
1;