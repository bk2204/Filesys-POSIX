package Filesys::POSIX::Mem::Transaction;

use strict;
use warnings;

sub new {
    my ($class, $fs) = @_;

    return bless {
        'fs'        => $fs,
        'actions'   => []
    }, $class;
}

sub copy {
    
}

1;
