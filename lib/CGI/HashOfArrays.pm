=head1 NAME

CGI::HashOfArrays - Perl module that implements a hash whose keys can have
either single or multiple values, and which can process url-encoded data.

=cut

######################################################################

package CGI::HashOfArrays;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '1.01';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	I<none>

=head1 SYNOPSIS

	use CGI::HashOfArrays 1.01;

	my $case_insensitive = 1;
	my $complementry_set = 1;

	my $params = CGI::HashOfArrays->new( $case_insensitive, 
		$ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'}, '; ', '&' );

	my $query_string = '';
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};
	} else {
		read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
	}
	$params->from_url_encoded_string( $query_string );
	$params->trim_bounding_whitespace();  # clean up user input

	foreach my $key ($params->keys()) {
		my @values = $params->fetch( $key );
		print "Field '$key' contains: '".join( "','", @values )."'\n";
	}

	open( KEVOEL, "+<guestbook.txt" ) or die "can't open file: $!\n";
	flock( KEVOEL, 2 );
	local $/ = undef;
	seek( KEVOEL, 0, 2 );
	print KEVOEL "\n=\n".$params->to_url_encoded_string( "\n" );
	local $\ = undef;
	seek( KEVOEL, 0, 0 );
	my $all_records_str = <KEVOEL>;
	flock( KEVOEL, 8 );
	close( KEVOEL );

	@record_str_list = split( /\n*=?\n/, $records );
	@record_list = map { 
		CGI::HashOfArrays->new( $case_insensitive, $_, "\n" )
		} @record_str_list;
		
	foreach my $record (@record_list) {
		print "\nSubmitted by:".$record->fetch_value( 'name' )."\n";
		print "\nTracking cookie:".$record->fetch_value( 'track' )."\n";
		my %Qs_and_As = $record->fetch_all( ['name', 'track'], $complementary_set );
		foreach my $key (keys %Qs_and_As) {
			my @values = @{$Qs_and_As{$key}};
			print "Question: '$key'\n";
			print "Answers: '".join( "','", @values )."'\n";
		}
	}

=head1 DESCRIPTION

This Perl 5 object class implements a simple data structure that is similar to a
hash except that each key can have several values instead of just one.  There are
many places that such a structure is useful, such as database records whose
fields may be multi-valued, or when parsing results of an html form that contains
several fields with the same name.  This class can export a wide variety of
key/value subsets of its data when only some keys are needed.  In addition, this
class can parse and create url-encoded strings, such as with http query or cookie 
strings, or for encoding binary information in a text file.

While you could do tasks similar to this class by making your own hash with array
refs for values, you will need to repeat some messy-looking code everywhere you
need to use that data, creating a lot of redundant access or parsing code and 
increasing the risk of introducing errors.

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_MAIN_HASH = 'main_hash';  # this is a hash of arrays
my $KEY_CASE_INSE = 'case_inse';  # are our keys case insensitive?

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions and
B<$object-E<gt>method()> for methods.

All method parameters and results are passed by value (where appropriate) such
that subsequent editing of them will not change values internal to the HoA
object; this is the generally accepted behaviour.

Most methods take either KEY or VALUES parameters.  KEYs are always treated as
scalars and VALUES are taken as a list.  Value lists can be passed either as an
ARRAY ref, whereupon they are internally flattened, or as an ordinary LIST.  If
the first VALUES parameter is an ARRAY ref, it is interpreted as being the entire
list and subsequent parameters are ignored.  If you want to store an actual ARRAY
ref as a value, make sure to put it inside another ARRAY ref first, or it will be
flattened.

Any method which returns a list will check if it is being called in scalar or
list context.  If the context wants a scalar then the method returns its list in
an ARRAY ref; otherwise, the list is returned as a list.  This behaviour is the
same whether the returned list is an associative list (hash) or an ordinary list
(array).  Failures are returned as "undef" in scalar context and "()" in list
context.  Scalar results are returned as themselves, of course.

=head1 FUNCTIONS AND METHODS

=head2 new([ CASE[, SOURCE[, DELIM[, VALSEP]]] ])

This function creates a new CGI::HashOfArrays object and returns it. The
optional parameter CASE (scalar) specifies whether or not the new object uses
case-insensitive keys or not; the default value is false. This attribute can not
be changed later, except by calling the B<initialize()> method.

