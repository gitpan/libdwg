=head1 NAME

CGI::EventCountFile - Perl module that interfaces to a tab-delimited text file
for storing date-bounded counts of occurances for multiple events, such as web
page views.

=cut

######################################################################

package CGI::EventCountFile;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '1.01';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	Fcntl

=head2 Nonstandard Modules

	I<none>

=cut

######################################################################

use Fcntl qw(:DEFAULT :flock);

######################################################################

=head1 SYNOPSIS

	use CGI::EventCountFile;
	
	MAIN: {
		$self->mail_me_and_reset_counts_if_new_day( "counts.txt" );

		$self->update_one_count_file( "counts.txt", 
			(map { "\$ENV{$_} = \"$ENV{$_}\"" } qw(
			REQUEST_METHOD SERVER_NAME SCRIPT_FILENAME
			HTTP_HOST SCRIPT_NAME SERVER_SOFTWARE HTTP_REFERER )
		) );
	}

	sub update_one_count_file {
		my ($self, $file_path, @keys_to_inc) = @_;

		push( @keys_to_inc, '__total__' );

		my $count_file = IO::EventCountFile->new( $file_path, 1 );
		$count_file->open_and_lock( 1 ) or return( 0 );
		$count_file->read_all_records();

		foreach my $key (@keys_to_inc) {
			$key eq '' and $key = '__nil__';
			$count_file->key_increment( $key );
		}

		$count_file->write_all_records();
		$count_file->unlock_and_close();
	}
	
	sub mail_me_and_reset_counts_if_new_day {
		my ($self, $file_path) = @_;
	
		my $dcm_file = IO::EventCountFile->new( $file_path, 1 );
		$dcm_file->open_and_lock( 1 ) or do {
			print "<!-- ".$dcm_file->is_error()." -->\n";
			return( undef );
		};
		$dcm_file->read_all_records();
		if( $dcm_file->key_was_incremented_today( '__total__' ) ) {
			$dcm_file->unlock_and_close();
			return( 1 );
		}
		$dcm_file->key_increment( '__total__' );
		$dcm_file->set_all_day_counts_to_zero();
		$dcm_file->write_all_records();
		$dcm_file->unlock_and_close();
		
		my @mail_body = ();
		push( @mail_body, "\n\ncontent of '$file_path':\n\n" );
		push( @mail_body, $dcm_file->get_sorted_file_content() );
		
		open(MAIL, "|/usr/lib/sendmail -t") or do {
			print "<!-- sendmail can't send daily usage info -->\n";
			return( undef );
		};
		print MAIL "To: site_owner\@their_host\n";
		print MAIL "From: spying anonymous <spy\@anonymous>\n";
		print MAIL "Subject: daily hit count update\n\n";
		print MAIL "@mail_body\n\n";
		close (MAIL);
	}

=head1 DESCRIPTION

This Perl 5 object class provides an easy-to-use interface for a plain text file
format that is capable of storing an unordered list of events.  Each event is
identified by a string and has 4 attributes: date of first and last occurances,
count of all occurances between first and last, count of only today's occurances.

A common use for this class is to track web site usage.  Usage events that can be
counted include: which site pages were viewed, which external urls we redirect
visitors to, which external urls have a link to us (that were used), which
internal site pages had links that were clicked on to go to other pages, which
web browsers the visitors are using, where the visitors are from, and
miscellaneous environment details like GET vs POST vs HEAD requests.  However,
events can be anything at all that we want to keep counts of.

This class is designed to facilitate ease of compiling and sorting count
information for being e-mailed to the site owner once per day for backup/report
purposes.

All event names have control characters (ascii 0 thru 31) removed prior to
storage, so they don't interfere with file parsing; no escaping is done to
preserve binary values as it is assumed they won't be used.  Event names can be
any length.

