=head1 NAME

HTML::FormMaker - Perl module that maintains a predefined html input form
definition with which it can generate form html, complete with persistant and
error-checked user input, as well as formatted reports of the user input in html
or plain text format.

=cut

######################################################################

package HTML::FormMaker;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = '1.0b';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::HashOfArrays
	Class::ParamParser
	HTML::TagMaker

=cut

######################################################################

use CGI::HashOfArrays;
use HTML::TagMaker;
@ISA = qw( HTML::TagMaker );

######################################################################

=head1 SYNOPSIS

	use HTML::FormMaker;
	
	my @definitions = (
		{
			visible_title => "What's your name?",
			type => 'textfield',
			name => 'name',
		}, {
			visible_title => "What's the combination?",
			type => 'checkbox_group',
			name => 'words',
			'values' => ['eenie', 'meenie', 'minie', 'moe'],
			default => ['eenie', 'minie'],
		}, {
			visible_title => "What's your favorite colour?",
			type => 'popup_menu',
			name => 'color',
			'values' => ['red', 'green', 'blue', 'chartreuse'],
		}, {
			type => 'submit', 
		},
	);
	
	my $query_string = '';
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};
	} else {
		read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
	}
	my $user_input = CGI::HashOfArrays->new( 1, $query_string );
	
	my $form = HTML::FormMaker->new();
	$form->form_submit_url( $ENV{'SCRIPT_NAME'} );
	$form->field_definitions( \@definitions );
	$form->user_input( $user_input );
	
	print
		'Content-type: text/html'."\n\n",
		$form->start_html( 'A Simple Example' ),
		$form->h1( 'A Simple Example' ),
		$form->make_html_input_form( 1 ),
		$form->hr,
		$form->new_form() ? '' : $form->make_html_input_echo( 1 ),
		$form->end_html;
	
=head1 DESCRIPTION

This Perl 5 object class can create web fill-out forms as well as parse,
error-check, and report their contents.  Forms can start out blank or with
initial values, or by repeating the user's last input values.  Facilities for
interactive user-input-correction are also provided.

The class is designed so that a form can be completely defined, using
field_definitions(), before any html is generated or any error-checking is done. 
For that reason, a form can be generated multiple times, each with a single
function call, while the form only has to be defined once.  Form descriptions can
optionally be read from a file by the calling code, making that code a lot more
generic and robust than code which had to define the field manually.

If the calling code provides a HashOfArrays object or HASH ref containing the
parsed user input from the last time the form was submitted, via user_input(),
then the newly generated form will incorporate that, making the entered values
persistant. Since the calling code has control over the provided "user input",
they can either get it live or read it from a file, which is transparent to us. 
This makes it easy to make programs that allow the user to "come back later" and
continue editing where they left off, or to seed a form with initial values.
(Field definitions can also contain initial values.)

Based on the provided field definitions, this module can do some limited user
input checking, and automatically generate error messages and help text beside
the appropriate form fields when html is generated, so to show the user exactly
what they have to fix.  The "error state" for each field is stored in a hash,
which the calling code can obtain and edit using invalid_input(), so that results
of its own input checking routines are reflected in the new form.

Note that this class is a subclass of both Class::ParamParser and HTML::TagMaker, and inherits all of their methods.

=head1 HTML CODE FROM SYNOPSIS PROGRAM

	Content-type: text/html


	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
	<HTML>
	<HEAD>
	<TITLE>A Simple Example</TITLE>
	</HEAD>
	<BODY>
	<H1>A Simple Example</H1>
	<FORM METHOD="post" ACTION="localhost">
	<TABLE CELLSPACING="5">
	<INPUT TYPE="hidden" NAME=".is_submit" VALUE="1">
	<TR>
	<TD VALIGN="top" ALIGN="left"></TD>
	<TD VALIGN="top" ALIGN="left">
	<STRONG>What's your name?:</STRONG></TD>
	<TD VALIGN="top" ALIGN="left">
	<INPUT TYPE="text" NAME="name"></TD></TR>
	<TR>
	<TD VALIGN="top" ALIGN="left"></TD>
	<TD VALIGN="top" ALIGN="left">
	<STRONG>What's the combination?:</STRONG></TD>
	<TD VALIGN="top" ALIGN="left">
	<INPUT TYPE="checkbox" NAME="words" CHECKED VALUE="eenie">eenie
	<INPUT TYPE="checkbox" NAME="words" VALUE="meenie">meenie
	<INPUT TYPE="checkbox" NAME="words" CHECKED VALUE="minie">minie
	<INPUT TYPE="checkbox" NAME="words" VALUE="moe">moe</TD></TR>
	<TR>
	<TD VALIGN="top" ALIGN="left"></TD>
	<TD VALIGN="top" ALIGN="left">
	<STRONG>What's your favorite colour?:</STRONG></TD>
	<TD VALIGN="top" ALIGN="left">
	<SELECT NAME="color" SIZE="1">
	<OPTION VALUE="red">red
	<OPTION VALUE="green">green
	<OPTION VALUE="blue">blue
	<OPTION VALUE="chartreuse">chartreuse
	</SELECT></TD></TR>
	<TR>
	<TD VALIGN="top" ALIGN="left"></TD>
	<TD VALIGN="top" ALIGN="left"></TD>
	<TD VALIGN="top" ALIGN="left">
	<INPUT TYPE="submit" NAME="nonamefield001"></TD></TR>
	</TABLE>
	</FORM>
	<HR>
	</BODY>
	</HTML>

=head1 RECOGNIZED FORM FIELD TYPES

This class recognizes 10 form field types, and a complete field of that type can
be made either by providing a "field definition" with the same "type" attribute
value, or by calling a method with the same name as the field type.  Likewise,
groups of related form fields can be made with either a single field definition
or method call, for 6 of those field types.

Standalone fields of the following types are recognized:

=over 4

=item B<reset> - makes a reset button

=item B<submit> - makes a submit button

=item B<hidden> - makes a hidden field, which the user won't see

=item B<textfield> - makes a text entry field, one row high

=item B<password_field> - same as textfield except contents are bulleted out

=item B<textarea> - makes a big text entry field, several rows high

=item B<checkbox> - makes a standalone check box

=item B<radio> - makes a standalone radio button

=item B<popup_menu> - makes a popup menu, one item can be selected at once

=item B<scrolling_list> - makes a scrolling list, multiple selections possible

=back

Groups of related fields of the following types are recognized:

=over 4

=item B<hidden_group> - makes a group of related hidden fields

=item B<textfield_group> - makes a group of related text entry fields

=item B<password_field_group> - makes a group of related password fields

=item B<textarea_group> - makes a group of related big text entry fields

=item B<checkbox_group> - makes a group of related checkboxes

=item B<radio_group> - makes a group of related radio buttons

=back

Other field types aren't intrinsicly recognized, but can still be generated as
ordinary html tags by calling a method with the name of that tag.  A list of all
the valid field types is returned by the valid_field_type_list() method.

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_FIELD_DEFN = 'field_defn';  # instruc for how to make form fields
my $KEY_NORMALIZED = 'normalized';  # are field defn in proper form?
my $KEY_USER_INPUT = 'user_input';     # form data user submits; to process
my $KEY_NEW_FORM   = 'new_form';  # true when form used first time
my $KEY_INVALID    = 'invalid';   # fields with invalid user input
my $KEY_FIELD_HTML = 'field_html'; # hash; generated field html
my $KEY_SUBMIT_URL = 'submit_url';  # where form goes when submitted
my $KEY_SUBMIT_MET = 'submit_method';  # ususlly POST or GET

# Names of properties for objects of parent class are declared here:
my $KEY_AUTO_GROUP = 'auto_group';  # do we make tag groups by default?
my $KEY_AUTO_POSIT = 'auto_posit';  # with methods whose parameters 
	# could be either named or positional, when we aren't sure what we 
	# are given, do we guess positional?  Default is named.

# Keys for items in form property $KEY_FIELD_DEFN:
my $FKEY_TYPE     = 'type';  # form inputs
my $FKEY_NAME     = 'name';  # form inputs
my $FKEY_VALUE    = 'value';  # form inputs
my $FKEY_DEFAULT  = 'default';  # form inputs
my $FKEY_OVERRIDE = 'override';  # force coded values to be used
my $FKEY_TEXT = 'text';  #tag pair is wrapped around this
my $FKEY_LIST = 'list';  #force tag groups to ret as list inst of scalar
my $FKEY_IS_REQUIRED     = 'is_required';  # field must be filled in
my $FKEY_IS_PRIVATE      = 'is_private';   # field not shared with public
my $FKEY_VALIDATION_RULE = 'validation_rule';  # a regular expression
my $FKEY_VISIBLE_TITLE   = 'visible_title';  # main title/prompt for field
my $FKEY_HELP_MESSAGE    = 'help_message';   # suggestions for field use
my $FKEY_ERROR_MESSAGE   = 'error_message';  # appears when input invalid
my $FKEY_EXCLUDE_IN_ECHO = 'exclude_in_echo';  # always exclude from reports
my $FKEY_KEEP_WITH_PREV  = 'keep_with_prev';  # put field in same P as prev
	# note that the "keep with prev" is not implemented yet

