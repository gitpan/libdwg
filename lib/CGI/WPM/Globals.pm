=head1 NAME

CGI::WPM::Globals - Perl module that is used by all subclasses of CGI::WPM::Base
for managing global program settings, file system and web site hierarchy
contexts, providing environment details, gathering and managing user input, and
providing utilities like sending e-mail.

=cut

######################################################################

package CGI::WPM::Globals;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.2';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::HashOfArrays
	Net::SMTP 2.15  # only if we send e-mails

=cut

######################################################################

use CGI::HashOfArrays;

######################################################################
# Names of properties for objects of this class are declared here:

# These properties are set only once because they correspond to user 
# input that can only be gathered prior to this program starting up.
my $KEY_INITIAL_UI = 'initial_user_input';
	my $IKEY_COOKIE   = 'user_cookie_str'; # cookies from browser
	my $IKEY_QUERY    = 'user_query_str';  # query str from browser
	my $IKEY_POST     = 'user_post_str';   # post data from browser
	my $IKEY_OFFLINE  = 'user_offline_str'; # shell args / redirect
	my $IKEY_OVERSIZE = 'is_oversize_post'; # true if cont len >max

# This property is set by the calling code and may affect how certain 
# areas of the program function, but it can be safely ignored.
my $KEY_IS_DEBUG = 'is_debug';  # are we debugging the site or not?

# This property is set when a server-side problem causes the program 
# to not function correctly.  This includes inability to load modules, 
# inability to get preferences, inability to use e-mail or databases.
my $KEY_SITE_ERRORS = 'site_errors'; # holds error string list, if any

# These properties are set by the code which instantiates this object,
# are operating system specific, and indicate where all the support 
# files are for a site.
my $KEY_SITE_ROOT_DIR = 'site_root_dir';  # root dir of support files
my $KEY_DELIM_SYS_PATH = 'delim_sys_path';  # level delim in system paths

# These properties maintain recursive copies of themselves such that 
# subordinate page making modules can inherit (or override) properties 
# of their parents, but any changes made won't affect the properties 
# that the parents see (unless the parents allow it).
my $KEY_PREFS   = 'site_prefs';  # settings from files in the srp
my $KEY_SRP = 'srp_elements';  # site resource path (files)
my $KEY_VRP = 'vrp_elements';  # virtual resource path (url)
	# the above vrp is used soley when constructing new urls
my $KEY_PREFS_STACK = 'prefs_stack';
my $KEY_SRP_STACK   = 'srp_stack';
my $KEY_VRP_STACK   = 'vrp_stack';

# These properties are not recursive, but are unlikely to get edited
my $KEY_USER_COOKIE = 'user_cookie'; # settings from browser cookies
my $KEY_USER_INPUT  = 'user_input';  # settings from browser query/post
my $KEY_USER_VRP_EL = 'user_vrp_el'; # vrp that user is requesting
my $KEY_USER_VRP_LV = 'user_vrp_lv'; # level page makers working at

# These properties keep track of important user/pref data that should
# be returned to the browser even if not recognized by subordinates.
my $KEY_PERSIST_QUERY  = 'persist_query';  # which qp persist for session
	# this is used only when constructing new urls, and it stores just 
	# the names of user input params whose values we are to return.

# These properties are used under the assumption that the vrp which 
# the user provides us is in the query string.
my $KEY_VRP_UIPN = 'uipn_vrp';  # query param that has vrp as its value

# These properties are used in conjunction with sending e-mails.
my $KEY_SMTP_HOST    = 'smtp_host';    # what computer sends our mail
my $KEY_SMTP_TIMEOUT = 'smtp_timeout'; # how long wait for mail send
my $KEY_SITE_TITLE   = 'site_title';   # name of site
my $KEY_OWNER_NAME   = 'owner_name';   # name of site's owner
my $KEY_OWNER_EMAIL  = 'owner_email';  # e-mail of site's owner
my $KEY_OWNER_EM_VRP = 'owner_em_vrp'; # vrp for e-mail page

