=head1 NAME

CGI::WPM::Usage - Perl module that is a subclass of CGI::WPM::Base and tracks
site usage details, as well as e-mail backups of usage counts to the site owner.

=cut

######################################################################

package CGI::WPM::Usage;
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

	CGI::WPM::Base
	CGI::WPM::Content
	CGI::WPM::Globals
	CGI::EventCountFile 1.01

=cut

######################################################################

use CGI::WPM::Base;
@ISA = qw(CGI::WPM::Base);

######################################################################
# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_PAGE_CONTENT = 'page_content';  # hold return values

# Keys for items in site page preferences:
my $PKEY_WPM_MODULE = 'wpm_module'; # wpm module making content
my $PKEY_WPM_SUBDIR = 'wpm_subdir'; # subdir holding wpm support files
my $PKEY_WPM_PREFS  = 'wpm_prefs';  # prefs hash/fn we give to wpm mod
my $PKEY_LOG_USAGE  = 'log_usage';  # true if we should log usage
my $PKEY_USG_SUBDIR = 'usg_subdir'; # subdir holding usg support files
my $PKEY_USG_SUB_DG = 'usg_sub_dg'; # subdir for usg logs when debugging
my $PKEY_USG_PREFS  = 'usg_prefs';  # prefs hash/fn we give to usg mod

# Keys for items in $PKEY_USG_PREFS preference:

my $UKEY_SITE_URLS = 'site_urls'; # list urls site is, no qs
	# This is useful, for example, to treat 'www' or prefixless versions 
	# of this site's url as being one and the same.  Include 'http://'.
	# Don't worry about case, as urls are automatically lowercased.
my $UKEY_ENV_MISC   = 'env_misc'; # name misc env variables to watch

# These are names of files we store usage data in.
my $UKEY_FN_DCM      = 'fn_dcm'; # filename for "date counts mailed" record
my $UKEY_FN_ENV_MISC = 'fn_env_misc'; # misc env variables go in here
	# Generally only ENVs with a low distribution of values go here.
my $UKEY_FN_SITE_VRP = 'fn_site_vrp'; # virtual resource paths go in here
my $UKEY_FN_RED_URLS = 'fn_red_urls'; # urls we redirect to go in here
my $UKEY_FN_REF_URLS = 'fn_ref_urls'; # urls that refer to us go in here
	# note that urls for common search engines are omitted here, go next
	# remaining urls keep their query strings, for now
my $UKEY_FN_REF_SEUL = 'fn_ref_seul'; # urls for ref common search engines
	# note that search engine query strings are removed here, go next
my $UKEY_FN_REF_SEKW = 'fn_ref_sekw'; # keywords used in sea eng ref url
	# note that only se are counted, normal site kw kept with their urls
my $UKEY_FN_REF_JUNK = 'fn_ref_junk'; # urls such as news:// go only here
	# note that once each day's worth is delivered, it gets wiped
#my $UKEY_FN_REF_ISNW = 'fn_ref_isnw'; # if called by isindex query, kw

# These tokens are stored in the count files as extra "events", which 
# happen to be totals of something or other.  TOTAL is incremented with 
# every page hit.  NIL is used when the event is an empty string. 
# During any hit, a single one of the REF tokens is incremented as it 
# best fits the referring url.  REF tokens are stored in every REF file 
# that they complement, such that between the normal file values and the 
# REFs and NIL, the counts all add up to TOTAL.
my $UKEY_T_TOTAL    = 't_total';    # token counts number of file updates
my $UKEY_T_NIL      = 't_nil';      # token counts number of '' values
my $UKEY_T_REF_SELF = 't_ref_self'; # indicates referer was same site
my $UKEY_T_REF_URLS = 't_ref_urls'; # referer was a normal,non-se site
my $UKEY_T_REF_SEUL = 't_ref_seul'; # referer was a search engine
my $UKEY_T_REF_JUNK = 't_ref_junk'; # someone read their e-mail/news in wb

# Constant values used in this class go here:

# This hash stores domain parts for common search engines in the keys, 
# and its values are names of query params that hold the keywords.
# They are all lowercased here for simplicity.  It's not complete, but I 
# learned these engines because they linked to my web site.
my %SEARCH_ENGINE_TERMS = (  # match keys against domains proper only
	altavista => 'q',
	aol => 'query',
	'cnet.com' => 'qt',
	'dmoz.org' => 'search',
	excite => 'search',
	'google.com' => 'q',
	'hotbot.lycos.com' => 'mt',
	icq => 'query',
	'icqit.com' => 'query',
	'iwon.com' => 'searchfor',
	'l2g.com' => 'search',
	looksmart => 'key',
	msn => ['q','mt'],
	netscape => 'search',
	'search.com' => 'q',
	'search.dogpile.com' => 'q',
	'simplesearch.com' => 'search',
	snap => 'keyword',
	'webcrawler.com' => 'searchtext',
	'websearch.cs.com' => 'sterm',
	yahoo => 'p',
);

