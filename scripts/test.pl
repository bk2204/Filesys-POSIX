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
$fs->unmount('/mnt/real');
$fs->mount($real, '/mnt/real');

foreach ($fs->mountpoints) {
    my $dev = $fs->statfs($_);

    printf("%s on %s (%s)\n", $dev, $_, join(', ', keys %{$dev->{'flags'}}));
}
