=head1 NAME

CGI::SequentialFile - Perl module that interfaces to a common text file format
which stores records as named and url-escaped key=value pairs.

=cut

######################################################################

package CGI::SequentialFile;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION);
$VERSION = '1.0b';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	Fcntl

=head2 Nonstandard Modules

	CGI::HashOfArrays

=cut

######################################################################

use Fcntl qw(:DEFAULT :flock);
use CGI::HashOfArrays;

######################################################################

=head1 SYNOPSIS

	use CGI::SequentialFile;
	
	my $create_nonexistent = 1;
	my $case_insensitive = 1;
	
	my $field_defin_file = CGI::SequentialFile->new( "GB_Questions.txt" );
	my $message_file = CGI::SequentialFile->new( 
		"GB_Messages.txt", $create_nonexistent );
	
	my $query_string = '';
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD)$/ ) {
		$query_string = $ENV{'QUERY_STRING'};
	} else {
		read( STDIN, $query_string, $ENV{'CONTENT_LENGTH'} );
	}
	my $user_input = CGI::HashOfArrays->new( $case_insensitive, $query_string );
	$message_file->append_new_records( $user_input ) or 
		die "Error saving new GuestBook message: ".$message_file->is_error()."\n";
	
	my @field_list = $field_defin_file->fetch_all_records( $case_insensitive );
	if( my $err_msg = $field_defin_file->is_error() ) {
		die "Error determining GuestBook questions: $err_msg\n";
	}
	my @message_list = $message_file->fetch_all_records( $case_insensitive );
	if( my $err_msg = $message_file->is_error() ) {
		die "Error reading existing GuestBook messages: $err_msg\n";
	}
	
	print "All GuestBook Messages:\n";
	foreach my $message (@message_list) {
		print "\n";
		foreach my $field (@field_list) {
			my $field_name = $field->fetch_value( 'name' );
			my $title = $field->fetch_value( 'title' );
			my @inputs = $message->fetch( $field_name );
			print "Question: '$title'\n";
			print "Answers: '".join( "','", @inputs )."'\n";
		}
	}

=head1 DESCRIPTION

This Perl 5 object class provides an easy-to-use interface for a plain text file
format that is capable of storing an ordered list of variable-length records
where the fields of each record are stored in name=value pairs, one field value
per line.

Each record can have different fields from the others, and each field can have
either one or several values.  In the latter case, the field name is repeated for
each value.  Records are delimited by lines that contain only a "=" and are
otherwise empty.  The order of individual fields in the file doesn't matter, but
the order of parts of multivalued fields does; this order is preserved.  

All field names and values are url-escaped, so we are capable of storing binary
data without corrupting it.

=head1 FILE FORMAT EXAMPLE

	=
	name=name
	type=textfield
	visible_title=What%27s+your+name%3f
	=
	default=eenie
	default=minie
	name=words
	type=checkbox_group
	values=eenie
	values=meenie
	values=minie
	values=moe
	visible_title=What%27s+the+combination%3f
	=
	name=color
	type=popup_menu
	values=red
	values=green
	values=blue
	values=chartreuse
	visible_title=What%27s+your+favorite+colour%3f
	=
	type=submit

=cut

######################################################################

# Names of properties for objects of this class are declared here:
my $KEY_FILEHANDLE = 'filehandle';  # stores the filehandle
my $KEY_FILE_PATH  = 'file_path';   # external name of this file
my $KEY_CREAT_NNX  = 'creat_nnx';   # create file if nonexistant
my $KEY_ACC_PERMS  = 'acc_perms';   # new files have these permissions
my $KEY_CASE_INSE  = 'case_inse';   # are HoA keys case insensitive?
my $KEY_USE_EMPTY  = 'use_empty';   # do we process empty records?
my $KEY_IS_ERROR   = 'is_error';    # holds error string, if any

# Constant values used in this class go here:
my $DELIM_RECORDS = "\n=\n";     # this is standard
my $DELIM_FIELDS = "\n";  # this is a standard

######################################################################

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions and
B<$object-E<gt>method()> for methods.

Record data taken from a file is returned as a list of CGI::HashOfArrays
(HoA) objects, one object for each record.  The keys in the HoA are the field
names, and the list of values associated with each HoA key are the values of the
field.  Record data to be stored in a file must likewise be provided as a list of
HoA objects, or a list of HASH refs.  HoAs are used because they simplify the
manipulation of hashes whose keys may have one or several values (see the HoA
documentation for details of their use).

Objects of this class always store the filehandle they are working with as an
internal property.  However, you have a choice as to whether it creates the
filehandle or whether you pass it an existing one.  Likewise, you can retrieve
the filehandle in question for your own manipulation, irregardless of how this
class object got it in the first place.

=head1 FUNCTIONS AND METHODS

=head2 new([ FILE[, CREAT[, PERMS]] ])