# Constant values used in this class go here:

my %INPUT_FIELDS = map { ( $_ => 1 ) } qw(
	reset submit hidden
	textfield textarea password_field
	checkbox radio
	popup_menu scrolling_list
);

my %INPUT_FIELD_GROUPS = map { ( $_ => 1 ) } qw(
	hidden
	textfield textarea password_field
	checkbox radio
);

my $DEF_SUBMIT_MET = 'post';
my $DEF_SUBMIT_URL = 'localhost';

my $DEF_FF_TYPE     = 'textfield';
my $DEF_FF_NAME_PFX = 'nonamefield';
my $FFN_IS_SUBMIT   = '.is_submit';

my %INPUT_MPP_ARGS = ();
foreach my $field_type (qw( reset submit )) {
	$INPUT_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_DEFAULT ], 
		{ $FKEY_VALUE => $FKEY_DEFAULT, label => $FKEY_DEFAULT }
	];
}
$INPUT_MPP_ARGS{hidden} = [
	[ $FKEY_NAME, $FKEY_DEFAULT ], 
	{ $FKEY_VALUE => $FKEY_DEFAULT }
];
foreach my $field_type (qw( textfield password_field )) {
	$INPUT_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_DEFAULT, 'size', 'maxlength' ], 
		{ $FKEY_VALUE => $FKEY_DEFAULT, 'force' => $FKEY_OVERRIDE }
	];
}
$INPUT_MPP_ARGS{textarea} = [
	[ $FKEY_NAME, $FKEY_DEFAULT, 'rows', 'cols' ], 
	{ $FKEY_VALUE => $FKEY_DEFAULT, $FKEY_TEXT => $FKEY_DEFAULT, 
	'columns' => 'cols', 'force' => $FKEY_OVERRIDE }, $FKEY_DEFAULT
];
foreach my $field_type (qw( checkbox radio )) {
	$INPUT_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_DEFAULT, $FKEY_VALUE, $FKEY_TEXT ],
		{ 'checked' => $FKEY_DEFAULT, selected => $FKEY_DEFAULT, 
		on => $FKEY_DEFAULT, 'label' => $FKEY_TEXT,
		'force' => $FKEY_OVERRIDE }, $FKEY_TEXT
	];
}
foreach my $field_type (qw( popup_menu scrolling_list )) {
	$INPUT_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_VALUE, $FKEY_DEFAULT, $FKEY_TEXT ],
		{ 'values' => $FKEY_VALUE, selected => $FKEY_DEFAULT, 
		checked => $FKEY_DEFAULT, on => $FKEY_DEFAULT, 
		defaults => $FKEY_DEFAULT, labels => $FKEY_TEXT, 
		label => $FKEY_TEXT, 'force' => $FKEY_OVERRIDE }, $FKEY_TEXT
	];
}

my %INPUT_GROUP_MPP_ARGS = ();
$INPUT_GROUP_MPP_ARGS{hidden} = [
	[ $FKEY_NAME, $FKEY_DEFAULT ], 
	{ $FKEY_VALUE => $FKEY_DEFAULT, 'values' => $FKEY_DEFAULT, 
		defaults => $FKEY_DEFAULT }
];
foreach my $field_type (qw( textfield password_field )) {
	$INPUT_GROUP_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_DEFAULT, 'linebreak', 'size', 'maxlength' ], 
		{ $FKEY_VALUE => $FKEY_DEFAULT, 'values' => $FKEY_DEFAULT, 
		defaults => $FKEY_DEFAULT, 'force' => $FKEY_OVERRIDE }
	];
}
$INPUT_GROUP_MPP_ARGS{textarea} = [
	[ $FKEY_NAME, $FKEY_DEFAULT, 'linebreak', 'rows', 'cols' ], 
	{ $FKEY_VALUE => $FKEY_DEFAULT, $FKEY_TEXT => $FKEY_DEFAULT, 
	'values' => $FKEY_DEFAULT, defaults => $FKEY_DEFAULT, 
	'columns' => 'cols', 'force' => $FKEY_OVERRIDE }, $FKEY_DEFAULT
];
foreach my $field_type (qw( checkbox radio )) {
	$INPUT_GROUP_MPP_ARGS{$field_type} = [
		[ $FKEY_NAME, $FKEY_VALUE, $FKEY_DEFAULT, 'linebreak', 
		$FKEY_TEXT ], { 'values' => $FKEY_VALUE, selected => 
		$FKEY_DEFAULT, checked => $FKEY_DEFAULT, on => $FKEY_DEFAULT, 
		defaults => $FKEY_DEFAULT, labels => $FKEY_TEXT, 
		label => $FKEY_TEXT, nolabels => 'nolabel', 
		'force' => $FKEY_OVERRIDE }, $FKEY_TEXT 
	];
}

my %INPUT_TAG_IMPL_TYPE = (
	'reset' => 'reset',
	submit => 'submit',
	hidden => 'hidden',
	textfield => 'text',
	password_field => 'password',
	checkbox => 'checkbox',
	radio => 'radio',
);

my $TAG_GROUP = 'group';  # values that "what_to_make" can have
my $TAG_PAIR  = 'pair'; 
my $TAG_START = 'start';
my $TAG_END   = 'end';

my $BAD_INPUT_MARKER = '<FONT COLOR="#ff0000">?</FONT>';
my $REQ_FIELD_MARKER = '<FONT COLOR="#0000ff">*</FONT>';
my $PRV_FIELD_MARKER = '<FONT COLOR="#00ff00">~</FONT>';

my %VALID_TYPES = map { ( $_ => 1 ) } qw(
	reset submit hidden
	textfield textarea password_field
	checkbox radio
	popup_menu scrolling_list
	hidden_group
	textfield_group textarea_group password_field_group
	checkbox_group radio_group
);

my %VALID_MV_TYPES = map { ( $_ => 1 ) } qw(
	popup_menu scrolling_list
	hidden_group
	textfield_group textarea_group password_field_group
	checkbox_group radio_group
);

my %VALID_ATTRIBUTES = ();
foreach my $field_type (keys %VALID_TYPES) {
	$VALID_ATTRIBUTES{$field_type} = [qw(
		type name default override is_required is_private validation_rule 
		visible_title help_message error_message exclude_in_echo
	)];
}
foreach my $field_type (qw( checkbox radio popup_menu scrolling_list 
		checkbox_group radio_group )) {
	push( @{$VALID_ATTRIBUTES{$field_type}}, qw( value label ) );
}
foreach my $field_type (qw( checkbox radio checkbox_group radio_group )) {
	push( @{$VALID_ATTRIBUTES{$field_type}}, qw( nolabel ) );
}
foreach my $field_type (qw( textfield password_field textfield_group 
		password_field_group )) {
	push( @{$VALID_ATTRIBUTES{$field_type}}, qw( size maxlength ) );
}
foreach my $field_type (qw( scrolling_list )) {
	push( @{$VALID_ATTRIBUTES{$field_type}}, qw( size multiple ) );
}
foreach my $field_type (qw( textarea textarea_group )) {
	push( @{$VALID_ATTRIBUTES{$field_type}}, qw( rows cols ) );
}

