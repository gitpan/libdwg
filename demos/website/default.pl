#!/usr/bin/perl

use strict;

######################################################################
# These could be considered "global preferences" but they are 
# included in this file for brevity.

my $WPM_MODULE = 'CGI::WPM::Usage';
my $WPM_SUBDIR = '';
my $WPM_PREFS = {
	wpm_module => 'CGI::WPM::MultiPage',
	wpm_subdir => 'content',
	wpm_prefs => 'content_prefs.pl',
	log_usage => 1,
	usg_subdir => 'usage',
	usg_dg_sub => 'usage_debug',
	usg_prefs => {
		site_urls => [qw(
			http://www.sample.net
			http://sample.net
			http://www.sample.net/default.pl
			http://sample.net/default.pl
			http://www.sample.net:80
			http://sample.net:80
			http://www.sample.net:80/default.pl
			http://sample.net:80/default.pl
		)],
	},
};

######################################################################
# This program is based on both of my personal web sites.

eval { main(); };

if( $@ ) { 
	print STDERR "fatal program error: $@\n";
	
	print STDOUT <<__endquote;
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<HTML><HEAD>
<TITLE>Fatal Program Error</TITLE>
</HEAD><BODY>

<H1>Fatal Program Error</H1>

<P>I'm sorry, but a fatal error has occurred that prevents this 
program from continuing further.  It is possible that a critical 
section of this web site was being updated at the moment, and that it 
will resolve itself shortly.  Otherwise please contact the site 
administrator (john\@sample.net) to have the problem resolved.</P>

$@

</BODY>
</HTML>
__endquote
}

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

	$globals->site_root_dir( '/users/me/www_files/demos/website' );
	$globals->system_path_delimiter( '/' );

	$globals->user_vrp( lc( $globals->user_input_param( 
		$globals->vrp_param_name( 'path' ) ) ) );
	$globals->current_user_vrp_level( 1 );
	
	$globals->site_title( 'Sample Website By WPM' );
	$globals->site_owner_name( 'John Sample' );
	$globals->site_owner_email( 'john@sample.net' );
	$globals->site_owner_email_vrp( '/mailme' );

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

	if( $@ ) {
		print STDERR "can't use module '$WPM_MODULE': $@\n";
	
		$webpage = CGI::WPM::Content->new();

		$webpage->title( 'Error Getting Page' );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error occurred while getting the requested
page.  We were unable to use the module that was supposed to 
generate the page content, named "$WPM_MODULE".</P>

<P>It is possible that a critical section of this web site was being 
updated at the moment, and that it will resolve itself shortly.  
Otherwise please contact the site administrator 
(john\@sample.net) to have the problem resolved.</P>

<P>$@</P>
__endquote
	}

	if( $globals->is_debug() ) {
		$webpage->body_append( <<__endquote );
<P>Debugging is currently turned on.</P>
__endquote
	}

	$webpage->add_later_replace( { 
		__mailme_url__ => "__vrp_id__=/mailme",
		__external_id__ => "__vrp_id__=/external&url",
	} );

	$webpage->add_later_replace( { 
		__vrp_id__ => $globals->persistant_vrp_url(),
	} );

	print STDOUT $webpage->to_string();
	
	if( my @errs = $globals->get_errors() ) {
		foreach my $i (0..$#errs) {
			chomp( $errs[$i] );  # save on duplicate "\n"s
			print STDERR "Globals->get_error($i): $errs[$i]\n";
		}
	}
}

1;