Dates are all stored in ISO 8601 format ("1994-02-03 14:15:29") with precision to
the second, and dates are all in Universal Coordinated Time (UTC), aka Greenwich
Mean Time (GMT).  It is assumed that any dates provided using key_store are in
UTC and formatted as ISO 8601 (six numbers in descending order of importance). 
That format allows for dates to be easily string-sorted without parsing.  If you
want to display in another time zone, you must do the conversion externally.

=head1 FILE FORMAT EXAMPLE

	/guestbook	2000-05-16 12:31:41 UTC	2000-05-30 11:36:55 UTC	16	0
	/guestbook/sign	2000-05-16 20:37:25 UTC	2000-05-30 11:36:32 UTC	7	0
	/links	2000-05-16 14:18:48 UTC	2000-05-30 18:02:12 UTC	14	0
	/mailme	2000-05-16 14:17:57 UTC	2000-05-30 16:54:39 UTC	17	0
	/myperl	2000-05-16 09:16:22 UTC	2000-05-31 17:54:12 UTC	103	3
	/myperl/base/1	2000-05-29 08:07:51 UTC	2000-05-29 08:07:51 UTC	1	0
	/myperl/eventcountfile/1	2000-05-29 23:54:38 UTC	2000-05-29 23:54:38 UTC	1	0
	/myperl/guestbook/1	2000-05-17 13:17:59 UTC	2000-05-29 08:40:39 UTC	3	0
	/myperl/hashofarrays/1	2000-05-16 11:35:40 UTC	2000-05-30 20:58:32 UTC	6	0
	/myperl/htmlformmaker/1	2000-05-17 06:41:04 UTC	2000-05-17 06:49:05 UTC	2	0
	/myperl/htmltagmaker/1	2000-05-16 18:18:54 UTC	2000-05-31 17:05:23 UTC	4	1
	/myperl/mailme/1	2000-05-16 11:36:08 UTC	2000-05-29 08:35:09 UTC	2	0
	/myperl/methodparamparser/1	2000-05-16 15:31:58 UTC	2000-05-18 04:47:10 UTC	2	0
	/myperl/segtextdoc/1	2000-05-18 03:11:53 UTC	2000-05-18 03:11:53 UTC	1	0
	/myperl/sequentialfile/1	2000-05-16 15:30:54 UTC	2000-05-29 08:08:29 UTC	3	0
	/myperl/static/1	2000-05-16 12:31:07 UTC	2000-05-16 15:47:29 UTC	2	0
	/myperl/webpagecontent/1	2000-05-29 22:48:30 UTC	2000-05-30 11:11:16 UTC	2	0
	/myperl/websiteglobals/1	2000-05-16 15:33:02 UTC	2000-05-29 18:57:29 UTC	5	0
	/myperl/websitemanager/1	2000-05-16 17:37:05 UTC	2000-05-29 22:46:04 UTC	7	0
	/mysites	2000-05-15 22:58:30 UTC	2000-05-31 01:40:52 UTC	78	1
	/resume	2000-05-15 23:26:23 UTC	2000-05-30 16:52:11 UTC	57	0
	__nil__	2000-05-15 07:57:37 UTC	2000-05-31 17:59:02 UTC	201	5
	__total__	2000-05-15 07:57:37 UTC	2000-05-31 17:59:02 UTC	720	11
	external	2000-05-15 22:59:16 UTC	2000-05-31 01:41:03 UTC	186	1

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_FILEHANDLE = 'filehandle';  # stores the filehandle
my $KEY_FILE_PATH  = 'file_path';   # external name of this file
my $KEY_CREAT_NNX  = 'creat_nnx';   # create file if nonexistant
my $KEY_ACC_PERMS  = 'acc_perms';   # new files have these permissions
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any
my $KEY_FILE_LINES = 'file_lines';  # hold content of file when open