my %ATTRIB_DEFINS = (
	type => {
		visible_title => 'Field Type',
		type => 'popup_menu',
		values => [keys %VALID_TYPES],
		default => 'textfield',
	}, 
	name => {
		visible_title => 'Field Name',
		type => 'textfield',
		is_required => 1,
		validation_rule => '[a-z]',
		size => 20,
	}, 
	value => {
		visible_title => 'Values for list options',
		type => 'textfield',
		size => 30,
	}, 
	default => {
		visible_title => 'Default Value(s)',
		type => 'textfield',
		size => 30,
	}, 
	override => {
		visible_title => 'Revert to defaults when correcting',
		type => 'checkbox',
	}, 
	label => {
		visible_title => 'Labels for list options',
		type => 'textfield',
		size => 30,
		help_text => 'If not filled in, the values are used for labels.',
	}, 
	nolabel => {
		visible_title => 'Do not show any option labels',
		type => 'checkbox',
	}, 
	multiple => {
		visible_title => 'Allow multiple list selections',
		type => 'checkbox',
	}, 
	size => {
		visible_title => 'Visible Size',
		type => 'textfield',
		size => 4,
		validation_rule => '^\s*\d+\s*$',
		help_message => 'Input must be a valid whole number.',
	}, 
	maxlength => {
		visible_title => 'Maximum Content Length',
		type => 'textfield',
		size => 4,
		validation_rule => '^\s*\d+\s*$',
		help_message => 'Input must be a valid whole number.',
	}, 
	rows => {
		visible_title => 'Height in Rows',
		type => 'textfield',
		size => 4,
		validation_rule => '^\s*\d+\s*$',
		help_message => 'Input must be a valid whole number.',
	}, 
	cols => {
		visible_title => 'Width in Columns',
		type => 'textfield',
		size => 4,
		validation_rule => '^\s*\d+\s*$',
		help_message => 'Input must be a valid whole number.',
	}, 
	is_required => {
		visible_title => 'Input is Required',
		type => 'checkbox',
	}, 
	is_private => {
		visible_title => 'Input is Private',
		type => 'checkbox',
	}, 
	validation_rule => {
		visible_title => 'Input Validation Rule',
		type => 'textfield',
		help_message => 'Input must be a valid Perl 5 regular expression.',
	}, 
	visible_title => {
		visible_title => 'Visible Title',
		type => 'textfield',
	}, 
	help_message => {
		visible_title => 'Help Message',
		type => 'textarea',
		rows => 2,
		cols => 40,
	}, 
	error_message => {
		visible_title => 'Error Message',
		type => 'textarea',
		rows => 2,
		cols => 40,
	}, 
	exclude_in_echo => {
		visible_title => 'Mark field to exclude from reports',
		type => 'checkbox',
	},
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
different order than it is generated.

=head1 FIELD DEFINITION PARAMETERS

In addition to the form field parameters shown in the next section, there are
several additional ones that are only used when this class generates an entire
form or echoing report at once, or when it does user input checking:

=over 4

=item B<is_required> - boolean - An assertion that the field must be filled in by
the user, or otherwise there is an error condition.  A visual cue is provided to
the user in the form of a blue asterisk ("*"), that this is so.  You need to make
your own legend explaining this where appropriate.

=item B<is_private> - boolean - A visual cue is provided to the user in the form
of a green tilde ("~"), that you don't intend to make the contents of that field
public.  You need to make your own legend explaining this where appropriate.

=item B<validation_rule> - string - A Perl 5 regular expression that is applied
to user input, and if it evaluates to false then an error condition is present.  
In cases where user input has been evaluated to be in error, a visual cue is
provided to the user in the form of a red question mark ("?"), that this is so. 
You need to make your own legend explaining this where appropriate.

=item B<visible_title> - string - This is the "name" or "question" or "prompt"
that is visually associated with a form field or field group that lets the user
know what the field is for.  It is printed in bold type with a colon (":")
appended on the end.  This title is also used with the input echo reports, as a
label or heading for each piece of user input.

=item B<help_message> - string - This is an optional sentance or three that helps
the user further, such as explaining the reason for this' fields existence, or by
providing examples of valid input.  It is printed in smaller type and enclosed in
parenthesis.

=item B<error_message> - string - This is an optional sentance or three that only
appears when the user didn't enter invalid input.  It helps the user further,
such as explaining what they did wrong or giving examples of valid input.  It is
printed in smaller type and is colored red.

=item B<exclude_in_echo> - boolean - An assertion that this field's value will
never be shown when reports are generated.  This provides an alternative to the
more messy redefining of the form field definitions that would otherwise be
required to exclude fields that aren't private or hidden or buttons.  Normally
the calling code is manually displaying the information from fields excluded this
way in a location outside the report html.

=back

=head1 FORM FIELD PARAMETERS

When form field html is generated by calling a method with the same name as the
field type, several method parameter formats are supported, including named
arguments and positional parameters.  When using named parameters, the parameter
name can optionally be preceeded by a "-".  See the documentation for
Class::ParamParser for details.  Not all parameters are supported in
positional format, so that is only sometimes suitable.

When a form field is being defined in advance using field_definitions(), then
only the named format is acceptable, and the names must not be preceeded by a
"-", or they won't be recognized.  Additionally, parameter names are case
sensitive when used in field_definitions(), so make them entirely lowercase.  The
uppercase names below are just for ease of visibility.

When using field definitions, a "type" parameter should be provided in a
definition, or "textfield" will be used by default.  Also, if a field "name"
isn't provided, then "nonamefieldNNN" will be used by default.  This is fine only
if you don't need to reference fields by name in your own code.

In either case, many field parameters can accept aliases to their names, when
using named format, and this varies by field type.  You must never use more than
one alias for a parameter in a single field definition, or confusion will result
and all but one of them will be lost.

Note that the form field name ".is_submit" is reserved for internal use by this
class, so do not use it!

I<Note that this documentation isn't as complete as I would like, although there
is a lot here.  Optionality isn't shown here for these arguments, and neither is
a description for what the arguments do.  Use your best judgement.  Also, see the
CGI.pm documentation, as these methods are all backwards-compatible with
like-named CGI methods.>

=head2 reset( NAME, DEFAULT )
	
	NAME
	[DEFAULT or VALUE or LABEL]

=head2 submit( NAME, DEFAULT )
	
	NAME
	[DEFAULT or VALUE or LABEL]

=head2 hidden( NAME, DEFAULT )
	
	NAME
	[DEFAULT or VALUE]

=head2 textfield( NAME, DEFAULT, SIZE, MAXLENGTH )
	
	NAME
	[DEFAULT or VALUE]
	SIZE
	MAXLENGTH
	[OVERRIDE or FORCE]

=head2 password_field( NAME, DEFAULT, SIZE, MAXLENGTH )
	
	NAME
	[DEFAULT or VALUE]
	SIZE
	MAXLENGTH
	[OVERRIDE or FORCE]

=head2 textarea( NAME, DEFAULT, ROWS, COLS )
	
	NAME
	[DEFAULT or VALUE or TEXT]
	ROWS
	[COLS or COLUMNS]
	[OVERRIDE or FORCE]

=head2 checkbox( NAME, DEFAULT, VALUE, LABEL )
	
	NAME
	VALUE
	[DEFAULT or CHECKED or SELECTED or ON]
	[LABEL or TEXT]
	NOLABEL
	[OVERRIDE or FORCE]

=head2 radio( NAME, DEFAULT, VALUE, LABEL )
	
	NAME
	VALUE
	[DEFAULT or CHECKED or SELECTED or ON]
	[LABEL or TEXT]
	NOLABEL
	[OVERRIDE or FORCE]

=head2 popup_menu( NAME, DEFAULTS, VALUES, LABELS )
	
	NAME
	[VALUES or VALUE]
	[DEFAULTS or DEFAULT or CHECKED or SELECTED or ON]
	[LABELS or LABEL or TEXT]
	[OVERRIDE or FORCE]

=head2 scrolling_list( NAME, DEFAULTS, VALUES, LABELS )
	
	NAME
	[VALUES or VALUE]
	[DEFAULTS or DEFAULT or CHECKED or SELECTED or ON]
	[LABELS or LABEL or TEXT]
	SIZE
	MULTIPLE
	[OVERRIDE or FORCE]

=head2 hidden_group( NAME, DEFAULTS )
	
	NAME
	[DEFAULTS or DEFAULT or VALUES or VALUE]
	LIST - method returns array ref with one field per element

=head2 textfield_group( NAME, DEFAULTS, LINEBREAK, SIZE, MAXLENGTH )
	
	NAME
	[DEFAULTS or DEFAULT or VALUES or VALUE]
	SIZE
	MAXLENGTH
	[OVERRIDE or FORCE]
	LINEBREAK
	LIST - method returns array ref with one field per element

=head2 password_field_group( NAME, DEFAULTS, LINEBREAK, SIZE, MAXLENGTH )
	
	NAME
	[DEFAULTS or DEFAULT or VALUES or VALUE]
	SIZE
	MAXLENGTH
	[OVERRIDE or FORCE]
	LINEBREAK
	LIST - method returns array ref with one field per element

=head2 textarea_group( NAME, DEFAULTS, LINEBREAK, ROWS, COLS )
	
	NAME
	[DEFAULTS or DEFAULT or VALUES or VALUE or TEXT]
	ROWS
	[COLS or COLUMNS]
	[OVERRIDE or FORCE]
	LINEBREAK
	LIST - method returns array ref with one field per element

=head2 checkbox_group( NAME, VALUES, DEFAULTS, LINEBREAK, LABELS )
	
	NAME
	[VALUES or VALUE]
	[DEFAULTS or DEFAULT or CHECKED or SELECTED or ON]
	[LABELS or LABEL or TEXT]
	[NOLABELS or NOLABEL]
	[OVERRIDE or FORCE]
	LINEBREAK
	LIST - method returns array ref with one field per element

=head2 radio_group( NAME, VALUES, DEFAULTS, LINEBREAK, LABELS )
	
	NAME
	[VALUES or VALUE]
	[DEFAULTS or DEFAULT or CHECKED or SELECTED or ON]
	[LABELS or LABEL or TEXT]
	[NOLABELS or NOLABEL]
	[OVERRIDE or FORCE]
	LINEBREAK
	LIST - method returns array ref with one field per element

=cut

######################################################################

sub AUTOLOAD {
	my $self = shift( @_ );
	$AUTOLOAD =~ m/([^:]*)$/;   # we don't need fully qualified name
	my $called_sub_name = lc($1);

	if( $INPUT_FIELDS{$called_sub_name} ) {
		return( $self->make_input_tag( $called_sub_name, \@_ ) );
	}

	$called_sub_name =~ m/(.*)_group$/;
	if( $1 and $INPUT_FIELD_GROUPS{$1} ) {
		return( $self->make_input_tag_group( $1, \@_ ) );
	}

	# "$self->SUPER::$called_sub_name( @_ )" yields a compile error
	return( eval "\$self->SUPER::$called_sub_name( \@_ )" );
}

######################################################################

=head1 FUNCTIONS AND METHODS

=head2 new()

This function creates a new HTML::FormMaker object and returns it.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = SUPER::new $class ( @_ );
	
	$self->{$KEY_FIELD_DEFN} = [];
	$self->reset_to_new_form();
	$self->{$KEY_SUBMIT_URL} = $DEF_SUBMIT_URL;
	$self->{$KEY_SUBMIT_MET} = $DEF_SUBMIT_MET;

	return( $self );
}

