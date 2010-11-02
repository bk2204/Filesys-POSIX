package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;

use Carp;

=head1 NAME

Filesys::POSIX::IO

=head1 DESCRIPTION

Filesys::POSIX::IO is a mixin imported into the Filesys::POSIX namespace by the
Filesys::POSIX module itself.  This module provides the standard file I/O
routines.

=over

=item $fs->open($path, $flags)

=item $fs->open($path, $flags, $mode)

Open a file descriptor for an inode specified by $path.  This operation can be
modified by usage of the following flags which can be specified together using
logical OR (|).  The flags as follows are exported by Filesys::POSIX::Bits:

=over

=item $O_CREAT

If an inode at the specified path does not exist, attempt to create one.

When a mode is specified, the value is split into the format ($S_IFMT) and
permission ($S_IPERM) bitfields.  If no value was specified for the format,
then the default value of $S_IFREG (regular file) is substituted.  

When no mode is specified whatsoever, the default values of an $S_IFREG format,
and a mode of 0666 are used, modified by the current umask value.

In either case, the permissions to be used are modified with an exclusive OR
operation by the current umask value.

=item $O_EXCL

When specified in the presence of $O_CREAT, the call will only succeed when the
path lists a nonexisting inode.  A "File exists" exception will be thrown if
this is not the case.

=item $O_TRUNC

When specified, any existing file data will be truncated, and the file handle
position will start at offset 0 (zero).

=item $O_APPEND

When specified, the file handle position will start at the offset value equal
to the size of the file.

=item $O_RDONLY

The default flag field value.  When neither $O_WRONLY nor $O_RDWR are
specified, any write operations will be prohibited on the newly issued file
descriptor.

=item $O_WRONLY

When specified, any read operations will be prohibited on the newly issued file
descriptor.

=item $O_RDWR

When specified, both read and write operations will be allowed on the newly
issued file descriptor.

=back

=cut
sub open {
    my ($self, $path, $flags, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $inode;

    if ($flags & $O_CREAT) {
        my $parent = $self->stat($hier->dirname);
        my $dirent = $parent->dirent;

        if ($inode = $dirent->get($name)) {
            confess('File exists') if $flags & $O_EXCL;
        } else {
            my $format = $mode? ($mode & $S_IFMT? $mode & $S_IFMT: $S_IFREG): $S_IFREG;
            my $perms = $mode? $mode & $S_IPERM: $S_IRW;

            if ($format == $S_IFDIR) {
                $perms |= $S_IX unless $mode;
            }

            $perms &= ~$self->{'umask'};

            $inode = $parent->child($name, $format | $perms);
        }
    } else {
        $inode = $self->stat($path);
    }

    return $self->{'fds'}->open($inode, $flags);
}

=item $fs->read($fd, $buf, $len)

Perform a read on the file descriptor passed, storing at maximum the number of
bytes specified in $len into the buffer, $buf.  Returns the number of bytes
actually read; fewer bytes may be read than requested if the expected amount of
data from the current file handle position, plus the requested length, does not
match the requested length, such as when the length exceeds the end of the file
stream.  Returns zero if no more data is available to be read.

Exceptions are thrown for the following:

=over

=item Invalid argument

A read was attempted on a write-only file descriptor.

=back

=cut
sub read {
    my $self = shift;
    my $fd = shift;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') if $entry->{'flags'} & $O_WRONLY;

    return $entry->{'handle'}->read(@_);
}


=item $fs->write($fd, $buf, $len)

Perform a write on the file descriptor passed, writing at maximum the number of
bytes specified in $len from $buf to the open file.  Returns the number of
bytes actually written; fewer bytes may be written than requested if the buffer
does not contain enough, or if the underlying file handle implementation was
not able to write the full amount in the case of a Filesys::POSIX::IO::Handle
object issued for an open Filesys::POSIX::Real::Inode object.

The following exceptions may be thrown:

=over

=item Invalid argument

A write was attempted on a read-only file descriptor.

=back

=cut
sub write {
    my ($self, $fd, $buf, $len) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    return $entry->{'handle'}->write($buf, $len);
}

=item $fs->print($fd, @args)

Works similarly to $fs->write().  Each argument is concatenated using the
current value of $/ (see L<perlvar>), and passed with the amalgamated value's
length to the underlying file handle's $handle->write() call.

Exceptions may be thrown for the following:

=over

=item Invalid argument

Issued when called on a read-only file descriptor.

=back

=cut
sub print {
    my ($self, $fd, @args) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    my $buf = join($/, @args);

    return $entry->{'handle'}->write($buf, length $buf);
}

=item $fs->printf($fd, $format, @args)

Similar to $fs->print(), this call allows writes formatted by
L<sprintf()|perlfunc/sprintf> to be made to the given file descriptor.

Exceptions are thrown for:

=over

=item Invalid argument

Issued when called on a read-only file descriptor.

=back

=cut
sub printf {
    my ($self, $fd, $format, @args) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    my $buf = sprintf($format, @args);

    return $entry->{'handle'}->write($buf, length $buf);
}

=item $fs->tell($fd)

Returns the byte offset of the file descriptor's file handle.

=cut
sub tell {
    my ($self, $fd) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'}->tell;
}

=item $fs->seek($fd, $pos, $whence)

Sets the byte offset of the file descriptor's file handle, relative to the
current offset as modified by the value specified in $whence.  $whence can be
used to specify how the new position will be set relative to the current offset
with the following values:

=over

=item $SEEK_SET

The new offset of the file handle will be set to 0 + $pos bytes, or, relative
to the beginning of the file.  This sets the file handle to an absolute offset.

=item $SEEK_CUR

The new offset of the file handle will be set to $cur + $pos bytes, or,
relative to the current file handle offset.

=item $SEEK_END

The new offset of the file will be set to $size + $pos bytes, or, relative to
the end of the file.

=back

=cut
sub seek {
    my ($self, $fd, $pos, $whence) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'}->seek($pos, $whence);
}

=item $fs->close($fd)

Close the file handle issued for the given file descriptor, and deallocate said
file descriptor.  The file descriptor will then be freed for subsequent use and
issue by $fs->open().

=cut
sub close {
    my ($self, $fd) = @_;
    $self->{'fds'}->close($fd);
}

=item $fs->fdopen($fd)

Returns the underlying file handle opened for the file descriptor passed.

=cut
sub fdopen {
    my ($self, $fd) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'};
}

=back

=cut

1;
