# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Filesys::POSIX' ); }

my $object = Filesys::POSIX->new ();
isa_ok ($object, 'Filesys::POSIX');


