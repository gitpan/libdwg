=head1 NAME

CGI::WPM::Content - Perl module that stores and assembles components of a new web
page, including HTTP headers, and it is returned by all subclasses of
CGI::WPM::Base.

=cut

######################################################################

package CGI::WPM::Content;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '0.2001';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	HTTP::Headers 1.36 (earlier versions may work, but not tested)

=head2 Nonstandard Modules

	HTML::TagMaker

=cut

######################################################################

use HTTP::Headers;

######################################################################

=head1 SYNOPSIS

	use CGI::WPM::Content;

	my $webpage = CGI::WPM::Content->new();

	$webpage->title( "What Is To Tell" );
	$webpage->author( "Mine Own Self" );
	$webpage->meta( { keywords => "hot spicy salty" } );
	$webpage->style_sources( "mypage.css" );
	$webpage->style_code( "H1 { align: center; }" );

	$webpage->replacements( {
		__url_one__ => (localtime())[6] == 0 ? "one.html" : "two.html",
		__url_two__ => (localtime())[6] == 0 ? "three.html" : "four.html",
	} );

	$webpage->body_content( <<__endquote );
	<H1>Good Reading</H1>
	<P>Greetings visitors, you must wonder why I called you here.
	Well you shall find out soon enough, but not from me.</P>
	__endquote

	if( (localtime())[6] == 0 ) {
		$webpage->body_append( <<__endquote );
	<P>Sorry, I have just been informed that we can't help you today,
	as the knowledge-bringers are not in attendance.  You will
	have to come back another time.</P>
	__endquote
	} else {
		$webpage->body_append( <<__endquote );
	<P>That's right, not from me, not in a million years.</P>
	__endquote
	}

	$webpage->body_append( <<__endquote );
	<P>[ click <A HREF="__url_one__">here</A> | 
	or <A HREF="__url_two__">here</A> ]</P>
	__endquote

	print STDOUT $webpage->to_string();
	
=head1 DESCRIPTION

This Perl 5 object class implements a simple data structure that makes it easy to
build up an HTML web page one piece at a time.  In its simplest concept, this
structure is an ordered list of content that would go between the "body" tags in
the document, and it is easy to either append or prepend content to a page.

Building on that concept, this class can also generate a complete HTML page with
one method call, attaching the appropriate headers and footers to the content of
the page.  For more customization, this class also stores a list of content that
goes in the HTML document's "head" section.  As well, it remembers attributes for
a page such as "title", "author", various "meta" information, and style sheets 
(linked or embedded).

This class also manages and generates all the HTTP headers that need to be sent
to the web browser prior to the actual HTML code.  Similarly, this class can
generate redirection headers when we don't want to display any content ourselves.
 A single to_string() call will return everything the browser needs to see at
once, whether page or redirect.

Additional features include global search-and-replace in the body of multiple
tokens, which can be defined ahead of time and performed later.  Tokens can be
priortized such that the replacements are done in a specified order, rather than
the order they are defined; this is useful when one replacement yields a token
that another replacement must handle.

Future versions of this class will expand to handle an entire frameset document,
but that was omitted now for simplicity.

=head1 OUTPUT FROM SYNOPSIS PROGRAM

	Content-Type: text/html

	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
	<HTML>
	<HEAD>
	<TITLE>What Is To Tell</TITLE>
	<LINK REV="made" HREF="mailto:Mine Own Self">
	<META NAME="keywords" VALUE="hot spicy salty">
	<LINK TYPE="text/css" REL="stylesheet" HREF="mypage.css">
	<STYLE>
	<!-- H1 { align: center; } --></STYLE>
	</HEAD>
	<BODY><H1>Good Reading</H1>
	<P>Greetings visitors, you must wonder why I called you here.
	Well you shall find out soon enough, but not from me.</P>
	<P>That's right, not from me, not in a million years.</P>
	<P>[ click <A HREF="two.html">here</A> | 
	or <A HREF="four.html">here</A> ]</P>

	</BODY>
	</HTML>

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_HTTP_HEADER = 'headers';  # this holds our HTTP::Headers object
my $KEY_MAIN_BODY = 'main_body';  # array of text -> <BODY>*</BODY>
my $KEY_MAIN_HEAD = 'main_head';  # array of text -> <HEAD>*</HEAD>
my $KEY_TITLE     = 'title';      # scalar of document title -> head
my $KEY_AUTHOR    = 'author';     # scalar of document author -> head
my $KEY_META      = 'meta';       # hash of meta keys/values -> head
my $KEY_CSS_SRC   = 'css_src';    # array of text -> head
my $KEY_CSS_CODE  = 'css_code';   # array of text -> head
my $KEY_BODY_ATTR = 'body_attr';  # hash of attrs -> <BODY *>
my $KEY_REPLACE   = 'replace';  # array of hashes, find and replace
my $KEY_REDIRECT_URL = 'redirect_url';  # if def, str is redir header

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions and
B<$object-E<gt>method()> for methods.

