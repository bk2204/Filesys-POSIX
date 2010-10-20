package Filesys::POSIX::Mem::Bucket;

use strict;
use warnings;

use Filesys::POSIX::Bits;

use File::Temp qw/mkstemp/;

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

    die('Already opened') if $self->{'fh'};

    if (exists $self->{'file'}) {
        sysopen(my $fh, $self->{'file'}, $O_RDWR) or die("Unable to reopen bucket $self->{'file'}: $!");

        $self->{'fh'} = $fh;
    }

    return $self;
}

sub _flush_to_disk {
    my ($self, $len) = @_;

    die('Already flushed to disk') if $self->{'file'};

    my ($fh, $file) = mkstemp("$self->{'dir'}/.bucket-XXXXXX") or die("Unable to create disk bucket file: $!");
    my $offset = 0;

    for (my $left = $self->{'size'}; $left > 0; $left -= $len) {
        my $wrlen = $left > $len? $len: $left;

        syswrite($fh, substr($self->{'buf'}, $offset, $wrlen), $wrlen);

        $offset += $wrlen;
    }

    sysseek($fh, 0, $SEEK_SET);

    @{$self}{qw/fh file/} = ($fh, $file);
}

sub write {
    my ($self, $buf, $len) = @_;
    my $ret = 0;

    unless ($self->{'fh'}) {
        $self->_flush_to_disk($len) if $self->{'size'} + $len > $self->{'max'};
    }

    if ($self->{'fh'}) {
        $ret = syswrite($self->{'fh'}, $buf) or die("Unable to write to disk bucket: $!");
    } else {
        $self->{'buf'} .= substr($buf, 0, $len);
        $ret = $len;
    }

    $self->{'size'} += $ret;

    #
    # If we happen to have a reference to the inode this bucket was
    # opened for, we should update its 'size' attribute as well.
    #
    if ($self->{'inode'}) {
        $self->{'inode'}->{'size'} = $self->{'size'};
    }
}

sub read {
    my $self = shift;
    my $len = pop;
    my $ret = 0;

    if ($self->{'fh'}) {
        $ret = sysread($self->{'fh'}, $_[0], $len);
        die("Unable to read bucket: $!") if $ret == 0 && $!;
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
        die('Invalid position') if $self->{'pos'} - $pos < 0;
        $self->{'pos'} -= $pos;
    }

    if ($self->{'fh'}) {
        sysseek($self->{'fh'}, $pos, $whence);
    }
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
