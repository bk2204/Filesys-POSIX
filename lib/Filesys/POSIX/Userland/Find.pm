# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

package Filesys::POSIX::Userland::Find;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path ();

sub EXPORT {
    qw/find/;
}

=head1 NAME

Filesys::POSIX::Userland::Find - Crawl directories in a filesystem

=head1 SYNOPSIS

    use Filesys::POSIX;
    use Filesys::POSIX::Real;

    my $fs = Filesys::POSIX->new(Filesys::POSIX::Real->new,
        'special'   => 'real:/home/foo',
        'noatime'   => 1
    );

    $fs->find(sub {
        my ($path, $inode) = @_;
        printf("0%o %s\n", $inode->{'mode'}, $path->full);
    }, '/');

=head1 DESCRIPTION

This module provides an extension module to L<Filesys::POSIX> that operates
very similarly in principle to the Perl Core module L<File::Find>, albeit with
some minor differences and fewer options.  For the sake of efficiency, tail
recursion, rather than pure call recursion, is used to handle very deep
hierarchies.

=head1 USAGE

=over

=item C<$fs-E<gt>find($callback, @paths)>

=item C<$fs-E<gt>find($callback, $options, @paths)>

C<$fs-E<gt>find> will perform recursive descent into each path passed, printing
the full pathname of each item found relative to each item found in the
C<@paths> list.  For each item found, both a Filesys::POSIX::Path object, and an
inode, respectively, are passed as the sole arguments to the callback.  With
this mechanism, it is possible to retrieve path data from each item in every way
currently provided by L<File::Find>, without retaining global state to do so.
As a reference to the corresponding item's inode object is passed, there is no
need to perform a C<$fs-E<gt>stat> call to further inspect the item.

When called with an C<$options> argument, specified in the form of an anonymous
HASH, the following flags (whose values are set nonzero) are honored:

=over

=item C<follow>

Any symlinks found along the way are resolved; if the paths they resolve to are
those of directories, then further descent will be made into said directories.

=back

=back

=cut

sub find {
    my $self     = shift;
    my $callback = shift;
    my %opts     = ref $_[0] eq 'HASH' ? %{ (shift) } : ();
    my @args     = @_;

    my @paths  = map { Filesys::POSIX::Path->new($_) } @args;
    my @inodes = map { $self->lstat($_) } @args;

    while ( my $inode = pop @inodes ) {
        my $path = pop @paths;

        if ( $inode->link ) {
            $inode = $self->stat( $inode->readlink ) if $opts{'follow'};
        }

        $callback->( $path, $inode );

        if ( $inode->dir ) {
            my $directory = $inode->directory->open;

            while ( defined( my $item = $directory->read ) ) {
                next if $item eq '.' || $item eq '..';
                push @paths,  Filesys::POSIX::Path->new( $path->full . "/$item" );
                push @inodes, $self->{'vfs'}->vnode( $directory->get($item) );
            }

            $directory->close;
        }
    }
}

1;