# if referring url contains these anywhere, it goes in ref junk
my @JUNK = qw(
	^(?!http://)
	deja.com
	hotmail 
	egroups 
	mail.chek.com 
	mail.yahoo.com/ym/showletter
	/cgi-bin/linkrd
);

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $globals->site_prefs();

	$rh_prefs->{$PKEY_WPM_PREFS} ||= {};
	$rh_prefs->{$PKEY_USG_SUB_DG} ||= 'usage_debug'; # diff than usage
	$rh_prefs->{$PKEY_USG_PREFS} ||= {};

	if( defined( $rh_prefs->{$PKEY_WPM_MODULE} ) ) {
		$self->get_inner_wpm_content();  # puts in $webpage
	} else {   # we're only being a hit counter, and nothing else
		$self->{$KEY_PAGE_CONTENT} = CGI::WPM::Content->new();
	}

	unless( $globals->site_pref( $PKEY_LOG_USAGE ) ) {
		return( 1 );  # our work here is done if no logs to keep
	}
	
	eval { require CGI::EventCountFile; };
	if( $@ ) { 
		$globals->add_error( "can't use module 'CGI::EventCountFile': $@\n" );
		return( 0 );
	}

	$globals->move_site_prefs( $rh_prefs->{$PKEY_USG_PREFS} );
	$globals->move_current_srp( $globals->is_debug() ? 
		$rh_prefs->{$PKEY_USG_SUB_DG} : $rh_prefs->{$PKEY_USG_SUBDIR} );

	$self->set_default_usage_prefs();

	$self->mail_me_and_reset_counts_if_new_day();
	
	$self->update_site_usage_counts();

	# Note that we don't presently print hit counts to the webpage.
	# But that'll likely be added later, along with web usage reports.

	$globals->restore_site_prefs();
	$globals->restore_last_srp();
}

######################################################################

sub get_inner_wpm_content {
	my $self = shift( @_ );
	my $webpage;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $wpm_prefs = $globals->site_prefs();

	my $wpm_mod_name = $wpm_prefs->{$PKEY_WPM_MODULE};

	$globals->move_current_srp( $wpm_prefs->{$PKEY_WPM_SUBDIR} );
	$globals->move_site_prefs( $wpm_prefs->{$PKEY_WPM_PREFS} );

	eval {
		# "require $wpm_mod_name;" yields can't find module in @INC error
		eval "require $wpm_mod_name;"; if( $@ ) { die $@; }

		unless( $wpm_mod_name->isa( 'CGI::WPM::Base' ) ) {
			die "Error: $wpm_mod_name isn't a subclass of ".
				"CGI::WPM::Base, so I don't know how to use it\n";
		}

		my $wpm = $wpm_mod_name->new( $globals );

		$wpm->dispatch_by_user();

		$webpage = $wpm->get_page_content();

		unless( ref( $webpage ) eq 'CGI::WPM::Content' ) {
			die "Error: $wpm_mod_name didn't return a valid ".
				"CGI::WPM::Content object so I can't use it\n";
		}
	};

	$globals->restore_site_prefs();
	$globals->restore_last_srp();

	if( $@ ) {
		$globals->add_error( "can't use module '$wpm_mod_name': $@\n" );
	
		$webpage = CGI::WPM::Content->new();

		$webpage->title( 'Error Getting Page' );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error occurred while getting the requested
page.  We were unable to use the module that was supposed to 
generate the page content, named "$wpm_mod_name".</P>

@{[$self->_get_amendment_message()]}

<P>$@</P>
__endquote
	}

	$self->{$KEY_PAGE_CONTENT} = $webpage;
}

######################################################################

