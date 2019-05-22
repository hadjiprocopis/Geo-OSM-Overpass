package Geo::OSM::Overpass;

####
# online resources:
#  http://overpass-api.de/query_form.html
#  https://overpass-turbo.eu/
#  https://forum.openstreetmap.org/
####

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

use utf8;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use LWP::UserAgent;
use HTTP::Request::Common;

use Geo::BoundingBox;

sub	new {
	my $class = shift;
	my $params = shift;
	$params = {} unless defined $params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = {
		'overpass-api-url' => 'http://overpass-api.de/api/interpreter',
		'output-filename' => undef,
		'verbosity' => 0,
		'ua' => undef,
		'bbox' => undef,

		# options specific to the query
		# '<osm-script' params
		'query-timeout' => 25, # in seconds
		'query-output-type' => 'xml', # xml, json, CSV, custom, popup (see https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL)
		'query-max-memory-size' => undef,

		# this affects the postamble print
		# can be center for center of the ways, see https://forum.openstreetmap.org/viewtopic.php?id=66178
		# default is skeleton
		'query-print-mode' => 'skeleton',

		# these are internal
		# we store the text of the last query (what we sent over):
		'last-query-text' => undef,
		# we store the result of the last query, undef is valid if error came back
		'last-result-text' => undef,

		# private
		'_query-preamble' => undef,
		'_query-postamble' => undef,
		# each time timeout/output type etc change this becomes 1
		# and preamble is recalculated if and when it is needed
		'_query-preamble-needs-recalc' => 1,
		'_query-postamble-needs-recalc' => 1,
		# private for lwp when doing debugging a ref is stored here, nothing to worry about
		'lwp-logger' => undef,
	};
	bless $self, $class;

	my $m;
	if( defined($m=$params->{'ua'}) ){
		# we were supplied with a custom LWP object
		$self->ua($m);
	} else {
		# we are creating our own LWP using optional params specified
		if( ! $self->_create_ua($params->{'ua-params'}) ){ print STDERR "$whoami (via $parent) : call to _create_ua() has failed.\n"; return undef }
	}

	if( defined($m=$params->{'output-filename'}) ){ $self->output_filename($m) }
	if( defined($m=$params->{'query-timeout'}) ){ $self->query_timeout($m) }
	if( defined($m=$params->{'query-output-type'}) ){ $self->query_output_type($m) }
	if( defined($m=$params->{'overpass-api-url'}) ){ $self->overpass_api_url($m) }
	if( defined($m=$params->{'verbosity'}) ){ $self->verbosity($m) }
	if( defined($m=$params->{'bbox'}) ){ $self->bbox($m) }
	if( defined($m=$params->{'query-print-mode'}) ){ $self->query_print_mode($m) }

	return $self
}
# parameter is the query text
# it copies it to 'last-query-text'
# result is copied to 'last-query-result' (if failed, then this becomes undef)
# returns 0 on failure
# returns 1 on success and also sets self->{'last-query-result'} to the result we got
sub	query {
	my $self = $_[0];
	my $query_txt = $_[1];

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	# firstly, zero the result
	$self->{'last-query-result'} = undef;

	if( ! defined $query_txt ){ print STDERR "$whoami (via $parent) : query text was not specified as the 1st parameter.\n"; return 0 }
	$self->{'last-query-text'} = $query_txt;

	my $VERB = $self->verbosity();
	if( $VERB > 0 ){ print "$whoami (via $parent) : will run the query:\n$query_txt\n-- end of query text.\n" }

	my $aresponse = $self->ua()->request(
		POST $self->overpass_api_url(),
		['data' => $query_txt]
	);
	if( ! defined $aresponse || ! $aresponse->is_success ){ print STDERR "$whoami (via $parent) : request to ".'overpass_api_url()'." has failed for the following query:\n$query_txt\n--- end of osm query text. Reason of failure: ".$aresponse->status_line."\n"; return 0 }
	# set the result
	$self->last_query_result($aresponse->decoded_content);
	if( $VERB > 0 ){ print "$whoami (via $parent) : received response:\n".$aresponse->decoded_content."\n" }

	return 1 # success
}
# optional output filename (overwrites that in $self)
# returns 0 on failure
# returns 1 on success
sub	save {
	my $self = $_[0];
	my $m = $_[1];

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	$m = $self->output_filename() unless defined $m;
	if( ! defined $m ){ print STDERR "$whoami (via $parent) : an output filename has not been specified either here or at the constructor.\n"; return 0 }

	my $resref = $self->last_query_result();
	# if no result (undef) then we print empty
	$resref = \'' unless defined $resref;
	my $FH;
	if( ! open $FH, '>:encoding(utf-8)', $m ){ print STDERR "$whoami (via $parent) : error, failed to open file '$m' for writing, $!\n"; return 0 }
	print $FH $$resref;
	close $FH;
	return 1 # success
}
sub	verbosity {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'verbosity'} unless defined $m;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	$self->{'verbosity'} = $m;
	my $ua;
	if( defined($ua=$self->ua()) ){
		if( $m > 1 ){
			print "$whoami (via $parent) : turning LWP debug on, level $m.\n";
			require LWP::ConsoleLogger::Easy;
			LWP::ConsoleLogger::Easy->import( qw(debug_ua) );
			$self->{'lwp-logger'} = LWP::ConsoleLogger::Easy::debug_ua($ua, $m);
			#if( $m > 2 ){
			#	# turn SSL debug on (if api has https on) using $IO::Socket::SSL::DEBUG=3
			#}
		} else {
			print "$whoami (via $parent) : turning LWP debug off.\n";
			if( defined $self->{'lwp-logger'} ){ $self->{'lwp-logger'}->dump_headers( 0 ) }
			# turn SSL debug off (if api has https on) using $IO::Socket::SSL::DEBUG=0
		}
	}
	return $m
}
sub	last_query_text { return $_[0]->{'last-query-text'} }
# returns a reference to the last-query-result text IF IT IS DEFINED
# if last query result is undef (meaning no query ran yet or query failed)
# then it returns undef
# or sets the result text as a string
sub	last_query_result {
	my $self = $_[0];
	my $m = $_[1];
	if( defined $m ){
		$self->{'last-query-result'} = $m;
		return \$self->{'last-query-result'}
	}
	if( defined $self->{'last-query-result'} ){
		return \$self->{'last-query-result'}
	}
	return undef # no result yet
}
sub	overpass_api_url {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'overpass-api-url'} unless defined $m;

	$self->{'overpass-api-url'} = $m;
	return $m
}
sub	output_filename {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'output-filename'} unless defined $m;

	$self->{'output-filename'} = $m;
	return $m
}
sub	bbox {
	my $self = $_[0];
	my $m = $_[1];

	return $self->{'bbox'} unless defined $m;

	if( ref($m) eq 'Geo::BoundingBox' ){ $self->{'bbox'} = $m; return $m }

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $bb = Geo::BoundingBox->new($m);
	if( ! defined $bb ){ print STDERR "$whoami (via $parent) : call to ".'Geo::BoundingBox->new()'." has failed for params: ".Dumper($m)."\n"; return undef }
	$self->{'bbox'} = $bb;
	return $bb
}
# sets/gets the UA object
# returns the UA on success or undef on failure
sub	ua {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'ua'} unless defined $m;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	# we need an LWP::UserAgent derivative, hope that catches all...
	if( ref($m) !~ /^LWP::UserAgent/ ){ print STDERR "$whoami (via $parent) : user-agent must be LWP::UserAgent or derived from it.\n"; return undef }

	$self->{'ua'} = $m;
	return $m # success
}
# create our own default LWP object given some optional params to pass on to the LWP constructor
sub	_create_ua {
	my $self = $_[0];
	my $ua_params = $_[1];
	$ua_params = {} unless defined $ua_params;

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	$self->{'ua'} = LWP::UserAgent->new(%{$ua_params});
	if( ! defined $self->{'ua'} ){ print STDERR "$whoami (via $parent) : call to ".'LWP::UserAgent->new()'." has failed.\n"; return undef }
	return $self->{'ua'}
}
# sets the seconds before the query times out
sub	query_timeout {
	my $self = $_[0];
	my $m = $_[1];

	return $self->{'query-timeout'} unless defined $m;
	$self->{'query-timeout'} = $m;
	$self->{'_query-preamble-needs-recalc'} = 1;
	return $m
}
# sets the output type of the results as one of:
# xml, json, CSV, custom, popup
# (see https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL)
sub	query_output_type {
	my $self = $_[0];
	my $m = $_[1];

	return $self->{'query-output-type'} unless defined $m;
	$self->{'query-output-type'} = lc $m;
	$self->{'_query-preamble-needs-recalc'} = 1;
	return $m
}
# sets max memory to be allocated for our query by the remote server
# max is 1073741824 bytes (see https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL)
# this is rubbish and crap and do not use it.
sub	max_memory_size {
	my $self = $_[0];
	my $m = $_[1];

	return $self->{'query-max-memory-size'} unless defined $m;
	$self->{'query-max-memory-size'} = $m;
	$self->{'_query-preamble-needs-recalc'} = 1;
	return $m
}
# sets the print mode, for example in finding the centre of a roundabout
# use center (roundabout is a 'way'), for nodes use 'body'
# body, center
# (see https://forum.openstreetmap.org/viewtopic.php?id=66178)
sub	query_print_mode {
	my $self = $_[0];
	my $m = $_[1];

	return $self->{'query-print-mode'} unless defined $m;
	$self->{'query-print-mode'} = lc $m;
	$self->{'_query-postamble-needs-recalc'} = 1;
	return $m
}
sub	_recalc_query_preamble {
	my $self = $_[0];
	if( ! $self->{'_query-preamble-needs-recalc'} ){ return }
	my $pr =
		 '<osm-script timeout="'.$self->query_timeout()
		.'" output="'.$self->query_output_type().'"'
	;
	my $m = $self->max_memory_size();
	if( defined $m ){ $pr .= '" element-limit="'.$m.'"' }
	$pr .= '>';

	$self->{'_query-preamble'} = $pr."\n";
	$self->{'_query-preamble-needs-recalc'} = 0;
}
sub	_recalc_query_postamble {
	my $self = $_[0];
	if( ! $self->{'_query-postamble-needs-recalc'} ){ return }
	my $pr = 
'  <print e="" from="_" geometry="'
.$self->query_print_mode()
.'" ids="yes" limit="" mode="body" n="" order="id" s="" w=""/>
  <recurse from="_" into="_" type="down"/>
  <print e="" from="_" geometry="skeleton" ids="yes" limit="" mode="skeleton" n="" order="quadtile" s="" w=""/>
</osm-script>'
	;
	$self->{'_query-postamble'} = $pr;
	$self->{'_query-postamble-needs-recalc'} = 0;
}
# return the XML preamble of the query
# it is static value but updated each time something changes (e.g. timeout) lazily
sub	_overpass_XML_preamble {
	my $self = $_[0];
	if( $self->{'_query-preamble-needs-recalc'} ){ $self->_recalc_query_preamble() }
	return $self->{'_query-preamble'}
}
# return the XML postamble of the query
# it is static value but updated each time something changes (e.g. timeout) lazily
sub	_overpass_XML_postamble {
	my $self = $_[0];
	if( $self->{'_query-postamble-needs-recalc'} ){ $self->_recalc_query_postamble() }
	return $self->{'_query-postamble'}
}

