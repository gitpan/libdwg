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
$VERSION = '0.1b';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	Class::Singleton 1.03
	CGI::HashOfArrays
	Net::SMTP 2.15

=cut

######################################################################

use Class::Singleton 1.03;
@ISA = qw( Class::Singleton );
use CGI::HashOfArrays;

######################################################################
# Names of properties for objects of this class are declared here:
my $KEY_INITIAL_QUERY = 'initial_query';  # this string never changes
my $KEY_SITE_ROOT_DIR = 'site_root_dir';  # root dir of support files
my $KEY_DELIM_SYS_PATH = 'delim_sys_path';  # level delim in system paths
my $KEY_SITE_PREFS = 'site_prefs';  # global settings we want go here
my $KEY_QUERY_PARAMS  = 'query_params';  # calling code can set/change
my $KEY_PERSIST_PARAMS = 'persist_params';  # param names we want persistant
my $KEY_IS_DEBUG = 'is_debug';  # are we debugging the site or not?
my $KEY_VRP_ELEMENTS = 'vrp_elements';  # virtual resource path param
my $KEY_CURR_VRP_LEV = 'curr_vrp_lev';  # level page makers working at
my $KEY_VRP_PARAM = 'vrp_param';  # query param our vrp is at
my $KEY_VRP_DELIM = 'vrp_delim';  # delimiter between vrp elements

# Constant values used in this class go here:
my $PARAM_KEYWORDS = '.keywords';
my $MAX_CONTENT_LENGTH = 100_000;  # currently limited to 100 kbytes
my $EMAIL_HEADER_STRIP_PATTERN = '[,<>"\'\n]';
my $DEF_VRP_PARAM = 'path';
my $DEF_VRP_DELIM = '/';

######################################################################
# Return the only object of this class if it exists, or create that 
# object and then return it.

sub new {
	my $class = shift( @_ );
	my $self = SUPER::instance $class ( @_ );
	return( $self );
}

# This is provided so Class::Singleton->instance() can call it.
sub _new_instance {
	my $class = shift( @_ );
	my $self = {};
	bless( $self, ref($class) || $class );

	$self->_input_initial_query_string();
	$self->initialize( @_ );

	return( $self );
}

######################################################################

sub initialize {
	my ($self, $root, $delim, $prefs, $query) = @_;
	$self->site_root_dir( $root );
	$self->system_path_delimiter( $delim );
	$self->site_prefs( $prefs );
	$self->set_query_params( defined( $query ) ? $query : 
		$self->{$KEY_INITIAL_QUERY} );
	$self->persistant_query_params( {} );
	$self->virtual_resource_path( '' );
	$self->vrp_param_name( $DEF_VRP_PARAM );
	$self->vrp_delimiter( $DEF_VRP_DELIM );
}

######################################################################

sub site_root_dir {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SITE_ROOT_DIR} = $new_value;
	}
	return( $self->{$KEY_SITE_ROOT_DIR} );
}

######################################################################

sub system_path_delimiter {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_DELIM_SYS_PATH} = $new_value;
	}
	return( $self->{$KEY_DELIM_SYS_PATH} );
}

######################################################################

sub site_pref {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_SITE_PREFS}->{$key} = $new_value;
	}
	return( $self->{$KEY_SITE_PREFS}->{$key} );
}

######################################################################

sub site_prefs {
	my $self = shift( @_ );
	my $new_value = shift( @_ );
	if( ref( $new_value ) eq 'HASH' ) {
		$self->{$KEY_SITE_PREFS} = {%{$new_value}};
	} elsif( defined( $new_value ) ) {
		my $root = $self->{$KEY_SITE_ROOT_DIR};
		my $delim = $self->{$KEY_DELIM_SYS_PATH};
		my $filepath = "$root$delim$new_value";
		my $result = $self->get_hash_from_file( $filepath );
		if( ref($result) eq 'HASH' ) {
			$self->{$KEY_SITE_PREFS} = $result;
		} else {
			die "can't execute global prefs file '$filepath': $!";
		}
	}
	return( $self->{$KEY_SITE_PREFS} );  # returns ref
}

######################################################################

sub keywords {
	my $self = shift( @_ );
	return( @{$self->{$KEY_QUERY_PARAMS}->fetch( $PARAM_KEYWORDS )} );
}

######################################################################

sub param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_QUERY_PARAMS}->store( $key, @_ ) );
	} elsif( wantarray ) {
		my $ra_values = $self->{$KEY_QUERY_PARAMS}->fetch( $key );
		return( (ref( $ra_values ) eq 'ARRAY') ? @{$ra_values} : () );
	} else {
		return( $self->{$KEY_QUERY_PARAMS}->fetch_value( $key ) );
	}
}

######################################################################

sub append {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS}->push( @_ ) );
}

######################################################################

sub prepend {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS}->unshift( @_ ) );
}

######################################################################

sub delete {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS}->delete( @_ ) );
}

######################################################################

sub delete_all {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS}->delete_all() );
}

######################################################################

