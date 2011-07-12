package Filesys::POSIX::Mem;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem::Inode     ();
use Filesys::POSIX::Mem::Directory ();

=head1 NAME

Filesys::POSIX::Mem - In-memory filesystem implementation

=head1 SYNOPSIS

    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    $fs->mkdir('/mnt');
    $fs->mount(Filesys::POSIX::Mem->new, '/mnt',
        'noatime' => 1
    );

=head1 DESCRIPTION

Provides the base class representing an instance of the memory file system.
All inode and directory entry data lives completely in memory, or in temporary
files referenced by inode buckets as provided by L<Filesys::POSIX::Mem::Bucket>
file handles.

=head1 MOUNT OPTIONS

The following options are honored.  They modify the behavior of the file handle
object implemented by L<Filesys::POSIX::Mem::Bucket>.

=over

=item C<bucket_dir>

When new files are created within a C<Filesys::POSIX::Mem> filesystem, temporary
files in the actual underlying filesystem may be created to hold their contents.
The C<bucket_dir> option specifies the base directory in which these temporary
files are placed, defaulting to C</tmp>.

=item C<bucket_max>

Specifies the maximum size, in bytes, any given file within a
C<Filesys::POSIX::Mem> filesystem may reach within memory before its contents
are flushed to and managed within a temporary disk file.  The default size is
C<16384> bytes.

=back

=head1 CREATING AND INITIALIZING THE FILESYSTEM

=over

=item C<Filesys::POSIX::Mem-E<gt>new>

Creates a new, unmounted filesystem.  The root inode of this filesystem is
created as a directory with 0755 permissions.

=cut

sub new {
    my ($class) = @_;
    my $fs = bless {}, $class;

    $fs->{'root'} = Filesys::POSIX::Mem::Inode->new(
        'mode' => $S_IFDIR | 0755,
        'dev'  => $fs
    );

    return $fs;
}

=item C<$fs-E<gt>init(%flags)>

Stores the flags passed in the current filesystem object.  This method is
usually called by L<Filesys::POSIX::Mount> when said filesystem object is
mounted.  These mount flags can be retrieved later.

=cut

sub init {
    my ( $self, %flags ) = @_;

    $self->{'flags'} = \%flags;

    return $self;
}

=back

=head1 DESTROYING THE FILESYSTEM

The filesystem object, as well as any of its constituent inodes, directories,
and other data are cleaned up completely when the C<DESTROY()> method is called.

=cut

1;
