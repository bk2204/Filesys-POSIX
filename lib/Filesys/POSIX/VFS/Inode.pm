# Filesys::POSIX           Copyright (c) 2011 cPanel, Inc.  All rights reserved.
# copyright@cpanel.net                                        http://cpanel.net/
# 
# Written by Erin Schönhals <erin@cpanel.net>.  Released under the terms of the
# Perl Artistic License.

package Filesys::POSIX::VFS::Inode;

use strict;
use warnings;

sub new {
    my ( $class, $mountpoint, $root ) = @_;

    return bless {
        %$root,
        'parent' => $mountpoint->{'parent'}
      },
      ref $root;
}

1;
