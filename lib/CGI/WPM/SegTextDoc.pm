=head1 NAME

CGI::WPM::SegTextDoc - Perl module that is a subclass of CGI::WPM::Base and
displays a static text page, which can be in multiple segments.

=cut

######################################################################

package CGI::WPM::SegTextDoc;
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
	CGI::WPM::Static

=cut

######################################################################

use CGI::WPM::Base;
@ISA = qw(CGI::WPM::Base);
use CGI::WPM::Static;

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
my $PKEY_TITLE = 'title';        # title of the document
my $PKEY_AUTHOR = 'author';      # who made the document
my $PKEY_CREATED = 'created';    # date and number of first version
my $PKEY_UPDATED = 'updated';    # date and number of newest version
my $PKEY_FILENAME = 'filename';  # common part of filename for pieces
my $PKEY_SEGMENTS = 'segments';  # number of pieces doc is in

# Constant values used in this class go here:

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};
	
	my $segments = $rh_prefs->{$PKEY_SEGMENTS};
	$segments >= 1 or $rh_prefs->{$PKEY_SEGMENTS} = $segments = 1;

	my $curr_seg_num = $globals->current_vrp_element();
	$curr_seg_num >= 1 or $curr_seg_num = 1;
	$curr_seg_num <= $segments or $curr_seg_num = $segments;
	$globals->current_vrp_element( $curr_seg_num );
	
	$self->get_curr_seg_content();
	if( $segments > 1 ) {
		$self->attach_document_navbar();
	}
	$self->attach_document_header();
}

######################################################################

sub get_curr_seg_content {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};

	my ($base, $ext) = ($rh_prefs->{$PKEY_FILENAME} =~ m/^([^\.]*)(.*)$/);
	my $seg_num_str = $rh_prefs->{$PKEY_SEGMENTS} > 1 ?
		'_'.sprintf( "%3.3d", $globals->current_vrp_element() ) : '';

	my $wpm_prefs = {
		filename => "$base$seg_num_str$ext",
		is_text => 1,
	};

	my $root_dir = $self->{$KEY_PAGE_ROOT_DIR};
	my $sys_path_delim = $globals->system_path_delimiter();
	my $wpm_work_dir = $rh_prefs->{$PKEY_SEGMENTS} > 1 ?
		"$root_dir$sys_path_delim$base" : $root_dir;

	my $wpm = CGI::WPM::Static->new( $wpm_work_dir, $wpm_prefs );
	$wpm->dispatch_by_user();
	my $webpage = $wpm->get_page_content();
		
	$self->{$KEY_IS_ERROR} = $wpm->is_error();
	$self->{$KEY_PAGE_CONTENT} = $webpage;
}

######################################################################

sub attach_document_navbar {
	my $self = shift( @_ );
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};

	my $segments = $rh_prefs->{$PKEY_SEGMENTS};
	my $curr_seg_num = $globals->current_vrp_element();

	my $common_url = $globals->site_pref( $GKEY_T_VRP_ID ).'='.
		$globals->higher_vrp_as_string().$globals->vrp_delimiter();
		
	my @seg_list_html = ();

	foreach my $seg_num (1..$segments) {
		if( $seg_num == $curr_seg_num ) {
			push( @seg_list_html, "$seg_num\n" );
		} else {
			push( @seg_list_html, 
				"<A HREF=\"$common_url$seg_num\">$seg_num</A>\n" );
		}
	}
	
	my $prev_seg_html = ($curr_seg_num == 1) ? "Previous\n" :
		"<A HREF=\"$common_url@{[$curr_seg_num-1]}\">Previous</A>\n";
	
	my $next_seg_html = ($curr_seg_num == $segments) ? "Next\n" :
		"<A HREF=\"$common_url@{[$curr_seg_num+1]}\">Next</A>\n";
	
	my $document_navbar =
		<<__endquote.
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=10><TR>
 <TD>$prev_seg_html</TD><TD ALIGN="center">
__endquote

		join( ' | ', @seg_list_html ).

		<<__endquote;
 </TD><TD>$next_seg_html</TD>
</TR></TABLE>
__endquote

	$webpage->body_prepend( [$document_navbar] );
	$webpage->body_append( [$document_navbar] );
}

######################################################################

sub attach_document_header {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $rh_prefs = $self->{$KEY_PAGE_PREFS};

	my $title = $rh_prefs->{$PKEY_TITLE};
	my $author = $rh_prefs->{$PKEY_AUTHOR};
	my $created = $rh_prefs->{$PKEY_CREATED};
	my $updated = $rh_prefs->{$PKEY_UPDATED};
	my $segments = $rh_prefs->{$PKEY_SEGMENTS};
	
	my $curr_seg_num = $globals->current_vrp_element();
	$title .= $segments > 1 ? ": $curr_seg_num / $segments" : '';
	
	$webpage->title( $title );

	$webpage->body_prepend( <<__endquote );
<H2>@{[$webpage->title()]}</H2>

<P>Author: $author<BR>
Created: $created<BR>
Updated: $updated</P>
__endquote
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
