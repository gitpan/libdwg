=head1 NAME

CGI::WPM::Main - Perl module that implements a simple "main program" which will
agnostically run any subclass of CGI::WPM::Base, print out its return value,
initialize program globals, track site usage details, and e-mail backups of usage
counts to the site owner.

=cut

######################################################################

package CGI::WPM::Main;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
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
	CGI::EventCountFile

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any

# Keys for items in site global preferences:
my $GKEY_SITE_TITLE = 'site_title';  # name of this website
my $GKEY_OWNER_NAME = 'owner_name';  # name of site's owner
my $GKEY_OWNER_EMAIL = 'owner_email';  # email addy of site's owner
my $GKEY_RETURN_EMAIL = 'return_email';  # visitors get this inst real addy
my $GKEY_SMTP_HOST = 'smtp_host';  # who we use to send mail
my $GKEY_WPM_MODULE = 'wpm_module';  # wpm module making content
my $GKEY_WPM_SUBDIR = 'wpm_subdir';  # subdir holding wpm support files
my $GKEY_WPM_PREFS = 'wpm_prefs';  # prefs hash/fn we give to wpm mod
my $GKEY_LOG_USAGE = 'log_usage';  # true if we should log usage
my $GKEY_USG_SUBDIR = 'usg_subdir';  # subdir holding usg support files
my $GKEY_USG_DG_SUB = 'usg_dg_sub';  # subdir for usg logs when debugging
my $GKEY_USG_PREFS = 'usg_prefs';  # prefs hash/fn we give to usg mod
my $GKEY_VRP_PARAM = 'vrp_param';  # query param our vir res path is in
my $GKEY_VRP_DELIM = 'vrp_delim';  # delimiter between vrp elements
my $GKEY_EURL_PARAM = 'eurl_param';  # when going external, says where
my $GKEY_T_SELF_URL = 't_self_url';  # replace with url for calling myself
my $GKEY_T_BASE_URL = 't_base_url';  # replace with url having no params
my $GKEY_T_PERS_URL = 't_pers_url';  # rep url has params that persist
my $GKEY_T_VRP_ID = 't_vrp_id';  # sort of like "__persist__&path="
my $GKEY_T_MAILME = 't_mailme';  # token to replace with mailme url
my $GKEY_T_EXT_ID = 't_ext_id';  # replace with url for a redirection
my $GKEY_P_MAILME = 'p_mailme';  # vrp of our mailme page
my $GKEY_P_EXTERNAL = 'p_external';  # if vrp is this, we redirect
my $GKEY_FIND_REPL = 'find_repl';  # misc find and replace of tokens
my $GKEY_AMEND_MSG = 'amend_msg';  # personalized html appears on error page
my $GKEY_DEBUG_PARAM = 'debug_param';  # param is used when we debug?
my $GKEY_DEBUG_VALUE = 'debug_value';  # param must have this value

# Keys for items in $GKEY_USG_PREFS global preference:
my $UKEY_FN_DCM = 'fn_dcm';  # filename for "date counts mailed" record
my $UKEY_FN_ENV     = 'fn_env';      # misc env variables go in here
my $UKEY_FN_VRP = 'fn_vrp';  # virtual resource paths go in here
my $UKEY_FN_EXT_URL = 'fn_ext_url';  # urls we redirect to go in here
my $UKEY_FN_REFERER = 'fn_referer';  # urls that refer to us go in here
my $UKEY_FN_REF_VRP = 'fn_ref_vrp';  # with self references, vrp of referer
my $UKEY_FN_BROWSER = 'fn_browser';  # web browsers visitors use go in here
my $UKEY_FN_DOMAINS = 'fn_domains';  # domain of visitors isp goes in here
my $UKEY_ENV_VARS   = 'env_vars';    # name misc env variables to watch
my $UKEY_T_TOTAL = 't_total';  # token counts number of file updates
my $UKEY_T_NIL = 't_nil';  # token counts number of '' values
my $UKEY_T_SELF_REF = 't_self_ref';  # put in referer file when self ref
# my $UKEY_EMAIL_FN = 'email_fn';

