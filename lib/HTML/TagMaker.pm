=head1 NAME

HTML::TagMaker - Perl module that can create any HTML tags, as well as groups of
or just parts of them, and complete html headers or footers.

=cut

######################################################################

package HTML::TagMaker;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = '1.0';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	Class::ParamParser

=cut

######################################################################

use Class::ParamParser;
@ISA = qw( Class::ParamParser );

######################################################################

=head1 SYNOPSIS

	use HTML::TagMaker;

	my $html = HTML::TagMaker->new();
	$html->groups_by_default( 1 );	

	print
		'Content-type: text/html'."\n\n",	
		$html->start_html( 
			-title => "This Is My Page", 
			-style => { -code => <<__endquote },
	\nBODY {
		background-color: #ffffff; 
		background-image: none;
	}
	__endquote
		),	
		$html->h1( 'A Simple Example' ),	
		$html->p( 
			"Click " . 
			$html->a( href => 'http://search.cpan.org', text => 'here' ) . 
			" for more."
		),	
		$html->hr,	
		$html->table(
			$html->tr( [
				$html->th( [ 'Name', 'Count', 'URL', 'First Access' ] ), 
				$html->td( [ 'Old Page', 33, 'http://www.domain.com', 
					'1999/04/23 13:55:02' ] )
			] )
		),	
		$html->hr,	
		$html->form_start( method => 'post', action => 'http://localhost' ),
		$html->p( 
			"What's your name? " . 
			$html->input( type => 'text', name => 'name' ) 
		),
		$html->p( 
			"What's the combination?" .
			$html->input_group( 
				-type => 'checkbox', 
				-name => 'words',
				-value => ['eenie', 'meenie', 'minie', 'moe'],
				-checked => [1, 0, 1, 0],
				-text => ['eenie', 'meenie', 'minie', 'moe'] ),
		),
		$html->p( 
			"What's your favorite colour? " .
			$html->select_start( -size => 1, -name => 'color' ) .
			$html->option_group(
				-value => ['red', 'green', 'blue', 'chartreuse'], 
				-text => ['Red', 'Green', 'Blue', 'Chartreuse'] ) .
			$html->select_end
		),
		$html->input( type => 'submit' ),
		$html->form_end,	
		$html->end_html;

=head1 DESCRIPTION

This Perl 5 object class can be used to generate any HTML tags in a format that
is consistent with the W3C HTML 4.0 standard.  There are no restrictions on what
tags are named, however; you can ask for any new or unsupported tag that comes
along from Netscape or Microsoft, and it will be made.  Additionally, you can
generate lists of said tags with one method call, or just parts of said tags (but
not both at once).

In this implementation, "standard format" means that tags are made as pairs
(<TAG></TAG>) by default, unless they are known to be "no pair" tags.  Tags that
I know to be "no pair" are [basefont, img, area, param, br, hr, input, option,
tbody, frame, comment, isindex, base, link, meta].  However, you can force any
tag to be "pair" or "start only" or "end only" by appropriately modifying your
call to the tag making method.

Also, "standard format" means that tag modifiers are formatted as "key=value" by
default, unless they are known to be "no value" modifiers.  Modifiers that I know
to be "no value" are [ismap, noshade, compact, checked, multiple, selected,
nowrap, noresize, param].  These are formatted simply as "key" because their very
presence indicates positive assertion, while their absense means otherwise.  For
modifiers with values, the values will always become bounded by quotes, which
ensures they work with both string and numerical quantities (eg: key="value").

Note that this class is a subclass of Class::ParamParser, and inherits
all of its methods, "params_to_hash()" and "params_to_array()".

