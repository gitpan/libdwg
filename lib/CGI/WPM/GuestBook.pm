=head1 NAME

CGI::WPM::GuestBook - Perl module that is a subclass of CGI::WPM::Base and
implements a complete guest book.

=cut

######################################################################

package CGI::WPM::GuestBook;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.1b';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::WPM::Base
	CGI::WPM::Content
	CGI::WPM::Globals
	HTML::FormMaker
	CGI::HashOfArrays
	CGI::SequentialFile

=cut

######################################################################

use CGI::WPM::Base;
@ISA = qw(CGI::WPM::Base);
use HTML::FormMaker;
use CGI::SequentialFile;

######################################################################
# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_PAGE_CONTENT = 'page_content';  # hold return values
my $KEY_PAGE_PREFS   = 'page_prefs';    # hold our own settings
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any

# Keys for items in site global preferences:
my $GKEY_SITE_TITLE = 'site_title';  # name of this website
my $GKEY_OWNER_NAME = 'owner_name';  # name of site's owner
my $GKEY_OWNER_EMAIL = 'owner_email';  # email addy of site's owner
my $GKEY_RETURN_EMAIL = 'return_email';  # visitors get this inst real addy
my $GKEY_SMTP_HOST = 'smtp_host';  # who we use to send mail

# Keys for items in site page preferences:
my $PKEY_FN_FIELD_DEF = 'fn_field_def';
my $PKEY_FN_MESSAGES  = 'fn_messages';

# Names of the fields in our html form:
my $FFN_NAMEREAL = 'namereal';  # user's real name
my $FFN_EMAILPRV = 'emailprv';  # user's e-mail for private use
my $FFN_WANTCOPY = 'wantcopy';  # true if sender wants a copy
my $FFN_MESSAGE  = 'message';   # user's message body

# Constant values used in this class go here:
my $VRP_SIGN = 'sign';  # in this sub path is the book signing page
	# if no sub path is chosen, we view guest book by default
my $EMPTY_FIELD_ECHO_STRING = '(no answer)';

# Extra fields in guest book log file
my $LFN_SUBMIT_DATE   = 'submit_date';
my $LFN_SUBMIT_DOMAIN = 'submit_domain';

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};

	SWITCH: {
		my $ra_field_defs = $self->get_field_definitions();
		if( $self->{$KEY_IS_ERROR} ) {
			$self->no_questions_error();
			last SWITCH;
		}

		my $form = HTML::FormMaker->new();
		$form->form_submit_url( $globals->base_url() );
		$form->field_definitions( $ra_field_defs );
		$form->empty_field_echo_string( $EMPTY_FIELD_ECHO_STRING );

		unless( $globals->current_vrp_element() eq $VRP_SIGN ) {
			$self->read_guest_book( $form );
			last SWITCH;
		}

		$form->user_input( $globals->query_params() );

		if( $form->new_form() ) {  # if we're called first time
			$self->new_message( $form );
			last SWITCH;
		}

		if( $form->validate_form_input() ) {  # if there were errors
			$self->invalid_input( $form );
			last SWITCH;
		}
		
		$self->send_mail_to_me( $form ) or last SWITCH;
		
		$self->sign_guest_book( $form ) or last SWITCH;

		$self->mail_me_and_sign_guest_ok( $form );
		
		if( $globals->param( $FFN_WANTCOPY ) eq 'on' ) {
			$self->send_mail_to_writer( $form );
		}
	}
}

######################################################################

