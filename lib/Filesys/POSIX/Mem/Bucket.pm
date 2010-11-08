package Filesys::POSIX::Mem::Bucket;

use strict;
use warnings;

use Filesys::POSIX::Bits;
use Filesys::POSIX::IO::Handle ();

use File::Temp qw/mkstemp/;
use Carp qw/confess/;

our @ISA = qw/Filesys::POSIX::IO::Handle/;

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
    $flags ||= 0;

    confess('Already opened') if $self->{'fh'};

    if ($flags & $O_APPEND) {
        $self->{'pos'} = $self->{'size'};
    } elsif ($flags & $O_TRUNC) {
        $self->{'pos'} = 0;
        $self->{'size'} = 0;
    }

    if ($self->{'file'}) {
        sysopen(my $fh, $self->{'file'}, $flags) or confess("Unable to reopen bucket $self->{'file'}: $!");

        $self->{'fh'} = $fh;
    } else {
        if ($flags & $O_TRUNC) {
            $self->{'size'} = 0;
            undef $self->{'buf'};
        }
    }

    $self->{'inode'}->{'size'} = 0 if $flags & $O_TRUNC;

    return $self;
}

sub _flush_to_disk {
    my ($self, $len) = @_;

    confess('Already flushed to disk') if $self->{'file'};

    my ($fh, $file) = eval {
        mkstemp("$self->{'dir'}/.bucket-XXXXXX")
    };

    confess("mkstemp() failure: $@") if $@;

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
        confess("Unable to write to disk bucket") unless fileno($self->{'fh'});
        $ret = syswrite($self->{'fh'}, $buf);
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

    $self->{'inode'}->{'size'} = $self->{'size'};

    return $ret;
}

sub read {
    my $self = shift;
    my $len = pop;
    my $ret = 0;

    if ($self->{'fh'}) {
        confess("Unable to read bucket: $!") unless fileno($self->{'fh'});
        $ret = sysread($self->{'fh'}, $_[0], $len);
    } else {
        my $pos = $self->{'pos'} > $self->{'size'}? $self->{'size'}: $self->{'pos'};
        my $maxlen = $self->{'size'} - $pos;
        $len = $maxlen if $len > $maxlen;

        unless ($len) {
            $_[0] = '';
            return 0;
        }

        $_[0] = substr($self->{'buf'}, $self->{'pos'}, $len);
        $ret = $len;
    }

    $self->{'pos'} += $ret;

    return $ret;
}

sub seek {
    my ($self, $pos, $whence) = @_;
    my $newpos;

    if ($self->{'fh'}) {
        $newpos = sysseek($self->{'fh'}, $pos, $whence);
    } elsif ($whence == $SEEK_SET) {
        $newpos = $pos;
    } elsif ($whence == $SEEK_CUR) {
        $newpos = $self->{'pos'} + $pos;
    } elsif ($whence == $SEEK_END) {
        $newpos = $self->{'size'} + $pos;
    } else {
        confess('Invalid argument');
    }

    return $self->{'pos'} = $newpos;
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

    $self->{'pos'} = 0;
}

1;