=head1 HTML CODE FROM SYNOPSIS PROGRAM

	Content-type: text/html


	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
	<HTML>
	<HEAD>
	<TITLE>This Is My Page</TITLE>
	<STYLE>
	<!-- 
	BODY {
		background-color: #ffffff; 
		background-image: none;
	}
	 --></STYLE>
	</HEAD>
	<BODY>
	<H1>A Simple Example</H1>
	<P>Click 
	<A HREF="http://search.cpan.org">here</A> for more.</P>
	<HR>
	<TABLE>
	<TR>
	<TH>Name</TH>
	<TH>Count</TH>
	<TH>URL</TH>
	<TH>First Access</TH></TR>
	<TR>
	<TD>Old Page</TD>
	<TD>33</TD>
	<TD>http://www.domain.com</TD>
	<TD>1999/04/23 13:55:02</TD></TR></TABLE>
	<HR>
	<FORM METHOD="post" ACTION="http://localhost">
	<P>What's your name? 
	<INPUT TYPE="text" NAME="name"></P>
	<P>What's the combination?
	<INPUT TYPE="checkbox" NAME="words" CHECKED VALUE="eenie">eenie
	<INPUT TYPE="checkbox" NAME="words" VALUE="meenie">meenie
	<INPUT TYPE="checkbox" NAME="words" CHECKED VALUE="minie">minie
	<INPUT TYPE="checkbox" NAME="words" VALUE="moe">moe</P>
	<P>What's your favorite colour? 
	<SELECT NAME="color" SIZE="1">
	<OPTION VALUE="red">Red
	<OPTION VALUE="green">Green
	<OPTION VALUE="blue">Blue
	<OPTION VALUE="chartreuse">Chartreuse
	</SELECT></P>
	<INPUT TYPE="submit">
	</FORM>
	</BODY>
	</HTML>

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_AUTO_GROUP = 'auto_group';  # do we make tag groups by default?
my $KEY_AUTO_POSIT = 'auto_posit';  # with methods whose parameters 
	# could be either named or positional, when we aren't sure what we 
	# are given, do we guess positional?  Default is named.

# These extra tag properties work only with AUTOLOAD:
my $PARAM_TEXT = 'text';  #tag pair is wrapped around this
my $PARAM_LIST = 'list';  #force tag groups to be returned in ARRAY ref

# Constant values used in this class go here:

my $TAG_GROUP = 'group';  # values that "what_to_make" can have
my $TAG_PAIR  = 'pair'; 
my $TAG_START = 'start';
my $TAG_END   = 'end';

my %NO_PAIR_TAGS = (  # comments correspond to Bare Bones sections
	basefont => 1,   # PRESENTATION FORMATTING
	img => 1,   # LINKS, GRAPHICS, AND SOUNDS
	area => 1,   # LINKS, GRAPHICS, AND SOUNDS
	param => 1,   # LINKS, GRAPHICS, AND SOUNDS
	br => 1,   # DIVIDERS
	hr => 1,   # DIVIDERS
	input => 1,   # FORMS
	option => 1,   # FORMS
	tbody => 1,   # TABLES
	frame => 1,   # FRAMES
	comment => 1,   # MISCELLANEOUS
	isindex => 1,   # MISCELLANEOUS
	base => 1,   # MISCELLANEOUS
	'link' => 1,   # MISCELLANEOUS
	meta => 1,   # MISCELLANEOUS
);

my %NO_VALUE_PARAMS = (  # comments correspond to Bare Bones sections
	ismap => 1,   # LINKS, GRAPHICS, AND SOUNDS
	noshade => 1,   # DIVIDERS
	compact => 1,   # LISTS
	checked => 1,   # FORMS
	multiple => 1,   # FORMS
	selected => 1,   # FORMS
	nowrap => 1,   # TABLES
	noresize => 1,   # FRAMES
	param => 1,   # SCRIPTS AND JAVA
);

my %PARAMS_PRECEDENCE = (   # larger number means goes first; undef last
	method => 190,
	action => 185,
	type => 180,
	name => 175,
	width => 170,
	height => 165,
	rows => 160,
	cols => 155,
	border => 150,
	cellspacing => 145,
	cellpadding => 140,
	multiple => 135,
	checked => 130,
	selected => 125,
	value => 120,
	target => 115,
	rev => 113,
	rel => 112,
	href => 110,
	src => 105,
	alt => 100,
);

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions and
B<$object-E<gt>method()> for methods.

Methods of this class always "return" their results, rather than printing them
out to a file or the screen.  Not only is this simpler, but it gives the calling
code the maximum amount of control over what happens in the program.  They may
wish to do post-processing with the generated HTML, or want to output it in a
different order than it is generated.  By default, all results are returned as a
scalar, but methods which generate a list of tags can optionally return an ARRAY
ref, with each element containing a single tag.  This can aid in post-processing
and possibly speed up the program because there is less copying done.