# Constant values used in this class go here:

my $MAX_CONTENT_LENGTH = 100_000;  # currently limited to 100 kbytes
my $UIP_KEYWORDS = '.keywords';  # user input param for ISINDEX queries

my $SITE_PATH_DELIM = '/';  # a "/" for site path = "site root dir"
my $DEF_VRP_UIPN = 'path';

my $TALB = '[';  # left side of bounds for token replacement arguments
my $TARB = ']';  # right side of same

my $EMAIL_HEADER_STRIP_PATTERN = '[,<>()"\'\n]';  #for names and addys
my $DEF_SMTP_HOST = 'localhost';
my $DEF_SMTP_TIMEOUT = 30;
my $DEF_SITE_TITLE = 'Untitled Website';

######################################################################

sub new {
	my $starter = shift( @_ );  # starter is either object or class
	my $self = {};
	bless( $self, ref($starter) || $starter );
	$self->{$KEY_INITIAL_UI} = ref($starter) ? 
		$starter->{$KEY_INITIAL_UI} : $self->get_initial_user_input();
	$self->initialize( @_ );
	return( $self );
}

######################################################################
# This collects user input, and should only be called once by a program
# for the reason that multiple POST reads from STDIN can cause a hang 
# if the extra data isn't there.

sub get_initial_user_input {
	my %iui = ();

	$iui{$IKEY_COOKIE} = $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'};
	
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD|POST)$/ ) {
		$iui{$IKEY_QUERY} = $ENV{'QUERY_STRING'};
		
		if( $ENV{'CONTENT_LENGTH'} <= $MAX_CONTENT_LENGTH ) {
			read( STDIN, $iui{$IKEY_POST}, $ENV{'CONTENT_LENGTH'} );
			chomp( $iui{$IKEY_POST} );
		} else {  # post too large, error condition, post not taken
			$iui{$IKEY_OVERSIZE} = $MAX_CONTENT_LENGTH;
		}

	} elsif( @ARGV ) {
		$iui{$IKEY_OFFLINE} = $ARGV[0];

	} else {
		print STDERR "offline mode: enter query string on standard input\n";
		print STDERR "it must be query-escaped and all one one line\n";
		$iui{$IKEY_OFFLINE} = <STDIN>;
		chomp( $iui{$IKEY_OFFLINE} );
	}

	return( \%iui );
}

######################################################################

sub initialize {
	my ($self, $root, $delim, $prefs, $user_input) = @_;
	
	%{$self} = (
		$KEY_INITIAL_UI => $self->{$KEY_INITIAL_UI},
		$KEY_IS_DEBUG => undef,
		$KEY_SITE_ERRORS => [],
		$KEY_SITE_ROOT_DIR  => undef,
		$KEY_DELIM_SYS_PATH => undef,
		$KEY_PREFS => {},
		$KEY_SRP   => [''],  # needs element zero defined and empty
		$KEY_VRP   => [''],  # needs element zero defined and empty
		$KEY_PREFS_STACK => [],
		$KEY_SRP_STACK   => [],
		$KEY_VRP_STACK   => [],
		$KEY_USER_COOKIE => $self->parse_url_encoded_cookies( 1, 
			$self->user_cookie_str() 
		),
		$KEY_USER_INPUT  => $self->parse_url_encoded_queries( 1, 
			$self->user_query_str(), 
			$self->user_post_str(), 
			$self->user_offline_str() 
		),
		$KEY_USER_VRP_EL => [],
		$KEY_USER_VRP_LV => undef,
		$KEY_PERSIST_QUERY  => {},
		$KEY_VRP_UIPN => $DEF_VRP_UIPN,
		$KEY_SMTP_HOST => $DEF_SMTP_HOST,
		$KEY_SMTP_TIMEOUT => $DEF_SMTP_TIMEOUT,
		$KEY_SITE_TITLE => $DEF_SITE_TITLE,
		$KEY_OWNER_NAME => undef,
		$KEY_OWNER_EMAIL => undef,
		$KEY_OWNER_EM_VRP => undef,
	);

	$self->site_root_dir( $root );
	$self->system_path_delimiter( $delim );
	$self->site_prefs( $prefs );
	$self->user_input( $user_input );
}