This function creates a new CGI::SequentialFile object and returns it.  The
first optional parameter, FILE, can be either a filehandle (GLOB ref) or a
scalar.  If it is a filehandle, then the "file handle" property is set to it, and
all other parameters are ignored.  If it is a scalar, then the "file path"
property is set to it.  The second optional parameter sets the "create if
nonexistant" property, and the third optional parameter sets the "access
permissions" property.  See the accessors for these properties to see what they
do.

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

=head2 ignores_case([ VALUE ])

This method is an accessor for the "ignores case" boolean/scalar property, which
it returns.  If VALUE is defined, this property is set to it.  This property is
only used when reading records from a file, and is used during initialization of
the HoA objects that read records are returned in.  Any HoAs with this property
set to true will lowercase any keys inserted into them, and they stay that way on
output.  This means that if a record read from a file has fields with names that
differ only by their case, they are treated as the same field.  The property is
false by default.

=cut

######################################################################

sub ignores_case {
	my $self = shift( @_ );
	if( my $new_value = shift( @_ ) ) {
		$self->{$KEY_CASE_INSE} = $new_value;
	}
	return( $self->{$KEY_CASE_INSE} );
}

######################################################################

=head2 uses_empty_records([ VALUE ])

This method is an accessor for the "use empty" boolean/scalar property, which it
returns.  If VALUE is defined, this property is set to it.  If this property is
true, this module will return a record for every record delimiter read,
irregardless of whether the record contained any fields.  If this property is
false, then consecutive record delimiters are disregarded until a record that has
fields is encountered.  On writing, a false value for this property means that we
disregard any records that don't have any fields, and a true value means we write
them anyway, resulting in multiple consecutive record delimiters.  This property
is false by default, and in that state we are guaranteed that reads only return
records with fields in them, and writes are likewise.

=cut

######################################################################

sub uses_empty_records {
	my $self = shift( @_ );
	if( my $new_value = shift( @_ ) ) {
		$self->{$KEY_USE_EMPTY} = $new_value;
	}
	return( $self->{$KEY_USE_EMPTY} );
}

######################################################################

=head2 is_error()

This method returns a string specifying the file-system error that just occurred,
if any, and the undefined value if the last file-system operation succeeded. 
This string includes the operation attempted, which is one of ['open', 'close',
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
then we are opening the file in read-and-write mode and use an exclusive lock. 
If it is false then we are opening the file in read-only mode and use a shared
lock.  The second optional parameter, PATH, will override the "file path"
property if defined, but the property isn't changed.  Likewise the properties
CREAT and PERMS will override the properties "create if nonexistant" and "access
permissions" if defined.  This method returns 1 on success and undef on failure. 
Presumably the file pointer is at byte zero now, but we don't do any seeking to
make sure.

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

=head2 read_records([ CASE[, MAX[, EMPTY]] ])

This method reads records from this object's "file handle", and returns them. 
The second optional scalar argument specifies the maximum number of records to
read.  If that argument is undefined or less than 1, then all records are read
until the end-of-file is reached.  The first and third optional arguments, CASE
and EMPTY, will override the object properties "ignores case" and "use empty" if
defined.  This method returns an ARRAY ref containing the new records (as HoAs)
on success, even if the end-of-file is reached before we find any records.  It
returns undef on a file-system error, even if some records were read first.

=cut

######################################################################

sub read_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $case_inse = shift( @_ );
	my $max_rec_num = shift( @_ );  # if <= 0, read all records
	my $use_empty = shift( @_ );
	
	defined( $case_inse ) or $case_inse = $self->{$KEY_CASE_INSE};
	defined( $use_empty ) or $use_empty = $self->{$KEY_USE_EMPTY};
	
	$self->{$KEY_IS_ERROR} = undef;

	my @record_list = ();
	my $remaining_rec_count = ($max_rec_num <= 0) ? -1 : $max_rec_num;

	local $/ = $DELIM_RECORDS;

	GET_ANOTHER_REC: {
		eof( $fh ) and return( \@record_list );
	
		defined( my $record_str = <$fh> ) or do {
			$self->_make_filesystem_error( "read record from" );
			return( undef );
		};
	
		my $record = CGI::HashOfArrays->new( 
			$case_inse, $record_str, $DELIM_FIELDS );
		
		$record->keys_count() or $use_empty or redo GET_ANOTHER_REC;

		push( @record_list, $record );

		--$remaining_rec_count != 0 and redo GET_ANOTHER_REC;

		return( \@record_list );
	}
}

######################################################################

=head2 write_records( LIST[, EMPTY] )

This method writes records to this object's "file handle".  The first argument,
LIST, is an ARRAY ref containing the records (as HoAs or HASH refs) to be
written, or it is a single record to be written.  If any array elements aren't
HoAs or HASH refs, they are disregarded.  The second, optional argument, EMPTY,
will override the object's "use empty" property if defined.  This method returns
1 on success, even if there are no records to write.  It returns undef on a
file-system error, even if some of the records were written first.

=cut

######################################################################