=head1 FUNCTIONS AND METHODS

=head2 new()

This function creates a new CGI::WPM::Content object and returns it.  This
page is empty by default.

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

=head2 initialize()

This method is used by B<new()> to set the initial properties of an object,
that it creates.  All page attributes are wiped clean, resulting in an empty page.

=cut

######################################################################

sub initialize {
	my $self = shift( @_ );

	$self->{$KEY_HTTP_HEADER} = HTTP::Headers->new();
	$self->{$KEY_MAIN_BODY} = [];
	$self->{$KEY_MAIN_HEAD} = [];
	$self->{$KEY_TITLE} = undef;
	$self->{$KEY_AUTHOR} = undef;
	$self->{$KEY_META} = {};
	$self->{$KEY_CSS_SRC} = [];
	$self->{$KEY_CSS_CODE} = [];	
	$self->{$KEY_BODY_ATTR} = {};
	$self->{$KEY_REPLACE} = [];
	$self->{$KEY_REDIRECT_URL} = undef;

	$self->{$KEY_HTTP_HEADER}->header( 
		content_type => 'text/html',
	);
}

######################################################################

=head2 clone()

This method creates a new CGI::WPM::Content object, which is a duplicate of
this one in every respect, and returns it.

=cut

######################################################################

sub clone {
	my $self = shift( @_ );
	my $clone = {};
	bless( $clone, ref($self) );
	$clone->{$KEY_HTTP_HEADER} = $self->{$KEY_HTTP_HEADER}->clone();
	$clone->{$KEY_MAIN_BODY} = [@{$self->{$KEY_MAIN_BODY}}];
	$clone->{$KEY_MAIN_HEAD} = [@{$self->{$KEY_MAIN_HEAD}}];
	$clone->{$KEY_TITLE} = $self->{$KEY_TITLE};
	$clone->{$KEY_AUTHOR} = $self->{$KEY_AUTHOR};
	$clone->{$KEY_META} = {%{$self->{$KEY_META}}};
	$clone->{$KEY_CSS_SRC} = [@{$self->{$KEY_CSS_SRC}}];
	$clone->{$KEY_CSS_CODE} = [@{$self->{$KEY_CSS_CODE}}];
	$clone->{$KEY_BODY_ATTR} = {%{$self->{$KEY_BODY_ATTR}}};
	$clone->{$KEY_REPLACE} = $self->replacements();  # makes copy
	$clone->{$KEY_REDIRECT_URL} = $self->{$KEY_REDIRECT_URL};
	return( $clone );
}

######################################################################

=head2 http_header()

This method is an accessor for the "http header" property of this object, which
it returns a reference to.  The object is of the HTTP::Headers class.

=cut

######################################################################

sub http_header {
	my $self = shift( @_ );
	return( $self->{$KEY_HTTP_HEADER} );  # returns ref to object
}

######################################################################

=head2 body_content([ VALUES ])

This method is an accessor for the "body content" list property of this object,
which it returns.  This property is used literally to go between the "body" tag
pair of a new HTML document.  If VALUES is defined, this property is set to it,
and replaces any existing content.  VALUES can be any kind of valid list.  If the
first argument to this method is an ARRAY ref then that is taken as the entire
list; otherwise, all the arguments are taken as elements in a list.

=cut

