use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

use File::Spec;

sub MY::postamble {
    my (undef,%h) = @_;
    #require Data::Dumper;
    #print STDERR Data::Dumper->Dump([\%h], [qw(mm_args{postamble})]);
    my $indir = $h{'DIR'};
    $indir = '.' unless defined $indir;
    if( defined $h{'GITIGNORE'} ){
	# an array of gitignore lines
	my $gitignorefile = File::Spec->catdir($indir, '.gitignore');
	my $GH;
	if( ! open $GH, '>:encoding(utf-8)', $gitignorefile ){ print STDERR "$0 : failed to open '$gitignorefile' file for writing.\n"; exit(1) }
	print $GH $h{'GITIGNORE'};
	close $GH
    } # if 
    # append to Makefile, newlines and tabs are important!
    my $ret = "git-push ::\n";
    $ret .= "\tgit init\n";
    $ret .= "\tgit add ".(exists($h{'GIT_ADD'})?$h{'GIT_ADD'}:'.')."\n";
    $ret .= "\tgit commit -am 'first commit'\n";
    $ret .= "\t".'@git ls-remote '.$h{GIT_DESTINATION}.' &> /dev/null || (echo "make : you need to create the repository '.$h{GIT_DESTINATION}.' first ..."; exit 1)'."\n";
    $ret .= "\t".'git push -f "'.$h{GIT_DESTINATION}.'" --all'."\n";
    return $ret;
}

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
    postamble => {
	CURDIR => '.',
	GIT_DESTINATION => 'git@github.com:hadjiprocopis/geo-osm-overpass.git',
	GIT_ADD => '.', # list of files to add or wildcards, space separated, quote for shell
	GITIGNORE => <<'EOC',
# whitelist mode:
# first, ignore everything
/*
# then add what we like
!lib
!bin
!*/t
!*/xt
!Makefile.PL
!Changes
!MANIFEST
!README
EOC
    }
);