sub write_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $ra_record_list = shift( @_ );
	my $use_empty = shift( @_ );
	
	ref( $ra_record_list ) eq 'ARRAY' or $ra_record_list = [];
	defined( $use_empty ) or $use_empty = $self->{$KEY_USE_EMPTY};
	
	$self->{$KEY_IS_ERROR} = undef;

	local $\ = undef;

	foreach my $record (@{$ra_record_list}) {
		ref( $record ) eq 'HASH' and $record = 
			CGI::HashOfArrays->new( 0, $record );
		ref( $record ) eq "CGI::HashOfArrays" or next;
		
		!$use_empty and !$record->keys_count() and next;

		my $record_str = $record->to_url_encoded_string( $DELIM_FIELDS );

		print $fh "$DELIM_RECORDS$record_str" or do {
			$self->_make_filesystem_error( "write record to" );
			return( undef );
		};
	}
	
	return( 1 );
}

######################################################################

=head2 fetch_all_records([ CASE ])

This method will return a list containing all the records from a file, which may
be empty if the file is empty.  The list is returned as a single ARRAY ref if
this method is called in scalar context.  This method returns undef on failure. 
It assumes that the file is not already open.

=cut

######################################################################

sub fetch_all_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $case_inse = shift( @_ );
	
	$self->{$KEY_IS_ERROR} = undef;

	$self->open_and_lock( 0 ) or return( undef );

	seek( $fh, 0, 0 ) or do {
		$self->_make_filesystem_error( "seek start of" );
		return( undef );
	};

	my $ra_record_list = $self->read_records( $case_inse, -1 ) 
		or return( undef );

	$self->unlock_and_close() or return( undef );

	return( wantarray ? @{$ra_record_list} : $ra_record_list );
}

######################################################################

=head2 append_new_records( LIST )

This method will take a list of records, and append them to a file.  The argument
LIST can either be an ARRAY ref or an actual list.  This method returns 1 on
success and undef on failure.  It assumes that the file is not already open.

=cut

######################################################################

sub append_new_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $ra_record_list = (ref( $_[0] ) eq 'ARRAY') ? $_[0] : [@_];
	
	$self->{$KEY_IS_ERROR} = undef;

	$self->open_and_lock( 1 ) or return( undef );

	seek( $fh, 0, 2 ) or do {
		$self->_make_filesystem_error( "seek end of" );
		return( undef );
	};

	$self->write_records( $ra_record_list ) or return( undef );

	$self->unlock_and_close() or return( undef );

	return( 1 );
}

######################################################################

=head2 replace_all_records( LIST )

This method will take a list of records, and overwrite a file with them.  The
argument LIST can either be an ARRAY ref or an actual list.  The file is
truncated before writing the new records.  An easy way to simply delete all
records in a file is to call this method with an empty list.  This method returns
1 on success and undef on failure.  It assumes that the file is not already open.

=cut

######################################################################

sub replace_all_records {
	my $self = shift( @_ );
	my $fh = $self->{$KEY_FILEHANDLE};
	my $ra_record_list = (ref( $_[0] ) eq 'ARRAY') ? $_[0] : [@_];
	
	$self->{$KEY_IS_ERROR} = undef;

	$self->open_and_lock( 1 ) or return( undef );

	seek( $fh, 0, 0 ) or do {
		$self->_make_filesystem_error( "seek start of" );
		return( undef );
	};

	truncate( $fh, 0 ) or do {
		$self->_make_filesystem_error( 'truncate to start of' );
		return( undef );
	};

	$self->write_records( $ra_record_list ) or return( undef );

	$self->unlock_and_close() or return( undef );

	return( 1 );
}

######################################################################

sub _make_filesystem_error {
	my $self = shift( @_ );
	my $unique_part = shift( @_ );
	return( $self->{$KEY_IS_ERROR} = 
		"can't $unique_part data file '$self->{$KEY_FILE_PATH}': $!" );
}

######################################################################

1;
__END__

=head1 DEVELOPMENT HISTORY

The file format that this module handles became known to me during a programming
exercise where I was given an example file containing usernames and passwords and
had to parse it.  I was informed at the time that this file format was common.  

This module was created for my own use, as I stored html form descriptions and
user input from my CGI scripts in the file format.  Through independent
development, my module gained the ability to store binary data safely through
url-encoding (preserving white-space formatting among other benefits), and could
store everything from multi-valued fields.

When I decided to take my modules public, and develop them further before doing
so, I first looked upon CPAN to see if someone else had already done what this
module does, and none had, surprisingly enough.  Maybe the format was too simple
to make a module for, but I thought it worthwhile.

=head1 COMPATABILITY WITH OTHER MODULES

It turns out that this file format is identical to that used by the Whitehead
Genome Center's data exchange format, and can be manipulated and even databased
using Boulderio utilities.  See
"http://www.genome.wi.mit.edu/genome_software/other/boulder.html" for further
details.  

Boulderio didn't turn up in any CPAN search, but I found out about it from
Lincoln D. Stein's documentation for CGI.pm, which itself uses a file format
identical to this module, when saving its state.

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

I have tested this module on Digital UNIX and Linux with no problems.

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

perl(1), Boulder, CGI, CGI::HashOfArrays.

=cut