######################################################################

=head2 clone()

This method creates a new HTML::FormMaker object, which is a duplicate of
this one in every respect, and returns it.

=cut

######################################################################

sub clone {
	my $self = shift( @_ );
	my $clone = $self->SUPER::clone( @_ );  # single-lev dup everything

	$clone->{$KEY_FIELD_DEFN} = 
		{map {$_->clone()} @{$self->{$KEY_FIELD_DEFN}}};

	$clone->{$KEY_USER_INPUT} = $self->{$KEY_USER_INPUT}->clone();
	defined( $self->{$KEY_INVALID} ) and 
		$clone->{$KEY_INVALID} = {%{$self->{$KEY_INVALID}}};

	defined( $self->{$KEY_FIELD_HTML} ) and 
		$clone->{$KEY_FIELD_HTML} = {%{$self->{$KEY_FIELD_HTML}}};

	return( $clone );
}

######################################################################

=head2 field_definitions([ DEFIN ])

This method is an accessor for the "field definitions" list property of this
object, which it returns.  If DEFIN is defined, this property is set to it.  This
property is a list of either HashOfArrays objects or HASH refs, each of which
contains a description for one field or field group that is to be made.  Fields
will be processed in the same order they appear in this list.  The list is empty
by default.  The method also clears any error conditions.

=cut

######################################################################

sub field_definitions {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		my @fields = 
			(ref($new_value) eq 'ARRAY') ? @{$new_value} : $new_value;

		my @field_defn = ();

		foreach my $field (@fields) {
			if( ref($field) eq 'CGI::HashOfArrays' ) {
				$field = $field->clone();
			} elsif( ref($field) eq 'HASH' ) {
				$field = CGI::HashOfArrays->new( 1, $field );
			} else {
				next;
			}
			push( @field_defn, $field );
		}

		$self->{$KEY_FIELD_DEFN} = \@field_defn;
		$self->{$KEY_NORMALIZED} = 0;
		$self->{$KEY_INVALID} = undef;
		$self->{$KEY_FIELD_HTML} = undef;
	}
	return( [@{$self->{$KEY_FIELD_DEFN}}] );
}

######################################################################

=head2 fields_normalized()

This method returns true if the field definitions have been "normalized".  The
boolean property that tracks this condition is false by default and only becomes
true when normalize_field_definitions() is called.  It becomes false when
field_definitions() is called.

=cut

######################################################################

sub fields_normalized {
	my $self = shift( @_ );
	return( $self->{$KEY_NORMALIZED} )
}

######################################################################

=head2 reset_to_new_form()

This method sets the boolean property "new form" to true, wipes out any user
input (putting form to factory defaults), and clears all error conditions.  You
can use this method to implement your own "defaults" button if you wish.

=cut

######################################################################

sub reset_to_new_form {
	my $self = shift( @_ );
	$self->{$KEY_USER_INPUT} = CGI::HashOfArrays->new( 1 );
	$self->{$KEY_NEW_FORM} = 1;
	$self->{$KEY_INVALID} = undef;
	$self->{$KEY_FIELD_HTML} = undef;
}

######################################################################

=head2 user_input([ INPUT ])

This method is an accessor for the "user input" property of this object, which it
returns.  If INPUT is defined, this property is set to it.  This property is a
single HashOfArrays object or HASH ref whose keys are the form fields that the user filled in
and whose values are what they entered.  These values are used when creating form
field html to preserve what the user previously entered, and they are used when
doing our own input checking, and they are used when generating input echo
reports.  This property is also examined when it is set and automatically changes
the "new form" property accordingly.  The property is undefined by default.  The
method also clears any error conditions.

=cut

######################################################################

sub user_input {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		if( ref($new_value) eq 'CGI::HashOfArrays' ) {
			$new_value = $new_value->clone();
		} elsif( ref($new_value) eq 'HASH' ) {
			$new_value = CGI::HashOfArrays->new( 1, $new_value );
		} else {
			last;
		}
		$self->{$KEY_USER_INPUT} = $new_value;
		$self->{$KEY_NEW_FORM} = 
			!$new_value->fetch_value( $FFN_IS_SUBMIT );
		$self->{$KEY_INVALID} = undef;
		$self->{$KEY_FIELD_HTML} = undef;
	}
	return( $self->{$KEY_USER_INPUT} );
}

######################################################################

=head2 new_form([ VALUE ])

This method is an accessor for the boolean "new form" property of this object,
which it returns.  If VALUE is defined, this property is set to it.  If this
property is true, then we act like this is the first time we were called.  That
means that the form is blank except for factory defaults, and there are no error
conditions.  If this property is false then we are being called again after the
user submitted the form at least once, and we do perform input checking.  This
property is true by default.  No other properties are changed.

=cut

######################################################################

sub new_form {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_NEW_FORM} = $new_value;
		$self->{$KEY_INVALID} = undef;
		$self->{$KEY_FIELD_HTML} = undef;
	}
	return( $self->{$KEY_NEW_FORM} );
}

######################################################################

=head2 invalid_input([ NAMES ])

This method is an accessor for the "invalid input" property of this object, which
it returns.  If NAMES is a valid hash ref, this property is set to it.  This
property is a hash that indicates which fields have invalid input.  The property
is undefined by default, and is set when validate_form_input() is called.  The
optional NAMES argument lets you override the internal input checking to apply
your own input checking.  If you want both to happen, then call it once with no
arguments (internal is automatically done), then edit the results, then call this
again providing your new hash as an argument.

=cut

######################################################################

sub invalid_input {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_INVALID} = {%{$new_value}};
	}
	unless( defined( $self->{$KEY_INVALID} ) ) {
		$self->validate_form_input();
	}
	return( $self->{$KEY_INVALID} );  # returns ref; caller may change
}

######################################################################

=head2 field_html([ NAME ])

This method returns generated html code for form fields that were defined using
field_definitions().  If NAME is defined it only returnes code for the field (or
group) with that name; otherwise it returns a list of html for all fields.  This
is useful if you want to define your form fields ahead of time, but still want to
roll your own complete form.

=cut

######################################################################

sub field_html {
	my $self = shift( @_ );
	unless( defined( $self->{$KEY_FIELD_HTML} ) ) {
		$self->make_input_html();
	}
	if( defined( my $field_name = shift( @_ ) ) ) {
		return( $self->{$KEY_FIELD_HTML}->{$field_name} );
	} else {
		return( {%{$self->{$KEY_FIELD_HTML}}} );
	}
}

######################################################################

=head2 form_submit_url([ VALUE ])

This method is an accessor for the scalar "submit url" property of this object,
which it returns.  If VALUE is defined, this property is set to it.  This
property defines the URL of a processing script that the web browser would use to
process the generated form.  The default value is "localhost".

=cut

######################################################################

sub form_submit_url {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SUBMIT_URL} = $new_value;
	}
	return( $self->{$KEY_SUBMIT_URL} );
}

######################################################################

=head2 form_submit_method([ VALUE ])

This method is an accessor for the scalar "submit method" property of this
object, which it returns.  If VALUE is defined, this property is set to it.  This
property defines the method that the web browser would use to submit form data to
a processor script.  The default value is "post", and "get" is the other option.

=cut

######################################################################

sub form_submit_method {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SUBMIT_MET} = $new_value;
	}
	return( $self->{$KEY_SUBMIT_MET} );
}

######################################################################

=head2 normalize_field_definitions()

This method edits the "field definitions" such that any fields without names are
given one (called "nonamefieldNNN"), any unknown field types become textfields,
and any special fields we use internally are created.  It returns true when
finished.  This method is called by any input checking or html making routines if
"normalized" is false because it is a precondition for them to work properly.

=cut

######################################################################

sub normalize_field_definitions {
	my $self = shift( @_ );
	my $ra_field_defn = $self->{$KEY_FIELD_DEFN};
	
	my $nfn_field_count = 0;
	my $has_is_submit = 0;
	my $has_submit_button = 0;

	foreach my $field (@{$ra_field_defn}) {
		my $field_type = $field->fetch_value( $FKEY_TYPE );
		unless( $field_type ) {
			$field_type = $DEF_FF_TYPE;
			$field->store( $FKEY_TYPE, $field_type );
		}

		my $field_name = $field->fetch_value( $FKEY_NAME );
		if( !$field_name or $field_name =~ /^$DEF_FF_NAME_PFX/ ) {
			$field_name = $DEF_FF_NAME_PFX . 
				sprintf( "%3.3d", ++$nfn_field_count );
			$field->store( $FKEY_NAME, $field_name );
		}

		my $pattern = $field->fetch_value( $FKEY_VALIDATION_RULE );
		eval { /$pattern/ };
		if( $@ ) {
			die <<__endquote;
Fatal Error: The regular expression you provided as the 
"validation_rule" for the form field named "$field_name" doesn't 
compile, or there are other problems.  Details follow:
$@
__endquote
		}

		$field_name eq $FFN_IS_SUBMIT and $has_is_submit = 1;
		$field_type eq 'submit' and $has_submit_button = 1;
	}
	
	unless( $has_is_submit ) {	
		unshift( @{$ra_field_defn}, CGI::HashOfArrays->new( 1, {
			$FKEY_TYPE => 'hidden',
			$FKEY_NAME => $FFN_IS_SUBMIT,
			$FKEY_DEFAULT => 1,
		} ) );
	}
	
	unless( $has_submit_button ) {	
		push( @{$ra_field_defn}, CGI::HashOfArrays->new( 1, {
			$FKEY_TYPE => 'submit',
			$FKEY_NAME => $DEF_FF_NAME_PFX . 
				sprintf( "%3.3d", ++$nfn_field_count ),
		} ) );
	}
	
	return( $self->{$KEY_NORMALIZED} = 1 );
}

