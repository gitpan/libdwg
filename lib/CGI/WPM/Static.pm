=head1 NAME

CGI::WPM::Static - Perl module that is a subclass of CGI::WPM::Base and displays
a static HTML page.

=cut

######################################################################

package CGI::WPM::Static;
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
# Names of properties for objects of parent class are declared here:
my $KEY_SITE_GLOBALS = 'site_globals';  # hold global site values
my $KEY_PAGE_CONTENT = 'page_content';  # hold return values
my $KEY_PAGE_PREFS   = 'page_prefs';    # hold our own settings
my $KEY_IS_ERROR     = 'is_error';      # holds error string, if any

# Keys for items in site global preferences:

# Keys for items in site page preferences:
my $PKEY_FILENAME = 'filename';  # name of file we will open
my $PKEY_IS_TEXT  = 'is_text';   # true if file is not html, but text
my $PKEY_TITLE = 'title';  # title for this document

# Constant values used in this class go here:

######################################################################
# This is provided so CGI::WPM::Base->dispatch_by_user() can call it.

sub _dispatch_by_user {
	my $self = shift( @_ );
	my $globals = $self->{$KEY_SITE_GLOBALS};
	my $webpage = $self->{$KEY_PAGE_CONTENT};
	my $filename = $self->{$KEY_PAGE_PREFS}->{$PKEY_FILENAME};
	my $filepath = $self->_prepend_path( $filename );
	my $is_text = $self->{$KEY_PAGE_PREFS}->{$PKEY_IS_TEXT};
	my $title = $self->{$KEY_PAGE_PREFS}->{$PKEY_TITLE};

	SWITCH: {
		$self->{$KEY_IS_ERROR} = undef;

		open( STATIC, "<$filepath" ) or do {
			$self->_make_filesystem_error( $filepath, "open" );
			last SWITCH;
		};
		local $/ = undef;
		defined( my $file_content = <STATIC> ) or do {
			$self->_make_filesystem_error( $filepath, "read from" );
			last SWITCH;
		};
		close( STATIC ) or do {
			$self->_make_filesystem_error( $filepath, "close" );
			last SWITCH;
		};
		
		if( $is_text ) {
			$file_content =~ s/&/&amp;/g;  # do some html escaping
			$file_content =~ s/\"/&quot;/g;
			$file_content =~ s/>/&gt;/g;
			$file_content =~ s/</&lt;/g;
		
			$webpage->body_content( 
				[ "\n<PRE>\n", $file_content, "\n</PRE>\n" ] );
			$webpage->title( $title );
		
		} elsif( $file_content =~ m|<BODY[^>]*>(.*)</BODY>|si ) {
			$webpage->body_content( $1 );
			if( $file_content =~ m|<TITLE>(.*)</TITLE>|si ) {
				$webpage->title( $1 );
			}
		} else {
			$webpage->body_content( $file_content );
			$webpage->title( $title );
		}	
	}

	if( $self->{$KEY_IS_ERROR} ) {
		$webpage->title( 'Error Opening Page' );
		$webpage->body_content( <<__endquote );
<H2 ALIGN="center">@{[$webpage->title()]}</H2>

<P>I'm sorry, but an error has occurred while trying to open 
the page you requested, which is in the file "$filename".</P>  

@{[$self->_get_amendment_message()]}

<P>Details: $self->{$KEY_IS_ERROR}</P>
__endquote
	}
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
