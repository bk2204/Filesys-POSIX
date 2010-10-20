package Filesys::POSIX::Userland::Tar;

use strict;
use warnings;

use Filesys::POSIX::Path;
use Filesys::POSIX::Bits;

my $BLOCK_SIZE = 512;

my %TYPES = (
    0   => $S_IFREG,
    1   => $S_IFREG,
    2   => $S_IFLNK,
    3   => $S_IFCHR,
    4   => $S_IFBLK,
    5   => $S_IFDIR,
    6   => $S_IFIFO
);

sub EXPORT {
    qw/tar/;
}

sub _pad_filename {
    my ($filename, $len) = @_;
    my $size = length $filename >= $len? $len + 1: $len;

    return substr(pack("Z$size", $filename), 0, $len);
}

sub _split_filename {
    my ($filename) = @_;

    if (length $filename > 255) {
        die('Filename too long');
    } elsif (length $filename > 100) {
        return (
            'prefix' => substr($filename, 0, 155),
            'suffix' => substr($filename, 155, 100)
        );
    }

    return (
        'prefix' => '',
        'suffix' => $filename
    );
}

sub _format_string {
    my ($string, $size) = @_;
    return pack("Z$size", $string? $string: '');
}

sub _format_number {
    my ($number, $size) = @_;
    my $digits = $size <= 1? 1: $size - 1;

    return _format_string(sprintf("%.${digits}o", $number), $size);
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

sub header {
    my ($inode, $dest) = @_;
    my %filename_parts = _split_filename($dest);
    my $header;

    my $size = ($inode->{'mode'} & $S_IFMT) == $S_IFDIR? 0: $inode->{'size'};

    $header .= _pad_filename($filename_parts{'suffix'}, 100);
    $header .= _format_number($inode->{'mode'} & $S_IPERM, 8);
    $header .= _format_number($inode->{'uid'}, 8);
    $header .= _format_number($inode->{'gid'}, 8);
    $header .= _format_number($size, 12);
    $header .= _format_number($inode->{'mtime'}, 12);
    $header .= ' ' x 8;
    $header .= _format_number(_type($inode), 1);
    $header .= "\x00" x 100;
    $header .= 'ustar00';
    $header .= ' ' x 32;
    $header .= ' ' x 32;
    $header .= _format_number(0, 8);
    $header .= _format_number(0, 8);
    $header .= _pad_filename($filename_parts{'prefix'}, 155);

    my $checksum = _checksum($header);
    substr($header, 148, 8) = _format_number($checksum, 8);

    return pack("a$BLOCK_SIZE", $header);
}

sub tar {
    my ($self, $handle, @paths) = @_;

    $self->import_module('Filesys::POSIX::Userland::Find');

    $self->find(sub {
        my ($path, $inode) = @_;
        my $format = $inode->{'mode'} & $S_IFMT;
        my $dest = $path->full;

        unless ($dest =~ /\/$/) {
            $dest .= '/' if $format == $S_IFDIR;
        }

        my $header = header($inode, $dest);
        $handle->write($header, 512) == 512 or die('Short write while dumping tar header to file handle');

        if ($format == $S_IFREG) {
            my $fd = $self->open($path->full, $O_RDONLY);
            my $fh = $self->fdopen($fd);

            while (my $len = $fh->read(my $buf, 4096)) {
                if ((my $padlen = $BLOCK_SIZE - ($len % $BLOCK_SIZE)) != $BLOCK_SIZE) {
                    $len += $padlen;
                    $buf .= "\x0" x $padlen;
                }

                $handle->write($buf, $len) == $len or die('Short write while dumping file buffer to handle');
            }

            $self->close($fd);
        }
    }, @paths);
}

1;