The second optional parameter, SOURCE is used as initial keys and values for this
object.  If it is a Hash Ref (normal or of arrays), then the store_all() method
is called to handle it.  If the same parameter is an HoA object, then its keys
and values are similarly given to store_all().  Otherwise, the method
from_url_encoded_string() is used.  In the last case only, the third and fourth
optional arguments, DELIM and VALSEP, would be used in parsing SOURCE.

Case-insensitivity simplifies matching form field names whose case may have been
changed by the web browser while in transit (I have seen it happen).

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = {};
	bless( $self, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

######################################################################

=head2 initialize([ CASE[, SOURCE[, DELIM[, VALSEP]]] ])

This method is used by B<new()> to set the initial properties of objects that it
creates.  Calling it yourself will empty the internal hash.  If you provide
arguments to this method then the first one, CASE, will initialize the
case-insensitivity attribute, and any subsequent parameters will provide initial
keys and values for the internal hash.  Nothing is returned.

=cut

######################################################################

sub initialize {
	my $self = shift( @_ );
	$self->{$KEY_MAIN_HASH} = {};
	if( scalar( @_ ) ) {	
		$self->{$KEY_CASE_INSE} = shift( @_ );
		my $initializer = shift( @_ );
		if( ref($initializer) eq 'CGI::HashOfArrays' or 
				ref($initializer) eq 'HASH' ) {
			$self->store_all( $initializer );
		} else {
			$self->from_url_encoded_string( $initializer, @_ );
		}
	}
}

######################################################################

=head2 clone([ KEYS[, COMPLEMENT] ])

This method creates a new CGI::HashOfArrays object, which is a duplicate of
this one in every respect, and returns it.  However, if the optional arguments
are used, then the clone may not have all the keys that the parent does.  The
first optional argument, KEYS, is an array ref that specifies a subset of all
this object's keys that we want returned.  If the second optional boolean
argument, COMPLEMENT, is true, then the complement of the keys listed in KEYS is
returned instead.

=cut

######################################################################

sub clone {
	my $self = shift( @_ );
	my $clone = {};
	bless( $clone, ref($self) );
	
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, [@{$rh_main_hash->{$_}}] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}

	$clone->{$KEY_MAIN_HASH} = \%hash_copy;
	$clone->{$KEY_CASE_INSE} = $self->{$KEY_CASE_INSE};
	
	return( $clone );
}

######################################################################

=head2 ignores_case()

This method returns true if this object uses case-insensitive keys.

=cut

######################################################################

sub ignores_case {
	my $self = shift( @_ );
	return( $self->{$KEY_CASE_INSE} );
}

######################################################################

=head2 keys()

This method returns a list of all this object's keys.

=cut

######################################################################

sub keys {
	my $self = shift( @_ );
	my @keys_list = keys %{$self->{$KEY_MAIN_HASH}};
	return( wantarray ? @keys_list : \@keys_list );
}

######################################################################

=head2 keys_count()

This method returns a count of this object's keys.

=cut

######################################################################

sub keys_count {
	my $self = shift( @_ );
	return( scalar( keys %{$self->{$KEY_MAIN_HASH}} ) );
}

######################################################################

=head2 values()

This method returns a flattened list of all this object's values.

=cut

######################################################################

sub values {
	my $self = shift( @_ );
	my @values_list = map { @{$_} } values %{$self->{$KEY_MAIN_HASH}};
	return( wantarray ? @values_list : \@values_list );
}

######################################################################

=head2 values_count()

This method returns a count of all this object's values.

=cut

######################################################################

sub values_count {
	my $self = shift( @_ );
	my $count = 0;
	map { $count += scalar( @{$_} ) } values %{$self->{$KEY_MAIN_HASH}};
	return( $count );
}

######################################################################

=head2 exists( KEY )

This method returns true if KEY is in the hash, although it may not have any
values.

=cut

######################################################################

sub exists {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) );
}

######################################################################

=head2 count( KEY )

This method returns a count of the values that KEY has.  It returns failure if
KEY doesn't exist.

=cut

######################################################################

sub count {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key};
	return( defined( $ra_values ) ? scalar( @{$ra_values} ) : undef );
}

######################################################################

=head2 fetch( KEY )