sub get_field_definitions {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my @field_definitions = ();

	push( @field_definitions, CGI::HashOfArrays->new( 1, {
		type => 'hidden',
		name => $globals->vrp_param_name(),
		value => $globals->vrp_as_string(),
	} ) );
	
	my $rh_persistant_query = $globals->query_params()->fetch_all(
		[keys %{$globals->persistant_query_params()}] );
	foreach my $key (keys %{$rh_persistant_query}) {
		push( @field_definitions, CGI::HashOfArrays->new( 1, {
			type => 'hidden_group',
			name => $key,
			values => $rh_persistant_query->{$key},
		} ) );
	}
	
	push( @field_definitions, 
		CGI::HashOfArrays->new( 1, {
			visible_title => "Your Name",
			type => 'textfield',
			name => $FFN_NAMEREAL,
			size => 30,
			is_required => 1,
			error_message => 'You must enter your name.',
			exclude_in_echo => 1,
		} ), CGI::HashOfArrays->new( 1, {
			visible_title => "Your E-mail",
			type => 'textfield',
			name => $FFN_EMAILPRV,
			size => 30,
			is_required => 1,
			validation_rule => '\S\@\S',
			help_message => 'E-mails are in the form "user@domain".',
			error_message => 'You must enter your e-mail.',
			exclude_in_echo => 1,
		} ), CGI::HashOfArrays->new( 1, {
			visible_title => "Keep A Copy",
			type => 'checkbox',
			name => $FFN_WANTCOPY,
			nolabel => 1,
			help_message => "If checked, a copy of this message is e-mailed to
you.",
			exclude_in_echo => 1,
		} ), 
	);

	push( @field_definitions, @{$self->get_question_field_defs()} );

	push( @field_definitions, 
		CGI::HashOfArrays->new( 1, {
			type => 'submit', 
			label => 'Post',
		} ), CGI::HashOfArrays->new( 1, {
			type => 'reset', 
			label => 'Clear',
			keep_with_prev => 1,
		} ),
	);

	return( \@field_definitions );
}

######################################################################

sub get_question_field_defs {
	my $self = shift( @_ );
	my $filename = $self->{$KEY_PAGE_PREFS}->{$PKEY_FN_FIELD_DEF};
	my $filepath = $self->_prepend_path( $filename );
	my $field_defin_file = CGI::SequentialFile->new( $filepath );
	my $ra_field_list = $field_defin_file->fetch_all_records( 1 );
	ref( $ra_field_list ) eq 'ARRAY' or $ra_field_list = [];
	$self->{$KEY_IS_ERROR} = $field_defin_file->is_error();
	return( $ra_field_list );
}

######################################################################

