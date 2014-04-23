# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

package Filesys::POSIX::Real::Inode;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::Bits::System;
use Filesys::POSIX::Inode      ();
use Filesys::POSIX::Mem::Inode ();
use Filesys::POSIX::IO::Handle ();

use Fcntl qw/:DEFAULT :mode/;
use Carp qw/confess/;

our @ISA = qw/Filesys::POSIX::Inode/;

sub new {
    my ( $class, $path, %opts ) = @_;

    my $sticky = 0;

    #
    # Allow the sticky flag to be set for every inode belonging to a
    # Filesys::POSIX::Real filesystem, with usage of a special mount flag.
    # However, allow this flag to be overridden on a per-inode basis, which
    # happens with each call from Filesys::POSIX::Extensions->map and the like.
    #
    if ( defined $opts{'dev'}->{'sticky'} ) {
        $sticky = $opts{'dev'}->{'sticky'} ? 1 : 0;
    }

    if ( defined $opts{'sticky'} ) {
        $sticky = $opts{'sticky'} ? 1 : 0;
    }

    return bless {
        'path'   => $path,
        'dev'    => $opts{'dev'},
        'parent' => $opts{'parent'},
        'sticky' => $sticky,
        'dirty'  => 0
    }, $class;
}

sub from_disk {
    my ( $class, $path, %opts ) = @_;
    my @st = $opts{'st_info'} ? @{ $opts{'st_info'} } : lstat $path or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).

    my $inode = $class->new( $path, %opts )->update(@st);

    if ( S_IFMT( $st[2] ) == S_IFDIR ) {
        $inode->{'directory'} = Filesys::POSIX::Real::Directory->new( $path, $inode );
    }

    return $inode;
}

sub child {
    my ( $self, $name, $mode ) = @_;
    my $directory = $self->directory;

    confess('Invalid directory entry name') if $name =~ /\//;
    confess('File exists') if $directory->exists($name);

    my $path = "$self->{'path'}/$name";

    my %data = (
        'dev'    => $self->{'dev'},
        'sticky' => $self->{'sticky'},
        'parent' => $directory->get('.')
    );

    if ( ( $mode & $S_IFMT ) == $S_IFREG ) {
        sysopen( my $fh, $path, O_CREAT | O_EXCL | O_WRONLY, Filesys::POSIX::Bits::System::convertModeToSystem($mode) )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
        close($fh);
    }
    elsif ( ( $mode & $S_IFMT ) == $S_IFDIR ) {
        mkdir( $path, $mode )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
    }

    my $inode;

    if ( ( $mode & $S_IFMT ) == $S_IFLNK ) {
        confess('Operation not permitted') unless $self->{'sticky'};

        $inode = Filesys::POSIX::Mem::Inode->new( %data, 'mode' => $mode );
    }
    else {
        $inode = __PACKAGE__->from_disk( $path, %data );
    }

    return $directory->set( $name, $inode );
}

sub taint {
    my ($self) = @_;

    $self->{'dirty'} = 1;

    return $self;
}

sub update {
    my ( $self, @st ) = @_;

    if ( $self->{'sticky'} && $self->{'dirty'} ) {
        @{$self}{qw/rdev size atime mtime ctime/} = @st[ 6 .. 10 ];
    }
    else {
        $self->SUPER::update(@st);
    }

    return $self;
}

sub open {
    my ( $self, $flags ) = @_;

    sysopen( my $fh, $self->{'path'}, Filesys::POSIX::Bits::System::convertFlagsToSystem($flags) )
      or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).

    return Filesys::POSIX::IO::Handle->new($fh);
}

sub chown {
    my ( $self, $uid, $gid ) = @_;

    unless ( $self->{'sticky'} ) {
        CORE::chown( $uid, $gid, $self->{'path'} )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
    }

    @{$self}{qw/uid gid/} = ( $uid, $gid );

    return $self->taint;
}

sub chmod {
    my ( $self, $mode ) = @_;
    my $format = $self->{'mode'} & $S_IFMT;
    my $perm = $mode & ( $S_IPERM | $S_IPROT );

    unless ( $self->{'sticky'} ) {
        CORE::chmod( $perm, $self->{'path'} )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
    }

    $self->{'mode'} = $format | $perm;

    return $self->taint;
}

sub readlink {
    my ($self) = @_;

    unless ( $self->{'dest'} ) {
        $self->{'dest'} = CORE::readlink( $self->{'path'} )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
    }

    return $self->{'dest'};
}

sub symlink {
    my ( $self, $dest ) = @_;

    unless ( $self->{'sticky'} ) {
        symlink( $dest, $self->{'path'} )
          or confess("$!");    # Use quotes to copy the error string (resolves Case 98565).
    }

    $self->{'dest'} = $dest;

    return $self->taint;
}

1;
