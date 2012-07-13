# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

package Filesys::POSIX::Userland::Tar;

use strict;
use warnings;

use Filesys::POSIX::Bits;

use Filesys::POSIX::Path                  ();
use Filesys::POSIX::Userland::Tar::Header ();

use Carp ();

=head1 NAME

Filesys::POSIX::Userland::Tar - Generate ustar archives from L<Filesys::POSIX>

=head1 SYNOPSIS

    use Filesys::POSIX;
    use Filesys::POSIX::Mem;
    use Filesys::POSIX::IO::Handle;

    my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new,
        'noatime' => 1
    );

    $fs->import_module('Filesys::POSIX::Userland::Tar');

    $fs->mkdir('foo');
    $fs->touch('foo/bar');

    $fs->tar(Filesys::POSIX::IO::Handle->new(\*STDOUT), '.');

=head1 DESCRIPTION

This module provides an implementation of the ustar standard on top of the
virtual filesystem layer, a mechanism intended to take advantage of the many
possible mapping and manipulation capabilities inherent in this mechanism.
Internally, it uses the L<Filesys::POSIX::Userland::Find> module to perform
depth- last recursion to locate inodes for packaging.

As mentioned, archives are written in the ustar format, with pathnames of the
extended maximum length of 256 characters, supporting file sizes up to 4GB.
Currently, only user and group IDs are stored; names are not resolved and
stored as of the time of this writing.  All inode types are supported for
archival.

=head1 USAGE

=over

=cut

sub EXPORT {
    qw/tar/;
}

our $BLOCK_SIZE = 512;

#
# NOTE: I'm only using $inode->open() calls to avoid having to call stat().
# This is not necessarily something that should be done by end user software.
#
sub _write_file {
    my ( $inode, $handle ) = @_;
    my $fh = $inode->open($O_RDONLY);

    while ( my $len = $fh->read( my $buf, 4096 ) ) {
        if ( ( my $padlen = $BLOCK_SIZE - ( $len % $BLOCK_SIZE ) ) != $BLOCK_SIZE ) {
            $len += $padlen;
            $buf .= "\x0" x $padlen;
        }

        $handle->write( $buf, $len ) == $len or Carp::confess('Short write while dumping file buffer to handle');
    }

    $fh->close;
}

sub _archive {
    my ( $inode, $handle, $path, $opts ) = @_;

    my $header = Filesys::POSIX::Userland::Tar::Header->from_inode( $inode, $path );
    my $blocks = '';

    if ( $header->{'truncated'} ) {
        die('Filename too long') unless $opts->{'gnu_extensions'};

        $blocks .= $header->encode_longlink;
    }

    $blocks .= $header->encode;

    my $len = length $blocks;

    unless ( $handle->write( $blocks, $len ) == $len ) {
        Carp::confess('Short write while dumping tar header to file handle');
    }

    _write_file( $inode, $handle ) if $inode->file;
}

=item C<$fs-E<gt>tar($handle, @items)>

=item C<$fs-E<gt>tar($handle, $opts, @items)>

Locate files and directories in each path specified in the C<@items> array,
writing results to the I/O handle wrapper specified by C<$handle>, an instance
of L<Filesys::POSIX::IO::Handle>.  When an anonymous HASH argument, C<$opts>, is
specified, the data is passed unmodified to L<Filesys::POSIX::Userland::Find>.
In this way, for instance, the behavior of following symlinks can be specified.

In addition to options supported by L<Filesys::POSIX::Userland::Find>, the
following options are recognized uniquely by C<$fs-E<gt>tar()>:

=over

=item C<gnu_extensions>

When set, certain GNU extensions to the tar output format are enabled, namely
support for arbitrarily long filenames.

=back

=cut

sub tar {
    my $self   = shift;
    my $handle = shift;
    my $opts   = ref $_[0] eq 'HASH' ? shift : {};
    my @items  = @_;

    $self->import_module('Filesys::POSIX::Userland::Find');

    $self->find(
        sub {
            my ( $path, $inode ) = @_;

            _archive( $inode, $handle, $path->full, $opts );
        },
        $opts,
        @items
    );
}

=back

=cut

1;
