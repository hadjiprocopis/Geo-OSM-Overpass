#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use Test::More;
use File::Temp;

use Geo::OSM::Overpass;
use Geo::BoundingBox;

my $num_tests = 0;

my $op = Geo::OSM::Overpass->new();
ok(defined $op, 'Geo::OSM::Overpass->new()'.": called") or BAIL_OUT('Geo::OSM::Overpass->new()'.": failed, can not continue."); $num_tests++;

$op->verbosity(2);

ok(defined $op->ua(), "checking ua()"); $num_tests++;

my $bbox = Geo::BoundingBox->new();
# make a 100mx100m bbox centred at lat,lon
$bbox->centred_at([35.170985, 33.357755, 100, 100]);
ok($bbox->equals($op->bbox($bbox), 6), "checking bbox()"); $num_tests++;

# prepare a query
my $nodeid = '2000554054';
my $querystr =
	$op->_overpass_XML_preamble()
	."\n<id-query ref='$nodeid' type='node'/>\n"
	.$op->_overpass_XML_postamble()."\n"
;
# run a query
is($op->query($querystr), 1, "checking query()"); $num_tests++;

my $result = $op->last_query_result();
ok(defined($result), "checking if got result"); $num_tests++;
ok(defined($result) && 1 == ( ()= $$result =~ m|<node.+id="${nodeid}".+?/|gs), "checking if got specific node."); $num_tests++;

my (undef, $tmpf) = File::Temp::tempfile(OPEN=>0);
$op->output_filename($tmpf);
ok($tmpf eq $op->output_filename(), "checking output_filename()"); $num_tests++;

# save the results of the query to file
is($op->save(), 1, "checking save()"); $num_tests++;
ok(-f $tmpf && -s $tmpf, "checking save(), output file exists and > 0"); $num_tests++;

# change some things:
$op->query_timeout(23);
$op->query_output_type('json');
$querystr = $op->_overpass_XML_preamble()
."\n<id-query ref='$nodeid' type='node'/>\n"
.$op->_overpass_XML_postamble()."\n"
;

# run the query again
is($op->query($querystr), 1, "checking query()"); $num_tests++;
my $qtext = $op->last_query_text();
ok($qtext eq $querystr, "checking if query text was copied in self prior to making the query."); $num_tests++;
print "qtext=\n$qtext\n---\n";
ok($qtext =~ /timeout="23"/, "checking query_timeout()"); $num_tests++;
ok($qtext =~ /output="json"/, "checking query_output_type()"); $num_tests++;
$result = $op->last_query_result();
ok(defined($result), "checking if got result for query()");$num_tests++;
ok(defined($result) && $$result =~ m|"type"\s*:\s*"node"|, "checking result contains a node."); $num_tests++;
ok(defined($result) && $$result =~ m|"lat"\s*:\s*\d+\.\d+|, "checking result contains coordinates."); $num_tests++;

unlink($tmpf);

# END
done_testing($num_tests);
