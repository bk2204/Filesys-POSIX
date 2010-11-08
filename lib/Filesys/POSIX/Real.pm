package Filesys::POSIX::Real;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path ();
use Filesys::POSIX::Real::Inode ();
use Filesys::POSIX::Real::Dirent ();

use Carp qw/confess/;

=head1 NAME

Filesys::POSIX::Real

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

=item Filesys::POSIX::Real->new()

Create a new, uninitialized filesystem.

=back

=cut
sub new {
    return bless {}, shift;
}

=head1 INITIALIAZATION

=over

=item $fs->init(%data)

Initializes the new filesystem.  A reference to the %data argument is saved in
the filesystem object.  The following attribute in the %data hash is required,
however:

=over

=item C<special>

A URI-like specifier indicating the absolute path of a portion of the real
filesystem, starting with the 'real:' prefix.

=back

Exceptions will be thrown for the following:

=over

=item Invalid special path

The format of the $data{'special'} argument does not match the aforementioned
specification.

=item Not a directory

The path specified in $data{'special'} on the real filesystem does not
correspond to an actual directory.

=back

=back

=cut
sub init {
    my ($self, %data) = @_;

    my $path = $data{'special'};
    $path =~ s/^real:// or confess('Invalid special path');

    my $root = Filesys::POSIX::Real::Inode->new($path,
        'dev' => $self
    );

    confess('Not a directory') unless $root->dir;

    $self->{'flags'} = \%data;
    $self->{'path'} = Filesys::POSIX::Path->full($path);
    $self->{'root'} = $root;

    return $self;
}

1;