# Indexes into array of record fields:
my $IND_KEY_TO_COUNT   = 0;  # name of what we are counting
my $IND_DATE_ACC_FIRST = 1;  # date of first access
my $IND_DATE_ACC_LAST  = 2;  # date of last access
my $IND_COUNT_ACC_ALL  = 3;  # count of accesses btwn first and last
my $IND_COUNT_ACC_DAY  = 4;  # count of accesses today only

# Constant values used in this class go here:
my $DELIM_RECORDS = "\n";     # this is standard
my $DELIM_FIELDS = "\t";  # this is a standard
my $BYTES_TO_KILL = '[\00-\31]';  # remove all control characters

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.

Objects of this class always store the filehandle they are working with as an
internal property.  However, you have a choice as to whether it creates the
filehandle or whether you pass it an existing one.  Likewise, you can retrieve
the filehandle in question for your own manipulation, irregardless of how this
class object got it in the first place.

Objects of this class always read the entire file into memory at once and do any
manipulations of it there, then write it all back at once if we want to save
updates.  This approach makes fewer system calls and should be much faster.  The
objects store the file data internally, so once the file is read in we use the
object's accessor methods to retrieve or manipulate data.

When saving changes, this class always truncates the file to ensure that if the
new data will be shorter than what was there last time, such as when deleting
records, so that none of the old data survives to cause corruption on the next
read.  While under ideal circumstances the truncation could be done either before
or after a write, this class will always do it before, so that in the event of a
failure part way through we don't have old data mixed with the new.  I may add
the ability to change this behaviour in later revisions of the class.

=head1 FUNCTIONS AND METHODS

=head2 new([ FILE[, CREAT[, PERMS]] ])

This function creates a new CGI::EventCountFile object and returns it.  The first
optional parameter, FILE, can be either a filehandle (GLOB ref) or a scalar.  If
it is a filehandle, then the "file handle" property is set to it, and all other
parameters are ignored.  If it is a scalar, then the "file path" property is set
to it.  The second optional parameter sets the "create if nonexistant" property,
and the third optional parameter sets the "access permissions" property.  See the
accessors for these properties to see what they do.

=cut

######################################################################

sub new {
	my $class = shift( @_ );
	my $self = {};
	bless( $self, ref($class) || $class );
	$self->initialize( @_ );
	return( $self );
}

######################################################################

=head2 initialize([ FILE[, CREAT[, PERMS]] ])

This method is used by B<new()> to set the initial properties of an object,
except when the new object is a clone.  Calling it yourself will clear the
existing properties and set new ones according to the optional parameters, which
are the same as those to new().  Nothing is returned.

=cut

######################################################################

sub initialize {
	my $self = shift( @_ );
	%{$self} = ();
	if( ref( $_[0] ) eq 'GLOB' ) {
		$self->{$KEY_FILEHANDLE} = shift( @_ );
	} else {
		$self->{$KEY_FILEHANDLE} = \*FH;
		$self->{$KEY_FILE_PATH} = shift( @_ );
		$self->{$KEY_CREAT_NNX} = shift( @_ );
		$self->{$KEY_ACC_PERMS} = shift( @_ );
	}
}

######################################################################

=head2 clone()

This method creates a new CGI::SequentialFile object, which is a duplicate of
this one in every respect, and returns it.  But the filehandle itself isn't
duplicated, rather we now might have two references to the same one.  (I'm not
yet sure when or not this is the case.)

=cut

######################################################################

sub clone {
	my $self = shift( @_ );
	my $clone = {};
	bless( $clone, ref($self) );
	%{$clone} = %{$self};  # only does single-level copy
	return( $clone );
}

######################################################################

=head2 filehandle([ VALUE ])

This method is an accessor for the "filehandle" property, which it returns.  If
VALUE is defined, this property is set to it.  This filehandle is what this class
is providing an interface to.  Filehandles are expected to be passed as a GLOB
reference, such as "\*FH".

=cut

######################################################################

sub filehandle {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'GLOB' ) {
		$self->{$KEY_FILEHANDLE} = $new_value;
	}
	return( $self->{$KEY_FILEHANDLE} );
}

