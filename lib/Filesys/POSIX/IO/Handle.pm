package Filesys::POSIX::IO::Handle;

use strict;
use warnings;

use Filesys::POSIX::Bits;

sub new {
    my ($class, $fh) = @_;

    return bless \$fh, $class;
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

    return sysseek($$self, 0, $SEEK_CUR);
}

sub close {
    my ($self) = @_;

    close $$self;
}

1;