sub set_default_usage_prefs {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $usg_prefs = $globals->site_pref( $PKEY_USG_PREFS );

	$usg_prefs->{$UKEY_ENV_MISC} ||= [qw(
		DOCUMENT_ROOT GATEWAY_INTERFACE
		HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
		HTTP_ACCEPT_LANGUAGE HTTP_CONNECTION HTTP_HOST
		REQUEST_METHOD 
		SCRIPT_FILENAME SCRIPT_NAME
		SERVER_ADMIN SERVER_NAME SERVER_PORT SERVER_PROTOCOL SERVER_SOFTWARE
	)];
	ref( $usg_prefs->{$UKEY_ENV_MISC} ) eq 'ARRAY' or 
		$usg_prefs->{$UKEY_ENV_MISC} = [$usg_prefs->{$UKEY_ENV_MISC}];

	$usg_prefs->{$UKEY_SITE_URLS} ||= [];
	ref( $usg_prefs->{$UKEY_SITE_URLS} ) eq 'ARRAY' or 
		$usg_prefs->{$UKEY_SITE_URLS} = [$usg_prefs->{$UKEY_SITE_URLS}];
	unshift( @{$usg_prefs->{$UKEY_SITE_URLS}}, $globals->base_url() );

	$usg_prefs->{$UKEY_FN_DCM} ||= 'date_counts_mailed.txt';
	$usg_prefs->{$UKEY_FN_ENV_MISC} ||= 'env.txt';
	$usg_prefs->{$UKEY_FN_SITE_VRP} ||= 'site_vrp.txt';
	$usg_prefs->{$UKEY_FN_RED_URLS} ||= 'redirect_urls.txt';
	$usg_prefs->{$UKEY_FN_REF_URLS} ||= 'ref_urls.txt';
	$usg_prefs->{$UKEY_FN_REF_SEUL} ||= 'ref_se_urls.txt';
	$usg_prefs->{$UKEY_FN_REF_SEKW} ||= 'ref_se_keywords.txt';
	$usg_prefs->{$UKEY_FN_REF_JUNK} ||= 'ref_junk.txt';

	$usg_prefs->{$UKEY_T_TOTAL} ||= '__total__';
	$usg_prefs->{$UKEY_T_NIL} ||= '__nil__';
	$usg_prefs->{$UKEY_T_REF_SELF} ||= '__self_reference__';
	$usg_prefs->{$UKEY_T_REF_URLS} ||= '__normal_website_ref__';
	$usg_prefs->{$UKEY_T_REF_SEUL} ||= '__search_engine_ref__';
	$usg_prefs->{$UKEY_T_REF_JUNK} ||= '__email_or_news_ref__';
}

######################################################################