######################################################################

sub user_cookie_str  { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_COOKIE}   }
sub user_query_str   { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_QUERY}    }
sub user_post_str    { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_POST}     }
sub user_offline_str { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_OFFLINE}  }
sub is_oversize_post { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_OVERSIZE} }

######################################################################

sub request_method { $ENV{'REQUEST_METHOD'} || 'GET' }
sub content_length { $ENV{'CONTENT_LENGTH'} || '0' }

sub server_name { $ENV{'SERVER_NAME'} || 'localhost' }
sub virtual_host { $ENV{'HTTP_HOST'} || $_[0]->server_name() }
sub server_port { $ENV{'SERVER_PORT'} || 80 }
sub script_name {
	my $str = $ENV{'SCRIPT_NAME'};
	$str =~ tr/+/ /;
	$str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( $str );
}

sub http_referer {
	my $str = $ENV{'HTTP_REFERER'};
	$str =~ tr/+/ /;
	$str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( $str );
}

sub remote_addr { $ENV{'REMOTE_ADDR'} || '127.0.0.1' }
sub remote_host { $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 
	'localhost' }
sub remote_user { $ENV{'AUTH_USER'} || $ENV{'LOGON_USER'} || 
	$ENV{'REMOTE_USER'} || $ENV{'HTTP_FROM'} || $ENV{'REMOTE_IDENT'} }
sub user_agent { $ENV{'HTTP_USER_AGENT'} }

######################################################################

sub is_mod_perl {
	return( defined( $ENV{'GATEWAY_INTERFACE'} ) &&
		$ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl/ );
}

######################################################################

sub base_url {
	my $self = shift( @_ );
	my $port = $self->server_port();
	return( 'http://'.$self->virtual_host().
		($port != 80 ? ":$port" : '').
		$self->script_name() );
}

######################################################################

sub self_url {
	my $self = shift( @_ );
	my $query = $self->user_query_str() || 
		$self->user_offline_str();
	return( $self->base_url().($query ? "?$query" : '') );
}

######################################################################

sub self_post {
	my $self = shift( @_ );
	my $button_label = shift( @_ ) || 'click here';
	my $url = $self->self_url();
	my $post_fields = $self->parse_url_encoded_queries( 0, 
		$self->user_post_str() )->to_html_encoded_hidden_fields();
	return( <<__endquote );
<FORM METHOD="post" ACTION="$url">
$post_fields
<INPUT TYPE="submit" NAME="" VALUE="$button_label">
</FORM>
__endquote
}

######################################################################

sub self_html {
	my $self = shift( @_ );
	my $visible_text = shift( @_ ) || 'here';
	return( $self->user_post_str() ? 
		$self->self_post( $visible_text ) : 
		'<A HREF="'.$self->self_url().'">'.$visible_text.'</A>' );
}

######################################################################

sub is_debug {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_IS_DEBUG} = $new_value;
	}
	return( $self->{$KEY_IS_DEBUG} );
}

######################################################################

sub get_errors {
	return( grep( defined($_), @{$_[0]->{$KEY_SITE_ERRORS}} ) );
}

sub get_error {
	my ($self, $index) = @_;
	defined( $index ) or $index = -1;
	return( $self->{$KEY_SITE_ERRORS}->[$index] );
}

sub add_error {
	my ($self, $message) = @_;
	return( push( @{$self->{$KEY_SITE_ERRORS}}, $message ) );
}

sub add_no_error {
	push( @{$_[0]->{$KEY_SITE_ERRORS}}, undef );
}

sub add_filesystem_error {
	my ($self, $filename, $unique_part) = @_;
	my $filepath = $self->srp_child_string( $filename );
	return( $self->{$KEY_SITE_ERRORS} = 
		"can't $unique_part file '$filepath': $!" );
}

######################################################################

