#!/usr/bin/perl

use strict;

######################################################################
# These could be considered "global preferences" but they are 
# included in this file for brevity.

my $WPM_MODULE = 'CGI::WPM::Usage';
my $WPM_SUBDIR = '';
my $WPM_PREFS = {
	log_usage => 1,
	usg_subdir => 'usage',
	usg_dg_sub => 'usage_debug',
	usg_prefs => {},
};

######################################################################
# Note that this program is based on one that I use at my old web
# site location after I changed my address, such that visitors going 
# to the old address get redirected to the new one, but see a quick 
# message as well.  Usage is counted here so I know who I need to ask 
# to change their links to my site.  The redirect goes out irregardless 
# of whether there was a failure in the usage section.

eval { main(); };

print STDOUT <<__endquote;
Content-Type: text/html

<META HTTP-EQUIV="refresh" CONTENT="0; URL=http://www.sample.com">
<H2><A HREF="http://www.sample.com">http://www.sample.com</A></H2>
__endquote

######################################################################

sub main {
	use lib '/users/me/www_files/lib';

	require CGI::WPM::Content;
	require CGI::WPM::Globals;
	require CGI::WPM::Base;

	my $webpage;
	my $globals = CGI::WPM::Globals->new();

	if( $globals->user_input_param( 'debugging' ) eq 'on' ) {
		$globals->is_debug( 1 );
		$globals->persistant_user_input_param( 'debugging', 1 );
	}

	$globals->site_root_dir( '/users/me/www_files/demos/redirector' );
	$globals->system_path_delimiter( '/' );

	$globals->user_vrp( lc( $globals->user_input_param( 
		$globals->vrp_param_name( 'path' ) ) ) );
	$globals->current_user_vrp_level( 1 );
	
	$globals->site_title( 'Sample Website By WPM' );
	$globals->site_owner_name( 'John Sample' );
	$globals->site_owner_email( 'john@sample.net' );

	$globals->move_current_srp( $WPM_SUBDIR );
	$globals->move_site_prefs( $WPM_PREFS );

	eval {
		# "require $WPM_MODULE;" yields can't find module in @INC error
		eval "require $WPM_MODULE;"; if( $@ ) { die $@; }

		unless( $WPM_MODULE->isa( 'CGI::WPM::Base' ) ) {
			die "Error: $WPM_MODULE isn't a subclass of ".
				"CGI::WPM::Base, so I don't know how to use it\n";
		}

		my $wpm = $WPM_MODULE->new( $globals );

		$wpm->dispatch_by_user();

		$webpage = $wpm->get_page_content();

		unless( ref( $webpage ) eq 'CGI::WPM::Content' ) {
			die "Error: $WPM_MODULE didn't return a valid ".
				"CGI::WPM::Content object so I can't use it\n";
		}
	};
}

1;
