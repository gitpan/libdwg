=head1 NAME

CGI::WPM::MultiPage - Perl module that is a subclass of CGI::WPM::Base and
resolves navigation for one level in the web site page hierarchy from a parent
node to its children, encapsulates and returns its childrens' returned web page
components, and can make a navigation bar to child pages.

=cut

######################################################################

package CGI::WPM::MultiPage;
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

=cut

######################################################################

use CGI::WPM::Base;
@ISA = qw(CGI::WPM::Base);

######################################################################
# Names of properties for objects of this class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_PAGE_CONTENT = 'page_content';  # hold return values
my $KEY_PAGE_ROOT_DIR = 'page_root_dir';  # root dir of support files
my $KEY_PAGE_PREFS   = 'page_prefs';    # hold our own settings
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any

# Keys for items in site global preferences:
my $GKEY_T_VRP_ID = 't_vrp_id';  # sort of like "__persist__&path="

# Keys for items in site page preferences:
my $PKEY_VRP_HANDLERS = 'vrp_handlers';  # match wpm handler to a vrp
my $PKEY_DEF_HANDLER  = 'def_handler';  # if vrp undef, which handler?
my $PKEY_MENU_ITEMS   = 'menu_items';  # items in site menu, vrp for each
my $PKEY_MENU_COLS    = 'menu_cols';  # menu divided into n cols
my $PKEY_MENU_COLWID  = 'menu_colwid';  # width of each col, in pixels
my $PKEY_MENU_SHOWDIV = 'menu_showdiv';  # show dividers btwn menu groups?
my $PKEY_MENU_BGCOLOR = 'menu_bgcolor';  # background for menu
my $PKEY_PAGE_SHOWDIV = 'page_showdiv';  # do we use HRs to sep menu?
# my $PKEY_BODY_ATTR    = 'body_attr';   handled by Base before get_page
# my $PKEY_PAGE_HEADER  = 'page_header'; handled by Base before get_page
# my $PKEY_PAGE_FOOTER  = 'page_footer'; handled by Base before get_page

# Keys for elements in $PKEY_VRP_HANDLERS hash:
my $HKEY_WPM_MODULE = 'wpm_module';  # wpm module making content
my $HKEY_WPM_SUBDIR = 'wpm_subdir';  # subdir holding wpm support files
my $HKEY_WPM_PREFS = 'wpm_prefs';  # prefs hash/fn we give to wpm mod

# Keys for elements in $PKEY_MENU_ITEMS array:
my $MKEY_MENU_NAME = 'menu_name';  # visible name appearing in site menu
my $MKEY_MENU_PATH = 'menu_path';  # vrp used in url for menu item
my $MKEY_IS_ACTIVE = 'is_active';  # is menu item enabled or not?

# Constant values used in this class go here:

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );

	$self->get_inner_wpm_content();  # puts in $webpage

	my $webpage = $self->{$KEY_PAGE_CONTENT};  # needs to go after giwc
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};

	if( $rh_prefs->{$PKEY_PAGE_SHOWDIV} ) {
		$webpage->body_prepend( "\n<HR>\n" );
		$webpage->body_append( "\n<HR>\n" );
	}

	if( ref( $rh_prefs->{$PKEY_MENU_ITEMS} ) eq 'ARRAY' ) {
		$self->attach_page_menu();
	}
}

######################################################################

sub get_inner_wpm_content {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};

	my $page_id = $globals->current_vrp_element();
	$page_id ||= $rh_prefs->{$PKEY_DEF_HANDLER};
	my $vrp_handler = $rh_prefs->{$PKEY_VRP_HANDLERS}->{$page_id};
	
	unless( ref( $vrp_handler ) eq 'HASH' ) {
		$webpage->title( '404 Page Not Found' );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but the page you requested, 
"@{[$globals->vrp_as_string()]}", doesn't seem to exist.  If you 
manually typed that address into the browser, then it is either 
outdated or you misspelled it.  If you got this error while clicking 
on one of the links on this website, then the problem is likely 
on this end.  In the latter case...</P>

@{[$self->_get_amendment_message()]}
__endquote
		return( 1 );
	}
	
	my $wpm_mod_name = $vrp_handler->{$HKEY_WPM_MODULE};
	my $wpm_sub_dir = $vrp_handler->{$HKEY_WPM_SUBDIR};
	my $wpm_prefs = $vrp_handler->{$HKEY_WPM_PREFS};
	
	$globals->inc_vrp_level();  # our handler ignores our page id

	my $root_dir = $self->{$KEY_PAGE_ROOT_DIR};
	my $sys_path_delim = $globals->system_path_delimiter();
	my $wpm_work_dir = $wpm_sub_dir ? 
		"$root_dir$sys_path_delim$wpm_sub_dir" : $root_dir;

	eval {
		# "require $wpm_mod_name;" yields can't find module in @INC error
		eval "require $wpm_mod_name;"; if( $@ ) { die $@; }

		my $wpm = $wpm_mod_name->new( $wpm_work_dir, $wpm_prefs );

		$wpm->dispatch_by_user();

		$webpage = $wpm->get_page_content();
		unless( ref( $webpage ) eq 'CGI::WPM::Content' ) {
			die "Error: $wpm_mod_name didn't return a valid ".
				"CGI::WPM::Content object\n";
		}
		
		$self->{$KEY_IS_ERROR} = $wpm->is_error();
		$self->{$KEY_PAGE_CONTENT} = $webpage;
	};

	if( $@ ) {
		$webpage->title( "Error Getting Page" );

		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error occurred while getting the requested
page.  We were unable to use the module that was supposed to 
generate the page content, named "$wpm_mod_name".</P>

@{[$self->_get_amendment_message()]}

<P>$@</P>
__endquote
	}
}