sub site_root_dir {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SITE_ROOT_DIR} = $new_value;
	}
	return( $self->{$KEY_SITE_ROOT_DIR} );
}

sub system_path_delimiter {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_DELIM_SYS_PATH} = $new_value;
	}
	return( $self->{$KEY_DELIM_SYS_PATH} );
}

sub phys_filename_string {
	my ($self, $filename) = @_;
	my $root_dir = $self->{$KEY_SITE_ROOT_DIR};
	my $sys_delim = $self->{$KEY_DELIM_SYS_PATH};
	my @sp_parts = @{$self->srp_child( $filename )};
	return( $root_dir.join( $sys_delim, @sp_parts ) );
}

######################################################################

sub site_prefs {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_PREFS} = $self->get_prefs_rh( $new_value ) || {};
	}
	return( $self->{$KEY_PREFS} );
}

sub move_site_prefs {
	my ($self, $new_value) = @_;
	push( @{$self->{$KEY_PREFS_STACK}}, $self->{$KEY_PREFS} );
	$self->{$KEY_PREFS} = $self->get_prefs_rh( $new_value ) || {};
}

sub restore_site_prefs {
	my $self = shift( @_ );
	$self->{$KEY_PREFS} = pop( @{$self->{$KEY_PREFS_STACK}} ) || {};
}

sub site_pref {
	my $self = shift( @_ );
	my $key = shift( @_ );

	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_PREFS}->{$key} = $new_value;
	}
	my $value = $self->{$KEY_PREFS}->{$key};

	# if current version doesn't define key, look in older versions
	unless( defined( $value ) ) {
		foreach my $prefs (reverse @{$self->{$KEY_PREFS_STACK}}) {
			$value = $prefs->{$key};
			defined( $value ) and last;
		}
	}
	
	return( $value );
}

######################################################################

sub site_resource_path {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		my @elements = ('', ref( $new_value ) eq 'ARRAY' ?
			@{$new_value} : @{$self->site_path_str_to_ra( $new_value )});
		$self->{$KEY_SRP} = $self->simplify_path_ra( \@elements );
	}
	return( $self->{$KEY_SRP} );
}

sub site_resource_path_string {
	my $self = shift( @_ );
	my $trailer = shift( @_ ) ? $SITE_PATH_DELIM : '';
	return( $self->site_path_ra_to_str( $self->{$KEY_SRP} ).$trailer );
}
	
sub move_current_srp {
	my ($self, $chg_vec) = @_;
	push( @{$self->{$KEY_SRP_STACK}}, $self->{$KEY_SRP} );
	my $ra_elements = $self->join_two_path_ra( $self->{$KEY_SRP}, 
		ref($chg_vec) eq 'ARRAY' ? $chg_vec :
		$self->site_path_str_to_ra( $chg_vec ) );
	$self->{$KEY_SRP} = $self->simplify_path_ra( $ra_elements );
}

sub restore_last_srp {
	my $self = shift( @_ );
	$self->{$KEY_SRP} = pop( @{$self->{$KEY_SRP_STACK}} ) || [];
}

sub srp_child {
	my ($self, $filename) = @_;
	my $ra_elements = $self->join_two_path_ra( $self->{$KEY_SRP}, 
		ref($filename) eq 'ARRAY' ? $filename :
		$self->site_path_str_to_ra( $filename ) );
	return( $self->simplify_path_ra( $ra_elements ) );
}

sub srp_child_string {
	my ($self, $fn, $sx) = @_;
	$sx and $sx = $SITE_PATH_DELIM;
	return( $self->site_path_ra_to_str( $self->srp_child( $fn ) ).$sx );
}

######################################################################

sub virtual_resource_path {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		my @elements = ('', ref( $new_value ) eq 'ARRAY' ?
			@{$new_value} : @{$self->site_path_str_to_ra( $new_value )});
		$self->{$KEY_VRP} = $self->simplify_path_ra( \@elements );
	}
	return( $self->{$KEY_VRP} );
}

