#! /usr/bin/perl -I../lib

use strict;
use warnings;

use Filesys::POSIX::Mem;

use Data::Dumper;

my $fs = Filesys::POSIX::Mem->new;
$fs->mkdir('foo');
$fs->chdir('foo/..');

printf("File descriptors: %s\n", join(', ', keys %{$fs->{'fds'}}));
