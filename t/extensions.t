use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Mem::Inode;
use Filesys::POSIX::Bits;

use Test::More ('tests' => 5);
use Test::Exception;

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new);
$fs->import_module('Filesys::POSIX::Extensions');

$fs->mkpath('/mnt/mem');
$fs->mount(Filesys::POSIX::Mem->new, '/mnt/mem',
    'noatime' => 1
);

$fs->mkdir('/bin');

$fs->map('/bin/sh', '/bin/sh');
my $inode = $fs->stat('/bin/sh');

ok(ref($inode) eq 'Filesys::POSIX::Real::Inode', "Filesys::POSIX->map() succeeded");

$fs->attach($inode, '/bin/bash');
ok($fs->stat('/bin/bash') eq $inode, "Filesys::POSIX->attach() operates expectedly");

$fs->mkdir('/mnt/mem/bin');
$fs->alias('/bin/bash', '/mnt/mem/bin/bash');
ok($fs->stat('/mnt/mem/bin/bash') eq $inode, "Filesys::POSIX->alias() operates expectedly");

throws_ok {
    $fs->detach('/mnt/mem/bin/bash');
    $fs->stat('/mnt/mem/bin/bash');
} qr/^No such file or directory/, "Filesys::POSIX->detach() operates expectedly";

$fs->touch('/bin/true');
$fs->replace('/bin/true', $inode);
ok($fs->stat('/bin/true') eq $inode, "Filesys::POSIX->replace() operates expectedly");