# Constant values used in this class go here:

######################################################################
# This should be the only thing that calling code uses.

sub main {
	my $class = shift( @_ );
	my $self = {};
	bless( $self, ref($class) || $class );
	
	eval { require CGI::WPM::Content; };
	if( $@ ) { 
		$self->print_fatal_program_error_page( <<__endquote );
<P>The "CGI::WPM::Main" module requires the 
"CGI::WPM::Content" module to operate, and that module did 
not compile successfully.</P>
<P>$@</P>
__endquote
		return( 0 );
	}
	eval { require CGI::WPM::Globals; };
	if( $@ ) { 
		$self->print_fatal_program_error_page( <<__endquote );
<P>The "CGI::WPM::Main" module requires the 
"CGI::WPM::Globals" module to operate, and that module did 
not compile successfully.</P>
<P>$@</P>
__endquote
		return( 0 );
	}
	
	my $globals;
	eval { $globals = CGI::WPM::Globals->new( @_ ); };
	if( $@ ) { 
		$self->print_fatal_program_error_page( <<__endquote );
<P>We were unable to obtain the global preferences necessary to 
create this instance of a web site.  The file that contains it 
couldn't be used.</P>
<P>$@</P>
__endquote
		return( 0 );
	}
	$self->{$KEY_SITE_GLOBALS} = $globals;

	$self->_set_default_site_prefs();

	my $debug_key = $globals->site_pref( $GKEY_DEBUG_PARAM );
	my $debug_value = $globals->site_pref( $GKEY_DEBUG_VALUE );
	if( $globals->param( $debug_key ) eq $debug_value ) {
		$globals->is_debug( 1 );
		$globals->persistant_query_param( $debug_key, 1 );
	}

	$globals->vrp_param_name( $globals->site_pref( $GKEY_VRP_PARAM ) );
	$globals->vrp_delimiter( $globals->site_pref( $GKEY_VRP_DELIM ) );
	$globals->virtual_resource_path( $globals->param( 
		$globals->vrp_param_name() ) );

	if( $globals->vrp_as_string() eq 
		$globals->site_pref( $GKEY_P_EXTERNAL ) ) {
			$self->print_redirect_page();
	} else {
		$self->print_content_page();
	}
	
	# by now the user may have seen our page, unless the server waits 
	# for this program to finish first

	unless( $globals->site_pref( $GKEY_LOG_USAGE ) ) {
		return( 1 );  # our work here is done if no logs to keep
	}
	
	eval { require CGI::EventCountFile; };
	if( $@ ) { 
		print "<!-- error on require of CGI::EventCountFile -->\n";
		return( 0 );
	}

	$self->_set_default_usage_prefs();

	$self->update_site_usage_counts( $globals->vrp_as_string() eq 
		$globals->site_pref( $GKEY_P_EXTERNAL ) );
}

######################################################################
# This program can't continue, so print out a message to web browser.

sub print_fatal_program_error_page {
	my ($self, $detail) = @_;

	print STDOUT <<__endquote;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<HTML>
<HEAD>
<TITLE>Fatal Program Error</TITLE>
</HEAD>
<BODY><H2 ALIGN="center">Fatal Program Error</H2>

<P>I'm sorry, but a fatal error has occurred that prevents this 
program from continuing further.  It is possible that a critical 
section of this site was being updated at the moment, and that it will
resolve itself shortly.  Otherwise please contact the site 
administrator to have the problem resolved.</P>

$detail

</BODY>
</HTML>
__endquote
}

######################################################################

