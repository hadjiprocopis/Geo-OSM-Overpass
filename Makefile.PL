use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    INSTALL_BASE     => $ENV{'HOME'}.'/usr',
    NAME             => 'Geo::OSM::Overpass',
    AUTHOR           => q{Andreas Hadjiprocopis <bliako@cpan.org>},
    VERSION_FROM     => 'lib/Geo/OSM/Overpass.pm',
    ABSTRACT_FROM    => 'lib/Geo/OSM/Overpass.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    EXE_FILES	     => ['bin/osm-make-query.bash'],
    MIN_PERL_VERSION => '5.006',
    CONFIGURE_REQUIRES => {
	'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
	'Test::More' => '0',
	'LWP::UserAgent' => '6.35',
	'HTTP::Request::Common' => '6.15',
	'LWP::ConsoleLogger::Easy' => '0.000039', # only when verbosity >2
	'Geo::BoundingBox' => '0.01',
    },
    PREREQ_PM => {
	#'ABC'	      => '1.6',
	#'Foo::Bar::Module' => '5.0401',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Geo-OSM-Overpass-*' },
);