######################################################################

=head2 validate_form_input()

This method sets the "invalid input" property by applying the "is requrired" and
"validation rule" field attributes to the user input for those fields.  If "new
form" is true then all fields are declared to be error free.  It returns a count
of the number of erroneous fields, and 0 if there are no errors.  This method is
called by make_html_input_form() and invalid_input() if "invalid input" is false
because it is a precondition for them to work properly.

=cut

######################################################################

sub validate_form_input {
	my $self = shift( @_ );
	unless( $self->{$KEY_NORMALIZED} ) {
		$self->normalize_field_definitions();
	}

	if( $self->{$KEY_NEW_FORM} ) {
		$self->{$KEY_INVALID} = {};
		return( 0 );
	}

	my $user_input = $self->{$KEY_USER_INPUT};
	my %input_invalid = ();
	
	FIELD: foreach my $field (@{$self->{$KEY_FIELD_DEFN}}) {
		my $field_type = $field->fetch_value( $FKEY_TYPE );

		next unless( $field_type =~ 
			/^(textfield|textarea|password_field)(_group)?$/ );

		my $field_name = $field->fetch_value( $FKEY_NAME );
		my $is_required = $field->fetch_value( $FKEY_IS_REQUIRED );
		my $pattern = $field->fetch_value( $FKEY_VALIDATION_RULE );
		my $ra_field_input = $user_input->fetch( $field_name );

		if( $is_required ) {  # succeeds if one value has content
			$input_invalid{$field_name} = 1;
			foreach my $value (@{$ra_field_input}) {
				if( $value ne '' ) {
					delete( $input_invalid{$field_name} );
					last;
				}
			}
			$input_invalid{$field_name} and next FIELD;
		}

		if( $pattern ) {  # succeeds if all values match or are empty
			foreach my $value (@{$ra_field_input}) {
				if( $value ne '' and $value !~ /$pattern/ ) {
					$input_invalid{$field_name} = 1;
					last;
				}
			}
		}
	}
	
	$self->{$KEY_INVALID} = \%input_invalid;
	return( scalar( keys %input_invalid ) );
}

######################################################################

=head2 make_field_html()

This method goes through all the fields and has html made for them, then puts it
away for those that need it, namely make_html_input_form() and field_html().  It
returns a count of the number of fields generated, which includes all hidden
fields and buttons.

=cut

######################################################################

sub make_field_html {
	my $self = shift( @_ );
	unless( $self->{$KEY_NORMALIZED} ) {
		$self->normalize_field_definitions();
	}

	my $user_input = $self->{$KEY_USER_INPUT};
	my %input_field_html = ();

	foreach my $field (@{$self->{$KEY_FIELD_DEFN}}) {
		my $field_type = $field->fetch_value( $FKEY_TYPE );
		my $field_name = $field->fetch_value( $FKEY_NAME );

		my $field_html = '';

		SWITCH: {
			my $rh_params;
			if( $field_type eq 'popup_menu' or 
					$field_type eq 'scrolling_list' ) {
				$rh_params = { 
					$field->fetch_all( [ $FKEY_TYPE, 
						$FKEY_IS_REQUIRED, $FKEY_IS_PRIVATE, 
						$FKEY_VALIDATION_RULE, $FKEY_VISIBLE_TITLE, 
						$FKEY_HELP_MESSAGE, $FKEY_ERROR_MESSAGE, 
						$FKEY_EXCLUDE_IN_ECHO, $FKEY_KEEP_WITH_PREV ], 1 ),
					$FKEY_NAME => $field->fetch_value( $FKEY_NAME ),
					'size' => $field->fetch_value( 'size' ),
					'multiple' => $field->fetch_value( 'multiple' ),
				};
			} elsif( $INPUT_FIELDS{$field_type} ) {
				$rh_params = $field->fetch_first( [ $FKEY_TYPE, 
						$FKEY_IS_REQUIRED, $FKEY_IS_PRIVATE, 
						$FKEY_VALIDATION_RULE, $FKEY_VISIBLE_TITLE, 
						$FKEY_HELP_MESSAGE, $FKEY_ERROR_MESSAGE, 
						$FKEY_EXCLUDE_IN_ECHO, $FKEY_KEEP_WITH_PREV ], 1 );
			} else {
				$rh_params = $field->fetch_all( [ $FKEY_TYPE, 
						$FKEY_IS_REQUIRED, $FKEY_IS_PRIVATE, 
						$FKEY_VALIDATION_RULE, $FKEY_VISIBLE_TITLE, 
						$FKEY_HELP_MESSAGE, $FKEY_ERROR_MESSAGE, 
						$FKEY_EXCLUDE_IN_ECHO, $FKEY_KEEP_WITH_PREV ], 1 );
			}

			my $ra_field_input = $user_input->fetch( $field_name );

			if( $INPUT_FIELDS{$field_type} ) {
				$field_html = $self->make_input_tag( 
					$field_type, [$rh_params], $ra_field_input );
				last SWITCH;   # send all inputs; mit knows what to do
			}
			
			$field_type =~ m/(.*)_group$/;
			if( $1 and $INPUT_FIELD_GROUPS{$1} ) {
				$field_type = $1;
				$field_html = $self->make_input_tag_group( 
					$field_type, [$rh_params], $ra_field_input );
				last SWITCH;
			}
						
			$field_html = <<__endquote;
\n[Field type of "$field_type" is not supported by HTMLFormMaker]
__endquote
		}

		$input_field_html{$field_name} = $field_html;
	}

	$self->{$KEY_FIELD_HTML} = \%input_field_html;
	return( scalar( keys %input_field_html ) );
}

######################################################################

=head2 make_html_input_form([ TABLE[, FORCE] ])

This method returns a complete html input form, including all form field tags,
reflected user input values, various text headings and labels, and any visual
cues indicating special status for various fields.  The first optional boolean
argument, TABLE, says to return the form within an HTML table, with one field or
field group per row.  Field headings and help text appear on the left and the
field or group itself appears on the right.  All table cells are
top-left-aligned, and no widths or heights are specified.  If TABLE is false then
each field or group is returned in a paragraph that starts with its title.  The
second optional boolean argument, FORCE, causes the resulting form body to be
returned as an array ref whose elements are pieces of the page.  If this is false
then everything is returned in a single scalar.

=cut

######################################################################

sub make_html_input_form {
	my $self = shift( @_ );
	my $in_table_format = shift( @_ );
	my $force_list = shift( @_ );

	unless( defined( $self->{$KEY_INVALID} ) ) {
		$self->validate_form_input();
	}
	unless( defined( $self->{$KEY_FIELD_HTML} ) ) {
		$self->make_field_html();
	}

	my $rh_invalid = $self->{$KEY_INVALID};
	my $rh_field_html = $self->{$KEY_FIELD_HTML};
	my @input_form = ();
	
	push( @input_form, $self->start_form() );
	if( $in_table_format ) {
		push( @input_form, "\n<TABLE CELLSPACING=\"5\">" );
	}

	foreach my $field (@{$self->{$KEY_FIELD_DEFN}}) {
		my $field_type = $field->fetch_value( $FKEY_TYPE );
		my $field_name = $field->fetch_value( $FKEY_NAME );

		if( $field_type =~ /^(hidden|hidden_group)$/ ) {
			push( @input_form, $rh_field_html->{$field_name} );
			next;
		}
		
		my $flags_html = '';
		my $label_html = '';
		my $error_html = '';

		unless( $field_type =~ /^(submit|reset|hidden|hidden_group)/ ) {
			if( $rh_invalid->{$field_name} ) {
				$flags_html .= "\n$BAD_INPUT_MARKER";
			}
			if( $field->fetch_value( $FKEY_IS_REQUIRED ) ) {
				$flags_html .= "\n$REQ_FIELD_MARKER";
			}
			if( $field->fetch_value( $FKEY_IS_PRIVATE ) ) {
				$flags_html .= "\n$PRV_FIELD_MARKER";
			}
			
			$label_html .= "\n<STRONG>" .
				$field->fetch_value( $FKEY_VISIBLE_TITLE ) . ":</STRONG>";
			if( my $hm = $field->fetch_value( $FKEY_HELP_MESSAGE ) ) {
				if( $in_table_format ) {
					$label_html .= "<BR>";
				}
				$label_html .= "\n<SMALL>($hm)</SMALL>";
			}

			if( $rh_invalid->{$field_name} ) {
				$error_html .= "\n<SMALL><FONT COLOR=\"#ff0000\">" .
					$field->fetch_value( $FKEY_ERROR_MESSAGE ) . 
					"</FONT></SMALL>";
				if( $in_table_format ) {
					$error_html .= "<BR>";
				}
			}
		}
		
		if( $in_table_format ) {
			my $row_cells = $self->td_group( 
				valign => 'top', 
				align => 'left', 
				text => [ $flags_html, $label_html, 
					$error_html.$rh_field_html->{$field_name} ]
			);
			push( @input_form, "\n<TR>$row_cells</TR>" );
		} else {
			push( @input_form, <<__endquote );
<P>
$flags_html 
$label_html 
$error_html 
$rh_field_html->{$field_name}
</P>
__endquote
		}
	}

	if( $in_table_format ) {
		push( @input_form, "\n</TABLE>" );
	}
	push( @input_form, $self->end_form() );

	return( $force_list ? \@input_form : join( '', @input_form ) );
}

