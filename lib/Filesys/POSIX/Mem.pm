package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Mem::Dirent;

=head1 NAME

Filesys::POSIX::Mem

=head1 DESCRIPTION

Provides the base class representing an instance of the memory file system.
All inode and directory entry data lives completely in memory, or in temporary
files referenced by inode buckets as provided by Filesys::POSIX::Mem::Bucket
file handles.

=head1 CREATING AND INITIALIZING THE FILESYSTEM

=over

=item $fs->new()

Creates a new, unmounted filesystem.  The root inode of this filesystem is
created as a directory with 0755 permissions.

=cut
sub new {
    my ($class) = @_;
    my $fs = bless {}, $class;

    $fs->{'root'} = Filesys::POSIX::Mem::Inode->new(
        'mode'  => $S_IFDIR | 0755,
        'dev'   => $fs
    );

    return $fs;
}

=item $fs->init(%flags)

Stores the flags passed in the current filesystem object.  This method is
usually called by L<Filesys::POSIX::Mount> when said filesystem object is
mounted.  These mount flags can be retrieved later.

=cut
sub init {
    my ($self, %flags) = @_;

    $self->{'flags'} = \%flags;

    return $self;
}

1;