sub print_content_page {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $page_content;
	my $site_title = $globals->site_pref( $GKEY_SITE_TITLE );
	
	my $wpm_mod_name = $globals->site_pref( $GKEY_WPM_MODULE );
	my $wpm_sub_dir = $globals->site_pref( $GKEY_WPM_SUBDIR );
	my $wpm_prefs = $globals->site_pref( $GKEY_WPM_PREFS );
	
	$globals->current_vrp_level( 1 );  # elem 0 is always empty
	
	my $site_root_dir = $globals->site_root_dir();
	my $sys_path_delim = $globals->system_path_delimiter();
	my $wpm_work_dir = $wpm_sub_dir ? 
		"$site_root_dir$sys_path_delim$wpm_sub_dir" : $site_root_dir;

	eval {
		# "require $wpm_mod_name;" yields can't find module in @INC error
		eval "require $wpm_mod_name;"; if( $@ ) { die $@; }

		my $wpm = $wpm_mod_name->new( $wpm_work_dir, $wpm_prefs );

		$wpm->dispatch_by_user();

		$page_content = $wpm->get_page_content();
		unless( ref( $page_content ) eq 'CGI::WPM::Content' ) {
			die "Error: $wpm_mod_name didn't return a valid ".
				"CGI::WPM::Content object\n";
		}
		
		$self->{$KEY_IS_ERROR} = $wpm->is_error();
	};

	if( $@ ) {
		$page_content = CGI::WPM::Content->new();
		$page_content->title( "$site_title - Fatal Error" );
		$page_content->body_content( <<__endquote );
<H2 ALIGN="center">$site_title - Fatal Error</H2>

<P>I'm sorry, but a fatal error occurred with the site generator 
program.  We were unable to use the module that was supposed to 
generate the page content, named "$wpm_mod_name".</P>

@{[$self->_get_amendment_message()]}

<P>$@</P>
__endquote
	}

	if( $globals->is_debug() ) {
		$page_content->body_append( <<__endquote );
<P>Debugging is currently turned on.</P>
__endquote
	}

	$self->_set_global_replacements( $page_content );

	print STDOUT $page_content->to_string();
}

######################################################################

sub print_redirect_page {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $page_content = CGI::WPM::Content->new();
	
	my $url = $globals->param( 
		$globals->site_pref( $GKEY_EURL_PARAM ) );
	
	$page_content->redirect_url( $url );
	print STDOUT $page_content->to_string();
}

######################################################################

sub update_site_usage_counts {
	my ($self, $is_redirect) = @_;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $usg_prefs = $globals->site_pref( $GKEY_USG_PREFS );
	
	my $site_root_dir = $globals->site_root_dir();
	my $sys_path_delim = $globals->system_path_delimiter();
	my $usg_sub_dir = $globals->is_debug() ? $globals->site_pref( 
		$GKEY_USG_DG_SUB ) : $globals->site_pref( $GKEY_USG_SUBDIR );
	my $usg_work_dir = $usg_sub_dir ? 
		"$site_root_dir$sys_path_delim$usg_sub_dir" : $site_root_dir;

	$self->mail_me_and_reset_counts_if_new_day( $usg_work_dir );
	
	$self->update_one_count_file( $usg_work_dir, 
		$usg_prefs->{$UKEY_FN_ENV}, (map { "\$ENV{$_} = \"$ENV{$_}\"" } 
		@{$usg_prefs->{$UKEY_ENV_VARS}}) );
	
	$self->update_one_count_file( $usg_work_dir, 
		$usg_prefs->{$UKEY_FN_VRP}, $globals->vrp_as_string() );
	
	$self->update_one_count_file( $usg_work_dir, 
		$usg_prefs->{$UKEY_FN_EXT_URL}, $globals->param( 
		$globals->site_pref( $GKEY_EURL_PARAM ) ) || '' );
	
	my $referer = $globals->http_referer();
	my $base_url = $globals->base_url();
	my $vrp_name = $globals->vrp_param_name();
	if( $referer =~ m/^$base_url/i ) {
		$self->update_one_count_file( $usg_work_dir, 
			$usg_prefs->{$UKEY_FN_REFERER}, 
			$usg_prefs->{$UKEY_T_SELF_REF} );
#		$referer =~ m/[\?&]$vrp_name=([^&]*)/i;
#		$self->update_one_count_file( $usg_work_dir, 
#			$usg_prefs->{$UKEY_FN_REF_VRP}, $1 );
	} else {
		$self->update_one_count_file( $usg_work_dir, 
			$usg_prefs->{$UKEY_FN_REFERER}, $referer );
#		$self->update_one_count_file( $usg_work_dir, 
#			$usg_prefs->{$UKEY_FN_REF_VRP}, '' );
	}
	
#	$self->update_one_count_file( $usg_work_dir, 
#		$usg_prefs->{$UKEY_FN_BROWSER}, $globals->user_agent() );
	
#	$self->update_one_count_file( $usg_work_dir, 
#		$usg_prefs->{$UKEY_FN_DOMAINS}, $globals->remote_host() );
}

