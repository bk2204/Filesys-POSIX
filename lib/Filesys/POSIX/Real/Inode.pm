package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Fcntl;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Inode;
use Filesys::POSIX::IO::Handle;

use Carp;

our @ISA = qw/Filesys::POSIX::Inode/;

sub new {
    my ($class, $path, %opts) = @_;
    my @st = $opts{'st_info'}? @{$opts{'st_info'}}: lstat $path or confess($!);

    my $inode = bless {
        'path'      => $path,
        'dev'       => $opts{'dev'},
        'parent'    => $opts{'parent'}
    }, $class;

    $inode->update(@st);

    if (($st[2] & $S_IFMT) == $S_IFDIR) {
        $inode->{'dirent'} = Filesys::POSIX::Real::Dirent->new($path, $inode);
    }

    return $inode;
}

sub child {
    my ($self, $name, $mode) = @_;
    my $dirent = $self->dirent;

    confess('Invalid directory entry name') if $name =~ /\//;
    confess('File exists') if $dirent->exists($name);

    my $path = "$self->{'path'}/$name";
    my $child;

    if (($mode & $S_IFMT) == $S_IFDIR) {
        mkdir($path, $mode) or confess $!;
    } else {
        sysopen(my $fh, $path, O_CREAT | O_EXCL | O_WRONLY, $mode) or confess $!;
        close($fh);
    }

    my $inode = __PACKAGE__->new($path,
        'dev'       => $self->{'dev'},
        'parent'    => $self
    );

    $dirent->set($name, $inode);
}

sub open {
    my ($self, $flags) = @_;

    sysopen(my $fh, $self->{'path'}, $flags) or confess $!;

    return Filesys::POSIX::IO::Handle->new($fh);
}

sub chown {
    my ($self, $uid, $gid) = @_;
    CORE::chown($uid, $gid, $self->{'path'});
    @{$self}{qw/uid gid/} = ($uid, $gid);
}

sub chmod {
    my ($self, $mode) = @_;
    CORE::chmod($mode, $self->{'path'});
    $self->{'mode'} = $mode;
}

sub readlink {
    my ($self) = @_;
    confess('Not a symlink') unless ($self->{'mode'} & $S_IFMT) == $S_IFLNK;

    return CORE::readlink($self->{'path'});
}

sub symlink {
    my ($self, $dest) = @_;
    confess('Not a symlink') unless -l $self->{'path'};

    CORE::unlink($self->{'path'}) or confess($!);
    symlink($self->{'path'}, $dest) or confess($!);
}

1;
