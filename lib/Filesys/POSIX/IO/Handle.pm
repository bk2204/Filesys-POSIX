package Filesys::POSIX::IO::Handle;

use strict;
use warnings;

sub new {
    my ($class, $fh) = @_;

    return bless \$fh, $class;
}

sub flush {
    my ($self) = @_;

    $|++;
}

sub print {
    my ($self, @args) = @_;

    return print {$$self} @args;
}

sub printf {
    my ($self, @args) = @_;

    return printf {$$self} @args;
}

sub write {
    my ($self, $buf, $len) = @_;

    return syswrite($$self, $buf, $len);
}

sub read {
    my $self = shift;
    my $len = pop;

    return sysread($$self, $_[0], $len);
}

sub seek {
    my ($self, $pos, $whence) = @_;

    return sysseek($$self, $pos, $whence);
}

sub tell {
    my ($self) = @_;

    return tell($$self);
}

sub close {
    my ($self) = @_;

    close $$self;
}

1;
