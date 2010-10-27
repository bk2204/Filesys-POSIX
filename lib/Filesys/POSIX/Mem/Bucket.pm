package Filesys::POSIX::Mem::Bucket;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use File::Temp qw/mkstemp/;
use Fcntl;

use Carp;

my $DEFAULT_MAX = 16384;
my $DEFAULT_DIR = '/tmp';

sub new {
    my ($class, %opts) = @_;

    return bless {
        'fh'    => undef,
        'buf'   => '',
        'max'   => defined $opts{'max'}? $opts{'max'}: $DEFAULT_MAX,
        'dir'   => defined $opts{'dir'}? $opts{'dir'}: $DEFAULT_DIR,
        'inode' => $opts{'inode'},
        'size'  => 0,
        'pos'   => 0
    }, $class;
}

sub DESTROY {
    my ($self) = @_;

    if ($self->{'fh'}) {
        close($self->{'fh'});
    }

    if ($self->{'file'} && -f $self->{'file'}) {
        unlink $self->{'file'};
    }
}

sub open {
    my ($self, $flags) = @_;

    $self->{'flags'} = $flags? $flags: $O_RDONLY;

    confess('Already opened') if $self->{'fh'};

    if ($flags & $O_APPEND) {
        $self->{'pos'} = $self->{'size'};
    } elsif ($flags & $O_TRUNC) {
        $self->{'pos'} = 0;
    }

    if (exists $self->{'file'}) {
        my $realflags = 0;

        sysopen(my $fh, $self->{'file'}, $flags) or confess("Unable to reopen bucket $self->{'file'}: $!");

        $self->{'fh'} = $fh;
    } else {
        if ($flags & $O_TRUNC) {
            $self->{'size'} = 0;
            undef $self->{'buf'};
        }
    }

    return $self;
}

sub _flush_to_disk {
    my ($self, $len) = @_;

    confess('Already flushed to disk') if $self->{'file'};

    my ($fh, $file) = mkstemp("$self->{'dir'}/.bucket-XXXXXX") or confess("Unable to create disk bucket file: $!");
    my $offset = 0;

    for (my $left = $self->{'size'}; $left > 0; $left -= $len) {
        my $wrlen = $left > $len? $len: $left;

        syswrite($fh, substr($self->{'buf'}, $offset, $wrlen), $wrlen);

        $offset += $wrlen;
    }

    @{$self}{qw/fh file/} = ($fh, $file);
}

sub write {
    my ($self, $buf, $len) = @_;
    my $ret = 0;

    unless ($self->{'fh'}) {
        $self->_flush_to_disk($len) if $self->{'pos'} + $len > $self->{'max'};
    }

    if ($self->{'fh'}) {
        $ret = syswrite($self->{'fh'}, $buf) or confess("Unable to write to disk bucket: $!");
    } else {
        if ((my $gap = $self->{'pos'} - $self->{'size'}) > 0) {
            $self->{'buf'} .= "\x00" x $gap;
        }

        substr($self->{'buf'}, $self->{'pos'}, $len) = substr($buf, 0, $len);
        $ret = $len;
    }

    $self->{'pos'} += $ret;
    $self->{'size'} += $ret;

    if ($self->{'pos'} > $self->{'size'}) {
        $self->{'size'} = $self->{'pos'};
    }

    #
    # If we happen to have a reference to the inode this bucket was
    # opened for, we should update its 'size' attribute as well.
    #
    if ($self->{'inode'}) {
        $self->{'inode'}->{'size'} = $self->{'size'};
    }

    return $ret;
}

sub read {
    my $self = shift;
    my $len = pop;
    my $ret = 0;

    if ($self->{'fh'}) {
        $ret = sysread($self->{'fh'}, $_[0], $len);
        confess("Unable to read bucket: $!") if $ret == 0 && $!;
    } else {
        my $maxlen = $self->{'size'} - $self->{'pos'};
        $len = $maxlen if $len > $maxlen;

        $_[0] = substr($self->{'buf'}, $self->{'pos'}, $len);
        $ret = $len;
    }

    $self->{'pos'} += $ret;

    return $ret;
}

sub seek {
    my ($self, $pos, $whence) = @_;

    if ($whence == $SEEK_SET) {
        $self->{'pos'} = $pos;
    } elsif ($whence == $SEEK_CUR) {
        $self->{'pos'} += $pos;
    } elsif ($whence == $SEEK_END) {
        confess('Invalid position') if $self->{'pos'} - $pos < 0;
        $self->{'pos'} -= $pos;
    }

    if ($self->{'fh'}) {
        return sysseek($self->{'fh'}, $pos, $whence);
    }

    return $self->{'pos'};
}

sub tell {
    return shift->{'pos'};
}

sub close {
    my ($self) = @_;

    if ($self->{'fh'}) {
        close $self->{'fh'};
        undef $self->{'fh'};
    }

    $self->{'pos'}  = 0;
}

1;