Through the magic of autoloading, this class can make any html tag by calling a
class method with the same name as the tag you want.  For examples, use "hr()" to
make a "<HR>" tag, or "p('text')" to make "<P>text</P>".  This also means that if
you mis-spell any method name, it will still make a new tag with the mis-spelled
name.  For autoloaded methods only, the method names are case-insensitive.

If you call a class method whose name ends in either of ['_start', '_end',
'_pair'], this will be interpreted as an instruction to make just part of one tag
whose name are the part of the method name preceeding that suffix.  For example,
calling "p_start( 'text' )" results in "<P>text" rather than "<P>text</P>". 
Similarly, calling "p_end()" will generate a "</P>" only.  Using the '_pair'
suffix will force tags to be made as a pair, whether or not they would do so
naturally.  For example, calling "br_pair" would produce a "<BR></BR>" rather
than the normal "<BR>".  When using either of ['_start','_pair'], the arguments
you pass the method are exactly the same as the unmodified method would use, and
there are no other symantec differences.  However, when using the '_end' suffix,
any arguments are ignored, as the latter member of a tag pair never carries any
attributes anyway.

If you call a class method whose name ends in "_group", this will be interpreted
as an instruction to make a list of tags whose name are the part of the method
name preceeding the "_group".  For example, calling "td_group(
['here','we','are'] )" results in "<TD>here</TD><TD>we</TD><TD>are</TD>" being
generated.  The arguments that you call this method are exactly the same as for
calling a method to make a single tag of the same name, except that the extra
optional parameter "list" can be used to force an ARRAY ref of the new tags to be
returned instead of a scalar.  The symantec difference is that any arguments
whose values are ARRAY refs are interpreted as a list of values where each one is
used in a separate tag; for a single tag, the literal ARRAY ref itself would be
used.  The number of tags produced is equal to the length of the longest ARRAY
ref passed as an argument.  For any other arguments who have fewer than this
count, their last value is replicated and appended enough times as necessary to
make them the same length.  The value of a scalar argument is used for all the
tags.  For example, calling "input_group( type => checkbox, name => 'letters',
value => ['a','b','c'] )" produces '<INPUT TYPE="checkbox" NAME="letters"
VALUE="a"><INPUT TYPE="checkbox" NAME="letters" VALUE="b"><INPUT TYPE="checkbox"
NAME="letters" VALUE="c">'.

All autoloaded methods require their parameters to be in named format.  These
names and values correspond to attribute names and values for the new tags. 
Since "no value" attributes are essentially booleans, they can have any true or
false value associated with them in the parameter list, which won't be printed. 
If an autoloaded method is passed exactly one parameter, it will be interpreted
as the "text" that goes between the tag pair (<TAG>text</TAG>) or after "start
tags" (<TAG>text).  The same result can be had explicitely by passing the named
parameter "text".  Most static (non-autoloaded) methods require positional
parameters, except for start_html(), which can take either format.  The names of
any named parameters can optionally start with a "-".

=cut

######################################################################
# All HTML tags have a method of this class associated with them.

sub AUTOLOAD {
	my $self = shift( @_ );
	$AUTOLOAD =~ m/([^:]*)$/;   # we don't need fully qualified name
	my $called_sub_name = $1;

	my ($tag_name, $what_to_make) = split( '_', $called_sub_name, 2 );
	unless( lc($what_to_make) =~ 
			/^($TAG_GROUP|$TAG_PAIR|$TAG_START|$TAG_END)$/ ) {
		if( $self->{$KEY_AUTO_GROUP} ) {
			$what_to_make = $TAG_GROUP;
		} else {
			$what_to_make = undef;
		}
	}

	my $rh_params = $self->params_to_hash( \@_, 0, $PARAM_TEXT, 
		{}, $PARAM_TEXT );
	my $ra_text = delete( $rh_params->{$PARAM_TEXT} );
	my $force_list = delete( $rh_params->{$PARAM_LIST} );

	if( lc($what_to_make) eq $TAG_GROUP ) {
		return( $self->make_html_tag_group( 
			$tag_name, $rh_params, $ra_text, $force_list ) );
	}

	return( $self->make_html_tag( 
		$tag_name, $rh_params, $ra_text, $what_to_make ) );
}