sub query_string {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS}->to_url_encoded_string() );
}

######################################################################

sub query_params {
	my $self = shift( @_ );
	return( $self->{$KEY_QUERY_PARAMS} );  # return ref to HoA
}

######################################################################

sub set_query_params {
	my $self = shift( @_ );
	my $new_value = shift( @_ );
	my $query_params;
	
	if( ref( $new_value ) eq 'GLOB' ) {
		return( $self->read_query_params( $new_value ) );
	}
	
	if( ref( $new_value ) eq 'CGI::HashOfArrays' ) {
		$query_params = $new_value->clone();

	} elsif( ref( $new_value ) eq 'HASH' ) {
		$query_params = CGI::HashOfArrays->new( 1, $new_value );
	
	} elsif( ref( $new_value ) eq 'ARRAY' ) {
		$query_params = CGI::HashOfArrays->new( 1, 
			{ $PARAM_KEYWORDS => $new_value } );

	} elsif( $new_value eq '' ) {
		$query_params = CGI::HashOfArrays->new( 1 );
	} elsif( $new_value =~ /=/ ) {
		$query_params = CGI::HashOfArrays->new( 1, $new_value );
	} else {
		$query_params = 
			CGI::HashOfArrays->new( 1, { $PARAM_KEYWORDS => 
			[split( /\s+/, $self->_url_unescape( $new_value ) )] } );
	} 
	
	$self->{$KEY_QUERY_PARAMS} = $query_params;
}

######################################################################

sub save_query_params {
	my $self = shift( @_ );
	my $fh = shift( @_ );
	return( 0 ) unless( ref( $fh ) eq 'GLOB' );
	require CGI::SequentialFile;
	my $query_file = CGI::SequentialFile->new( $fh );
	return( $query_file->write_records( 
		[$self->{$KEY_QUERY_PARAMS}] ) );
}
	
######################################################################

sub read_query_params {
	my $self = shift( @_ );
	my $fh = shift( @_ );
	return( 0 ) unless( ref( $fh ) eq 'GLOB' );
	require CGI::SequentialFile;
	my $query_file = CGI::SequentialFile->new( $fh );
	my $ra_record = $query_file->read_records( 1, 1 );
	if( $ra_record and $ra_record->[0] ) {
		$self->{$KEY_QUERY_PARAMS} = $ra_record->[0];
	} else {
		$self->{$KEY_QUERY_PARAMS} = CGI::HashOfArrays->new( 1 );
	}
	return( $query_file->is_error() ? undef : 1 );
}
	
######################################################################

sub persistant_query_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_PERSIST_PARAMS}->{$key} = $new_value;
	}
	return( $self->{$KEY_PERSIST_PARAMS}->{$key} );
}

######################################################################

sub persistant_query_params {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_PERSIST_PARAMS} = $new_value;
	}
	return( $self->{$KEY_PERSIST_PARAMS} );  # returns ref
}

######################################################################

sub script_name {
	my $self = shift( @_ );
	return( $self->_url_unescape( $ENV{'SCRIPT_NAME'} ) );
}
	
######################################################################

sub self_url {
	my $self = shift( @_ );
	my $initial_query = $self->{$KEY_INITIAL_QUERY};
	return( $self->base_url().
		($initial_query ? "?$initial_query" : '') );
}

######################################################################

sub base_url {
	my $self = shift( @_ );
	my $port = $ENV{'SERVER_PORT'} || 80;
	return( 'http://'.$self->virtual_host().
		($port != 80 ? ":$port" : '').
		$self->script_name() );
}

######################################################################

sub persistant_url {
	my $self = shift( @_ );
	my $persist_params = $self->{$KEY_QUERY_PARAMS}->clone( 
		[keys %{$self->{$KEY_PERSIST_PARAMS}}] );
	my $persist_query_str = $persist_params->to_url_encoded_string();
	return( $self->base_url().
		($persist_query_str ? "?$persist_query_str" : '') );
}

######################################################################

sub http_referer {
	my $self = shift( @_ );
	return( $self->_url_unescape( $ENV{'HTTP_REFERER'} ) );
}
	
######################################################################