######################################################################

=head2 make_html_input_echo([ TABLE[, EXCLUDE[, EMPTY[, FORCE]]] ])

This method returns a complete html-formatted input "echo" report that includes
all the field titles and reflected user input values.  Any buttons or hidden
fields are excluded.  There is nothing that indicates whether the user input has
errors or not.  There is one heading per field group, and the values from each
member of the group are displayed together in a list.  The first optional boolean
argument, TABLE, says to return the report within an HTML table, with one field
or field group per row.  All table cells are top-left-aligned, and no widths or
heights are specified.  If TABLE is false then each field or group input is
returned in a paragraph that starts with its title.  The second optional boolean
argument, EXCLUDE, ensures that any fields that were defined to be "private" are
excluded from this report; by default they are included.  The third optional
string argument, EMPTY, specifies the string to use in place of the user's input
where the user left the field empty; by default nothing is shown.  The fourth
optional boolean argument, FORCE, causes the resulting form body to be returned
as an array ref whose elements are pieces of the page.  If this is false then
everything is returned in a single scalar.

=cut

######################################################################

sub make_html_input_echo {
	my $self = shift( @_ );
	my $in_table_format = shift( @_ );
	my $exclude_private = shift( @_ );
	my $empty_field_str = shift( @_ );
	my $force_list = shift( @_ );

	my $user_input = $self->{$KEY_USER_INPUT};
	my @input_echo = ();
	
	if( $in_table_format ) {
		push( @input_echo, "\n<TABLE CELLSPACING=\"5\">" );
	}

	foreach my $field (@{$self->{$KEY_FIELD_DEFN}}) {
		if( $field->fetch_value( $FKEY_TYPE ) =~ 
				/^(reset|submit|hidden|hidden_group)$/ ) {
			next;
		}
		if( $field->fetch_value( $FKEY_EXCLUDE_IN_ECHO ) ) {
			next;
		}
		if( $exclude_private and 
				$field->fetch_value( $FKEY_IS_PRIVATE ) ) {
			next;
		}
		
		my $field_title = "\n<STRONG>" .
			$field->fetch_value( $FKEY_VISIBLE_TITLE ) . ":</STRONG>";

		my $field_name = $field->fetch_value( $FKEY_NAME );
		my @field_values = map { $_ eq '' ? $empty_field_str : $_ } 
			$user_input->fetch( $field_name );
		my $user_input = 
			join( $in_table_format ? '<BR>' : ', ', @field_values );

		if( $in_table_format ) {
			my $row_cells = $self->td_group( 
				valign => 'top', 
				align => 'left', 
				text => [ $field_title, $user_input ]
			);
			push( @input_echo, "\n<TR>$row_cells</TR>" );
		} else {
			push( @input_echo, "<P>$field_title $user_input</P>" );
		}
	}

	if( $in_table_format ) {
		push( @input_echo, "\n</TABLE>" );
	}

	return( $force_list ? \@input_echo : join( '', @input_echo ) );
}

######################################################################

=head2 make_text_input_echo([ EXCLUDE[, EMPTY[, FORCE]] ])

This method returns a complete plain-text-formatted input "echo" report that
includes all the field titles and reflected user input values.  This report is
designed not for web display but for text reports or for inclusion in e-mail
messages.  Any buttons or hidden fields are excluded.  There is nothing that
indicates whether the user input has errors or not.  There is one heading per
field group, and the values from each member of the group are displayed together
in a list.  For each field, the title is displayed on one line, then followed by
a blank line, then followed by the user inputs.  The title is preceeded by the
text "Q: ", indicating it is the "question".  The first optional boolean
argument, EXCLUDE, ensures that any fields that were defined to be "private" are
excluded from this report; by default they are included.  The second optional
string argument, EMPTY, specifies the string to use in place of the user's input
where the user left the field empty; by default nothing is shown.  The third
optional boolean argument, FORCE, causes the resulting form body to be returned
as an array ref whose elements are pieces of the page.  If this is false then
everything is returned in a single scalar, and there is a delimiter placed
between each field or group that consists of a line of asterisks ("*").

=cut

######################################################################

sub make_text_input_echo {
	my $self = shift( @_ );
	my $exclude_private = shift( @_ );
	my $empty_field_str = shift( @_ );
	my $force_list = shift( @_ );

	my $user_input = $self->{$KEY_USER_INPUT};
	my @input_echo = ();
	
	foreach my $field (@{$self->{$KEY_FIELD_DEFN}}) {
		if( $field->fetch_value( $FKEY_TYPE ) =~ 
				/^(reset|submit|hidden|hidden_group)$/ ) {
			next;
		}
		if( $field->fetch_value( $FKEY_EXCLUDE_IN_ECHO ) ) {
			next;
		}
		if( $exclude_private and 
				$field->fetch_value( $FKEY_IS_PRIVATE ) ) {
			next;
		}

		my $field_name = $field->fetch_value( $FKEY_NAME );
		my @field_values = map { $_ eq '' ? $empty_field_str : $_ } 
			$user_input->fetch( $field_name );

		push( @input_echo, 
			"\nQ: ".$field->fetch_value( $FKEY_VISIBLE_TITLE )."\n".
			"\n".join( "\n", @field_values )."\n" );
	}

	return( $force_list ? \@input_echo : join( 
		"\n******************************\n", @input_echo ) );
}

######################################################################

=head2 bad_input_marker()

This method returns the string that is used to visually indicate in which form
fields the user has entered invalid input.

=cut

######################################################################

sub bad_input_marker {
	return( $BAD_INPUT_MARKER );
}

######################################################################

=head2 required_field_marker()

This method returns the string that is used to visually indicate which form
fields are required, and must be filled in by users for the form to be processed.

=cut

######################################################################

sub required_field_marker {
	return( $REQ_FIELD_MARKER );
}

######################################################################

=head2 private_field_marker()

This method returns the string that is used to visually indicate which form
fields are private, meaning that their content won't be shown to the public.

=cut

######################################################################

sub private_field_marker {
	return( $PRV_FIELD_MARKER );
}

######################################################################

=head2 start_form([ METHOD[, ACTION] ])

This method returns the top of an HTML form.  It consists of the opening 'form'
tag.  This method can take its optional two arguments in either named or
positional format; in the first case, the names look the same as the positional
placeholders above, except they must be in lower case.  The two arguments, METHOD
and ACTION, are scalars which respectively define the method that the form are
submitted with and the URL it is submitted to.  If either argument is undefined,
then the appropriate scalar properties of this object are used instead, and their
defaults are "POST" for METHOD and "localhost" for ACTION.  See the
form_submit_url() and form_submit_method() methods to access these properties.

=cut

######################################################################

sub start_form {
	my $self = shift( @_ );
	my $rh_params = $self->params_to_hash( \@_, 
		$self->{$KEY_AUTO_POSIT}, ['method', 'action'] );
	$rh_params->{'method'} ||= $self->{$KEY_SUBMIT_MET};
	$rh_params->{'action'} ||= $self->{$KEY_SUBMIT_URL};
	return( $self->make_html_tag( 'form', $rh_params, undef, $TAG_START ) );
}

######################################################################

=head2 end_form()

This method returns the bottom of an HTML form.  It consists of the closing
'form' tag.

=cut

######################################################################

sub end_form {
	my $self = shift( @_ );
	return( $self->make_html_tag( 'form', {}, undef, $TAG_END ) );
}

######################################################################

=head2 make_input_tag( TYPE, PARAMS[, USER] )

This method is used internally to do the actual construction of all standalone
input form fields.  You can call it directly when you want faster code and/or
more control over how fields are made.  The first argument, TYPE, is a scalar
that names the field type we are making; it is case-insensitive.  Valid types
are: [reset, submit, hidden, textfield, password_field, textarea, checkbox,
radio, popup_menu, scrolling_list]; an invalid TYPE results in a normal HTML tag
with its name being made.  The second argument, PARAMS, is an ARRAY ref
containing attribute names and values for the new form field; this is identical
to the argument list that is passed to methods of this class whose names are the
same as the form field types.  The third optional argument, USER, is an ARRAY ref
containing the values that users would have entered into this same field during
this form's previous invocation.  These USER values override the field values
provided by the "default" property for this field, if present.  If the "new form"
object property is true, or if this field's "override" property is true, then the
USER values are ignored.  This method returns a scalar containing the new form
field html.

