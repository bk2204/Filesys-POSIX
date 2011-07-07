package Filesys::POSIX::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Inode - Base class for filesystem inode objects

=head1 DESCRIPTION

Provides a base class for filesystem-type dependent inode objects.  This class
offers a number of methods used to help determine the nature of the inode by
analyzing its attributes.

=over

=item C<$inode-E<gt>dir>

Returns true if the current inode refers to a directory.

=cut

sub dir {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFDIR;
}

=item C<$inode-E<gt>link>

Returns true if the current inode is a symlink.

=cut

sub link {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFLNK;
}

=item C<$inode-E<gt>file>

Returns true if the current inode is a regular file.

=cut

sub file {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFREG;
}

=item C<$inode-E<gt>char>

Returns true if the current inode is a character device.

=cut

sub char {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFCHR;
}

=item C<$inode-E<gt>block>

Returns true if the current inode is a block device.

=cut

sub block {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFBLK;
}

=item C<$inode-E<gt>fifo>

Returns true if the current inode is a FIFO.

=cut

sub fifo {
    ( shift->{'mode'} & $S_IFMT ) == $S_IFIFO;
}

=item C<$inode-E<gt>major>

If the current inode is a block or character device, return the major number.

=cut

sub major {
    my ($self) = @_;

    confess('Invalid argument') unless $self->char || $self->block;

    return ( $self->{'dev'} & 0xff00 ) >> 15;
}

=item C<$inode-E<gt>minor>

If the current inode is a block or character device, return the minor number.

=cut

sub minor {
    my ($self) = @_;

    confess('Invalid argument') unless $self->char || $self->block;

    return $self->{'dev'} & 0x00ff;
}

=item C<$inode-E<gt>perms>

Returns the permissions bitfield value of the current inode's mode attribute.

=cut

sub perms {
    shift->{'mode'} & $S_IPERM;
}

=item C<$inode-E<gt>readable>

Returns true if the inode is readable by anyone.

=cut

sub readable {
    ( shift->{'mode'} & $S_IR ) != 0;
}

=item C<$inode-E<gt>writable>

Returns true if the inode is writable by anyone.

=cut

sub writable {
    ( shift->{'mode'} & $S_IW ) != 0;
}

=item C<$inode-E<gt>executable>

Returns true if the inode is executable by anyone.

=cut

sub executable {
    ( shift->{'mode'} & $S_IX ) != 0;
}

=item C<$inode-E<gt>setuid>

Returns true if the inode has a setuid bit set.

=cut

sub setuid {
    ( shift->{'mode'} & $S_ISUID ) != 0;
}

=item C<$inode-E<gt>setgid>

Returns true if the inode has a setgid bit set.

=cut

sub setgid {
    ( shift->{'mode'} & $S_ISGID ) != 0;
}

=item C<$inode-E<gt>update(@st)>

Updates the current inode object with a list of values as returned by
L<stat()|perlfunc/stat>.

=cut

sub update {
    my ( $self, @st ) = @_;

    @{$self}{qw/size atime mtime ctime uid gid mode rdev/} = ( @st[ 7 .. 10 ], @st[ 4 .. 5 ], $st[2], $st[6] );

    return $self;
}

=item C<$inode-E<gt>directory>

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

=item C<$inode-E<gt>empty>

Uses the above C<$inode-E<gt>directory()> call to obtain the directory for the
current inode, and returns the result of C<$directory-E<gt>empty()>.

=cut

sub empty {
    my ($self) = @_;

    return $self->directory->empty;
}

=back

=cut

1;