######################################################################

sub mail_me_and_reset_counts_if_new_day {
	my ($self, $usg_work_dir) = @_;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $sys_path_delim = $globals->system_path_delimiter();
	my $usg_prefs = $globals->site_pref( $GKEY_USG_PREFS );

	my $dcm_file = CGI::EventCountFile->new( 
		"$usg_work_dir$sys_path_delim$usg_prefs->{$UKEY_FN_DCM}", 1 );
	$dcm_file->open_and_lock( 1 ) or do {
		print "<!-- ".$dcm_file->is_error()." -->\n";
		return( undef );
	};
	$dcm_file->read_all_records();
	if( $dcm_file->key_was_incremented_today( 
			$usg_prefs->{$UKEY_T_TOTAL} ) ) {
		$dcm_file->unlock_and_close();
		return( 1 );
	}
	$dcm_file->key_increment( $usg_prefs->{$UKEY_T_TOTAL} );
	$dcm_file->write_all_records();
	$dcm_file->unlock_and_close();

#	my @filenames = map { $usg_prefs->{$_} } 
#		($UKEY_FN_ENV, $UKEY_FN_VRP, $UKEY_FN_EXT_URL, 
#		$UKEY_FN_REFERER, $UKEY_FN_REF_VRP, $UKEY_FN_BROWSER, 
#		$UKEY_FN_DOMAINS);
	my @filenames = map { $usg_prefs->{$_} } 
		($UKEY_FN_ENV, $UKEY_FN_VRP, $UKEY_FN_EXT_URL, 
		$UKEY_FN_REFERER);

	my @mail_body = ();

	foreach my $filename (@filenames) {
		my $count_file = CGI::EventCountFile->new( 
			"$usg_work_dir$sys_path_delim$filename", 1 );
		$count_file->open_and_lock( 1 ) or do {
			push( @mail_body, "\n\n".$count_file->is_error()."\n" );
			next;
		};
		$count_file->read_all_records();
		push( @mail_body, "\n\ncontent of '$filename':\n\n" );
		push( @mail_body, $count_file->get_sorted_file_content() );
		$count_file->set_all_day_counts_to_zero();
		$count_file->write_all_records();
		$count_file->unlock_and_close();
	}

	my $site_title = $globals->site_pref( $GKEY_SITE_TITLE );
	my ($today_str) = ($globals->today_date_utc() =~ m/^(\S+)/ );
	my $debug_on_off = $globals->is_debug() ? 'on' : 'off';

	unshift( @mail_body, <<__endquote );
--------------------------------------------------
This is a daily copy of the usage count logs for the 
web site "$site_title", which is located at 
@{[$globals->base_url()]}.
The first visitor activity on $today_str has just occurred.
The time is now @{[$globals->today_date_utc()]}.
This log set is used when debugging is $debug_on_off.
--------------------------------------------------
__endquote

	push( @mail_body, <<__endquote );


--------------------------------------------------
END OF MESSAGE
__endquote

	my $err_msg = $globals->send_email_message(
		$globals->site_pref( $GKEY_SMTP_HOST ),
		$globals->site_pref( $GKEY_OWNER_NAME ),
		$globals->site_pref( $GKEY_OWNER_EMAIL ),
		$globals->site_pref( $GKEY_OWNER_NAME ),
		$globals->site_pref( $GKEY_OWNER_EMAIL ),
		"$site_title -- Usage to $today_str".
		($globals->is_debug() ? ' -- debug' : ''),
		join( '', @mail_body ),
	);

	if( $err_msg ) {
		print "<!-- error on e-mailing usage counts to owner: $err_msg -->\n";
	}
}

