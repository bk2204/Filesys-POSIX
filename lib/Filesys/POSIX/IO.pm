package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;

sub open {
    my ($self, $path, $flags, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $inode;

    if ($flags & $O_CREAT) {
        my $parent = $self->stat($hier->dirname);
        my $format = $mode? $mode & $S_IFMT: $S_IFREG;
        my $perms = $mode? $mode & $S_IPERM: $S_IRW ^ $self->{'umask'};

        die('Not a directory') unless $parent->{'mode'} & $S_IFDIR;
        die('File exists') if $parent->{'dirent'}->exists($name);

        if ($format & $S_IFDIR) {
            $perms |= $S_IX ^ $self->{'umask'} unless $perms;
        }

        $inode = $parent->child($name, $format | $perms);
    }

    return $self->{'fds'}->open($inode, $flags);
}

sub read {
    my $self = shift;
    my $entry = $self->{'fds'}->lookup($_[0]);

    die('Invalid argument') unless $entry->{'flags'} & ($O_RDONLY | $O_RDWR);

    return $entry->{'handle'}->read(@_);
}

sub write {
    my ($self, $fd, $buf, $len) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    die('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    return $entry->{'handle'}->write($fd, $buf, $len);
}

sub seek {
    my ($self, $fd, $pos, $whence) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'}->seek($fd, $pos, $whence);
}

sub close {
    my ($self, $fd) = @_;
    $self->{'fds'}->close($fd);
}

1;