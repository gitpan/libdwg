#!/usr/bin/perl

use strict;
use lib '/users/me/www_files/lib';
use lib 'Documents:website:www_files:lib';

my @localization = 
	($^O =~ /Mac/i) ? (
		'Documents:website:www_files:demo',
		':',
		'site_prefs.pl'
	) : (
		'/users/me/www_files/demo',
		'/',
		'site_prefs.pl'
	);

use CGI::WPM::Main;

CGI::WPM::Main->main( @localization );

1;