######################################################################

sub update_one_count_file {
	my ($self, $usg_work_dir, $filename, @keys_to_inc) = @_;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $sys_path_delim = $globals->system_path_delimiter();
	my $usg_prefs = $globals->site_pref( $GKEY_USG_PREFS );

	push( @keys_to_inc, $usg_prefs->{$UKEY_T_TOTAL} );

	my $count_file = CGI::EventCountFile->new( 
		"$usg_work_dir$sys_path_delim$filename", 1 );
	$count_file->open_and_lock( 1 ) or return( 0 );
	$count_file->read_all_records();

	foreach my $key (@keys_to_inc) {
		$key eq '' and $key = $usg_prefs->{$UKEY_T_NIL};
		$count_file->key_increment( $key );
	}

	$count_file->write_all_records();
	$count_file->unlock_and_close();
}

######################################################################

sub _set_default_site_prefs {
	my $self = shift( @_ );
	my $rh_prefs = $self->{$KEY_SITE_GLOBALS}->site_prefs();
	$rh_prefs->{$GKEY_SITE_TITLE} ||= 'Untitled Web Site';
	$rh_prefs->{$GKEY_OWNER_NAME} ||= 'Unnamed Owner';
	$rh_prefs->{$GKEY_OWNER_EMAIL} ||= 'nobody@nowhere';
	$rh_prefs->{$GKEY_RETURN_EMAIL} ||= 'nobody@nowhere';
	$rh_prefs->{$GKEY_SMTP_HOST} ||= 'mail.nowhere';
	$rh_prefs->{$GKEY_WPM_MODULE} ||= 'CGI::WPM::Base';
	$rh_prefs->{$GKEY_WPM_SUBDIR} ||= undef;  # used to be 'content'
	$rh_prefs->{$GKEY_WPM_PREFS} ||= {};
	$rh_prefs->{$GKEY_LOG_USAGE} ||= 0;
	$rh_prefs->{$GKEY_USG_SUBDIR} ||= undef;  # used to be 'usage'
	$rh_prefs->{$GKEY_USG_DG_SUB} ||= 'usage_debug';
	$rh_prefs->{$GKEY_USG_PREFS} ||= {};
	$rh_prefs->{$GKEY_VRP_PARAM} ||= 'path';
	$rh_prefs->{$GKEY_VRP_DELIM} ||= '/';
	$rh_prefs->{$GKEY_EURL_PARAM} ||= 'url';
	$rh_prefs->{$GKEY_T_SELF_URL} ||= '__self_url__';
	$rh_prefs->{$GKEY_T_BASE_URL} ||= '__base_url__';
	$rh_prefs->{$GKEY_T_PERS_URL} ||= '__persistant_url__';
	$rh_prefs->{$GKEY_T_VRP_ID} ||= '__vrp_id__';
	$rh_prefs->{$GKEY_T_MAILME} ||= '__mailme_url__';
	$rh_prefs->{$GKEY_T_EXT_ID} ||= '__external_id__';
	$rh_prefs->{$GKEY_P_MAILME} ||= '/mailme';
	$rh_prefs->{$GKEY_P_EXTERNAL} ||= 'external';
	$rh_prefs->{$GKEY_FIND_REPL} ||= {};
	$rh_prefs->{$GKEY_AMEND_MSG} ||= undef;
	$rh_prefs->{$GKEY_DEBUG_PARAM} ||= 'debug';
	$rh_prefs->{$GKEY_DEBUG_VALUE} ||= 1;
}

