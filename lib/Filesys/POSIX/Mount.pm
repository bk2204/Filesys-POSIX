package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path;

use Carp;

=head1 NAME

Filesys::POSIX::Mount

=head1 DESCRIPTION

Filesys::POSIX::Mount is a mixin module imported into the Filesys::POSIX
namespace by said module that provides a frontend to the internal VFS.  Rather
than dealing in terms of mount point vnodes as Filesys::POSIX::VFS does, the
system calls provided in this module deal in terms of pathnames.

=head1 SYSTEM CALLS

=over

=item $fs->mount($dev, $path, %data)

Attach the filesystem device, $dev, to the directory inode specified by $path.
The %data hash, for special types of filesystems other than Filesys::POSIX::Mem
should contain a 'special' value which has a device-dependent meaning.  Mount
flags are also specified and saved by the VFS for later retrieval.

The filesystem mount record is kept in an ordered list by the VFS, and can be
retrieved later using the $fs->statfs(), or $fs->mountlist() system calls.

=cut
sub mount {
    my ($self, $dev, $path, %data) = @_;
    my $mountpoint = $self->stat($path);
    my $realpath = $self->_find_inode_path($mountpoint);

    $dev->init(%data);

    $self->{'vfs'}->mount($dev, $realpath, $mountpoint, %data);
}

=item $fs->unmount($path)

Attempts to unmount a filesystem mounted at the directory pointed to by $path,
performing a number of sanity checks to ensure the safety of the current
operation.  The following checks are made:

=over

=item The directory inode is retrieved using $fs->stat().

=item Using Filesys::POSIX::VFS->statfs(), with the directory inode passed, the
VFS is queried to determine if the location given has a filesystem mounted at
all.  If so, the mount record is kept for reference for the next series of
checks.

=item The file descriptor table is scanned for open files whose inodes exist on
the device found for the mount record queried in the previous step by the VFS.
An exception is thrown when matching file descriptors are found.

=item The current working directory is checked to ensure it is not a reference
to a directory inode associated with the mounted device.  An exception is
thrown if the current directory is on the same device that is to be unmounted.

=back

=cut
sub unmount {
    my ($self, $path) = @_;
    my $mountpoint = $self->stat($path);
    my $mount = $self->{'vfs'}->statfs($mountpoint, 'exact' => 1);

    #
    # First, check for open file descriptors held on the desired device.
    #
    foreach ($self->{'fds'}->list) {
        my $inode = $self->{'fds'}->fetch($_);

        confess('Device or resource busy') if $mount->{'dev'} eq $inode->{'dev'};
    }

    #
    # Next, check to see if the current working directory's device inode
    # is the same device as the one being requested for unmounting.
    #
    confess('Device or resource busy') if $mount->{'dev'} eq $self->{'cwd'}->{'dev'};

    $self->{'vfs'}->unmount($mount);
}

=item $fs->statfs($path)

Returns the mount record for the device associated with the inode specified by
$path.  The inode is found using $fs->stat(), then queried for by
Filesys::POSIX::VFS->statfs().

=cut
sub statfs {
    my ($self, $path) = @_;
    my $inode = $self->stat($path);

    return $self->{'vfs'}->statfs($inode);
}

=item $fs->fstatfs($fd)

Returns the mount record for the device associated with the inode referenced by
the open file descriptor, $fd.  The inode is found using $fs->fstat(), then
queried for by Filesys::POSIX::VFS->statfs().

=cut
sub fstatfs {
    my ($self, $fd) = @_;
    my $inode = $self->fstat($fd);

    return $self->{'vfs'}->statfs($inode);
}

=item $fs->mountlist()

Returns a list of records for each filesystem currently mounted, in the order
in which they were mounted.

=cut
sub mountlist {
    shift->{'vfs'}->mountlist;
}

=back

=head1 ANATOMY OF A MOUNT RECORD

Mount records are created internally by Filesys::POSIX::VFS->mount(), and are
stored as anonymous HASHes.  They contain the following attributes:

=over

=item C<mountpoint>

Reference to the directory inode (or vnode in the case of multiple filesystems
mounted in the same logical location) the filesystem is mounted to.

=item C<root>

Reference to the mounted filesystem's root directory inode.  This is never a
vnode.

=item C<special>

The value of the C<special> flag specified in a call to $fs->mount().  When no
value is specified, the value stored is equal to C<ref $dev>.

=item C<dev>

A reference to the filesystem device object that was mounted by $fs->mount().

=item C<type>

A lowercase string formed by chopping all but the last item in a Perl fully
qualified package name corresponding to the type of the device mounted.  For
instance, an instance of Filesys::POSIX::Mem mounted will result in a value of
'mem'.

=item C<path>

The true, original, and sanitized path of the mount point specified by
$fs->mount().

=item C<vnode>

A VFS inode created by Filesys::POSIX::VFS::Inode->new(), containing most
attributes of the mounted device's root inode, but with a parent pointing to
the mount point inode's parent.

=item C<flags>

A copy of the options passed to $fs->mount(), minus the C<special> option.

=back

=cut

1;