######################################################################

=head2 file_path([ VALUE ])

This method is an accessor for the "file path" scalar property, which it returns.
If VALUE is defined, this property is set to it.  If this module is opening a
file itself, it will use this property to determine where the file is located.
This module is file-system agnostic, and will pass this "file path" to the open()
function as-is.  This means that if you provide only a file name and not a full
path, the file must be in the current working directory.  Do not provide any meta
characters like "<" or ">>" in the file name, as we don't use them.  This
property is "" by default.

=cut

######################################################################

sub file_path {
	my $self = shift( @_ );
	if( my $new_value = shift( @_ ) ) {
		$self->{$KEY_FILE_PATH} = $new_value;
	}
	return( $self->{$KEY_FILE_PATH} );
}

######################################################################

=head2 create_if_nonex([ VALUE ])

This method is an accessor for the "create if nonexistant" boolean/scalar
property, which it returns.  If VALUE is defined, this property is set to it.
When this module has to open a file, and the file doesn't exist, then it will
create the file if this property is true, and return a fatal error otherwise.
This property is false by default.

=cut

######################################################################

sub create_if_nonex {
	my $self = shift( @_ );
	if( my $new_value = shift( @_ ) ) {
		$self->{$KEY_CREAT_NNX} = $new_value;
	}
	return( $self->{$KEY_CREAT_NNX} );
}

######################################################################

=head2 access_perms([ VALUE ])

This method is an accessor for the "access permissions" octal/scalar property,
which it returns.  If VALUE is defined, this property is set to it.  If this
module creates a new file due to the "create if nonexistant" property being true,
then this property determines which access permissions the new file has.  The
property is "0666" (everyone can read and write) by default.

=cut

######################################################################

sub access_perms {
	my $self = shift( @_ );
	if( my $new_value = shift( @_ ) ) {
		$self->{$KEY_ACC_PERMS} = $new_value;
	}
	return( $self->{$KEY_ACC_PERMS} );
}

######################################################################

=head2 is_error()

This method returns a string specifying the file-system error that just occurred,
if any, and the undefined value if the last file-system operation succeeded. This
string includes the operation attempted, which is one of ['open', 'close',
'lock', 'unlock', 'seek start', 'seek end', 'read from', 'write to'], as well as
the file-system name of our file (if we opened it) and the system error string
from $!, but has no linebreaks.  The property is undefined by default.

=cut

######################################################################

sub is_error {
	my $self = shift( @_ );
	return( $self->{$KEY_IS_ERROR} );
}

######################################################################

=head2 open_and_lock([ RDWR[, PATH[, CREAT[, PERMS]]] ])

This method opens a file which is associated with the objects "file handle"
property, and gains an access lock on it.  The first optional argument, RDWR, is
a boolean/scalar which specifies how we will be using the file.  If it is true
then we are opening the file in read-and-write mode and use an exclusive lock. If
it is false then we are opening the file in read-only mode and use a shared lock.
 The second optional parameter, PATH, will override the "file path" property if
defined, but the property isn't changed.  Likewise the properties CREAT and PERMS
will override the properties "create if nonexistant" and "access permissions" if
defined.  This method returns 1 on success and undef on failure. Presumably the
file pointer is at byte zero now, but we don't do any seeking to make sure.

=cut

######################################################################

