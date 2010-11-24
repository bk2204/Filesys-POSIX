package Filesys::POSIX::Dirent;

use strict;
use warnings;

use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Dirent

=head1 DESCRIPTION

Filesys::POSIX::Dirent is a common interface used to implement classes that act
like directory entries.  Directory entries are to be associated with directory
inodes, and should be able to be accessed randomly or iteratively.

Note that this class does not provide an implementation; actual implementations
should, of course, inherit from this nonetheless using the C<@ISA> variable,
and should adhere to the behavior documented herein.

=head1 RANDOM ACCESS

=over

=item $dirent->get($name)

If the current directory entry contains an item named for $name, return the
corresponding inode.  Otherwise, an C<undef> is returned.

=cut
sub get {
    confess('Not implemented');
}

=item $dirent->set($name, $inode)

Store a reference to $inode in the current directory entry, named after the
member label $name.  If an item already exists for $name, then it will be
replaced by $inode.

=cut
sub set {
    confess('Not implemented');
}

=item $dirent->exists($name)

Returns true if a member called $name exists in the current directory entry.
Returns false if no such member inode is listed.

=cut
sub exists {
    confess('Not implemented');
}

=item $dirent->detach($name)

Drop any references to a member called $name in the current directory entry.
No side effects outside of the directory entry object instance shall occur.

=cut
sub detach {
    confess('Not implemented');
}

=item $dirent->delete($name)

Drop any references to a member called $name in the current directory entry.
Side effects to other system resources referenced by this directory entry
member may potentially occur, depending on the specific directory entry
implementation.

=cut
sub delete {
    confess('Not implemented');
}

=back

=head1 LIST ACCESS

=over

=item $dirent->list()

Return a list of all items in the current directory entry, including C<.> and
C<..>.

=cut
sub list {
    confess('Not implemented');
}

=item $dirent->count()

Return the number of all items in the current directory entry, including C<.>
and C<..>.

=cut
sub count {
    confess('Not implemented');
}

=back

=head1 ITERATIVE ACCESS

=over

=item $dirent->open()

Prepare the current directory entry object for iterative reading access.

=cut
sub open {
    confess('Not implemented');
}

=item $dirent->rewind()

Rewind the current directory entry object to the beginning of the directory
entry list when being accessed iteratively.

=cut
sub rewind {
    confess('Not implemented');
}

=item $dirent->read()

Read and return a single item from the directory entry, advancing the pointer
to the next item to be read, if any.  A list containing both the name of the
object, and the inode it references, are returned.

=cut
sub read {
    confess('Not implemented');
}

=item $dirent->close()

Close the current directory entry for iterative access.

=cut
sub close {
    confess('Not implemented');
}

=back

=cut

1;