######################################################################

sub body_content {
	my $self = shift( @_ );
	if( defined( $_[0] ) ) {
		$self->{$KEY_MAIN_BODY} = 
			(ref( $_[0] ) eq 'ARRAY') ? [@{$_[0]}] : [@_];
	}
	return( $self->{$KEY_MAIN_BODY} );  # returns ref
}

######################################################################

=head2 head_content([ VALUES ])

This method is an accessor for the "head content" list property of this object,
which it returns.  This property is used literally to go between the "head" tag
pair of a new HTML document.  If VALUES is defined, this property is set to it,
and replaces any existing content.  VALUES can be any kind of valid list.  If the
first argument to this method is an ARRAY ref then that is taken as the entire
list; otherwise, all the arguments are taken as elements in a list.

=cut

######################################################################

sub head_content {
	my $self = shift( @_ );
	if( defined( $_[0] ) ) {
		$self->{$KEY_MAIN_HEAD} = 
			(ref( $_[0] ) eq 'ARRAY') ? [@{$_[0]}] : [@_];
	}
	return( $self->{$KEY_MAIN_HEAD} );  # returns ref
}

######################################################################

=head2 title([ VALUE ])

This method is an accessor for the "title" scalar property of this object, which
it returns.  If VALUE is defined, this property is set to it.  This property is
used in the header of a new document to define its title.  Specifically, it goes
between a <TITLE></TITLE> tag pair.

=cut

######################################################################

sub title {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_TITLE} = $new_value;
	}
	return( $self->{$KEY_TITLE} );  # ret copy
}

######################################################################

=head2 author([ VALUE ])

This method is an accessor for the "author" scalar property of this object, which
it returns.  If VALUE is defined, this property is set to it.  This property is
used in the header of a new document to define its author.  Specifically, it is
used in a new '<LINK REV="made">' tag if defined.

=cut

######################################################################

sub author {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_AUTHOR} = $new_value;
	}
	return( $self->{$KEY_AUTHOR} );  # ret copy
}

######################################################################

=head2 meta([ KEY[, VALUE] ])

This method is an accessor for the "meta" hash property of this object, which it
returns.  If KEY is defined and it is a valid HASH ref, then this property is set
to it.  If KEY is defined but is not a HASH ref, then it is treated as a single
key into the hash of meta information, and the value associated with that hash
key is returned.  In the latter case, if VALUE is defined, then that new value is
assigned to the approprate meta key.  Meta information is used in the header of a
new document to say things like what the best keywords are for a search engine to
index this page under.  If this property is defined, then a '<META NAME="n"
VALUE="v">' tag would be made for each key/value pair.

=cut

######################################################################

sub meta {
	my $self = shift( @_ );
	if( ref( my $first = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_META} = {%{$first}};
	} elsif( defined( $first ) ) {
		if( defined( my $second = shift( @_ ) ) ) {
			$self->{$KEY_META}->{$first} = $second;
		}
		return( $self->{$KEY_META}->{$first} );
	}
	return( $self->{$KEY_META} );  # returns ref
}

######################################################################

=head2 style_sources([ VALUES ])

This method is an accessor for the "style sources" list property of this object,
which it returns.  If VALUES is defined, this property is set to it, and replaces
any existing content.  VALUES can be any kind of valid list.  If the first
argument to this method is an ARRAY ref then that is taken as the entire list;
otherwise, all the arguments are taken as elements in a list.  This property is
used in the header of a new document for linking in CSS definitions that are
contained in external documents; CSS is used by web browsers to describe how a
page is visually presented.  If this property is defined, then a '<LINK
REL="stylesheet" SRC="url">' tag would be made for each list element.

=cut

######################################################################

sub style_sources {
	my $self = shift( @_ );
	if( defined( $_[0] ) ) {
		$self->{$KEY_CSS_SRC} = 
			(ref( $_[0] ) eq 'ARRAY') ? [@{$_[0]}] : [@_];
	}
	return( $self->{$KEY_CSS_SRC} );  # returns ref
}

######################################################################

=head2 style_code([ VALUES ])