sub cookie_raw {
	my $self = shift( @_ );
	return( $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'} );
}

######################################################################

sub request_method {
	my $self = shift( @_ );
	return( $ENV{'REQUEST_METHOD'} );
}
	
######################################################################

sub server_name {
	my $self = shift( @_ );
	return( $ENV{'SERVER_NAME'} || 'localhost' );
}

######################################################################

sub virtual_host {
	my $self = shift( @_ );
	return( $ENV{'HTTP_HOST'} || $self->server_name() );
}

######################################################################

sub remote_addr {
	my $self = shift( @_ );
	return( $ENV{'REMOTE_ADDR'} || '127.0.0.1' );
}

######################################################################

sub remote_host {
	my $self = shift( @_ );
	return( $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 'localhost' );
}

######################################################################

sub remote_user {
	my $self = shift( @_ );
	return( $ENV{'AUTH_USER'} || $ENV{'LOGON_USER'} || 
		$ENV{'REMOTE_USER'} || $ENV{'HTTP_FROM'} || 
		$ENV{'REMOTE_IDENT'} );
}

######################################################################

sub user_agent {
	my $self = shift( @_ );
	return( $ENV{'HTTP_USER_AGENT'} );
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

sub virtual_resource_path {
	my $self = shift( @_ );
	my $new_value = shift( @_ );
	if( ref( $new_value ) eq 'ARRAY' ) {
		$self->{$KEY_VRP_ELEMENTS} = [map { lc($_) } @{$new_value}];
		$self->{$KEY_CURR_VRP_LEV} = 0;
	} elsif( defined( $new_value ) ) {
		$self->{$KEY_VRP_ELEMENTS} = 
			[split( $self->{$KEY_VRP_DELIM}, lc( $new_value ) )];
		$self->{$KEY_CURR_VRP_LEV} = 0;
	}
	return( $self->{$KEY_VRP_ELEMENTS} );  # returns ref
}

######################################################################

sub vrp_as_string {
	my $self = shift( @_ );
	return( join( $self->{$KEY_VRP_DELIM}, @{$self->{$KEY_VRP_ELEMENTS}} ) );
}

######################################################################

sub current_vrp_level {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_CURR_VRP_LEV} = 0 + $new_value;
	}
	return( $self->{$KEY_CURR_VRP_LEV} );
}

######################################################################

sub inc_vrp_level {
	my $self = shift( @_ );
	return( ++$self->{$KEY_CURR_VRP_LEV} );
}

######################################################################

sub dec_vrp_level {
	my $self = shift( @_ );
	return( --$self->{$KEY_CURR_VRP_LEV} );
}

######################################################################

sub current_vrp_element {
	my $self = shift( @_ );
	my $curr_elem_num = $self->{$KEY_CURR_VRP_LEV};
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_VRP_ELEMENTS}->[$curr_elem_num] = $new_value;
	}
	return( $self->{$KEY_VRP_ELEMENTS}->[$curr_elem_num] );
}

######################################################################

sub higher_vrp_as_string {
	my $self = shift( @_ );
	my $curr_elem_num = $self->{$KEY_CURR_VRP_LEV};
	return( join( $self->{$KEY_VRP_DELIM}, 
		@{$self->{$KEY_VRP_ELEMENTS}}[0..($curr_elem_num-1)] ) );
}

######################################################################

sub vrp_param_name {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_VRP_PARAM} = $new_value;
	}
	return( $self->{$KEY_VRP_PARAM} );
}

######################################################################

sub vrp_delimiter {
	my $self = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_VRP_DELIM} = $new_value;
	}
	return( $self->{$KEY_VRP_DELIM} );
}

######################################################################
# Note: in order for this to work, the file must contain valid perl 
# code that, when compiled, produces a valid HASH reference.

sub get_hash_from_file {
	my $self = shift( @_ );
	my $filename = shift( @_ );
	my $result = do $filename;
	return( (ref( $result ) eq 'HASH') ? $result : undef );
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

sub send_email_message {
	my ($self, $smtp_host, $to_name, $to_email, $from_name, 
		$from_email, $subject, $body) = @_;
	$to_name    =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$to_email   =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$from_name  =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	$from_email =~ s/$EMAIL_HEADER_STRIP_PATTERN//g;
	my $smtp;

	my $error_msg = '';

	TRY: {
		eval { require Net::SMTP; };
		if( $@ ) {
			$error_msg = "can't open program module 'Net::SMTP'";
			last TRY;
		}
	
		unless( $smtp = Net::SMTP->new( $smtp_host, Timeout => 30 ) ) {
			$error_msg = "can't connect to smtp host: $smtp_host";
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

		$smtp->data();
		$smtp->datasend( <<__endquote );
From: $from_name <$from_email>
To: $to_name <$to_email>
Subject: $subject
Content-Type: text/plain; charset=us-ascii

$body
__endquote
		$smtp->dataend();

		$smtp->quit();
	}
	
	return( $error_msg );
}

######################################################################

sub _input_initial_query_string {
	my $self = shift( @_ );
	my $query_string;
	
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};

	} elsif( $ENV{'REQUEST_METHOD'} eq 'POST' ) {
		if( $ENV{'CONTENT_LENGTH'} <= $MAX_CONTENT_LENGTH ) {
			read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
		} else {
			die "POST query too large; >$MAX_CONTENT_LENGTH bytes.\n";
		}
		chomp( $query_string );

	} elsif( @ARGV ) {
		$query_string = $ARGV[0];

	} else {
		print STDERR "offline mode: enter query string on standard input\n";
		print STDERR "it must be query-escaped and all one one line\n";
		$query_string = <STDIN>;
		chomp( $query_string );
	}
	
	$self->{$KEY_INITIAL_QUERY} = $query_string;
}

######################################################################

sub _url_unescape {
	my $self = shift( @_ );
	my $str = shift( @_ );
	$str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( $str );
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
