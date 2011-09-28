package Filesys::POSIX::Directory::Handle;

sub new {
    my ($class) = @_;

    return bless {}, $class;
}

sub open {
    my ($self) = @_;

    return $self;
}

sub close {
    return;
}

1;
