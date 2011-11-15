package Filesys::POSIX::Userland::Tar::Header;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Path ();

use Carp ();

our $HEADER_SIZE = 512;

my %TYPES = (
    0 => $S_IFREG,
    2 => $S_IFLNK,
    3 => $S_IFCHR,
    4 => $S_IFBLK,
    5 => $S_IFDIR,
    6 => $S_IFIFO
);

sub inode_linktype {
    my ($inode) = @_;

    foreach ( keys %TYPES ) {
        return $_ if ( $inode->{'mode'} & $S_IFMT ) == $TYPES{$_};
    }

    return 0;
}

sub from_inode {
    my ( $class, $inode, $path ) = @_;

    my $path_components = split_path_components($path);
    my $size = $inode->file ? $inode->{'size'} : 0;

    my $major = 0;
    my $minor = 0;

    if ( $inode->char || $inode->block ) {
        $major = $inode->major;
        $minor = $inode->minor;
    }

    return bless {
        'prefix'   => $path_components->{'prefix'},
        'suffix'   => $path_components->{'suffix'},
        'mode'     => $inode->{'mode'},
        'uid'      => $inode->{'uid'},
        'gid'      => $inode->{'gid'},
        'size'     => $inode->{'size'},
        'mtime'    => $inode->{'mtime'},
        'linktype' => inode_linktype($inode),
        'linkdest' => $inode->link ? $inode->readlink : '',
        'user'     => '',
        'group'    => '',
        'major'    => $major,
        'minor'    => $minor
    }, $class;
}

sub decode {
    my ( $class, $block ) = @_;

    my $suffix = read_str( $block, 0,   100 );
    my $prefix = read_str( $block, 345, 155 );
    my $checksum = read_oct( $block, 148, 8 );

    validate_block( $block, $checksum );

    return bless {
        'suffix'   => $suffix,
        'mode'     => read_oct( $block, 100, 8 ),
        'uid'      => read_oct( $block, 108, 8 ),
        'gid'      => read_oct( $block, 116, 8 ),
        'size'     => read_oct( $block, 124, 12 ),
        'mtime'    => read_oct( $block, 136, 12 ),
        'linktype' => read_oct( $block, 156, 1 ),
        'linkdest' => read_str( $block, 157, 100 ),
        'user'     => read_str( $block, 265, 32 ),
        'group'    => read_str( $block, 297, 32 ),
        'major'    => read_oct( $block, 329, 8 ),
        'minor'    => read_oct( $block, 337, 8 ),
        'prefix'   => $prefix
    }, $class;
}

sub encode {
    my ($self) = @_;
    my $block = "\x00" x $HEADER_SIZE;

    write_str( $block, 0, 100, $self->{'suffix'} );
    write_oct( $block, 100, 8,  $self->{'mode'} & $S_IPERM, 7 );
    write_oct( $block, 108, 8,  $self->{'uid'},             7 );
    write_oct( $block, 116, 8,  $self->{'gid'},             7 );
    write_oct( $block, 124, 12, $self->{'size'},            12 );
    write_oct( $block, 136, 12, $self->{'mtime'},           12 );
    write_str( $block, 148, 8, '        ' );
    write_oct( $block, 156, 1, $self->{'linktype'}, 1 );
    write_str( $block, 157, 100, $self->{'linkdest'} );
    write_str( $block, 257, 6,   'ustar' );
    write_str( $block, 263, 2,   '00' );
    write_str( $block, 265, 32,  $self->{'user'} );
    write_str( $block, 297, 32,  $self->{'group'} );
    write_oct( $block, 329, 8, $self->{'major'}, 7 );
    write_oct( $block, 337, 8, $self->{'minor'}, 7 );
    write_str( $block, 345, 155, $self->{'prefix'} );

    my $checksum = checksum($block);

    write_oct( $block, 148, 8, $checksum, 7 );

    return $block;
}

sub split_path_components {
    my ($path) = @_;

    my $len = length $path;
    my @parts = split( /\//, $path );

    if ( $len > 255 ) {
        Carp::confess('Filename too long');
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

    $suffix .= '/' if $path =~ /\/$/;

    return {
        'prefix' => $prefix,
        'suffix' => $suffix
    };
}

sub read_str {
    my ( $block, $offset, $len ) = @_;
    my $template = "Z$len";

    return unpack( $template, substr( $block, $offset, $len ) );
}

sub write_str {
    my ( $block, $offset, $len, $string ) = @_;

    if ( length($string) == $len ) {
        substr( $_[0], $offset, $len ) = $string;
    }
    else {
        substr( $_[0], $offset, $len ) = pack( "Z$len", $string );
    }

    return;
}

sub read_oct {
    my ( $block, $offset, $len ) = @_;
    my $template = "Z$len";

    return oct( unpack( $template, substr( $block, $offset, $len ) ) );
}

sub write_oct {
    my ( $block, $offset, $len, $value, $digits ) = @_;
    my $string     = sprintf( "%.${digits}o", $value );
    my $sub_offset = length($string) - $digits;
    my $substring  = substr( $string, $sub_offset, $digits );

    if ( $len == $digits ) {
        substr( $_[0], $offset, $len ) = $substring;
    }
    else {
        substr( $_[0], $offset, $len ) = pack( "Z$len", $substring );
    }

    return;
}

sub checksum {
    my ($block) = @_;
    my $sum = 0;

    foreach ( unpack 'C*', $block ) {
        $sum += $_;
    }

    return $sum;
}

sub validate_block {
    my ( $block, $checksum ) = @_;
    my $copy = "$block";

    write_str( $block, 148, 8, ' ' x 8 );

    my $calculated_checksum = checksum($copy);

    Carp::confess('Invalid block') unless $calculated_checksum == $checksum;

    return;
}

sub file {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFREG;
}

sub link {
    my ($self) = @_;

    return $self->{'linktype'} == 1;
}

sub symlink {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFLNK;
}

sub char {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFCHR;
}

sub block {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFBLK;
}

sub dir {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFDIR;
}

sub fifo {
    my ($self) = @_;

    return $TYPES{ $self->{'linktype'} } == $S_IFIFO;
}

sub contig {
    my ($self) = @_;

    return $self->{'linktype'} == 7;
}

1;