######################################################################

sub _set_global_replacements {
	my $self = shift( @_ );
	my $page_content = shift( @_ );

	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->site_prefs();
	my $vrp_is_first = index( $globals->persistant_url(), '?' ) == -1;
	
	$page_content->add_later_replace( $rh_prefs->{$GKEY_FIND_REPL} );

	$page_content->add_later_replace( { 
		$rh_prefs->{$GKEY_T_MAILME} =>
			"$rh_prefs->{$GKEY_T_VRP_ID}=$rh_prefs->{$GKEY_P_MAILME}",
		$rh_prefs->{$GKEY_T_EXT_ID} =>
			"$rh_prefs->{$GKEY_T_VRP_ID}=$rh_prefs->{$GKEY_P_EXTERNAL}".
			"&$rh_prefs->{$GKEY_EURL_PARAM}",
	} );

	$page_content->add_later_replace( { 
		$rh_prefs->{$GKEY_T_SELF_URL} => $globals->self_url(),
		$rh_prefs->{$GKEY_T_BASE_URL} => $globals->base_url(),
		$rh_prefs->{$GKEY_T_PERS_URL} => $globals->persistant_url(),
		$rh_prefs->{$GKEY_T_VRP_ID} => $globals->persistant_url().
			($vrp_is_first ? '?' : '&').$rh_prefs->{$GKEY_VRP_PARAM},
	} );
}

######################################################################

sub _get_amendment_message {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $ams = $globals->site_pref( $GKEY_AMEND_MSG ) || <<__endquote;
<P>This should be temporary, the result of a server glitch
or a site update being performed at the moment.  Click 
<A HREF="@{[$globals->self_url()]}">here</A> to automatically try again.  
If the problem persists, please try again later, or send an
<A HREF="@{[$globals->site_pref( $GKEY_T_MAILME )]}">e-mail</A>
message about the problem, so it can be fixed.</P>
__endquote
	return( $ams );
}

######################################################################

sub _set_default_usage_prefs {
	my $self = shift( @_ );
	my $rh_prefs = 
		$self->{$KEY_SITE_GLOBALS}->site_pref( $GKEY_USG_PREFS );
	$rh_prefs->{$UKEY_FN_DCM} ||= 'date_counts_mailed.txt';
	$rh_prefs->{$UKEY_FN_ENV} ||= 'env.txt';
	$rh_prefs->{$UKEY_FN_VRP} ||= 'vrp.txt';
	$rh_prefs->{$UKEY_FN_EXT_URL} ||= 'ext_url.txt';
	$rh_prefs->{$UKEY_FN_REFERER} ||= 'references.txt';
	$rh_prefs->{$UKEY_FN_REF_VRP} ||= 'ref_vrp.txt';
	$rh_prefs->{$UKEY_FN_BROWSER} ||= 'browsers.txt';
	$rh_prefs->{$UKEY_FN_DOMAINS} ||= 'domains.txt';
	$rh_prefs->{$UKEY_ENV_VARS} ||= [qw(
		REQUEST_METHOD SERVER_NAME SCRIPT_FILENAME
		HTTP_HOST SCRIPT_NAME SERVER_SOFTWARE
	)];
	$rh_prefs->{$UKEY_T_TOTAL} ||= '__total__';
	$rh_prefs->{$UKEY_T_NIL} ||= '__nil__';
	$rh_prefs->{$UKEY_T_SELF_REF} ||= '__self_reference__';
#	$rh_prefs->{$UKEY_EMAIL_FN} ||= [qw(
#		env.txt     vrp.txt      ext_url.txt references.txt 
#		ref_vrp.txt browsers.txt domains.txt 
#	)],
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