This method returns a list of all values that KEY has.  It returns failure if KEY
doesn't exist.

=cut

######################################################################

sub fetch {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key} or return;
	return( wantarray ? @{$ra_values} : [@{$ra_values}] );
}

######################################################################

=head2 fetch_value( KEY[, INDEX] )

This method returns a single value of KEY, which is at INDEX position in the
internal array of values; the default INDEX is 0.  It returns failure if KEY
doesn't exist.

=cut

######################################################################

sub fetch_value {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $index = shift( @_ ) || 0;
	my $ra_values = $self->{$KEY_MAIN_HASH}->{$key} or return;
	return( $ra_values->[$index] );
}

######################################################################

=head2 fetch_first([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys, but only the first value
for each key.  The first optional argument, KEYS, is an array ref that specifies
a subset of all this object's keys that we want returned. If the second optional
boolean argument, COMPLEMENT, is true, then the complement of the keys listed in
KEYS is returned instead.

=cut

######################################################################

sub fetch_first {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, $rh_main_hash->{$_}->[0] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 fetch_last([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys, but only the last value
for each key.  The first optional argument, KEYS, is an array ref that specifies
a subset of all this object's keys that we want returned. If the second optional
boolean argument, COMPLEMENT, is true, then the complement of the keys listed in
KEYS is returned instead.

=cut

######################################################################

sub fetch_last {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, $rh_main_hash->{$_}->[-1] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 fetch_all([ KEYS[, COMPLEMENT] ])

This method returns a hash with all this object's keys and values.  The values
for each key are contained in an ARRAY ref.  The first optional argument, KEYS,
is an array ref that specifies a subset of all this object's keys that we want
returned.  If the second optional boolean argument, COMPLEMENT, is true, then the
complement of the keys listed in KEYS is returned instead.

=cut

######################################################################

sub fetch_all {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my %hash_copy = 
		map { ( $_, [@{$rh_main_hash->{$_}}] ) } keys %{$rh_main_hash};
	if( $_[0] ) {
		$self->_reduce_hash_to_subset( \%hash_copy, @_ );
	}
	return( wantarray ? %hash_copy : \%hash_copy );
}

######################################################################

=head2 store( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES replace any that may have existed before.  This method returns the new
count of values that KEY has.  The best way to get a key which has no values is
to pass an empty ARRAY ref as the VALUES.

=cut

######################################################################

sub store {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} = [@{$ra_values}];
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 store_all( LIST )

This method takes one argument, LIST, which is an associative list or hash ref or
HoA object containing new keys and values to store in this object.  The value
associated with each key can be either scalar or an array.  Symantics are the
same as for calling store() multiple times, once for each KEY. Existing keys and
values with the same names are replaced.

=cut

######################################################################

sub store_all {
	my $self = shift( @_ );
	my %new = (ref( $_[0] ) eq 'CGI::HashOfArrays') ? 
		(%{shift( @_ )->{$KEY_MAIN_HASH}}) : 
		(ref( $_[0] ) eq 'HASH') ? (%{shift( @_ )}) : @_;
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $case_inse = $self->{$KEY_CASE_INSE};
	foreach my $key (keys %new) {
		$key = lc($key) if( $case_inse );
		my $ra_values = (ref($new{$key}) eq 'ARRAY') ? 
			[@{$new{$key}}] : [$new{$key}];
		$rh_main_hash->{$key} = $ra_values;
	}
	return( scalar( keys %new ) );
}

######################################################################

=head2 push( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES are appended to the list of any that existed before.  This method returns
the new count of values that KEY has.

=cut

######################################################################

sub push {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} ||= [];
	push( @{$self->{$KEY_MAIN_HASH}->{$key}}, @{$ra_values} );
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 unshift( KEY, VALUES )

This method adds a new KEY to this object, if it doesn't already exist. The
VALUES are prepended to the list of any that existed before.  This method returns
the new count of values that KEY has.

=cut

######################################################################

sub unshift {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	$self->{$KEY_MAIN_HASH}->{$key} ||= [];
	unshift( @{$self->{$KEY_MAIN_HASH}->{$key}}, @{$ra_values} );
	return( scalar( @{$self->{$KEY_MAIN_HASH}->{$key}} ) );
}

######################################################################

=head2 pop( KEY )

This method removes the last value associated with KEY and returns it.  It
returns failure if KEY doesn't exist.

=cut

######################################################################

sub pop {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) ?
		pop( @{$self->{$KEY_MAIN_HASH}->{$key}} ) : undef );
}

######################################################################

=head2 shift( KEY )

This method removes the last value associated with KEY and returns it.  It
returns failure if KEY doesn't exist.

=cut

######################################################################

sub shift {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	return( exists( $self->{$KEY_MAIN_HASH}->{$key} ) ?
		shift( @{$self->{$KEY_MAIN_HASH}->{$key}} ) : undef );
}

######################################################################

=head2 delete( KEY )

This method removes KEY and returns its values.  It returns failure if KEY
doesn't previously exist.

=cut

######################################################################

sub delete {
	my $self = shift( @_ );
	my $key = $self->{$KEY_CASE_INSE} ? lc(shift( @_ )) : shift( @_ );
	my $ra_values = delete( $self->{$KEY_MAIN_HASH}->{$key} );
	return( wantarray ? @{$ra_values} : $ra_values );
}

######################################################################

=head2 delete_all()

This method deletes all this object's keys and values and returns them in a hash.
 The values for each key are contained in an ARRAY ref.

=cut

######################################################################

sub delete_all {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	$self->{$KEY_MAIN_HASH} = {};
	return( wantarray ? %{$rh_main_hash} : $rh_main_hash );
}

######################################################################

=head2 trim_bounding_whitespace()

This method cleans up all of this object's values by trimming any leading or
trailing whitespace.  The keys are left alone.  This would normally be done when
the object is representing user input from a form, including when they entered
nothing but whitespace, and the program should act like they left the field
empty.

=cut

######################################################################

sub trim_bounding_whitespace {
	my $self = shift( @_ );
	foreach my $ra_values (values %{$self->{$KEY_MAIN_HASH}}) {
		foreach my $value (@{$ra_values}) {
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		}
	}
}

######################################################################

=head2 to_url_encoded_string([ DELIM[, VALSEP] ])

This method returns a scalar containing all of this object's keys and values
encoded in an url-escaped "query string" format.  The escaping format specifies
that any characters which aren't in [a-zA-Z0-9_ .-] are replaced with a triplet
containing a "%" followed by the two-hex-digit representation of the ascii value
for the character.  Also, any " " (space) is replaced with a "+".  Each key and
value pair is delimited by a "=".  If a key has multiple values, then there are
that many "key=value" pairs.  The optional argument, DELIM, is a scalar
specifying what to use as a delimiter between pairs.  This is "&" by default.  If
a "\n" is given for DELIM, the resulting string would be suitable for writing to
a file where each key=value pair is on a separate line.  The second optional
argument, VALSEP, is a scalar that specifies the delimiter between multiple
consecutive values which share a common key, and that key only appears once.  For
example, SOURCE could be "key1=val1&val2; key2=val3&val4", as is the case with
"cookie" strings (DELIM is "; " and VALSEP is "&") or "isindex" queries.

=cut

######################################################################

sub to_url_encoded_string {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/([^\w .-])/'%'.sprintf("%2.2x",ord($1))/ge;
		$key_enc =~ tr/ /+/;

		my @values;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/([^\w .-])/'%'.sprintf("%2.2x",ord($1))/ge;
			$value_enc =~ tr/ /+/;

			push( @values, $value_enc );
		}

		push( @result, "$key_enc=".( 
			$delim_values ? join( $delim_values, @values ) :
			join( "$delim_kvpair$key_enc=", @values ) 
		) );
	}

	return( join( $delim_kvpair, @result ) );
}

######################################################################

=head2 from_url_encoded_string( SOURCE[, DELIM[, VALSEP]] )

This method takes a scalar, SOURCE, containing a set of keys and values encoded
in an url-escaped "query string" format, and adds them to this object.  The
escaping format specifies that any characters which aren't in [a-zA-Z0-9_ .-] are
replaced with a triplet containing a "%" followed by the two-hex-digit
representation of the ascii value for the character.  Also, any " " (space) is
replaced with a "+".  Each key and value pair is delimited by a "=".  If a key
has multiple values, then there are that many "key=value" pairs.  The first
optional argument, DELIM, is a scalar specifying what to use as a delimiter
between pairs. This is "&" by default.  If a "\n" is given for DELIM, the source
string was likely read from a file where each key=value pair is on a separate
line.  The second optional argument, VALSEP, is a scalar that specifies the
delimiter between multiple consecutive values which share a common key, and that
key only appears once.  For example, SOURCE could be "key1=val1&val2;
key2=val3&val4", as is the case with "cookie" strings (DELIM is "; " and VALSEP
is "&") or "isindex" queries.

=cut

######################################################################

sub from_url_encoded_string {
	my $self = shift( @_ );
	my $source_str = shift( @_ );
	my $delim_kvpair = shift( @_ ) || '&';
	my $delim_values = shift( @_ );
	my @source = split( $delim_kvpair, $source_str );

	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my $case_inse = $self->{$KEY_CASE_INSE};

	foreach my $pair (@source) {
		my ($key, $values_str) = split( '=', $pair, 2 );
		next if( $key eq "" );

		$key =~ tr/+/ /;
		$key =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		$key = lc($key) if( $case_inse );
		$rh_main_hash->{$key} ||= [];

		my @values = $delim_values ? 
			split( $delim_values, $values_str ) : $values_str;

		foreach my $value (@values) {
			$value =~ tr/+/ /;
			$value =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
		
			push( @{$rh_main_hash->{$key}}, $value );
		}
	}

	return( scalar( @source ) );
}

######################################################################

=head2 to_html_encoded_hidden_fields()

This method returns a scalar containing html text which defines a list of hidden
form fields whose names and values are all of this object's keys and values. 
Each list element looks like '<INPUT TYPE="hidden" NAME="key" VALUE="value">'. 
Where a key has multiple values, a hidden field is made for each value.  All keys
and values are html-escaped such that any occurances of [&,",<,>] are substitued
with [&amp;,&quot;,&gt;,&lt;].  In cases where this object was storing user input
that was submitted using 'post', this method can generate the content of a
self-referencing form, should the main program need to call itself.  It would
handle persistant data which is too big to put in a self-referencing query
string.

=cut

######################################################################

sub to_html_encoded_hidden_fields {
	my $self = shift( @_ );
	my $rh_main_hash = $self->{$KEY_MAIN_HASH};
	my @result;

	foreach my $key (sort keys %{$rh_main_hash}) {
		my $key_enc = $key;
		$key_enc =~ s/&/&amp;/g;
		$key_enc =~ s/\"/&quot;/g;
		$key_enc =~ s/>/&gt;/g;
		$key_enc =~ s/</&lt;/g;

		foreach my $value (@{$rh_main_hash->{$key}}) {
			my $value_enc = $value;   # s/// on $value changes original
			$value_enc =~ s/&/&amp;/g;
			$value_enc =~ s/\"/&quot;/g;
			$value_enc =~ s/>/&gt;/g;
			$value_enc =~ s/</&lt;/g;

			push( @result, <<__endquote );
<INPUT TYPE="hidden" NAME="$key_enc" VALUE="$value_enc">
__endquote
		}
	}

	return( join( '', @result ) );
}

######################################################################

sub _reduce_hash_to_subset {    # meant only for internal use
	my $self = shift( @_ );
	my $rh_hash_copy = shift( @_ );
	my $ra_keys = shift( @_ );
	$ra_keys = (ref($ra_keys) eq 'HASH') ? (keys %{$ra_keys}) : 
		(ref($ra_keys) eq 'CGI::HashOfArrays') ? $ra_keys->keys() : 
		(ref($ra_keys) ne 'ARRAY') ? [$ra_keys] : $ra_keys;
	my $case_inse = $self->{$KEY_CASE_INSE};
	my %spec_keys = 
		map { ( $case_inse ? lc($_) : $_ => 1 ) } @{$ra_keys};	
	if( shift( @_ ) ) {   # want complement of keys list
		%{$rh_hash_copy} = map { !$spec_keys{$_} ? 
			($_ => $rh_hash_copy->{$_}) : () } keys %{$rh_hash_copy};
	} else {
		%{$rh_hash_copy} = map { $spec_keys{$_} ? 
			($_ => $rh_hash_copy->{$_}) : () } keys %{$rh_hash_copy};
	}
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL. Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1).

=cut
