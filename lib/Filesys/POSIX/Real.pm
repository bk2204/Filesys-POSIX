package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path            ();
use Filesys::POSIX::Real::Inode     ();
use Filesys::POSIX::Real::Directory ();

use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Real - Portal to actual underlying filesystem

=head1 SYNOPSIS

    use Filesys::POSIX;
    use Filesys::POSIX::Real;

    my $fs = Filesys::POSIX->new(Filesys::POSIX::Real->new,
        'special'   => 'real:/home/foo/test',
        'noatime'   => 1
    );

=head1 DESCRIPTION

This module implements the filesystem device type which provides a portal to
the actual system's underlying filesystem.

=head1 CREATING A NEW FILESYSTEM

=over

=item C<Filesys::POSIX::Real-E<gt>new>

Create a new, uninitialized filesystem.

=back

=cut

sub new {
    return bless {}, shift;
}

=head1 INITIALIAZATION

=over

=item C<$fs-E<gt>init(%data)>

Initializes the new filesystem.  A reference to the C<%data> argument is saved
in the filesystem object.  The following attribute in the C<%data> hash is
required, however:

=over

=item C<special>

A URI-like specifier indicating the absolute path of a portion of the real
filesystem, starting with the 'real:' prefix.

=back

Optional values in C<%data> are as follows:

=over

=item C<sticky>

When set to a value evaluating to true, any updates to certain attributes of any
inode brought to life by this module are not committed to disk.  When this flag
is used, the following calls only affect the inode in memory, but not on disk:

=over

=item C<$fs-E<gt>chmod>

=item C<$fs-E<gt>chown>

=item C<$fs-E<gt>symlink>

=back

Furthermore, only the following attributes are synced from disk onto their
corresponding memory inodes:

=over

=item C<size>

=item C<atime>

=item C<mtime>

=item C<ctime>

=back

=back

Exceptions will be thrown for the following:

=over

=item Invalid special path

The format of the C<$data{'special'}> argument does not match the aforementioned
specification.

=item Not a directory

The path specified in C<$data{'special'}> on the real filesystem does not
correspond to an actual directory.

=back

=back

=cut

sub init {
    my ( $self, %data ) = @_;

    my $path = $data{'special'};
    $path =~ s/^real:// or confess('Invalid special path');

    my $root = Filesys::POSIX::Real::Inode->from_disk(
        $path,
        'dev' => $self
    );

    confess('Not a directory') unless $root->dir;

    $self->{'flags'} = \%data;
    $self->{'path'}  = Filesys::POSIX::Path->full($path);
    $self->{'root'}  = $root;

    return $self;
}

1;
