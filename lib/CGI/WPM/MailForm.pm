=head1 NAME

CGI::WPM::MailForm - Perl module that is a subclass of CGI::WPM::Base and
implements a private e-mail form.

=cut

######################################################################

package CGI::WPM::MailForm;
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

=cut

######################################################################

use CGI::WPM::Base;
@ISA = qw(CGI::WPM::Base);
use HTML::FormMaker;

######################################################################
# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_PAGE_CONTENT = 'page_content';  # hold return values
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any

# Keys for items in site global preferences:
my $GKEY_SITE_TITLE = 'site_title';  # name of this website
my $GKEY_OWNER_NAME = 'owner_name';  # name of site's owner
my $GKEY_OWNER_EMAIL = 'owner_email';  # email addy of site's owner
my $GKEY_RETURN_EMAIL = 'return_email';  # visitors get this inst real addy
my $GKEY_SMTP_HOST = 'smtp_host';  # who we use to send mail

# Keys for items in site page preferences:

# Names of the fields in our html form:
my $FFN_NAMEREAL = 'namereal';  # user's real name
my $FFN_EMAILPRV = 'emailprv';  # user's e-mail for private use
my $FFN_WANTCOPY = 'wantcopy';  # true if sender wants a copy
my $FFN_MESSAGE  = 'message';   # user's message body

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};

	SWITCH: {
		my $form = HTML::FormMaker->new();
		$form->form_submit_url( $globals->base_url() );
		$form->field_definitions( $self->get_field_definitions() );

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
		
		$self->mail_me_ok( $form );
		
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
			label => 'Send',
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
	return( [
		CGI::HashOfArrays->new( 1, {
			visible_title => "Your Message",
			type => 'textarea',
			name => $FFN_MESSAGE,
			rows => 5,
			columns => 50,
			is_required => 1,
			error_message => 'You must enter a message.',
		} ),
	] );
}

######################################################################

sub new_message {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};

	$webpage->title( "Send Me An E-mail" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>This form is provided as an easy way for you to send me a private 
e-mail message, when you wish to contact me and/or give me your 
thoughts on this site.  This is also a good forum to report any bugs 
you have discovered, so I can fix them as soon as possible.  The 
fields indicated with a '@{[$form->required_field_marker()]}' are 
required.</P>

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

<P>Your message could not be sent because some of the fields were not
correctly filled in, which are indicated with a 
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
		$globals->site_pref( $GKEY_SITE_TITLE ).' -- Private Mail Me',
		$self->make_mail_message_body( $form, 0 )
	);

	if( $err_msg ) {
		$self->{$KEY_IS_ERROR} = $err_msg;
	
		$webpage->title( "Error Sending Mail" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to e-mail your 
message to me.  As a result I will not see it.</P>

<P>This problem can occur if you enter a nonexistant or unreachable 
e-mail address into the e-mail field, in which case, please enter a 
working e-mail address and try clicking 'Send' again.  You can check 
if that is the problem by checking the following error string:</P>

<P>$err_msg</P>

<P>If your address is valid, then the problem is likely at this end.  
This should be temporary, the result of a server glitch
or a site update being performed at the moment.  Click 
<A HREF="@{[$globals->self_url()]}">here</A> to automatically try again.  
If the problem persists, you are welcome to try again later.</P>

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

sub mail_me_ok {
	my ($self, $form) = @_;
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};

	$webpage->title( "Your Message Has Been Sent" );

	$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>This is what the message said:</P>

<P><STRONG>To:</STRONG> 
@{[$globals->site_pref( $GKEY_OWNER_NAME )]}
<BR><STRONG>From:</STRONG> 
@{[$globals->param( $FFN_NAMEREAL )]} 
&lt;@{[$globals->param( $FFN_EMAILPRV )]}>
<BR><STRONG>Subject:</STRONG> 
@{[$globals->site_pref( $GKEY_SITE_TITLE )]}
-- Private Mail Me</P>

@{[$form->make_html_input_echo( 1 )]}
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
		$globals->site_pref( $GKEY_SITE_TITLE ).' -- Private Mail Me',
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

@{[$form->make_text_input_echo()]}

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

@{[$form->make_text_input_echo()]}

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

@{[$form->make_text_input_echo()]}

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