# pod starts here
=encoding utf8
=head1 NAME

Geo::OSM::Overpass - Access OpenStreetMap data using the Overpass API

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Geo::OSM::Overpass;

    my $ovp = Geo::OSM::Overpass->new({
     'timeout' => 10,
    });
    $ovp->query(<<EOQ);
    <osm-script>
      <union>
          <query type="node">
            <has-kv k="highway" v="bus_stop"/>
            <bbox-query
    	s="35.096464"
    	w="33.273956"
    	n="35.195076"
    	e="33.437240"
    	/>
          </query>
      </union>
      <print mode="body"/>
      <recurse type="down"/>
      <print mode="skeleton"/>
    </osm-script>
EOQ

    $ovp->save("output.xml");
    print $ovp->last_query_text()."\nGot some results back for above query\n".${$ovp->last_query_result()}."\n"


=head1 SUBROUTINES/METHODS

Please note that this module does not provide any high-level data retrieval.
One must specify queries using Overpass API language(s), as per the example in the Synopsis.
What this module is good at is to initiate the communication with the OpenStreetMap
Overpass API server, send the query and get the results back. The real use of this module
would be if used in conjuction with plugins (see L<Geo::OSM::Overpass::Plugin>) which
abstract API queries to a level where one just says "fetch bus-stops".