=cut

######################################################################

sub make_input_tag {
	my $self = shift( @_ );
	my $input_name = lc(shift( @_ ));
	my $ra_params = shift( @_ );
	my $rh_params = $self->params_to_hash( $ra_params,
		$self->{$KEY_AUTO_POSIT}, @{$INPUT_MPP_ARGS{$input_name}} );
	my $ra_user_values = shift( @_ );
	unless( ref( $ra_user_values ) eq 'ARRAY' ) {
		$ra_user_values = [$ra_user_values];
	}

	$rh_params->{$FKEY_NAME} ||= $DEF_FF_NAME_PFX;

	if( $INPUT_TAG_IMPL_TYPE{$input_name} or $input_name eq 'textarea' ) {
		if( $INPUT_TAG_IMPL_TYPE{$input_name} ) {
			$rh_params->{$FKEY_TYPE} = $INPUT_TAG_IMPL_TYPE{$input_name};
		}

		if( $input_name eq 'checkbox' or $input_name eq 'radio' ) {
			$rh_params->{$FKEY_VALUE} ||= 'on';
			$rh_params->{$FKEY_TEXT} ||= $rh_params->{$FKEY_NAME};
			if( delete( $rh_params->{'nolabel'} ) ) {
				delete( $rh_params->{$FKEY_TEXT} );
			}
		}
		
		my $default = delete( $rh_params->{$FKEY_DEFAULT} );
		unless( delete( $rh_params->{$FKEY_OVERRIDE} ) or 
				$self->{$KEY_NEW_FORM} ) {
			$default = $ra_user_values->[0];
		}		

		$default =~ s/&/&amp;/g;
		$default =~ s/\"/&quot;/g;
		$default =~ s/>/&gt;/g;
		$default =~ s/</&lt;/g;

		if( $input_name eq 'textarea' ) {
			return( $self->make_html_tag( 'textarea', $rh_params, $default ) );
		}

		if( $input_name eq 'checkbox' or $input_name eq 'radio' ) {
			$rh_params->{'checked'} = $default;
		} else {
			$rh_params->{$FKEY_VALUE} = $default;
		}
		unless( $rh_params->{$FKEY_VALUE} ) {
			delete( $rh_params->{$FKEY_VALUE} );
		}
		my $text = delete( $rh_params->{$FKEY_TEXT} );
		return( $self->make_html_tag( 'input', $rh_params, $text ) );
	}
	
	if( $input_name eq 'popup_menu' or $input_name eq 'scrolling_list' ) {
		if( $input_name eq 'popup_menu' ) {
			$rh_params->{'size'} = 1;
			$rh_params->{'multiple'} = 0;
		}

		my $ra_values = delete( $rh_params->{$FKEY_VALUE} );
		ref( $ra_values ) eq 'ARRAY' or $ra_values = [$ra_values];

		$rh_params->{'size'} ||= scalar( @{$ra_values} );
	
		my $ra_text = delete( $rh_params->{$FKEY_TEXT} );
		if( ref( $ra_text ) eq 'HASH' ) {
			$ra_text = [map { $ra_text->{$_} } @{$ra_values}];
		} elsif( ref( $ra_text ) ne 'ARRAY' ) {
			$ra_text = [$ra_text];
		}
		foreach my $index (0..$#{$ra_values}) {
			unless( defined( $ra_text->[$index] ) ) {
				$ra_text->[$index] = $ra_values->[$index];
			}
		}

		my $rh_default = delete( $rh_params->{$FKEY_DEFAULT} );
		unless( delete( $rh_params->{$FKEY_OVERRIDE} ) or 
				$self->{$KEY_NEW_FORM} ) {
			$rh_default = $ra_user_values;
		}		

		if( ref( $rh_default ) eq 'ARRAY' ) {
			$rh_default = {map { ( $_ => 1 ) } @{$rh_default}};
		} elsif( ref( $rh_default ) ne 'HASH' ) {
			$rh_default = {$rh_default => 1};
		}
		my $ra_default = [map { $rh_default->{$_} } @{$ra_values}];

		foreach my $default (@{$ra_default}) {
			$default =~ s/&/&amp;/g;
			$default =~ s/\"/&quot;/g;
			$default =~ s/>/&gt;/g;
			$default =~ s/</&lt;/g;
		}

		my $ra_new_tags = $self->make_html_tag_group( 
			'option', { $FKEY_VALUE => $ra_values, 
			selected => $ra_default },	$ra_text, 1 );		
		unshift( @{$ra_new_tags}, $self->make_html_tag( 
			'select', $rh_params, undef, $TAG_START ) );	
		push( @{$ra_new_tags}, $self->make_html_tag( 
			'select', {}, undef, $TAG_END ) );
		
		return( join( '', @{$ra_new_tags} ) );
	}
	
	return( eval "\$self->SUPER::$input_name( \$ra_params )" );
}

######################################################################

=head2 make_input_tag_group( TYPE, PARAMS[, USER] )

This method is used internally to do the actual construction of all groups of
related input form fields.  You can call it directly when you want faster code
and/or more control over how fields are made.  The first argument, TYPE, is a
scalar that names the field type we are making; it is case-insensitive.  Valid
types are: [hidden, textfield, password_field, textarea, checkbox, radio]; an
invalid TYPE results in a normal HTML tag with its name being made.  The second
argument, PARAMS, is an ARRAY ref containing attribute names and values for the
new form fields; this is identical to the argument list that is passed to methods
of this class whose names are the same as the form field types.  The third
optional argument, USER, is an ARRAY ref containing the values that users would
have entered into this same field during this form's previous invocation.  Each
sequential element in that array will initialize one of the fields in this new
group.  These USER values override the field values provided by the "default"
property for this field, if present.  If the "new form" object property is true,
or if this field's "override" property is true, then the USER values are ignored.
 By default, this method returns a scalar containing the concatenated html for
all the fields in this group.  However, if this field's "list" property is true,
then an ARRAY ref is returned instead, with html for one field in each element. 
Otherwise, if the "linebreak" property is true, then a scalar is returned as by
default, except that a "<BR>" tag is inserted between the html for each field.

=cut

######################################################################

sub make_input_tag_group {
	my $self = shift( @_ );
	my $input_name = lc(shift( @_ ));
	my $ra_params = shift( @_ );
	my $rh_params = $self->params_to_hash( $ra_params,
		$self->{$KEY_AUTO_POSIT}, @{$INPUT_GROUP_MPP_ARGS{$input_name}} );
	my $ra_user_values = shift( @_ );
	unless( ref( $ra_user_values ) eq 'ARRAY' ) {
		$ra_user_values = [$ra_user_values];
	}

	$rh_params->{$FKEY_NAME} ||= $DEF_FF_NAME_PFX;

	if( $INPUT_TAG_IMPL_TYPE{$input_name} or $input_name eq 'textarea' ) {
		if( $INPUT_TAG_IMPL_TYPE{$input_name} ) {
			$rh_params->{$FKEY_TYPE} = $INPUT_TAG_IMPL_TYPE{$input_name};
		}

		my $ra_values = delete( $rh_params->{$FKEY_VALUE} );
		my $ra_text = delete( $rh_params->{$FKEY_TEXT} );
		my $ra_default = delete( $rh_params->{$FKEY_DEFAULT} );
		my $force_list = delete( $rh_params->{$FKEY_LIST} );
		my $is_linebreak = delete( $rh_params->{'linebreak'} );

		if( $input_name eq 'checkbox' or $input_name eq 'radio' ) {
			ref( $ra_values ) eq 'ARRAY' or $ra_values = [$ra_values];
			if( ref( $ra_text ) eq 'HASH' ) {
				$ra_text = [map { $ra_text->{$_} } @{$ra_values}];
			} elsif( ref( $ra_text ) ne 'ARRAY' ) {
				$ra_text = [$ra_text];
			}
			foreach my $index (0..$#{$ra_values}) {
				unless( defined( $ra_text->[$index] ) ) {
					$ra_text->[$index] = $ra_values->[$index];
				}
			}
			if( delete( $rh_params->{'nolabel'} ) ) {
				undef( $ra_text );
			}
		}
		
		unless( delete( $rh_params->{$FKEY_OVERRIDE} ) or 
				$self->{$KEY_NEW_FORM} ) {
			$ra_default = $ra_user_values;
		}

		if( $input_name eq 'checkbox' or $input_name eq 'radio' ) {
			my $rh_default = $ra_default;
			if( ref( $rh_default ) eq 'ARRAY' ) {
				$rh_default = {map { ( $_ => 1 ) } @{$rh_default}};
			} elsif( ref( $rh_default ) ne 'HASH' ) {
				$rh_default = {$rh_default => 1};
			}
			$ra_default = [map { $rh_default->{$_} } @{$ra_values}];
		} else {
			if( ref( $ra_default ) eq 'HASH' ) {
				$ra_default = [map { $ra_default->{$_} } @{$ra_values}];
			} elsif( ref( $ra_default ) ne 'ARRAY' ) {
				$ra_default = [$ra_default];
			}
		}

		foreach my $default (@{$ra_default}) {
			$default =~ s/&/&amp;/g;
			$default =~ s/\"/&quot;/g;
			$default =~ s/>/&gt;/g;
			$default =~ s/</&lt;/g;
		}

		my $ra_new_tags;

		if( $input_name eq 'textarea' ) {
			$ra_new_tags = $self->make_html_tag_group( 
				'textarea', $rh_params, $ra_default, 1 );
		}

		if( $input_name eq 'checkbox' or $input_name eq 'radio' ) {
			$rh_params->{$FKEY_VALUE} = $ra_values;
			$rh_params->{'checked'} = $ra_default;
		} else {
			$rh_params->{$FKEY_VALUE} = $ra_default;
		}
		$ra_new_tags = $self->make_html_tag_group( 
			'input', $rh_params, $ra_text, 1 );

		return( $force_list ? $ra_new_tags : $is_linebreak ? join( 
			'<BR>', @{$ra_new_tags} ) : join( '', @{$ra_new_tags} ) );
	}
		
	return( eval "\$self->SUPER::$input_name( \$ra_params )" );
}

