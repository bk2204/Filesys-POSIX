package Filesys::POSIX::Real::Dirent;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Errno qw/ENOENT/;

sub new {
    my ($class, $path, $node) = @_;

    return bless {
        'path'      => $path,
        'node'      => $node,
        'mtime'     => 0,
        'members'   => {
            '.'     => $node,
            '..'    => $node->{'parent'}? $node->{'parent'}: $node
        }
    }, $class;
}

sub _sync_all {
    my ($self) = @_;
    my $mtime = (lstat $self->{'path'})[9] or die $!;

    return unless $mtime > $self->{'mtime'};

    $self->open;

    while (my $item = $self->read) {
        $self->_sync_member($item);
    }

    $self->close;

    $self->{'mtime'} = $mtime;
}

sub _sync_member {
    my ($self, $name) = @_;
    my $subpath = "$self->{'path'}/$name";
    my @st = lstat "$self->{'path'}/$name";

    if ($!{'ENOENT'}) {
        delete $self->{'members'}->{$name};
        return;
    }

    die $! unless @st;

    if (exists $self->{'members'}->{$name}) {
        $self->{'members'}->{$name}->_load_st_info(@st);
    } else {
        $self->{'members'}->{$name} = Filesys::POSIX::Real::Inode->new($subpath,
            'st_info'   => \@st,
            'dev'       => $self->{'node'}->{'dev'},
            'parent'    => $self->{'node'}
        );
    }
}

sub get {
    my ($self, $name) = @_;
    $self->_sync_member($name);
    return $self->{'members'}->{$name};
}

sub exists {
    my ($self, $name) = @_;
    $self->_sync_member($name);
    return exists $self->{'members'}->{$name};
}

sub delete {
    my ($self, $name) = @_;
    my $member = $self->{'members'}->{$name} or return;
    my $subpath = "$self->{'path'}/$name";

    if (($member->{'mode'} & $S_IFMT) == $S_IFDIR) {
        rmdir($subpath);
    } else {
        unlink($subpath);
    }

    if ($!) {
        die $! unless $!{'ENOENT'};
    }

    my $now = time;
    @{$self->{'node'}}{qw/mtime ctime/} = ($now, $now);

    delete $self->{'members'}->{$name};
}

sub list {
    my ($self, $name) = @_;
    $self->_sync_all;

    return keys %{$self->{'members'}};
}

sub count {
    my ($self) = @_;
    $self->_sync_all;

    return scalar keys %{$self->{'members'}};
}

sub open {
    my ($self) = @_;

    $self->close;
    opendir($self->{'dh'}, $self->{'path'}) or die $!;
}

sub rewind {
    my ($self) = @_;

    if ($self->{'dh'}) {
        rewinddir $self->{'dh'};
    }
}

sub read {
    my ($self) = @_;

    if ($self->{'dh'}) {
        readdir $self->{'dh'};
    }
}

sub close {
    my ($self) = @_;

    if ($self->{'dh'}) {
        closedir $self->{'dh'};
        delete $self->{'dh'};
    }
}

1;