sub mail_me_and_reset_counts_if_new_day {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $usg_prefs = $globals->site_pref( $PKEY_USG_PREFS );

	$globals->add_no_error();
	my $dcm_file = CGI::EventCountFile->new( 
		$globals->phys_filename_string( $usg_prefs->{$UKEY_FN_DCM} ), 1 );
	$dcm_file->open_and_lock( 1 ) or do {
		$globals->add_error( $dcm_file->is_error() );
		return( 0 );
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

	my @mail_body = ();

	my @fns_aggregate = map { $usg_prefs->{$_} } 
		($UKEY_FN_ENV_MISC, $UKEY_FN_SITE_VRP, $UKEY_FN_RED_URLS, 
		$UKEY_FN_REF_URLS, $UKEY_FN_REF_SEUL, $UKEY_FN_REF_SEKW);

	foreach my $filename (@fns_aggregate) {
		my $count_file = CGI::EventCountFile->new( 
			$globals->phys_filename_string( $filename ), 1 );
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

	my @fns_clear_daily = map { $usg_prefs->{$_} } ($UKEY_FN_REF_JUNK);

	foreach my $filename (@fns_clear_daily) {
		my $count_file = CGI::EventCountFile->new( 
			$globals->phys_filename_string( $filename ), 1 );
		$count_file->open_and_lock( 1 ) or do {
			push( @mail_body, "\n\n".$count_file->is_error()."\n" );
			next;
		};
		$count_file->read_all_records();
		push( @mail_body, "\n\ncontent of '$filename':\n\n" );
		push( @mail_body, $count_file->get_sorted_file_content() );
		$count_file->delete_all_keys();
		$count_file->write_all_records();
		$count_file->unlock_and_close();
	}

	my ($today_str) = ($globals->today_date_utc() =~ m/^(\S+)/ );

	my $err_msg = $globals->send_email_message(
		$globals->site_owner_name(),
		$globals->site_owner_email(),
		$globals->site_owner_name(),
		$globals->site_owner_email(),
		$globals->site_title()." -- Usage to $today_str",
		join( '', @mail_body ),
		<<__endquote,
This is a daily copy of the site usage count logs.
The first visitor activity on $today_str has just occurred.
__endquote
	);

	if( $err_msg ) {
		$globals->add_error( "can't e-mail usage counts: $err_msg" );
	}
}

######################################################################

sub update_site_usage_counts {
	my $self = shift( @_ );
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $usg_prefs = $globals->site_pref( $PKEY_USG_PREFS );
	
	# save miscellaneous low-distribution environment vars
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_ENV_MISC}, 
		(map { "\$ENV{$_} = \"$ENV{$_}\"" } 
		@{$usg_prefs->{$UKEY_ENV_MISC}}) );
	
	# save which page within this site was hit
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_SITE_VRP}, 
		lc( $globals->user_vrp_string() ) );
	
	# save which url this site referred the visitor to, if any
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_RED_URLS}, 
		lc( $webpage->redirect_url() ) );
	
	# save which url had referred visitors to this site
	my (@ref_urls, @ref_seul, @ref_sekw, @ref_junk);

	SWITCH: {
		my $referer = lc( $globals->http_referer() );
		my ($ref_filename, $query) = split( /\?/, $referer, 2 );
		$ref_filename =~ s|/$||;     # lose trailing "/"s
		$referer = ($query =~ /[a-zA-Z0-9]/) ? 
			"$ref_filename?$query" : $ref_filename;
		$ref_filename =~ m|^http://([^/]+)(.*)|;
		my ($domain, $path) = ($1, $2);
		
		# first check if visitor is moving within our own site
		foreach my $synonym (@{$usg_prefs->{$UKEY_SITE_URLS}}) {
			if( $ref_filename eq lc($synonym) ) {
				push( @ref_urls, $usg_prefs->{$UKEY_T_REF_SELF} );
				push( @ref_seul, $usg_prefs->{$UKEY_T_REF_SELF} );
				push( @ref_sekw, $usg_prefs->{$UKEY_T_REF_SELF} );
				push( @ref_junk, $usg_prefs->{$UKEY_T_REF_SELF} );
				last SWITCH;
			}
		}

		# else check if visitor came from checking an e-mail online
		foreach my $ident (@JUNK) {
			if( $ref_filename =~ m|$ident| ) {
				push( @ref_urls, $usg_prefs->{$UKEY_T_REF_JUNK} );
				push( @ref_seul, $usg_prefs->{$UKEY_T_REF_JUNK} );
				push( @ref_sekw, $usg_prefs->{$UKEY_T_REF_JUNK} );
				push( @ref_junk, $referer );
				last SWITCH;
			}
		}
		
		# else check if the referring domain is a search engine
		foreach my $dom_frag (keys %SEARCH_ENGINE_TERMS) {
			if( $domain =~ m|$dom_frag| ) {
				my $se_query = CGI::HashOfArrays->new( 1, $query );
				my @se_keywords;
				
				my $kwpn = $SEARCH_ENGINE_TERMS{$dom_frag};
				my @kwpn = ref($kwpn) eq 'ARRAY' ? @{$kwpn} : $kwpn;
				foreach my $query_param (@kwpn) {
					push( @se_keywords, split( /\s+/, 
						$se_query->fetch_value( $query_param ) ) );
				}

				# save both the file name and the search words used
				push( @ref_urls, $usg_prefs->{$UKEY_T_REF_SEUL} );
				push( @ref_seul, $ref_filename );
				push( @ref_sekw, @se_keywords );
				push( @ref_junk, $usg_prefs->{$UKEY_T_REF_SEUL} );
				last SWITCH;
			}
		}

		# otherwise, referer is probably a normal web site
		push( @ref_urls, $referer );
		push( @ref_seul, $usg_prefs->{$UKEY_T_REF_URLS} );
		push( @ref_sekw, $usg_prefs->{$UKEY_T_REF_URLS} );
		push( @ref_junk, $usg_prefs->{$UKEY_T_REF_URLS} );
	}
	
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_REF_URLS}, 
		@ref_urls );
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_REF_SEUL}, 
		@ref_seul );
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_REF_SEKW}, 
		@ref_sekw );
	$self->update_one_count_file( $usg_prefs->{$UKEY_FN_REF_JUNK}, 
		@ref_junk );
}

######################################################################

sub update_one_count_file {
	my ($self, $filename, @keys_to_inc) = @_;
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $usg_prefs = $globals->site_pref( $PKEY_USG_PREFS );

	push( @keys_to_inc, $usg_prefs->{$UKEY_T_TOTAL} );

	my $count_file = CGI::EventCountFile->new( 
		$globals->phys_filename_string( $filename ), 1 );
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