sub virtual_resource_path_string {
	my $self = shift( @_ );
	my $trailer = shift( @_ ) ? $SITE_PATH_DELIM : '';
	return( $self->site_path_ra_to_str( $self->{$KEY_VRP} ).$trailer );
}
	
sub move_current_vrp {
	my ($self, $chg_vec) = @_;
	push( @{$self->{$KEY_VRP_STACK}}, $self->{$KEY_VRP} );
	my $ra_elements = $self->join_two_path_ra( $self->{$KEY_VRP}, 
		ref($chg_vec) eq 'ARRAY' ? $chg_vec :
		$self->site_path_str_to_ra( $chg_vec ) );
	$self->{$KEY_VRP} = $self->simplify_path_ra( $ra_elements );
}

sub restore_last_vrp {
	my $self = shift( @_ );
	$self->{$KEY_VRP} = pop( @{$self->{$KEY_VRP_STACK}} ) || [];
}

sub vrp_child {
	my ($self, $filename) = @_;
	my $ra_elements = $self->join_two_path_ra( $self->{$KEY_VRP}, 
		ref($filename) eq 'ARRAY' ? $filename :
		$self->site_path_str_to_ra( $filename ) );
	return( $self->simplify_path_ra( $ra_elements ) );
}

sub vrp_child_string {
	my ($self, $fn, $sx) = @_;
	$sx and $sx = $SITE_PATH_DELIM;
	return( $self->site_path_ra_to_str( $self->vrp_child( $fn ) ).$sx );
}

######################################################################

sub user_cookie {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'CGI::HashOfArrays' ) {
		$self->{$KEY_USER_COOKIE} = $new_value->clone();
	}
	return( $self->{$KEY_USER_COOKIE} );
}

sub user_cookie_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_COOKIE}->to_url_encoded_string('; ','&') );
}

sub user_cookie_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_USER_COOKIE}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_USER_COOKIE}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_USER_COOKIE}->fetch_value( $key ) );
	}
}

######################################################################

sub user_input {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'CGI::HashOfArrays' ) {
		$self->{$KEY_USER_INPUT} = $new_value->clone();
	}
	return( $self->{$KEY_USER_INPUT} );
}

sub user_input_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_INPUT}->to_url_encoded_string() );
}

sub user_input_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_USER_INPUT}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_USER_INPUT}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_USER_INPUT}->fetch_value( $key ) );
	}
}

sub user_input_keywords {
	my $self = shift( @_ );
	return( @{$self->{$KEY_USER_INPUT}->fetch( $UIP_KEYWORDS )} );
}

######################################################################

sub user_vrp {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		my @elements = ('', ref( $new_value ) eq 'ARRAY' ?
			@{$new_value} : @{$self->site_path_str_to_ra( $new_value )});
		$self->{$KEY_USER_VRP_EL} = $self->simplify_path_ra( \@elements );
	}
	return( $self->{$KEY_USER_VRP_EL} );
}

sub user_vrp_string {
	my $self = shift( @_ );
	return( $self->site_path_ra_to_str( $self->{$KEY_USER_VRP_EL} ) );
}

sub current_user_vrp_level {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_USER_VRP_LV} = 0 + $new_value;
	}
	return( $self->{$KEY_USER_VRP_LV} );
}

sub inc_user_vrp_level {
	my $self = shift( @_ );
	return( ++$self->{$KEY_USER_VRP_LV} );
}

sub dec_user_vrp_level {
	my $self = shift( @_ );
	return( --$self->{$KEY_USER_VRP_LV} );
}

sub current_user_vrp_element {
	my $self = shift( @_ );
	my $curr_elem_num = $self->{$KEY_USER_VRP_LV};
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_USER_VRP_EL}->[$curr_elem_num] = $new_value;
	}
	return( $self->{$KEY_USER_VRP_EL}->[$curr_elem_num] );
}

######################################################################

sub persistant_user_input_params {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_PERSIST_QUERY} = {%{$new_value}};
	}
	return( $self->{$KEY_PERSIST_QUERY} );
}