# This is provided so AUTOLOAD isn't called instead.
sub DESTROY {
}

######################################################################

=head1 FUNCTIONS AND METHODS

Note that all the methods defined below are static, so information specific to
autoloaded methods won't likely apply to them.  All of these methods take
positional arguments unless otherwise specified.

=head2 new()

This function creates a new HTML::TagMaker object and returns it.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = {};
	bless( $self, ref($class) || $class );
	$self->{$KEY_AUTO_GROUP} = 0;
	$self->{$KEY_AUTO_POSIT} = 0;
	return( $self );
}

######################################################################

=head2 clone()

This method creates a new HTML::TagMaker object, which is a duplicate of
this one in every respect, and returns it.

=cut

######################################################################

sub clone {
	my $self = shift( @_ );
	my $clone = {};
	bless( $clone, ref($self) );
	%{$clone} = %{$self};  # only does single-level copy
	return( $clone );
}

######################################################################

=head2 groups_by_default([ VALUE ])

This method is an accessor for the boolean "automatic grouping" property of this
object, which it returns.  If VALUE is defined, this property is set to it.  In
cases where we aren't told explicitely that autoloaded methods are making a
single or multiple tags (using ['_start', '_end', '_pair'] and '_group'
respectively), we look to this property to determine what operation we guess. 
The default is "single".  When this property is true, we can make both single and
groups of tags by using a suffix-less method name; however, making single tags
this way is slower than when this property is false.  Also, be aware that when we
are making a "group", arguments that are ARRAY refs are always flattened, and
when we are making a "single", ARRAY ref arguments are always used literally.

=cut

######################################################################

sub groups_by_default {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_AUTO_GROUP} = $new_value;
	}
	return( $self->{$KEY_AUTO_GROUP} );
}

######################################################################

=head2 positional_by_default([ VALUE ])

This method is an accessor for the boolean "positional arguments" property of
this object, which it returns.  If VALUE is defined, this property is set to it. 
With methods whose parameters could be either named or positional, when we aren't
sure what we are given, do we guess positional?  Default is named.

=cut

######################################################################

sub positional_by_default {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_AUTO_POSIT} = $new_value;
	}
	return( $self->{$KEY_AUTO_POSIT} );
}

######################################################################

=head2 prologue_tag()

This method returns a prologue tag, which is meant to be the very first thing in
an HTML document.  It tells the web browser such things as what version of the
HTML standard we are adhering to, version 4.0 in this case.  The prologue tag we
make looks like '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">'.

=cut

######################################################################

sub prologue_tag {
	my $self = shift( @_ );
	return( "\n".'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">' );
}

######################################################################

=head2 comment_tag( TEXT )

This method returns a comment tag, which is only visible to people viewing the
HTML source of a document, and not otherwise.  It can take either a scalar or a
list or an Array ref as its TEXT argument.  If a single item of text is passed,
then a comment tag that looks like "<!-- text -->" is made.  If more than one
item of text is passed, then a multi-line comment is made, which has each item of
text on its own line and indented with a single tab.  The latter is suitable for
displaying CSS or JavaScript code in an elegant manner.

=cut

######################################################################

sub comment_tag {
	my $self = shift( @_ );
	my @text = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;	
	if( scalar( @text ) <= 1 ) {
		return( "\n<!-- @text -->" );
	} else {
		return( "\n<!-- \n\t".join( "\n\t", @text )."\n -->" );
	}
}

######################################################################

=head2 make_html_tag( NAME[, PARAMS[, TEXT[, PART]]] )

This method is used internally to do the actual construction of single html tags.
 You can call it directly when you want faster code and/or more control over how
tags are made.  The first argument, NAME, is a scalar that defines the actual
name of the tag we are making (eg: 'br'); it is case-insensitive.  The optional
second argument, PARAMS, is a HASH ref containing attribute names and values for
the new tag; the names (keys) are case-insensitive.  The attribute values are all
printed literally, so they should be scalars.  The optional third argument, TEXT,
is a scalar containing the text that goes between the tag pairs; it is not a tag
attribute.  The optional fourth argument, PART, is a scalar which indicates we
should make just a certain part of the tag; acceptable values are ['pair',
'start', 'end'], and it is case-insensitive.  This method knows which HTML tags
are normally paired or not, which tag attributes take specified values or not,
and acts accordingly.