sub open_and_lock {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $read_and_write = shift( @_ );	
	my $file_path = shift( @_ );
	my $creat_nnx = shift( @_ );
	my $perms = shift( @_ );
	
	defined( $file_path ) or $file_path = $self->{$KEY_FILE_PATH};
	defined( $creat_nnx ) or $creat_nnx = $self->{$KEY_CREAT_NNX};
	defined( $perms ) or $perms = $self->{$KEY_ACC_PERMS};

	my $flags = 
		$read_and_write && $creat_nnx ? O_RDWR|O_CREAT :
		$read_and_write ? O_RDWR : 
		$creat_nnx ? O_RDONLY|O_CREAT : O_RDONLY;
	defined( $perms ) or $perms = 0666;

	$self->{$KEY_IS_ERROR} = undef;

	sysopen( $fh, $file_path, $flags, $perms ) or do {
		$self->_make_filesystem_error( "open" );
		return( undef );
	};

	flock( $fh, $read_and_write ? LOCK_EX : LOCK_SH ) or do {
		$self->_make_filesystem_error( "lock" );
		return( undef );
	};

	return( 1 );
}

######################################################################

=head2 unlock_and_close()

This method releases the access lock on the file that is associated with the
objects "file handle" property, and closes it.  This method returns 1 on success
and undef on failure.  As of Perl 5.004, which this module requires, the flock
function will flush buffered output prior to unlocking.

=cut

######################################################################

sub unlock_and_close {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	
	$self->{$KEY_IS_ERROR} = undef;

	flock( $fh, LOCK_UN ) or do {
		$self->_make_filesystem_error( "unlock" );
		return( undef );
	};

	close( $fh ) or do {
		$self->_make_filesystem_error( "close" );
		return( undef );
	};

	return( 1 );
}

######################################################################

=head2 read_all_records()

This method reads all of the records from this object's "file handle", and stores
them internally.  This method returns 1 on success, even if the end-of-file is
reached before we find any records.  It returns undef on a file-system error,
even if some records were read first.

=cut

######################################################################

sub read_all_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	
	$self->{$KEY_IS_ERROR} = undef;

	seek( $fh, 0, 0 ) or do {
		$self->_make_filesystem_error( "seek start of" );
		return( undef );
	};

	local $/ = undef;

	defined( my $file_content = <$fh> ) or do {
		$self->_make_filesystem_error( "read records from" );
		return( undef );
	};
	
	my @record_list = split( $DELIM_RECORDS, $file_content );
	my %record_hash = ();
	
	foreach my $record_str (@record_list) {
		my $key = substr( $record_str, 0, index( 
			$record_str, $DELIM_FIELDS ) );  # faster then reg exp?
		$record_hash{$key} = $record_str;
	}

	$self->{$KEY_FILE_LINES} = \%record_hash;
	
	return( 1 );
}

######################################################################

=head2 write_all_records()

This method writes all of this object's internally stored records to its "file
handle".  The file is truncated at zero prior to writing them.  This method
returns 1 on success, even if there are no records to write.  It returns undef on
a file-system error, even if some of the records were written first.

=cut

######################################################################

sub write_all_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	
	my @record_list = values %{$self->{$KEY_FILE_LINES}};
	my $file_content = join( $DELIM_RECORDS, @record_list );
	
	$self->{$KEY_IS_ERROR} = undef;

	seek( $fh, 0, 0 ) or do {
		$self->_make_filesystem_error( "seek start of" );
		return( undef );
	};

	truncate( $fh, 0 ) or do {
		$self->_make_filesystem_error( 'truncate to start of' );
		return( undef );
	};

	local $\ = undef;

	print $fh "$file_content" or do {
			$self->_make_filesystem_error( "write records to" );
			return( undef );
	};
	
	return( 1 );
}

######################################################################

=head2 key_exists( KEY )

This method returns true if KEY matches an existing internally stored record.

=cut

######################################################################

sub key_exists {
	my ($self, $key) = @_;
	$key =~ s/$BYTES_TO_KILL//;
	return( exists( $self->{$KEY_FILE_LINES}->{$key} ) );
}

######################################################################

=head2 key_fetch( KEY )

This method returns a list of the attributes that the internally stored record
matched by KEY has, or an empty list if KEY doesn't match anything.  The
attributes are: 1. the event key string; 2. date and time of the event's first
occurance; 3. date and time of the event's last occurance; 4. total count of
occurances between first and last; 5. count of only today's occurances.

