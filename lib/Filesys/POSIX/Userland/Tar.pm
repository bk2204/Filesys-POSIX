package Filesys::POSIX::Userland::Tar;

use strict;
use warnings;

use Filesys::POSIX::Path;
use Filesys::POSIX::Bits;

use Carp;

my $BLOCK_SIZE = 512;

my %TYPES = (
    0   => $S_IFREG,
    2   => $S_IFLNK,
    3   => $S_IFCHR,
    4   => $S_IFBLK,
    5   => $S_IFDIR,
    6   => $S_IFIFO
);

sub EXPORT {
    qw/tar/;
}

sub _split_filename {
    my ($filename) = @_;
    my $len = length $filename;

    if ($len > 255) {
        confess('Filename too long');
    } elsif ($len > 100) {
        return (
            'prefix' => substr($filename, 0, $len - 100),
            'suffix' => substr($filename, $len - 100, 100)
        );
    }

    return (
        'prefix' => '',
        'suffix' => $filename
    );
}

sub _pad_string {
    my ($string, $size) = @_;

    return $string if length($string) == $size;
    return pack("Z$size", $string);
}

sub _format_number {
    my ($number, $digits, $size) = @_;
    my $string = sprintf("%.${digits}o", $number);
    my $offset = length($string) - $digits;
    my $substring = substr($string, $offset, $digits);

    return $substring if $digits == $size;
    return pack("Z$size", $substring);
}

sub _checksum {
    my ($header) = @_;
    my $sum = 0;

    foreach (unpack 'C*', $header) {
        $sum += $_;
    }

    return $sum;
}

sub _type {
    my ($inode) = @_;

    foreach (keys %TYPES) {
        return $_ if ($inode->{'mode'} & $S_IFMT) == $TYPES{$_};
    }

    return 0;
}

sub _header {
    my ($inode, $dest) = @_;
    my %filename_parts = _split_filename($dest);
    my $header;

    my $size = ($inode->{'mode'} & $S_IFMT) == $S_IFREG? $inode->{'size'}: 0;

    $header .= _pad_string($filename_parts{'suffix'}, 100);
    $header .= _format_number($inode->{'mode'} & $S_IPERM, 7, 8);
    $header .= _format_number($inode->{'uid'}, 7, 8);
    $header .= _format_number($inode->{'gid'}, 7, 8);
    $header .= _format_number($size, 12, 12);
    $header .= _format_number($inode->{'mtime'}, 12, 12);
    $header .= ' ' x 8;
    $header .= _format_number(_type($inode), 1, 1);

    if (($inode->{'mode'} & $S_IFMT) == $S_IFLNK) {
        $header .= _pad_string($inode->readlink, 100);
    } else {
        $header .= "\x00" x 100;
    }

    $header .= _pad_string('ustar', 6);
    $header .= _pad_string('00', 2);
    $header .= "\x00" x 32;
    $header .= "\x00" x 32;
    $header .= _format_number(0, 7, 8);
    $header .= _format_number(0, 7, 8);
    $header .= _pad_string($filename_parts{'prefix'}, 155);

    my $checksum = _checksum($header);
    substr($header, 148, 8) = _format_number($checksum, 7, 8);

    return pack("a$BLOCK_SIZE", $header);
}

#
# NOTE: I'm only using $inode->open() calls to save stat()s.  This is not
# necessarily something that should be done by end user software.
#
sub _write_file {
    my ($fs, $handle, $dest, $inode) = @_;
    my $fh = $inode->open($O_RDONLY);

    while (my $len = $fh->read(my $buf, 4096)) {
        if ((my $padlen = $BLOCK_SIZE - ($len % $BLOCK_SIZE)) != $BLOCK_SIZE) {
            $len += $padlen;
            $buf .= "\x0" x $padlen;
        }

        $handle->write($buf, $len) == $len or confess('Short write while dumping file buffer to handle');
    }

    $inode->close;
}

sub _archive {
    my ($fs, $handle, $dest, $inode) = @_;
    my $format = $inode->{'mode'} & $S_IFMT;

    unless ($dest =~ /\/$/) {
        $dest .= '/' if $format == $S_IFDIR;
    }

    my $header = _header($inode, $dest);
    $handle->write($header, 512) == 512 or confess('Short write while dumping tar header to file handle');

    _write_file($fs, $handle, $dest, $inode) if $format == $S_IFREG;
}

sub tar {
    my $self = shift;
    my $handle = shift;
    my %opts = ref $_[0] eq 'HASH'? %{(shift)}: ();
    my @items = @_;

    $self->import_module('Filesys::POSIX::Userland::Find');

    $self->find(\%opts, sub {
        my ($path, $inode) = @_;

        _archive($self, $handle, $path->full, $inode);
    }, @items);
}

1;
