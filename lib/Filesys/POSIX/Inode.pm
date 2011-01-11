package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Inode

=head1 DESCRIPTION

Provides a base class for filesystem-type dependent inode objects.  This class
offers a number of methods used to help determine the nature of the inode by
analyzing its attributes.

=over

=item $inode->dir()

Returns a value indicating whether or not the current inode is a directory.

=cut
sub dir {
    (shift->{'mode'} & $S_IFMT) == $S_IFDIR;
}

=item $inode->link()

Returns true if the current inode is a symlink.

=cut
sub link {
    (shift->{'mode'} & $S_IFMT) == $S_IFLNK;
}

=item $inode->file()

Returns true if the current inode is a regular file.

=cut
sub file {
    (shift->{'mode'} & $S_IFMT) == $S_IFREG;
}

=item $inode->char()

Returns true if the current inode is a character device.

=cut
sub char {
    (shift->{'mode'} & $S_IFMT) == $S_IFCHR;
}

=item $inode->block()

Returns true if the current inode is a block device.

=cut
sub block {
    (shift->{'mode'} & $S_IFMT) == $S_IFBLK;
}

=item $inode->fifo()

Returns true if the current inode is a Unix FIFO.

=cut
sub fifo {
    (shift->{'mode'} & $S_IFMT) == $S_IFIFO;
}

=item $inode->perms()

Returns the permissions bitfield value of the current inode's mode attribute.

=cut
sub perms {
    shift->{'mode'} & $S_IPERM;
}

=item $inode->readable()

Returns true if the inode is readable by anyone.

=cut
sub readable {
    (shift->{'mode'} & $S_IR) != 0;
}

=item $inode->writable()

Returns true if the inode is writable by anyone.

=cut
sub writable {
    (shift->{'mode'} & $S_IW) != 0;
}

=item $inode->executable()

Returns true if the inode is executable by anyone.

=cut
sub executable {
    (shift->{'mode'} & $S_IX) != 0;
}

=item $inode->setuid()

Returns true if the inode has a setuid bit set.

=cut
sub setuid {
    (shift->{'mode'} & $S_ISUID) != 0;
}

=item $inode->setgid()

Returns true if the inode has a setgid bit set.

=cut
sub setgid {
    (shift->{'mode'} & $S_ISGID) != 0;
}

=item $inode->update(@st)

Updates the current inode object with a list of values as returned by
L<stat()|perlfunc/stat>.

=cut
sub update {
    my ($self, @st) = @_;

    @{$self}{qw/size atime mtime ctime uid gid mode rdev/} = (@st[7..10], @st[4..5], $st[2], $st[6]);
}

=item $inode->directory()

If the current inode is a directory, return the directory object held by it.
Otherwise, the following exception is issued:

=over

=item Not a directory

=back

=cut
sub directory {
    my ($self) = @_;
    confess('Not a directory') unless $self->dir;

    return $self->{'directory'};
}

=item $inode->empty()

Uses the above $inode->directory() call to obtain the directory for the current
inode, and returns true if the directory only contains the '..' and '.' members.

=cut
sub empty {
    my ($self) = @_;
    my $directory = $self->directory;

    return $directory->count == 2;
}

=back

=cut

1;
