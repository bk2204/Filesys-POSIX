package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode      ();
use Filesys::POSIX::IO::Handle ();

use Fcntl qw/:DEFAULT :mode/;
use Carp qw/confess/;

our @ISA = qw/Filesys::POSIX::Inode/;

sub new {
    my ( $class, $path, %opts ) = @_;

    return bless {
        'path'   => $path,
        'dev'    => $opts{'dev'},
        'parent' => $opts{'parent'}
    }, $class;
}

sub from_disk {
    my ( $class, $path, %opts ) = @_;
    my @st = $opts{'st_info'} ? @{ $opts{'st_info'} } : lstat $path or confess($!);

    my $inode = $class->new( $path, %opts )->update(@st);

    if ( S_IFMT( $st[2] ) == S_IFDIR ) {
        $inode->{'directory'} = Filesys::POSIX::Real::Directory->from_disk( $path, $inode );
    }

    return $inode;
}

sub child {
    my ( $self, $name, $mode ) = @_;
    my $directory = $self->directory;

    confess('Invalid directory entry name') if $name =~ /\//;
    confess('File exists') if $directory->exists($name);

    my $path = "$self->{'path'}/$name";
    my $child;

    if ( ( $mode & $S_IFMT ) == $S_IFDIR ) {
        mkdir( $path, $mode ) or confess($!);
    }
    elsif ( ( $mode & $S_IFMT ) == $S_IFLNK ) {
        return __PACKAGE__->new(
            $path,
            'dev'    => $self->{'dev'},
            'parent' => $directory->get('.')
        );
    }
    elsif ( ( $mode & $S_IFMT ) == $S_IFREG ) {
        sysopen( my $fh, $path, O_CREAT | O_EXCL | O_WRONLY, $mode ) or confess($!);
        close($fh);
    }

    my $inode = __PACKAGE__->from_disk(
        $path,
        'dev'    => $self->{'dev'},
        'parent' => $directory->get('.')
    );

    $directory->set( $name, $inode );
}

sub open {
    my ( $self, $flags ) = @_;

    sysopen( my $fh, $self->{'path'}, $flags ) or confess($!);

    return Filesys::POSIX::IO::Handle->new($fh);
}

sub chown {
    my ( $self, $uid, $gid ) = @_;
    CORE::chown( $uid, $gid, $self->{'path'} );
    @{$self}{qw/uid gid/} = ( $uid, $gid );
}

sub chmod {
    my ( $self, $mode ) = @_;
    CORE::chmod( $mode, $self->{'path'} );
    $self->{'mode'} = $mode;
}

sub readlink {
    my ($self) = @_;
    confess('Not a symlink') unless ( $self->{'mode'} & $S_IFMT ) == $S_IFLNK;

    return CORE::readlink( $self->{'path'} );
}

sub symlink {
    my ( $self, $dest ) = @_;

    symlink( $dest, $self->{'path'} ) or confess($!);

    return $self->update( stat $self->{'path'} );
}

1;