sub no_questions_error {
	my $self = shift( @_ );
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	$webpage->title( "Error Starting GuestBook" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to start 
the Guest Book.  We are missing critical settings information 
that is required to operate.  Specifically, we don't know what 
questions we are supposed to ask you.  Here are some details about 
what caused this problem:</P>

<P>$self->{$KEY_IS_ERROR}</P>

@{[$self->_get_amendment_message()]}
__endquote
}

######################################################################

sub read_guest_book {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	my $filename = $self->{$KEY_PAGE_PREFS}->{$PKEY_FN_MESSAGES};
	my $filepath = $self->_prepend_path( $filename );
	my $message_file = CGI::SequentialFile->new( $filepath, 1 );
	my @message_list = $message_file->fetch_all_records( 1 );

	if( my $err_msg = $message_file->is_error() ) {
		$self->{$KEY_IS_ERROR} = $err_msg;
	
		$webpage->title( "Error Reading GuestBook Postings" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to read the 
existing guest book messages from the log file, meaning that I can't 
show you any.</P>

<P>details: $err_msg</P>

@{[$self->_get_amendment_message()]}
__endquote

		return( 0 );
	}

	unless( @message_list ) {
		$webpage->title( "Empty Guest Book" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>The guest book currently has no messages in it, as either none 
were successfully posted or they were deleted since then.  You can 
still sign it yourself, however.</P>
__endquote

		return( 1 );
	}

	my @message_html = ();
	
	foreach my $message (reverse @message_list) {
		$form->user_input( $message );
		my $name_real = $message->fetch_value( $FFN_NAMEREAL );
		my $submit_date = $message->fetch_value( $LFN_SUBMIT_DATE );
		push( @message_html, "<H3>From $name_real at $submit_date:</H3>" );
		push( @message_html, 
			$form->make_html_input_echo( 1, 1, '(no answer)' ) );
		push( @message_html, "\n<HR>" );
	}
	pop( @message_html );  # get rid of trailing <HR>
	
	$webpage->body_content( \@message_html );		
	
	$webpage->title( "Guest Book Messages" );

	$webpage->body_prepend( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>Messages are ordered from newest to oldest.  You may also sign 
this guest book yourself, if you wish.</P>
__endquote

	$webpage->body_append( <<__endquote );
<P>You may also sign this guest book yourself, if you wish.</P>
__endquote

	return( 1 );
}

######################################################################

sub new_message {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};

	$webpage->title( "Sign the Guest Book" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>This form is provided as an easy way for you to give feedback 
concerning this web site, and at the same time, let everyone else 
know what you think.  The fields indicated with a 
'@{[$form->required_field_marker()]}' are required.</P>

@{$form->make_html_input_form( 1, 1 )}

<P>It may take from 1 to 30 seconds to process this form, so please be 
patient and don't click Send multiple times.  A confirmation message 
will appear if everything worked.</P>
__endquote
}

######################################################################

sub invalid_input {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};

	$webpage->title( "Information Missing" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>Your submission could not be added to the guest book because some 
of the fields were not correctly filled in, which are indicated with a 
'@{[$form->bad_input_marker()]}'.  Fields with a 
'@{[$form->required_field_marker()]}' are required and can not be left 
empty.  Please make sure you have entered your name and e-mail address 
correctly, and then try sending it again.</P>

@{$form->make_html_input_form( 1, 1 )}

<P>It may take from 1 to 30 seconds to process this form, so please be 
patient and don't click Send multiple times.  A confirmation message 
will appear if everything worked.</P>
__endquote
}

######################################################################

sub send_mail_to_me {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	my $err_msg = $globals->send_email_message(
		$globals->site_pref( $GKEY_SMTP_HOST ),
		$globals->site_pref( $GKEY_OWNER_NAME ),
		$globals->site_pref( $GKEY_OWNER_EMAIL ),
		$globals->param( $FFN_NAMEREAL ),
		$globals->param( $FFN_EMAILPRV ),
		$globals->site_pref( $GKEY_SITE_TITLE ).' -- GuestBook Message',
		$self->make_mail_message_body( $form, 0 )
	);

	if( $err_msg ) {
		$self->{$KEY_IS_ERROR} = $err_msg;
	
		$webpage->title( "Error Sending Mail" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to e-mail your 
message to me.  It also hasn't been added to the guest book.  As a 
result, no one will see it.</P>

<P>This problem can occur if you enter a nonexistant or unreachable 
e-mail address into the e-mail field, in which case, please enter a 
working e-mail address and try clicking 'Send' again.  You can check 
if that is the problem by checking the following error string:</P>

<P>$err_msg</P>

@{[$self->_get_amendment_message()]}

@{$form->make_html_input_form( 1, 1 )}

<P>It may take from 1 to 30 seconds to process this form, so please be 
patient and don't click Send multiple times.  A confirmation message 
will appear if everything worked.</P>
__endquote

		return( 0 );
	}
	
	return( 1 );
}

######################################################################

sub sign_guest_book {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	my $new_posting = $globals->query_params()->clone();
	$new_posting->store( $LFN_SUBMIT_DATE, $globals->today_date_utc() );
	$new_posting->store( $LFN_SUBMIT_DOMAIN, 
		$globals->remote_addr().':'.$globals->remote_host() );

	my $filename = $self->{$KEY_PAGE_PREFS}->{$PKEY_FN_MESSAGES};
	my $filepath = $self->_prepend_path( $filename );
	my $message_file = CGI::SequentialFile->new( $filepath, 1 );
	$message_file->append_new_records( $new_posting );

	if( my $err_msg = $message_file->is_error() ) {
		$self->{$KEY_IS_ERROR} = $err_msg;
	
		$webpage->title( "Error Writing to Guest Book" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to write your 
message into the guest book.  As a result it will not appear when
the guest book is viewed by others.  However, the message was
e-mailed to me.</P>

<P>details: $err_msg</P>

@{[$self->_get_amendment_message()]}

@{$form->make_html_input_form( 1, 1 )}

<P>It may take from 1 to 30 seconds to process this form, so please be 
patient and don't click Send multiple times.  A confirmation message 
will appear if everything worked.</P>
__endquote

		return( 0 );
	}
	
	return( 1 );
}

######################################################################

sub mail_me_and_sign_guest_ok {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	$webpage->title( "Your Message Has Been Added" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>Your message has been added to this guest book, and a copy was 
e-mailed to me as well.  This is what the copy e-mailed to me said:</P>

<P><STRONG>To:</STRONG> 
@{[$globals->site_pref( $GKEY_OWNER_NAME )]}
<BR><STRONG>From:</STRONG> 
@{[$globals->param( $FFN_NAMEREAL )]} 
&lt;@{[$globals->param( $FFN_EMAILPRV )]}>
<BR><STRONG>Subject:</STRONG> 
@{[$globals->site_pref( $GKEY_SITE_TITLE )]}
-- Private Mail Me</P>

@{[$form->make_html_input_echo( 1, 0, '(no answer)' )]}

<P>The guest book is not storing your e-mail address.</P>
__endquote
}

######################################################################

sub send_mail_to_writer {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	my $err_msg = $globals->send_email_message(
		$globals->site_pref( $GKEY_SMTP_HOST ),
		$globals->param( $FFN_NAMEREAL ),
		$globals->param( $FFN_EMAILPRV ),
		$globals->site_pref( $GKEY_OWNER_NAME ),
		$globals->site_pref( $GKEY_RETURN_EMAIL ),
		$globals->site_pref( $GKEY_SITE_TITLE ).' -- GuestBook Message',
		$self->make_mail_message_body( $form, 1 )
	);

	if( $err_msg ) {
		$self->{$KEY_IS_ERROR} = $err_msg;
		$webpage->body_append( <<__endquote );
<P>However, something went wrong when trying to send you a copy:
$err_msg.</P>
__endquote

	} else {
		$webpage->body_append( <<__endquote );
<P>Also, a copy was successfully sent to you at 
'@{[$globals->param( $FFN_EMAILPRV )]}'.</P>
__endquote
	}
}

######################################################################

sub make_mail_message_body {
	my ($self, $form, $is_visitor_copy) = @_;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $message_body;
	
	if( $is_visitor_copy ) {
		$message_body = <<__endquote;
--------------------------------------------------
This is a copy of an e-mail message that was sent to me 
at @{[$globals->today_date_utc()]} UTC by 
@{[$globals->param( $FFN_NAMEREAL )]} (@{[$globals->param( $FFN_EMAILPRV )]})
using a form on my web page, located at 
"@{[$globals->base_url()]}".  
From: @{[$globals->remote_addr()]} @{[$globals->remote_host()]}
--------------------------------------------------

@{[$form->make_text_input_echo( 0, '(no answer)' )]}

--------------------------------------------------
END OF MESSAGE
__endquote

	} elsif( $globals->param( $FFN_WANTCOPY ) ) {
		$message_body = <<__endquote;
--------------------------------------------------
This message was sent at @{[$globals->today_date_utc()]} UTC by
@{[$globals->param( $FFN_NAMEREAL )]} (@{[$globals->param( $FFN_EMAILPRV )]})
using a form on my web page, located at 
"@{[$globals->base_url()]}".  
From: @{[$globals->remote_addr()]} @{[$globals->remote_host()]}
The visitor also requested a copy be sent to them.
--------------------------------------------------

@{[$form->make_text_input_echo( 0, '(no answer)' )]}

--------------------------------------------------
END OF MESSAGE
__endquote

	} else {
		$message_body = <<__endquote;
--------------------------------------------------
This message was sent at @{[$globals->today_date_utc()]} UTC by
@{[$globals->param( $FFN_NAMEREAL )]} (@{[$globals->param( $FFN_EMAILPRV )]})
using a form on my web page, located at 
"@{[$globals->base_url()]}".  
From: @{[$globals->remote_addr()]} @{[$globals->remote_host()]}
The visitor did not request a copy be sent to them.
--------------------------------------------------

@{[$form->make_text_input_echo( 0, '(no answer)' )]}

--------------------------------------------------
END OF MESSAGE
__endquote
	}
	
	return( $message_body );
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
module to use in any of your own code then please send me the URL.  Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1).

=cut
