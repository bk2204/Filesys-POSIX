use strict;
use warnings;

use Filesys::POSIX ();
use Filesys::POSIX::Mem ();
use Filesys::POSIX::Mem::Inode ();
use Filesys::POSIX::Bits;

use Test::More ('tests' => 10);
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

#
# Testing Filesys::POSIX->map()
#
{
    ok(ref($inode) eq 'Filesys::POSIX::Real::Inode', "Filesys::POSIX->map() succeeded");

    throws_ok {
        $fs->touch('/bin/false');
        $fs->map('/bin/false', '/bin/false');
    } qr/^File exists/, "Filesys::POSIX->map() fails when destination exists";
}

#
# Testing Filesys::POSIX->attach()
#
{
    $fs->attach($inode, '/bin/bash');
    ok($fs->stat('/bin/bash') eq $inode, "Filesys::POSIX->attach() operates expectedly");

    throws_ok {
        $fs->touch('/bin/ksh');
        $fs->attach($inode, '/bin/ksh');
    } qr/^File exists/, "Filesys::POSIX->attach() will complain when destination exists";
}

#
# Testing Filesys::POSIX->alias()
#
{
    $fs->mkdir('/mnt/mem/bin');
    $fs->alias('/bin/bash', '/mnt/mem/bin/bash');
    ok($fs->stat('/mnt/mem/bin/bash') eq $inode, "Filesys::POSIX->alias() operates expectedly");

    throws_ok {
        $fs->alias('/bin/sh', '/mnt/mem/bin/bash')
    } qr/^File exists/, "Filesys::POSIX->alias() will complain when destination exists";
}

#
# Testing Filesys::POSIX->detach()
#
{
    throws_ok {
        $fs->detach('/mnt/mem/bin/bash');
        $fs->stat('/mnt/mem/bin/bash');
    } qr/^No such file or directory/, "Filesys::POSIX->detach() operates expectedly";

    throws_ok {
        $fs->detach('/mnt/mem/bin/bash');
    } qr/^No such file or directory/, "Filesys::POSIX->detach() will complain when specified inode does not exist";
}

#
# Testing Filesys::POSIX->replace()
#
{
    $fs->touch('/bin/true');
    $fs->replace('/bin/true', $inode);
    ok($fs->stat('/bin/true') eq $inode, "Filesys::POSIX->replace() operates expectedly");

    throws_ok {
        $fs->replace('/bin/csh', $inode);
    } qr/^No such file or directory/, "Filesys::POSIX->replace() will complain when specified path does not exist";
}
