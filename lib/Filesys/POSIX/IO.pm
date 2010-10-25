package Filesys::POSIX;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::FdTable;
use Filesys::POSIX::Path;

use Carp;

sub open {
    my ($self, $path, $flags, $mode) = @_;
    my $hier = Filesys::POSIX::Path->new($path);
    my $name = $hier->basename;
    my $inode;

    if ($flags & $O_CREAT) {
        my $parent = $self->stat($hier->dirname);

        confess('Not a directory') unless ($parent->{'mode'} & $S_IFMT) == $S_IFDIR;

        if ($inode = $parent->get($name)) {
            confess('File exists') if $flags & $O_EXCL;
        } else {
            my $format = $mode? $mode & $S_IFMT: $S_IFREG;
            my $perms = $mode? $mode & $S_IPERM: $S_IRW ^ $self->{'umask'};

            if ($format == $S_IFDIR) {
                $perms |= $S_IX ^ $self->{'umask'} unless $perms;
            }

            $inode = $parent->child($name, $format | $perms);
        }
    } else {
        $inode = $self->stat($path);
    }

    return $self->{'fds'}->open($inode, $flags);
}

sub read {
    my $self = shift;
    my $fd = shift;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') if $entry->{'flags'} & $O_WRONLY;

    return $entry->{'handle'}->read(@_);
}

sub write {
    my ($self, $fd, $buf, $len) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    return $entry->{'handle'}->write($buf, $len);
}

sub print {
    my ($self, $fd, @args) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    my $buf = join($/, @args);

    return $entry->{'handle'}->write($buf, length $buf);
}

sub printf {
    my ($self, $fd, $format, @args) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    confess('Invalid argument') unless $entry->{'flags'} & ($O_WRONLY | $O_RDWR);

    my $buf = sprintf($format, @args);

    return $entry->{'handle'}->write($buf, length $buf);
}

sub seek {
    my ($self, $fd, $pos, $whence) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'}->seek($pos, $whence);
}

sub close {
    my ($self, $fd) = @_;
    $self->{'fds'}->close($fd);
}

sub fdopen {
    my ($self, $fd, $mode) = @_;
    my $entry = $self->{'fds'}->lookup($fd);

    return $entry->{'handle'};
}

1;