=head2 C<< new($params) >>

Constructor with optional hashref of parameters.
Optional parameters are:

=over 4

=item * C<< ua >> specify an already created UserAgent object which must be derived from L<LWP::UserAgent>
or its subclassed modules. If no UserAgent object is specified, a default will be created at the
constructor phase (see also parameter C<< ua-params >> below).

=item * C<< ua-params >> if no UserAgent object is specified via the C<< ua >> parameter, then a default
UserAgent object will be created at the constructor with optional C<< ua-params >> hashref to be
passed to its constructor.

=item * C<< query-timeout >> specify the seconds after which query times out, can also be get/set using C<< query_timeout() >>

=item * C<< query-output-type >> specify the output type of the result of the query, can also be get/set using C<< query_output_type() >>

=item * C<< overpass-api-url >> specify the Overpass API url (currently at L<http://overpass-api.de/api/interpreter>), can also be get/set using C<< overpass_api_url() >>

=item * C<< verbosity >> specify the verbosity, can also be get/set using C<< verbosity() >>

=item * C<< bbox >> specify the bounding box for the query, can also be get/set using C<< bbox() >>

=item * C<< query-print-mode >> specify the output print mode, can also be get/set using C<< query_print_mode() >>

=back

=head2 C<< query($q) >>

Send query C<< $q >> to the OSM Overpass API url using our internal UserAgent object,
store C<< $q >> internally (can be accessed using C<< last_query_text() >>) and get the result
back (at the moment of writing as XML, JSON or CSV etc.)
and store the result internally so it can be accessed using C<< last_query_result() >>.
See L<https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide#Choose_file_format_.28output.3D.22json.22.2C_.5Bout:json.5D.29>
for Overpass API language guide which covers both XML-based queries (that means the query
is formulated using XML) or QL-based queries, QL being Overpass specially crafter query
language. Here is an example XML-based query to fetch all bus stops within the specified
bounding box:

    <osm-script>
      <union>
          <query type="node">
            <has-kv k="highway" v="bus_stop"/>
            <bbox-query
    	s="35.096464"
    	w="33.273956"
    	n="35.195076"
    	e="33.437240"
    	/>
          </query>
      </union>
      <print mode="body"/>
      <recurse type="down"/>
      <print mode="skeleton"/>
    </osm-script>

And here is an example using Overpass QL (taken from L<https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide>):

    ["highway"="bus_stop"]
      ["shelter"]
      ["shelter"!="no"]
      (50.7,7.1,50.8,7.25);
    out body;

This method returns 1 when it succeeds or 0 when it fails, in which case
C<< last_query_result() >> returns C<< undef >>.


=head2 C<< save($optional_filename) >>

Saves the result of the last query (as returned by C<< last_query_result() >>) to
a file. The filename can be specified using optional input parameter C<< $optional_filename >>,
otherwise the output filename set during construction will be used. If none specified,
it does no save and complains.

It returns 1 when it succeeds or 0 when it fails, either because no output filename
was ever specified or because saving had failed.

=head2 C<< verbosity($L) >>

If no input parameter is specified, then it returns the current verbosity level.
Otherwise it sets the current verbosity level to C<< $L >>.
level 0 verbosity means absolute silence, level 1 means basic staff, level 2 means using
L<LWP::ConsoleLogger::Easy> and level 3 will mean debugging SSL if and when
OSM Overpass API offers SSL connections for a good way to waste their resources.

=head2 C<< last_query_text() >>

Returns the text of the last query sent (successful or not) to the API server.
May return C<< undef >> if no query has yet been submitted.

=head2 C<< last_query_result($m) >>

If no input parameter is specified, it returns a SCALAR REFERENCE to
the string result of the last
query performed. This can be C<< undef >> if no query has yet been executed,
or if it returned an error.

If an input parameter is specified C<< $m >> (as a string AND NOT as SCALAR REFERENCE),
it sets this as the last query result.


=head2 C<< output_filename($m) >>

If no input parameter is specified, it returns the output filename already set
(can be C<< undef >>).

If an input parameter is specified C<< $m >>, it sets this as the output filename to
be used during C<< save() >>. The optional parameter to C<< save() >> takes precedence over
our internally stored output filename but only temporarily and is not remembered.


=head2 C<< query_timeout($m) >>

If no input parameter is specified, it returns the seconds after which
a query times out. There is a default value of 25 seconds.

If an input parameter is specified C<< $m >>, it sets this as the timeout value.


=head2 C<< query_output_type($m) >>

The results returned by a query can be in XML or JSON format. Other formats
are also available, see L<https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide#Choose_file_format_.28output.3D.22json.22.2C_.5Bout:json.5D.29>


=head2 C<< overpass_api_url($m) >>

If no input parameter is specified, it returns the url of the OSM Overpass API.

If an input parameter is specified C<< $m >>, it sets this as the API url. Default
url is L<http://overpass-api.de/api/interpreter>


=head2 C<< bbox($b) >>

If no input parameter is specified, it returns the bounding box (bbox) specific
to any future queries.

If an input parameter is specified C<< $b >>, it sets this as the bbox for all future
queries. There is no default bounding box, one must be specified prior to executing
a query which requires it. Be considerate when specifying the bounding box of your
searches because a larger box usually entails a higher load for the free OSM
servers. Be considerate.

Internally the bounding box is a L<Geo::BoundingBox> object. This is what is returned
when this method acts as a getter. However, in setting the bounding box using C<< $b >>,
one can either create a L<Geo::BoundingBox> object and supply it, or specify
an arrayref to be passed to the constructor of L<Geo::BoundingBox> or specify
a single string holding the bounding box specification as a string. Refer
to L<Geo::BoundingBox> for more information on how to create a bounding box:
i.e. via a centred-at spec: C<< lat:lon,width[xheight] >> or a bounded-by
spec: C<< bottom-left-lat:bottom-left-long, top-right-lat:top-right-lon >>.


=head2 C<< query_print_mode($m) >>

This sets the C<< geometry >> parameter of the C<< print >> tag part of the query (postamble).
Default is C<< skeleton >> and that works well for when the results consist of C<< node >>s,
meaning that it will print the coordinates of each node. However, when results
consist of C<< way >>s (which themselves consist of nodes), then this option can be set
to C<< center >> (sic) in order to calculate and print the center of all the C<< node >>s making
up the C<< way >>. This is useful in obtaining the centre of roundabouts (which are ways)
as part of the result of the query. See for example L<Geo::OSM::Overpass::Plugin::FetchRoundabouts>


=head2 C<< _overpass_XML_preamble() >>

This method is only ever required if you write a plugin. It will return
the preamble to any query text. The preamble may change if some parameters change,
for example C<< timeout >>.


=head2 C<< _overpass_XML_postamble() >>

This method is only ever required if you write a plugin. It will return
the postamble to any query text. The postamble may change if some parameters change,
for example the query print mode (see C<< query_print_mode() >>).


=head1 AUTHOR

Andreas Hadjiprocopis, C<< bliako at cpan.org >>


=head1 CAVEATS

This is alpha release, the API is not yet settled and may change.


=head1 BUGS

Please report any bugs or feature requests to C<< bug-geo-osm-overpass at rt.cpan.org >>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Geo-OSM-Overpass>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Geo::OSM::Overpass


You can also look for information at:

=over 4

=item * L<https://www.openstreetmap.org> main entry point

=item * L<https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide> Overpass API
query language guide.

=item * L<https://overpass-turbo.eu> Overpass Turbo query language online
sandbox. It can also convert to XML query language.

=item * L<http://overpass-api.de/query_form.html> yet another online sandbox and
converter.


=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Geo-OSM-Overpass>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Geo-OSM-Overpass>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Geo-OSM-Overpass>

=item * Search CPAN

L<https://metacpan.org/release/Geo-OSM-Overpass>

=back


=head1 DEDICATIONS

Almaz


=head1 ACKNOWLEDGEMENTS

There would be no need for this module if the great project OpenStreetMap
was not conceived, implemented, data-collectively-collected and publicly-served
by the great people of the OpenStreetMap project. Thanks!

```
 @misc{OpenStreetMap,
   author = {{OpenStreetMap contributors}},
   title = {{Planet dump retrieved from https://planet.osm.org }},
   howpublished = "\url{ https://www.openstreetmap.org }",
   year = {2017},
 }
```

=head1 LICENSE AND COPYRIGHT

Copyright 2019 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Geo::OSM::Overpass