sub persistant_user_input_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_PERSIST_QUERY}->{$key} = $new_value;
	}	
	return( $self->{$KEY_PERSIST_QUERY}->{$key} );
}

sub persistant_user_input_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_INPUT}->clone( 
		[keys %{$self->{$KEY_PERSIST_QUERY}}] 
		)->to_url_encoded_string() );
}

sub persistant_url {
	my $self = shift( @_ );
	my $persist_input_str = $self->persistant_user_input_string();
	return( $self->base_url().
		($persist_input_str ? "?$persist_input_str" : '') );
}

######################################################################

sub vrp_param_name {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_VRP_UIPN} = $new_value;
	}
	return( $self->{$KEY_VRP_UIPN} );
}

# This currently supports vrp in query string format only.
# If no argument provided, returns "[base]?[pers]&path"
# If 1 argument provided, returns "[base]?[pers]&path=[vrp_child]"
# If 2 arguments provided, returns "[base]?[pers]&path=[vrp_child]/"

sub persistant_vrp_url {
	my $self = shift( @_ );
	my $chg_vec = shift( @_ );
	my $persist_input_str = $self->persistant_user_input_string();
	return( $self->base_url().'?'.
		($persist_input_str ? "$persist_input_str&" : '').
		$self->{$KEY_VRP_UIPN}.(defined( $chg_vec ) ? 
		'='.$self->vrp_child_string( $chg_vec, @_ ) : '') );
}

######################################################################

sub smtp_host {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SMTP_HOST} = $new_value;
	}
	return( $self->{$KEY_SMTP_HOST} );
}

sub smtp_timeout {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SMTP_TIMEOUT} = $new_value;
	}
	return( $self->{$KEY_SMTP_TIMEOUT} );
}

sub site_title {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SITE_TITLE} = $new_value;
	}
	return( $self->{$KEY_SITE_TITLE} );
}

sub site_owner_name {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_OWNER_NAME} = $new_value;
	}
	return( $self->{$KEY_OWNER_NAME} );
}

sub site_owner_email {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_OWNER_EMAIL} = $new_value;
	}
	return( $self->{$KEY_OWNER_EMAIL} );
}

sub site_owner_email_vrp {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_OWNER_EM_VRP} = $new_value;
	}
	return( $self->{$KEY_OWNER_EM_VRP} );
}

sub site_owner_email_html {
	my $self = shift( @_ );
	my $visible_text = shift( @_ ) || 'e-mail';
	my $owner_vrp = $self->site_owner_email_vrp();
	my $owner_email = $self->site_owner_email();
	return( $owner_vrp ? '<A HREF="'.$self->persistant_vrp_url( 
		$owner_vrp ).'">'.$visible_text.'</A>' : '<A HREF="mailto:'.
		$owner_email.'">'.$visible_text.'</A> ('.$owner_email.')' );
}

######################################################################

sub send_email_message {
	my ($self, $to_name, $to_email, $from_name, $from_email, 
		$subject, $body, $body_head_addition) = @_;

	$to_name    =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$to_email   =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$from_name  =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$from_email =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$self->is_debug() and $subject .= " -- debug";
	
	my $body_header = <<__endquote.
--------------------------------------------------
This e-mail was sent at @{[$self->today_date_utc()]} 
by the web site "@{[$self->site_title()]}", 
which is located at "@{[$self->base_url()]}".
__endquote
	$body_head_addition.
	($self->is_debug() ? "Debugging is currently turned on.\n" : 
	'').<<__endquote;
--------------------------------------------------
__endquote

	my $body_footer = <<__endquote;


--------------------------------------------------
END OF MESSAGE
__endquote
	
	my $host = $self->smtp_host();
	my $timeout = $self->smtp_timeout();
	my $error_msg = '';

	TRY: {
		my $smtp;

		eval { require Net::SMTP; };
		if( $@ ) {
			$error_msg = "can't open program module 'Net::SMTP'";
			last TRY;
		}
	
		unless( $smtp = Net::SMTP->new( $host, Timeout => $timeout ) ) {
			$error_msg = "can't connect to smtp host: $host";
			last TRY;
		}

		unless( $smtp->verify( $from_email ) ) {
			$error_msg = "invalid address: @{[$smtp->message()]}";
			last TRY;
		}

		unless( $smtp->verify( $to_email ) ) {
			$error_msg = "invalid address: @{[$smtp->message()]}";
			last TRY;
		}

		unless( $smtp->mail( "$from_name <$from_email>" ) ) {
			$error_msg = "from: @{[$smtp->message()]}";
			last TRY;
		}

		unless( $smtp->to( "$to_name <$to_email>" ) ) {
			$error_msg = "to: @{[$smtp->message()]}";
			last TRY;
		}

		$smtp->data( <<__endquote );
From: $from_name <$from_email>
To: $to_name <$to_email>
Subject: $subject
Content-Type: text/plain; charset=us-ascii

$body_header
$body
$body_footer
__endquote

		$smtp->quit();
	}
	
	return( $error_msg );
}

