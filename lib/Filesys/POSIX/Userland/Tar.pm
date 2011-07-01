package Filesys::POSIX::Userland::Tar;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path ();

use Carp qw/confess/;

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

my $BLOCK_SIZE = 512;

my %TYPES = (
    0 => $S_IFREG,
    2 => $S_IFLNK,
    3 => $S_IFCHR,
    4 => $S_IFBLK,
    5 => $S_IFDIR,
    6 => $S_IFIFO
);

sub _split_filename {
    my ($filename) = @_;
    my $len = length $filename;
    my @parts = split( /\//, $filename );

    if ( $len > 255 ) {
        confess('Filename too long');
    }

    my $got = 0;
    my ( @prefix_items, @suffix_items );

    while (@parts) {
        my $item = pop @parts;
        $got += length($item) + 1;

        if ( $got >= 100 ) {
            push @prefix_items, $item;
        }
        else {
            push @suffix_items, $item;
        }
    }

    my $prefix = join( '/', reverse @prefix_items );
    my $suffix = join( '/', reverse @suffix_items );

    $suffix .= '/' if $filename =~ /\/$/;

    return (
        'prefix' => $prefix,
        'suffix' => $suffix
    );
}

sub _pad_string {
    my ( $string, $size ) = @_;

    return $string if length($string) == $size;
    return pack( "Z$size", $string );
}

sub _format_number {
    my ( $number, $digits, $size ) = @_;
    my $string    = sprintf( "%.${digits}o", $number );
    my $offset    = length($string) - $digits;
    my $substring = substr( $string, $offset, $digits );

    return $substring if $digits == $size;
    return pack( "Z$size", $substring );
}

sub _checksum {
    my ($header) = @_;
    my $sum = 0;

    foreach ( unpack 'C*', $header ) {
        $sum += $_;
    }

    return $sum;
}

sub _type {
    my ($inode) = @_;

    foreach ( keys %TYPES ) {
        return $_ if ( $inode->{'mode'} & $S_IFMT ) == $TYPES{$_};
    }

    return 0;
}

sub _header {
    my ( $inode, $dest ) = @_;
    my %filename_parts = _split_filename($dest);
    my $header;

    my $size  = $inode->file ? $inode->{'size'} : 0;
    my $major = 0;
    my $minor = 0;

    if ( $inode->char || $inode->block ) {
        $major = $inode->major;
        $minor = $inode->minor;
    }

    $header .= _pad_string( $filename_parts{'suffix'}, 100 );
    $header .= _format_number( $inode->{'mode'} & $S_IPERM, 7,  8 );
    $header .= _format_number( $inode->{'uid'},             7,  8 );
    $header .= _format_number( $inode->{'gid'},             7,  8 );
    $header .= _format_number( $size,                       12, 12 );
    $header .= _format_number( $inode->{'mtime'},           12, 12 );
    $header .= ' ' x 8;
    $header .= _format_number( _type($inode),               1,  1 );

    if ( $inode->link ) {
        $header .= _pad_string( $inode->readlink, 100 );
    }
    else {
        $header .= "\x00" x 100;
    }

    $header .= _pad_string( 'ustar', 6 );
    $header .= _pad_string( '00',    2 );
    $header .= "\x00" x 32;
    $header .= "\x00" x 32;
    $header .= _format_number( $major, 7, 8 );
    $header .= _format_number( $minor, 7, 8 );
    $header .= _pad_string( $filename_parts{'prefix'}, 155 );

    my $checksum = _checksum($header);
    substr( $header, 148, 8 ) = _format_number( $checksum, 7, 8 );

    return pack( "a$BLOCK_SIZE", $header );
}

#
# NOTE: I'm only using $inode->open() calls to avoid having to call stat().
# This is not necessarily something that should be done by end user software.
#
sub _write_file {
    my ( $fs, $handle, $dest, $inode ) = @_;
    my $fh = $inode->open($O_RDONLY);

    while ( my $len = $fh->read( my $buf, 4096 ) ) {
        if ( ( my $padlen = $BLOCK_SIZE - ( $len % $BLOCK_SIZE ) ) != $BLOCK_SIZE ) {
            $len += $padlen;
            $buf .= "\x0" x $padlen;
        }

        $handle->write( $buf, $len ) == $len or confess('Short write while dumping file buffer to handle');
    }

    $fh->close;
}

sub _archive {
    my ( $fs, $handle, $dest, $inode ) = @_;

    unless ( $dest =~ /\/$/ ) {
        $dest .= '/' if $inode->dir;
    }

    my $header = _header( $inode, $dest );
    $handle->write( $header, 512 ) == 512 or confess('Short write while dumping tar header to file handle');

    _write_file( $fs, $handle, $dest, $inode ) if $inode->file;
}

=item C<$fs-E<gt>tar($handle, @items)>

=item C<$fs-E<gt>tar($handle, $opts, @items)>

Locate files and directories in each path specified in the @items array,
writing results to the I/O handle wrapper specified by $handle, an instance of
L<Filesys::POSIX::IO::Handle>.  When an anonymous HASH argument, $opts, is
specified, the data is passed unmodified to L<Filesys::POSIX::Userland::Find>.
In this way, for instance, the behavior of following symlinks can be specified.

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

            _archive( $self, $handle, $path->full, $inode );
        },
        $opts,
        @items
    );
}

=back

=cut

1;