=cut

######################################################################

sub key_fetch {
	my ($self, $key) = @_;
	$key =~ s/$BYTES_TO_KILL//;
	my @fields = split( $DELIM_FIELDS, $self->{$KEY_FILE_LINES}->{$key} );
	return( wantarray ? @fields : \@fields );
}

######################################################################

=head2 key_store( KEY, FIRST, LAST, COUNT, TODAY )

This method adds a new internally stored event record to this object which KEY
matches, and if a matching record already exists then it is overwritten.  The
remaining method parameters are assigned to this record as properties: FIRST is
the date and time of the even'ts first occurance, LAST is the date and time of
the event's last occurance, COUNT is the total count of occurances between FIRST
and LAST, TODAY is the count of only today's occurances.  FIRST and LAST are
cleaned up to conform with ISO 8601 format before insertion, and either is given
today's date if it is undefined.  COUNT and TODAY is set to zero if undefined. 
This method returns the updated attribute list for KEY.

=cut

######################################################################

sub key_store {
	my $self = shift( @_ );
	my $key = shift( @_ );
	$key =~ s/$BYTES_TO_KILL//;
	my @fields = ();

	$fields[$IND_KEY_TO_COUNT] = $key;
	$fields[$IND_DATE_ACC_FIRST] = _clean_up_date_string( shift( @_ ) );
	$fields[$IND_DATE_ACC_LAST] = _clean_up_date_string( shift( @_ ) );
	$fields[$IND_COUNT_ACC_ALL] = 0 + shift( @_ );
	$fields[$IND_COUNT_ACC_DAY] = 0 + shift( @_ );

	$self->{$KEY_FILE_LINES}->{$key} = join( $DELIM_FIELDS, @fields );
	return( wantarray ? @fields : \@fields );
}

######################################################################

=head2 key_increment( KEY )

This method increments the counters by 1 for the internally stored event record
that is matched by KEY, and if a record didn't previously exist, a new one is
created with counts of 1.  The record's "last occurance" date is also set to
today.  If the record was just created or its previous total count property was
zero, then the record's "first occurance" date is also set to today.  This method
returns the updated attribute list for KEY.

=cut

######################################################################

sub key_increment {
	my ($self, $key) = @_;
	$key =~ s/$BYTES_TO_KILL//;
	my @fields = split( $DELIM_FIELDS, $self->{$KEY_FILE_LINES}->{$key} );
	
	my $today_str = $self->today_date_utc();

	$fields[$IND_KEY_TO_COUNT] = $key;
	if( $fields[$IND_COUNT_ACC_ALL] == 0 ) {
		$fields[$IND_DATE_ACC_FIRST] = $today_str;
	}
	$fields[$IND_DATE_ACC_LAST] = $today_str;
	$fields[$IND_COUNT_ACC_ALL]++;
	$fields[$IND_COUNT_ACC_DAY]++;  # call different method to reset

	$self->{$KEY_FILE_LINES}->{$key} = join( $DELIM_FIELDS, @fields );
	return( wantarray ? @fields : \@fields );
}

######################################################################

=head2 key_delete( KEY )

This method deletes any existing internally stored event record that is matched
by KEY, and returns its attribute list.

=cut

######################################################################

sub key_delete {
	my ($self, $key) = @_;
	$key =~ s/$BYTES_TO_KILL//;
	my @fields = split( $DELIM_FIELDS, delete( 
		$self->{$KEY_FILE_LINES}->{$key} ) );
	return( wantarray ? @fields : \@fields );
}

######################################################################

=head2 key_accumulate( DEST_KEY, SOURCE_KEYS )