######################################################################

sub today_date_utc {
	my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
	$year += 1900;  # year counts from 1900 AD otherwise
	$mon += 1;      # ensure January is 1, not 0
	my @parts = ($year, $mon, $mday, $hour, $min, $sec);
	return( sprintf( "%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d UTC", @parts ) );
}

######################################################################
# Note: in order for this to work, the file must contain valid perl 
# code that, when compiled, produces a valid HASH reference.

sub get_hash_from_file {
	my ($self, $filename) = @_;
	my $result = do $filename;
	return( (ref( $result ) eq 'HASH') ? $result : undef );
}
	
######################################################################

sub get_prefs_rh {
	my ($self, $site_prefs) = @_;

	if( ref( $site_prefs ) eq 'HASH' ) {
		$site_prefs = {%{$site_prefs}};

	} else {
		$self->add_no_error();
		$site_prefs = $self->get_hash_from_file( 
				$self->phys_filename_string( $site_prefs ) ) or do {
			my $filename = $self->srp_child_string( $site_prefs );
			$self->add_error( <<__endquote );
can't obtain required site preferences from file "$filename": $!
__endquote
		};

	}
	return( $site_prefs );
}

######################################################################

sub site_path_str_to_ra {
	return( [split( $SITE_PATH_DELIM, $_[1] )] );
}

sub site_path_ra_to_str {
	return( join( $SITE_PATH_DELIM, @{$_[1]} ) );
}

sub join_two_path_ra {
	my ($self, $curr, $chg) = @_;
	return( @{$chg} && $chg->[0] eq '' ? [@{$chg}] : [@{$curr}, @{$chg}] );
}

sub simplify_path_ra {
	my $self = shift( @_ );
	my @in = @{shift( @_ )};
	my @mid = ();
	my @out = $in[0] eq '' ? shift( @in ) : ();
	
	foreach my $part (@in) {
		$part =~ /[a-zA-Z0-9]/ and push( @mid, $part ) and next;
		$part ne '..' and next;
		@mid ? pop( @mid ) : push( @out, '..' );
	}

	$out[0] eq '' and @out = '';
	push( @out, @mid );
	return( \@out );
}

######################################################################

sub parse_url_encoded_cookies {
	my $self = shift( @_ );
	my $parsed = CGI::HashOfArrays->new( shift( @_ ) );
	foreach my $string (@_) {
		$string =~ s/\s+/ /g;
		$parsed->from_url_encoded_string( $string, '; ', '&' );
	}
	return( $parsed );
}

sub parse_url_encoded_queries {
	my $self = shift( @_ );
	my $parsed = CGI::HashOfArrays->new( shift( @_ ) );
	foreach my $string (@_) {
		$string =~ s/\s+/ /g;
		if( $string =~ /=/ ) {
			$parsed->from_url_encoded_string( $string );
		} else {
			$parsed->from_url_encoded_string( 
				"$UIP_KEYWORDS=$string", undef, ' ' );
		}
	}
	return( $parsed );
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