=cut

######################################################################

sub make_html_tag {
	my $self = shift( @_ );
	my $tag_name = lc(shift( @_ ));
	my $rh_params = shift( @_ );
	my $text = shift( @_ );
	my $what_to_make = lc(shift( @_ ));

	my %tag_params = map { ( lc($_) => $rh_params->{$_} ) } 
		(ref($rh_params) eq 'HASH') ? (keys %{$rh_params}) : ();

	unless( $what_to_make =~ /^($TAG_PAIR|$TAG_START|$TAG_END)$/ ) {
		$what_to_make = 
			$NO_PAIR_TAGS{$tag_name} ? $TAG_START : $TAG_PAIR;
	}
	
	my $tag_name_uc = uc($tag_name);
	
	if( $what_to_make eq $TAG_END ) {
		return( "\n</$tag_name_uc>" );
	}
				
	my $param_str = '';
	foreach my $param ( sort {
			$PARAMS_PRECEDENCE{$b} <=> $PARAMS_PRECEDENCE{$a}
			} keys %tag_params ) {
		next if( $NO_VALUE_PARAMS{$param} and !$tag_params{$param} );
		$param_str .= ' '.uc( $param );
		unless( $NO_VALUE_PARAMS{$param} ) {
			$param_str .= "=\"$tag_params{$param}\"";
		}
	}

	if( $what_to_make eq $TAG_START ) {
		return( "\n<$tag_name_uc$param_str>$text" );
	}
		
	return( "\n<$tag_name_uc$param_str>$text</$tag_name_uc>" );
}

######################################################################

=head2 make_html_tag_group( NAME[, PARAMS[, TEXT[, LIST]]] )

This method is used internally to do the actual construction of html tag groups. 
You can call it directly when you want faster code and/or more control over how
tags are made.  The first argument, NAME, is a scalar that defines the actual
name of the tag we are making (eg: 'br'); it is case-insensitive.  The optional
second argument, PARAMS, is a HASH ref containing attribute names and values for
the new tag; the names (keys) are case-insensitive.  Any attribute values which
are ARRAY refs are flattened, and the number of tags made is determined by the
length of the longest one.  The optional third argument, TEXT, is a HASH ref (or
scalar) containing the text that goes between the tag pairs; it is not a tag
attribute, but if its an ARRAY ref then its length will influence the number of
tags that are made as the length of tag attribute arrays do.  The optional fourth
argument, LIST, is a boolean/scalar which indicates whether this method returns
the new tags in an ARRAY ref (one tag per element) or as a scalar (tags are
concatenated together); a true value forces an ARRAY ref, scalar is the default. 
This method knows which HTML tags are normally paired or not, which tag
attributes take specified values or not, and acts accordingly.

=cut

######################################################################

