package Filesys::POSIX::Directory;

use strict;
use warnings;

use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Directory

=head1 DESCRIPTION

Filesys::POSIX::Directory is a common interface used to implement classes that
act like directories, and should be able to be accessed randomly or in an
iterative fashion.

Note that this class does not provide an implementation; actual implementations
should, of course, inherit from this nonetheless using the C<@ISA> variable,
and should adhere to the behavior documented herein.

=head1 RANDOM ACCESS

=over

=item $directory->get($name)

If the current directory contains an item named for $name, return the
corresponding inode.  Otherwise, an C<undef> is returned.

=cut

sub get {
    confess('Not implemented');
}

=item $directory->set($name, $inode)

Store a reference to $inode in the current directory, named after the member
label $name.  If an item already exists for $name, then it will be replaced by
$inode.

=cut

sub set {
    confess('Not implemented');
}

=item $directory->exists($name)

Returns true if a member called $name exists in the current directory.  Returns
false if no such member inode is listed.

=cut

sub exists {
    confess('Not implemented');
}

=item $directory->detach($name)

Drop any references to a member called $name in the current directory.  No side
effects outside of the directory object instance shall occur.

=cut

sub detach {
    confess('Not implemented');
}

=item $directory->delete($name)

Drop any references to a member called $name in the current directory.  Side
effects to other system resources referenced by this directory member may
potentially occur, depending on the specific directory implementation.

=cut

sub delete {
    confess('Not implemented');
}

=back

=head1 LIST ACCESS

=over

=item $directory->list()

Return a list of all items in the current directory, including C<.> and C<..>.

=cut

sub list {
    confess('Not implemented');
}

=item $directory->count()

Return the number of all items in the current directory, including C<.> and
C<..>.

=cut

sub count {
    confess('Not implemented');
}

=back

=head1 ITERATIVE ACCESS

=over

=item $directory->open()

Prepare the current directory object for iterative reading access.

=cut

sub open {
    confess('Not implemented');
}

=item $directory->rewind()

Rewind the current directory object to the beginning of the directory list when
being accessed iteratively.

=cut

sub rewind {
    confess('Not implemented');
}

=item $directory->read()

Read and return a single item from the directory, advancing the pointer to the
next item to be read, if any.  A list containing both the name of the object,
and the inode it references, are returned.

=cut

sub read {
    confess('Not implemented');
}

=item $directory->close()

Close the current directory for iterative access.

=cut

sub close {
    confess('Not implemented');
}

=back

=cut

1;