This method is an accessor for the "style code" list property of this object,
which it returns.  If VALUES is defined, this property is set to it, and replaces
any existing content.  VALUES can be any kind of valid list.  If the first
argument to this method is an ARRAY ref then that is taken as the entire list;
otherwise, all the arguments are taken as elements in a list.  This property is
used in the header of a new document for embedding CSS definitions in that
document; CSS is used by web browsers to describe how a page is visually
presented.  If this property is defined, then a "<STYLE><!-- code --></STYLE>"
multi-line tag is made for them.

=cut

######################################################################

sub style_code {
	my $self = shift( @_ );
	if( defined( $_[0] ) ) {
		$self->{$KEY_CSS_CODE} = 
			(ref( $_[0] ) eq 'ARRAY') ? [@{$_[0]}] : [@_];
	}
	return( $self->{$KEY_CSS_CODE} );  # returns ref
}

######################################################################

=head2 body_attributes([ KEY[, VALUE] ])

This method is an accessor for the "body attributes" hash property of this
object, which it returns.  If KEY is defined and it is a valid HASH ref, then
this property is set to it.  If KEY is defined but is not a HASH ref, then it is
treated as a single key into the hash of body attributes, and the value
associated with that hash key is returned.  In the latter case, if VALUE is
defined, then that new value is assigned to the approprate attribute key.  Body
attributes define such things as the background color the page should use, and
have names like 'bgcolor' and 'background'.  If this property is defined, then
the attribute keys and values go inside the opening <BODY> tag of a new document.

=cut

######################################################################

sub body_attributes {
	my $self = shift( @_ );
	if( ref( my $first = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_BODY_ATTR} = {%{$first}};
	} elsif( defined( $first ) ) {
		if( defined( my $second = shift( @_ ) ) ) {
			$self->{$KEY_BODY_ATTR}->{$first} = $second;
		}
		return( $self->{$KEY_BODY_ATTR}->{$first} );
	}
	return( $self->{$KEY_BODY_ATTR} );  # returns ref
}

######################################################################

=head2 replacements([ VALUES ])

This method is an accessor for the "replacements" array-of-hashes property of
this object, which it returns.  If VALUES is defined, this property is set to it,
and replaces any existing content.  VALUES can be any kind of valid list whose
elements are hashes.  This property is used in implementing this class'
search-and-replace functionality.  Within each hash, the keys define tokens that
we search our content for and the values are what we replace occurances with. 
Replacements are priortized by having multiple hashes; the hashes that are
earlier in the "replacements" list are performed before those later in the list.

=cut

######################################################################

sub replacements {
	my $self = shift( @_ );
	if( defined( $_[0] ) ) {
		my @new_values = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
		my @new_list = ();
		foreach my $element (@new_values) {
			ref( $element ) eq 'HASH' or next;
			push( @new_list, {%{$element}} );
		}
		$self->{$KEY_REPLACE} = \@new_list;
	}
	return( [map { {%{$_}} } @{$self->{$KEY_REPLACE}}] );  # ret copy
}

######################################################################

=head2 redirect_url([ VALUE ])

This method is an accessor for the "redirect url" scalar property of this object,
which it returns.  If VALUE is defined, this property is set to it.  If this
property is defined, then the to_string() method will return a redirection header
going to the url rather than an ordinary web page.

=cut

######################################################################

sub redirect_url {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_REDIRECT_URL} = $new_value;
	}
	return( $self->{$KEY_REDIRECT_URL} );
}

######################################################################

=head2 body_append( VALUES )

This method appends new elements to the "body content" list property of this
object, and that entire property is returned.

=cut

######################################################################

sub body_append {
	my $self = shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	push( @{$self->{$KEY_MAIN_BODY}}, @{$ra_values} );
	return( $self->{$KEY_MAIN_BODY} );  # returns ref
}

######################################################################

=head2 body_prepend( VALUES )

This method prepends new elements to the "body content" list property of this
object, and that entire property is returned.

=cut

######################################################################

sub body_prepend {
	my $self = shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	unshift( @{$self->{$KEY_MAIN_BODY}}, @{$ra_values} );
	return( $self->{$KEY_MAIN_BODY} );  # returns ref
}

