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

    my $sticky = 0;

    #
    # Allow the sticky flag to be set for every inode belonging to a
    # Filesys::POSIX::Real filesystem, with usage of a special mount flag.
    # However, allow this flag to be overridden on a per-inode basis, which
    # happens with each call from Filesys::POSIX::Extensions->map and the like.
    #
    if ( defined $opts{'dev'}->{'sticky'} ) {
        $sticky = $opts{'dev'}->{'sticky'} ? 1 : 0;
    }

    if ( defined $opts{'sticky'} ) {
        $sticky = $opts{'sticky'} ? 1 : 0;
    }

    return bless {
        'path'   => $path,
        'dev'    => $opts{'dev'},
        'parent' => $opts{'parent'},
        'sticky' => $sticky,
        'dirty'  => 0
    }, $class;
}

sub from_disk {
    my ( $class, $path, %opts ) = @_;
    my @st = $opts{'st_info'} ? @{ $opts{'st_info'} } : lstat $path or confess($!);

    my $inode = $class->new( $path, %opts )->update(@st);

    if ( S_IFMT( $st[2] ) == S_IFDIR ) {
        $inode->{'directory'} = Filesys::POSIX::Real::Directory->new( $path, $inode );
    }

    return $inode;
}

sub child {
    my ( $self, $name, $mode ) = @_;
    my $directory = $self->directory;

    confess('Invalid directory entry name') if $name =~ /\//;
    confess('File exists') if $directory->exists($name);

    my $path = "$self->{'path'}/$name";

    my @data = (
        $path,
        'dev'    => $self->{'dev'},
        'sticky' => $self->{'sticky'},
        'parent' => $directory->get('.')
    );

    if ( ( $mode & $S_IFMT ) == $S_IFREG ) {
        sysopen( my $fh, $path, O_CREAT | O_EXCL | O_WRONLY, $mode ) or confess($!);
        close($fh);
    }
    elsif ( ( $mode & $S_IFMT ) == $S_IFDIR ) {
        mkdir( $path, $mode ) or confess($!);
    }
    elsif ( ( $mode & $S_IFMT ) == $S_IFLNK ) {
        return __PACKAGE__->new(@data);
    }

    return $directory->set( $name, __PACKAGE__->from_disk(@data) );
}

sub taint {
    my ($self) = @_;

    $self->{'dirty'} = 1;

    return $self;
}

sub update {
    my ( $self, @st ) = @_;

    if ( $self->{'sticky'} && $self->{'dirty'} ) {
        @{$self}{qw/size atime mtime ctime/} = @st[ 7 .. 10 ];
    }
    else {
        $self->SUPER::update(@st);
    }

    return $self;
}

sub open {
    my ( $self, $flags ) = @_;

    sysopen( my $fh, $self->{'path'}, $flags ) or confess($!);

    return Filesys::POSIX::IO::Handle->new($fh);
}

sub chown {
    my ( $self, $uid, $gid ) = @_;

    unless ( $self->{'sticky'} ) {
        CORE::chown( $uid, $gid, $self->{'path'} ) or confess($!);
    }

    @{$self}{qw/uid gid/} = ( $uid, $gid );

    return $self->taint;
}

sub chmod {
    my ( $self, $mode ) = @_;
    my $format = $self->{'mode'} & $S_IFMT;
    my $perm   = $mode & ( $S_IPERM | $S_IPROT );

    unless ( $self->{'sticky'} ) {
        CORE::chmod( $perm, $self->{'path'} ) or confess($!);
    }

    $self->{'mode'} = $format | $perm;

    return $self->taint;
}

sub readlink {
    my ($self) = @_;

    unless ( $self->{'sticky'} ) {
        $self->{'dest'} = CORE::readlink( $self->{'path'} ) or confess($!);
    }

    $self->taint;

    return $self->{'dest'};
}

sub symlink {
    my ( $self, $dest ) = @_;

    unless ( $self->{'sticky'} ) {
        symlink( $dest, $self->{'path'} ) or confess($!);
    }

    $self->{'dest'} = $dest;

    return $self->taint;
}

1;
