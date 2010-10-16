#! /usr/bin/perl -I../lib

use strict;
use warnings;

use Filesys::POSIX;
use Filesys::POSIX::Bits;
use Filesys::POSIX::Mem;
use Filesys::POSIX::Real;
use Filesys::POSIX::Userland;

use Data::Dumper;
$Data::Dumper::Indent = 1;

my $fs = Filesys::POSIX->new(Filesys::POSIX::Mem->new,
    'noatime' => 1
);

my $real = Filesys::POSIX::Real->new('/Users/erin');

$fs->mkdir('/mnt');
$fs->mkdir('/mnt/real');
$fs->mount($real, '/mnt/real');
$fs->mkdir('/mnt/real/foo');

my $node = $fs->stat('/mnt/real/foo');
$node->chmod(0777);
$fs->rmdir('/mnt/real/foo');

printf("%s\n", $fs->realpath('/mnt/real/Documents/Virtual Machines'));
