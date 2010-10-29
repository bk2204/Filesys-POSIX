use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 1);
use Test::Exception;

{
    throws_ok {
        Filesys::POSIX->new
    } qr/^No root filesystem specified/, "Filesys::POSIX->new() requires a root filesystem";
}