This method is a utility designed to combine the counts from two or more event
records during any time after they were started.  One use for it is in the event
that several keys were used when one was meant to be used, such as upper or lower
cased versions of the same key.  This method will combine the attributes for the
related keys together that takes into account the earliest and latest dates among
them, and accumulating the counts as appropriate.  The first parameter, DEST_KEY,
is the identifier for the internally stored record that will be the accumulator;
if it already has values then they will be considered in the total.  The second
parameter, SOURCE_KEYS, is a list of identifiers for other internally stored
records that will be added to the accumulating record.  The other records are not
deleted afterwards, so that will have to be done afterwards if desired.  Another
use for this method is to create "summary records" which show a total account for
a group of more detailed records; in this case, the record is unlikely to exist
already.

=cut

######################################################################

sub key_accumulate {
	my ($self, $dest_key, @src_keys) = @_;
	$dest_key =~ s/$BYTES_TO_KILL//;
	my @dest_fields = split( $DELIM_FIELDS, 
		$self->{$KEY_FILE_LINES}->{$dest_key} );
	
	$dest_fields[$IND_KEY_TO_COUNT] = $dest_key;
	
	foreach my $src_key (@src_keys) {
		$src_key =~ s/$BYTES_TO_KILL//;
		my @src_fields = split( $DELIM_FIELDS, 
			$self->{$KEY_FILE_LINES}->{$src_key} );
		
		if( $src_fields[$IND_DATE_ACC_FIRST] lt 
				$dest_fields[$IND_DATE_ACC_FIRST] ) {
			$dest_fields[$IND_DATE_ACC_FIRST] = 
				$src_fields[$IND_DATE_ACC_FIRST];
		}
		
		if( $src_fields[$IND_DATE_ACC_LAST] gt 
				$dest_fields[$IND_DATE_ACC_LAST] ) {
			$dest_fields[$IND_DATE_ACC_LAST] = 
				$src_fields[$IND_DATE_ACC_LAST];
		}
		
		$dest_fields[$IND_COUNT_ACC_ALL] += 
			$src_fields[$IND_COUNT_ACC_ALL];
		$dest_fields[$IND_COUNT_ACC_DAY] += 
			$src_fields[$IND_COUNT_ACC_DAY];
	}	

	$dest_fields[$IND_DATE_ACC_FIRST] ||= $self->today_date_utc();
	$dest_fields[$IND_DATE_ACC_LAST] ||= $self->today_date_utc();

	$self->{$KEY_FILE_LINES}->{$dest_key} = 
		join( $DELIM_FIELDS, @dest_fields );
	return( wantarray ? @dest_fields : \@dest_fields );
}

######################################################################

=head2 delete_all_keys()

This method deletes all the internally stored event records.  A 
subsequent call to write_all_records() would then clear the file.

=cut

######################################################################

sub delete_all_keys {
	my ($self) = @_;
	$self->{$KEY_FILE_LINES} = {};
}

######################################################################

=head2 key_was_incremented_today( KEY )

This method inspects the internally stored event record that KEY matches and
compares its "last occurance" date to today's date.  If the record exists and its
day is the same then this method returns true; otherwise it returns false.  This
method is intended to be used as a timer which rings once every 24 hours, or at
the first count file update performed after midnight on any given day.  For it to
work properly, KEY must be incremented right afterwards.

=cut

######################################################################

sub key_was_incremented_today {
	my ($self, $key) = @_;
	$key =~ s/$BYTES_TO_KILL//;
	my @fields = split( $DELIM_FIELDS, $self->{$KEY_FILE_LINES}->{$key} );
	my ($today) = ($self->today_date_utc() =~ m/^(\S+)/ );
	my ($last_acc) = ($fields[$IND_DATE_ACC_LAST] =~ m/^(\S+)/ );
	return( $last_acc eq $today );
}

######################################################################

=head2 set_all_day_counts_to_zero()

This method iterates through all of the internally stored records and sets their
"count of only today's occurances" properties to zero.  It doesn't do anything
else.  This method is intended to be called immediately following a false value
being returned by the key_was_incremented_today() method, and prior to any keys
being incremented during this update.