######################################################################

=head2 head_append( VALUES )

This method appends new elements to the "head content" list property of this
object, and that entire property is returned.

=cut

######################################################################

sub head_append {
	my $self = shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	push( @{$self->{$KEY_MAIN_HEAD}}, @{$ra_values} );
	return( $self->{$KEY_MAIN_HEAD} );  # returns ref
}

######################################################################

=head2 head_prepend( VALUES )

This method prepends new elements to the "head content" list property of this
object, and that entire property is returned.

=cut

######################################################################

sub head_prepend {
	my $self = shift( @_ );
	my $ra_values = (ref( $_[0] ) eq 'ARRAY') ? shift( @_ ) : \@_;
	unshift( @{$self->{$KEY_MAIN_HEAD}}, @{$ra_values} );
	return( $self->{$KEY_MAIN_HEAD} );  # returns ref
}

######################################################################

=head2 add_earlier_replace( VALUE )

This method prepends a new hash, defined by VALUE, to the "replacements"
list-of-hashes property of this object such that keys and values in the new hash
are searched and replaced earlier than any existing ones.  Nothing is returned.

=cut

######################################################################

sub add_earlier_replace {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		unshift( @{$self->{$KEY_REPLACE}}, {%{$new_value}} );
	}
}

######################################################################

=head2 add_later_replace( VALUE )

This method appends a new hash, defined by VALUE, to the "replacements"
list-of-hashes property of this object such that keys and values in the new hash
are searched and replaced later than any existing ones.  Nothing is returned.

=cut

######################################################################

sub add_later_replace {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		push( @{$self->{$KEY_REPLACE}}, {%{$new_value}} );
	}
}

######################################################################

=head2 do_replacements()

This method performs a search-and-replace of the "body content" property as
defined by the "replacements" property of this object.  This method is always
called by to_string() prior to the latter assembling a web page.

=cut

######################################################################

sub do_replacements {
	my $self = shift( @_ );
	my $body = join( '', @{$self->{$KEY_MAIN_BODY}} );
	foreach my $rh_pairs (@{$self->{$KEY_REPLACE}}) {
		foreach my $find_val (keys %{$rh_pairs}) {
			my $replace_val = $rh_pairs->{$find_val};
			$body =~ s/$find_val/$replace_val/g;
		}
	}
	$self->{$KEY_MAIN_BODY} = [$body];
}

######################################################################

=head2 to_string()

This method returns a scalar containing the complete web page that this object
describes, that is, it returns the string representation of this object.  It
includes both the HTTP header and the HTTP body.  The HTTP body is usually the
formatted HTML document itself, which consists of a prologue tag, a pair of
"html" tags and everything in between.  If the object represents a different data
type (not yet supported), then the HTTP body is different.  If the object is a
redirection header (when "redirect url" property is true) then there is no HTTP
body at all.

=cut

######################################################################

sub to_string {
	my $self = shift( @_ );
	my $ret_value;

	$self->do_replacements();

	my $http = $self->{$KEY_HTTP_HEADER};

	if( my $url = $self->{$KEY_REDIRECT_URL} ) {
		$http->header( 
			status => '302 Found',
			uri => $url,
			location => $url,
			target => 'external_link_window',
		);
		$ret_value = $http->as_string( @_ );

	} else {
		require HTML::TagMaker;

		my $html = HTML::TagMaker->new();
		
		my $http_header = $http->as_string( @_ );

		my $header = $html->start_html(
			title => $self->{$KEY_TITLE},
			author => $self->{$KEY_AUTHOR},
			meta => $self->{$KEY_META},
			style => {
				src => $self->{$KEY_CSS_SRC},
				code => $self->{$KEY_CSS_CODE},
			},
			head => $self->{$KEY_MAIN_HEAD},
			body => $self->{$KEY_BODY_ATTR},
		);
		
		my $body = join( '', @{$self->{$KEY_MAIN_BODY}} );
		
		my $footer = $html->end_html();
	
		$ret_value = $http_header.$header.$body.$footer;
	}
		
	return( $ret_value );
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

perl(1), HTTP::Headers, HTML::TagMaker.

=cut