######################################################################

=head2 valid_types([ TYPE ])

This method returns a list of all the form field types that this class can
recognize when they are used either in the 'type' attribute of a field
definition, or as the name of an html-field-generating method.  This list
contains the same types listed in the "Recognized Form Field Types" of this
documentation.  If the optional scalar argument, TYPE, is defined, then this
method will instead return true if TYPE is a valid field type or false if not.

=cut

######################################################################

sub valid_types {
	return( $_[0] ? $VALID_TYPES{$_[0]} : 
		wantarray ? (keys %VALID_TYPES) : [keys %VALID_TYPES] );
}

######################################################################

=head2 valid_multivalue_types([ TYPE ])

This method returns true if a form field of the type defined by the optional
scalar argument, TYPE, makes use of multiple values; either presenting them to
the user or accepting them for user input.  If called without any arguments, this
method returns a list of all field types that make use of multiple values.

=cut

######################################################################

sub valid_multivalue_types {
	return( $_[0] ? $VALID_MV_TYPES{$_[0]} : 
		wantarray ? (keys %VALID_MV_TYPES) : [keys %VALID_MV_TYPES] );
}

######################################################################

=head2 valid_attributes( TYPE[, ATTRIB] )

This method returns a list of all the form field definition attributes that this
class can recognize when they are used in defining a field whose type is defined
by the scalar argument, TYPE.  If the optional scalar argument, ATTRIB, is
defined, then this method will instead return true if ATTRIB is a valid field
definition attribute or false if not.  The "list" attribute is not included.

=cut

######################################################################

sub valid_attributes {
	my $ra_valid = $VALID_ATTRIBUTES{shift( @_ )} or return( 0 );
	if( my $attr_name = shift( @_ ) ) {
		my %valid = map { ( $_ => 1 ) } @{$ra_valid};
		return( $valid{$attr_name} );
	} else {
		return( wantarray ? @{$ra_valid} : [@{$ra_valid}] );
	}
}

######################################################################

=head2 make_attribute_definition( ATTRIB, NAME[, COUNT] )

This method returns a form field definition that can be used with this class to
make an HTML form field whose user input is a the value (or value list) to give
the attribute whose name is defined by the first scalar argument, ATTRIB, in a
field definition for any type that uses that attribute.  The second scalar
argument, NAME, is used in the definition that this method creates as its 'name'
attribute.  The optional third scalar argument, COUNT, is only useful when the
field being ultimately defined is making use of multiple values.  The "list"
attribute is not included.

=cut

######################################################################

sub make_attribute_definition {
	my $attr_name = shift( @_ );
	my $rh_defin = $ATTRIB_DEFINS{$attr_name} || {
		$FKEY_VISIBLE_TITLE => $attr_name,
		$FKEY_TYPE => 'textfield',
		size => 20,
	};
	$rh_defin->{$FKEY_NAME} = shift( @_ );
	if( $VALID_MV_TYPES{$attr_name} ) {
		my $count = shift( @_ ) + 0;
		$rh_defin->{$FKEY_VALUE} = [map { '' } (1..$count)];
	}
	return( CGI::HashOfArrays->new( 1, $rh_defin ) );
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

See the related HTML::TagMaker documentation on start_html() and
other autoloaded HTML tag making methods, all of which this module inherits.

=item 0

We save in module complexity by not talking to any global variables or
files or users directly, expecting rather that the calling code will do this. 
Methods that generate HTML will return their results so the caller can print them
on their own terms, allowing greater control.  The calling code must obtain and
provide the user's submitted input from previous form incarnations, usually with
the user_input() accessor method.  If that method is used prior to generating
html, then the html methods will behave like those in CGI.pm do when instantiated
with a query string, or automatically, or when the "params" were otherwise
manipulated.  The caller must provide the url that the form submits to, usually
with the form_submit_url() accessor method, or the default for this value is 
"localhost".  That method must be used prior to methods that generate entire
forms, in order for them to work as desired.  By contrast, CGI.pm uses the
current script's url as the default.  Of course, if you build forms
piece-by-piece and call start_form() yourself, you can give it the "action"
argument, which overrides the corresponding property.

=item 0

start_form() doesn't provide a default value for the "encoding" argument,
so if the calling code doesn't provide one then it isn't used.  By contrast,
CGI.pm provides a default encoding of "application/x-www-form-urlencoded".

=item 0

We generally provide a B<lot> more aliases for named arguments to the form
field making methods, and these are detailed in the FORM FIELD PARAMETERS part of
this documentation.  This is partly to maintain backwards compatability with the
aliases that CGI.pm uses, and partly to provide a more consistant argument names
between the various methods, something that CGI.pm doesn't always do.  For
example, "value" is an alias for "default" in every method where they don't mean
different things.  Another example is that all arguments which have plural names
also take their singular versions as aliases.  Another reasoning for this
aliasing is to provide a consistant interface for those who are used to giving
all the literal HTML names for various arguments, which is exactly what
HTML::TagMaker uses.  In the cases where our field argument isn't a true
HTML argument, and rather is the text that goes outside the tag (such as textarea
values or checkbox labels), we accept "text" as aliases, which is the exact
convention that HTML::TagMaker uses when you want to specify such text
when using named parameters; this makes literalists happy.

=item 0

The arguments "default" and "labels" in our field making methods can be
either an ARRAY ref or a HASH ref (or a scalar) and we can handle them
appropriately; this choice translates to greater ease of use.  By contrast,
CGI.pm only takes Hashes for labels.

=item 0

Our checkbox_group and radio_group methods do not recognize the special
parameters that CGI.pm uses to organize new fields into tables.  These include
[rows, columns, rowheaders, colheaders].  We do, however, provide the new "list"
argument, meaning that field groups are returned in a list, and the caller can
always organize the field html into tables on its own.

=item 0

We don't give special treatment to any of the special JavaScript related
parameters to field making methods that CGI.pm does, and so we use them as
ordinary and miscellaneous html attributes.

=item 0

We save on complexity and don't have a special field type called "defaults"
like CGI.pm does.  Rather, calling code can just ask for a "submit" button with
an appropriate name, and then call our reset_to_new_form() method if they
discover it was clicked on during a previous form invocation.  This method has
the same effect, wiping out anything the user entered, but the caller has more
control over when the wipeout occurs.  For that matter, simply not setting the
user_input() property would have the same effect.

=item 0

We don't currently make "File Upload" fields or a "Clickable Image" buttons
or "Javascript Action" buttons that CGI.pm does, although we make all the other
field types.  We can still generate the HTML for these, however, if the
appropriate autoloaded HTML tag making methods are called.  We do make standalone
radio buttons, which CGI.pm does not (as a special case like checkbox anyway),
and we do make groups of hidden fields, text fields, big text fields, and
password fields as well.

=item 0

We can both predefine all fields before generating them, which CGI.pm does
not, and we can also define fields as-needed in the same manner that CGI.pm does.

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

Thanks to B<Lincoln D. Stein> for publishing the popular CGI.pm module, which I
found very useful in my programs.  Moreover, I have decided to emulate much of
its functionality in some of my own modules, so I should give credit where its
due for implementing that functionality first.  Lincoln should be pleased that I
am following his advice (look under heading "BUGS" in CGI) and discarding his
large and monolithic module in favor of simpler ones.

Also, since I currently lack the time to make full documentation for the
like-named methods that make form fields (such as "textfield"), I thank Lincoln
that I can just refer to the CGI.pm documentation in those regards, as my methods
are backwards compatible.  In similar fashion, my "synopsis" program is based on
the one for CGI.pm insofar as it generates the same HTML code, albeit in a
different fashion.

=head1 SEE ALSO

perl(1), CGI, Class::ParamParser, HTML::TagMaker, CGI::HashOfArrays.

=cut