=cut

######################################################################

sub set_all_day_counts_to_zero {
	my ($self) = @_;
	my $rh_file_lines = $self->{$KEY_FILE_LINES};
	foreach my $key (keys %{$rh_file_lines}) {
		my @fields = split( $DELIM_FIELDS, $rh_file_lines->{$key} );
		$fields[$IND_COUNT_ACC_DAY] = 0;
		$rh_file_lines->{$key} = join( $DELIM_FIELDS, @fields );
	}
}

######################################################################

=head2 get_file_content()

This method returns a scalar containing all of the internally stored file
records, formatted as they would be stored in the file.  The records are
delimited by line breaks and record fields are delimited by tabs.

=cut

######################################################################

sub get_file_content {
	return( join( "\n", values %{$_[0]->{$KEY_FILE_LINES}} ) );
}

######################################################################

=head2 get_sorted_file_content()

This method returns the same thing as get_file_content() except that the records
are sorted asciibetically (by key).

=cut

######################################################################

sub get_sorted_file_content {
	return( join( "\n", sort values %{$_[0]->{$KEY_FILE_LINES}} ) );
}

######################################################################

=head2 today_date_utc()

This method returns an ISO 8601 formatted string containing the current Universal
Coordinated Time with precision to the second.  The returned string has 'UTC' at
the end to make its time zone easy to identify when it is embedded in other text.

=cut

######################################################################

sub today_date_utc {
	my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
	$year += 1900;  # year counts from 1900 AD otherwise
	$mon += 1;      # ensure January is 1, not 0
	my @parts = ($year, $mon, $mday, $hour, $min, $sec);
	return( sprintf( "%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d UTC", @parts ) );
}

######################################################################

sub _clean_up_date_string {
	my ($self, $original) = @_;
	defined( $original ) or return( $self->today_date_utc() );
	my @parts = ($original =~ m/(\d+)/g);
	return( sprintf( "%4.4d-%2.2d-%2.2d %2.2d:%2.2d:%2.2d UTC", @parts ) );
}

######################################################################

sub _make_filesystem_error {
	my ($self, $unique_part) = @_;
	return( $self->{$KEY_IS_ERROR} = 
		"can't $unique_part data file '$self->{$KEY_FILE_PATH}': $!" );
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

=head1 BUGS

There is something very strange going on with the POD documentation for the
key_fetch() method, which is meant to appear between key_exists() and
key_store().  The problem is that it doesn't show up at all in my POD
interpreter, even though I can't find anything wrong with it.  Or more
specifically, the interpreter thinks it is normal Perl code to be left alone. 
Following is what it is supposed to say:

	key_fetch( KEY )

	This method returns a list of the attributes that the internally stored record
	matched by KEY has, or an empty list if KEY doesn't match anything.  The
	attributes are: 1. the event key string; 2. date and time of the event's first
	occurance; 3. date and time of the event's last occurance; 4. total count of
	occurances between first and last; 5. count of only today's occurances.

For some reason, changing a line in the previous function code, key_exists(),
makes the POD show up, but I have no idea why.  Help is appreciated.

I have tested this module on Digital UNIX and Linux with no Perl code problems.

However, MacPerl seems to have problems with sysread, which manifest themselves
later as a "bad file descriptor" error when writing to an open file.  Using plain
"open" seems to fix the problem, but that doesn't give me the flexability to
create nonexistant files on demand.

Also, the Mac OS currently doesn't implement the flock function, which this
module uses automatically during opening and closing.  Mac OS X will change this,
but in the meantime the only ways to use this module on a Mac is to either
comment out the flock call or just call read_records() and write_records()
directly while opening and closing the file yourself.

I will note that MacPerl comes with a set of shared libraries that may correct 
these difficulties, or maybe they don't.  But I never installed them to find out.

=head1 SEE ALSO

perl(1), Fcntl.

=cut