######################################################################

sub attach_page_menu {
	my $self = shift( @_ );
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	
	my $menu_table = $self->make_page_menu_table();

	$webpage->body_prepend( [$menu_table] );
	$webpage->body_append( [$menu_table] );
}

######################################################################

sub make_menu_items_html {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};
	
	my $t_vrp_id = $globals->site_pref( $GKEY_T_VRP_ID );
	my $ra_menu_items = $rh_prefs->{$PKEY_MENU_ITEMS};
	my @menu_html = ();
	
	foreach my $rh_curr_page (@{$ra_menu_items}) {
		if( ref( $rh_curr_page ) ne 'HASH' ) {
			$rh_prefs->{$PKEY_MENU_SHOWDIV} or next;
			push( @menu_html, undef );   # insert menu divider,
			next;                   
		}

		if( $rh_curr_page->{$MKEY_IS_ACTIVE} ) {
			push( @menu_html, "<A HREF=\"".
				"$t_vrp_id=$rh_curr_page->{$MKEY_MENU_PATH}".
				"\">$rh_curr_page->{$MKEY_MENU_NAME}</A>" );
			next;
		}
		
		push( @menu_html, "$rh_curr_page->{$MKEY_MENU_NAME}" );
	}
	
	return( @menu_html );
}

######################################################################

sub make_page_menu_vert {
	my $self = shift( @_ );
	my @menu_items = $self->make_menu_items_html();
	my @menu_html = ();
	my $prev_item = undef;
	foreach my $curr_item (@menu_items) {
		push( @menu_html, 
			!defined( $curr_item ) ? "<HR>\n" : 
			defined( $prev_item ) ? "<BR>$curr_item\n" : 
			"$curr_item\n" );
		$prev_item = $curr_item;
	}
	return( '<P>'.join( '', @menu_html ).'</P>' );
}

######################################################################

sub make_page_menu_horiz {
	my $self = shift( @_ );
	my @menu_items = $self->make_menu_items_html();
	my @menu_html = ();
	foreach my $curr_item (@menu_items) {
		defined( $curr_item ) or next;
		push( @menu_html, "$curr_item\n" );
	}
	return( '<P>'.join( ' | ', @menu_html ).'</P>' );
}

######################################################################

sub make_page_menu_table {
	my $self = shift( @_ );
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};
	my @menu_items = $self->make_menu_items_html();
	
	use integer;
	my $length = scalar( @menu_items );
	my $max_cols = $rh_prefs->{$PKEY_MENU_COLS};
	$max_cols <= 1 and $max_cols = 1;
	my $max_rows = $length / $max_cols + ($length % $max_cols ? 1 : 0);
	no integer;
	
	my $colwid = $rh_prefs->{$PKEY_MENU_COLWID};
	$colwid and $colwid = " WIDTH=\"$colwid\"";
	
	my $bgcolor = $rh_prefs->{$PKEY_MENU_BGCOLOR};
	$bgcolor and $bgcolor = " BGCOLOR=\"$bgcolor\"";
	
	my @table_lines = ();
	
	push( @table_lines, "<TABLE BORDER=0 CELLSPACING=0 ".
		"CELLPADDING=10 ALIGN=\"center\">\n<TR>\n" );
	
	foreach my $col_num (1..$max_cols) {
		my $prev_item = undef;
		my @cell_lines = ();
		my @cell_items = splice( @menu_items, 0, $max_rows ) or last;
		foreach my $curr_item (@cell_items) {
			push( @cell_lines, 
				!defined( $curr_item ) ? "<HR>\n" : 
				defined( $prev_item ) ? "<BR>$curr_item\n" : 
				"$curr_item\n" );
			$prev_item = $curr_item;
		}
		push( @table_lines,
			"<TD ALIGN=\"left\" VALIGN=\"top\"$bgcolor$colwid>\n",
			@cell_lines, "</TD>\n" );
	}
	
	push( @table_lines, "</TR>\n</TABLE>\n" );

	return( join( '', @table_lines ) );
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