sub make_html_tag_group {
	my $self = shift( @_ );
	my $tag_name = lc(shift( @_ ));
	my $rh_params = shift( @_ );
	my $text_in = shift( @_ );
	my $force_list = shift( @_ );

	my %tag_params = map { ( lc($_) => $rh_params->{$_} ) } 
		(ref($rh_params) eq 'HASH') ? (keys %{$rh_params}) : ();

	$tag_params{$PARAM_TEXT} = $text_in;

	my $max_tag_ind = 0;
	foreach my $key (keys %tag_params) {
		my $ra_values = $tag_params{$key};
		unless( ref($ra_values) eq 'ARRAY' ) {
			$tag_params{$key} = [$ra_values];
			next;
		}
		if( $#{$ra_values} > $max_tag_ind ) {
			$max_tag_ind = $#{$ra_values};
		}
	}

	foreach my $ra_values (values %tag_params) {
		my $last_value = $ra_values->[-1];
		push( @{$ra_values}, 
			map { $last_value } (($#{$ra_values} + 1)..$max_tag_ind) );
	}
	
	my $tag_name_uc = uc($tag_name);
	my $ra_text = delete( $tag_params{$PARAM_TEXT} );
	my @param_seq = sort { $PARAMS_PRECEDENCE{$b} 
		<=> $PARAMS_PRECEDENCE{$a} } keys %tag_params;
	my @new_tags = ();

	foreach my $index (0..$max_tag_ind) {
		my $param_str = '';
		foreach my $param ( @param_seq ) {
			next if( $NO_VALUE_PARAMS{$param} and 
				!$tag_params{$param}->[$index] );
			$param_str .= ' '.uc( $param );
			unless( $NO_VALUE_PARAMS{$param} ) {
				$param_str .= "=\"$tag_params{$param}->[$index]\"";
			}
		}
		my $text = $ra_text->[$index];
		if( $NO_PAIR_TAGS{$tag_name} ) {
			push( @new_tags, "\n<$tag_name_uc$param_str>$text" );
		} else {
			push( @new_tags, 
				"\n<$tag_name_uc$param_str>$text</$tag_name_uc>" );
		}
	}

	return( $force_list ? \@new_tags : join( '', @new_tags ) );
}

######################################################################

=head2 start_html([ TITLE[, AUTHOR[, META[, STYLE[, HEAD[, BODY]]]]] ])

This method returns a canned HTML template that is suitable for use as the top of
an HTML page.  It consists of the prologue tag (<!DOCTYPE...), the opening 'html'
tag, the entire 'head' section, and the opening 'body' tag.  The prologue tag
looks the same as that generated by the class method prologue_tag().  This method
can take its optional six arguments in either named or positional format; in the
first case, the names look the same as the positional placeholders above, except
they must be in lower case.  The first two arguments, TITLE and AUTHOR, are
scalars which respectively define the title and author for the document.  The
default value for TITLE is 'Untitled Document', and a '<LINK REV="made">' tag is
made if AUTHOR is present.  The third argument, META, is a HASH ref containing
name/value pairs of meta information, and a '<META NAME="n" VALUE="v">' tag is
made for each one.  The fourth argument, STYLE, allows Cascading Style Sheets to
be used in the document.  See the method B<css_for_start_html()>, which handles
the particulars of this argument.  The fifth argument, HEAD, is an ARRAY ref (or
scalar) containing anything else you would like to appear in the 'head' section;
it is flattened and the elements used as-is.  The sixth argument, BODY, is a HASH
ref containing attributes and values for the opening 'body' tag.

=cut

######################################################################

sub start_html {
	my $self = shift( @_ );
	my $rh_params = $self->params_to_hash( \@_, 
		$self->{$KEY_AUTO_POSIT}, qw(title author meta style head body) );

	my %meta = (ref( $rh_params->{'meta'} ) eq 'HASH') ?
		%{$rh_params->{'meta'}} : ();
	my $style = $self->css_for_html_head( $rh_params->{'style'} );
	my @head = (ref( $rh_params->{'head'} ) eq 'ARRAY') ?
		@{$rh_params->{'head'}} : ();
	
	return( join( '',
		$self->prologue_tag(),
		$self->html_start(),
		$self->head_start(),
		$self->title( $rh_params->{'title'} || 'Untitled Document' ),
		(defined $rh_params->{'author'}) ? $self->link( 
			rev => 'made', href => "mailto:$rh_params->{'author'}" ) : (),
		%meta ? (map { 
			$self->meta_group( name => $_, value => $meta{$_} ) 
			} keys %meta) : (),
		$style,
		@head,
		$self->head_end(),
		$self->body_start( $rh_params->{'body'} ),
	) );
}

######################################################################

=head2 end_html()

This method returns a canned HTML template that is suitable for use as the bottom
of an HTML page.  It consists of the closing 'body' and 'html' tags.

=cut

######################################################################

sub end_html {
	my $self = shift( @_ );
	return( $self->body_end().$self->html_end() );
}

######################################################################

=head2 css_for_start_html([ SRC[, CODE] ])

This method returns HTML code that allows Cascading Style Sheets to be used in
the document when the code is included in its "head" section.  This method is
used by start_html() to handle its STYLE argument.  This method can take its
optional arguments in either named or positional format; in the first case, the
names look the same as the positional placeholders above, except they must be in
lower case.  The first argument, SRC, is an Array ref (or scalar) whose elements
are urls for external StyleSheet documents that should be linked to by the
browser, and a '<LINK REL="stylesheet" SRC="url">' tag is made for each one.  The
second argument, CODE, is an Array ref (or scalar) whose elements are lines of
StyleSheet code that are to be embedded in the HTML document itself; a
"<STYLE><!-- code --></STYLE>" multi-line tag is made for them.  When both
arguments are used, the SRC appears first in the new HTML.

=cut

######################################################################

sub css_for_html_head {
	my $self = shift( @_ );
	my $rh_params = $self->params_to_hash( \@_, 
		$self->{$KEY_AUTO_POSIT}, qw(src code) );

	my @style_src = (ref( $rh_params->{'src'} ) eq 'ARRAY') ?
		@{$rh_params->{'src'}} : $rh_params->{'src'};
	my @style_code = (ref( $rh_params->{'code'} ) eq 'ARRAY') ?
		@{$rh_params->{'code'}} : $rh_params->{'code'};
	
	return( join( '',
		(defined $style_src[0]) ? $self->link_group( rel => 'stylesheet', 
			type => 'text/css', href => \@style_src ) : (),
		(defined $style_code[0]) ? $self->style( $self->comment_tag( 
			\@style_code ) ) : (),
	) );
}

######################################################################

1;
__END__

=head1 COMPATABILITY WITH OTHER MODULES

The methods of this class and their parameters are designed to be compatible with
any same-named methods in the popular CGI.pm class.  This class will produce
identical or browser-compatible HTML from such methods, and this class can accept
all the same argument formats.  Exceptions to this include:

=over 4

=item 0

None of our methods are exported and must be called using indirect
notation, whereas CGI.pm can export any of it's methods.

=item 0

start_html() doesn't support all the same arguments, but those that do have
the same names.  However, the effects of the missing arguments can be easily
replicated by making the appropriate tags explicitely and handing them in via
either the "head" or "body" arguments, where appropriate.  The common arguments
are ['title', 'author', 'meta', 'style', 'head', 'body'], in that order.

=item 0

Our textarea() method is autoloaded, and doesn't have the special symantecs
that CGI.pm's textarea() does.  However, any module who subclasses from this one
can override textarea() with one that matches CGI.pm's symantecs.  The 
"HTML::FormMaker" module does this.

=item 0

Autoloaded methods do not use the presence or absense of arguments to
decide whether to make the new tag as a pair or as "start only".

=item 0

Autoloaded methods that make html tags won't concatenate their arguments
into a single argument under any circumstances, but in some cases the "shortcuts"
of CGI.pm will do so.

=item 0

Currently we don't html-escape any argument values passed to our tag making
functions, whereas CGI.pm sometimes does.  While we expect our caller to do the
escaping themselves where necessary, we may do it later in an update.

=item 0

We go further to make the generated HTML human-readable by: 1. having each
new tag start on a new line; 2. making all tag and attribute names uppercase; 3.
ensuring that about 20 often-used tag attributes always appear in the same order
(eg: 'type' is before 'name' is before 'value'), and before any others.

=back

=head1 AUTHOR

Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL.  Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 CREDITS

Thanks very much to B<Kevin Werbach> for publishing "The Bare Bones Guide to
HTML", which I found to be an invaluable resource when writing this module (and
at other times as well).  The latest version of the document is available at
B<http://werbach.com/barebones/>.

This quick reference lists all the HTML tags that current browsers are likely to
recognize, including all the elements of the official HTML 4.0 recommendation,
and some Netscape and Microsoft extensions as well.  Common attributes for these
tags are also included in context, giving a good idea on how they are used.

When writing this module, I used the Bare Bones reference to verify the
consistant formatting used by all HTML tags, including how tag attributes are
formatted.  I could see the proper formatting for prologue and comment tags as
well; their formats are unique compared to all the other tags.  The other main
uses I had for the document was in determining all the HTML tags which were not
used as a pair (most use pairs, few don't), and for determining which tag
attributes made a positive assertion just by their presence, without need for any
associated values (most have values, few don't).

Thanks also to B<Lincoln D. Stein> for publishing the popular CGI.pm module,
which I found very useful in my programs.  Moreover, I have decided to emulate
much of its functionality in some of my own modules, so I should give credit
where its due for implementing that functionality first.  Lincoln should be
pleased that I am following his advice (look under heading "BUGS" in CGI) and
discarding his large and monolithic module in favor of simpler ones.

=head1 SEE ALSO

perl(1), CGI, Class::ParamParser.

=cut
