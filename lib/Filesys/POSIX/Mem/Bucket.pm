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
        'max'   => $opts{'max'}? $opts{'max'}: $DEFAULT_MAX,
        'dir'   => $opts{'dir'}? $opts{'dir'}: $DEFAULT_DIR,
        'inode' => $opts{'inode'},
        'size'  => 0,
        'pos'   => 0
    }, $class;
}

sub open {
    my ($self, $flags) = @_;

    $self->{'flags'} = $flags? $flags: $O_RDONLY;

    if (exists $self->{'file'}) {
        sysopen(my $fh, $self->{'file'}, $O_RDWR) or die("Unable to reopen bucket $self->{'file'}: $!");
    }

    return $self;
}

sub write {
    my ($self, $buf, $len) = @_;
    my $ret = 0;

    if ($self->{'size'} + $len > $self->{'max'}) {
        my ($fd, $file) = mkstemp("$self->{'dir'}/.bucket-XXXXXX") or die("Unable to create bucket: $!");

        syswrite($fd, $self->{'buf'}, $self->{'size'}) or die("Unable to flush bucket to disk: $!");
        $ret = syswrite($fd, $buf) or die("Unable to flush buffer to disk: $!");
        sysseek($fd, 0, 0);

        @{$self}{qw/fd file/} = ($fd, $file);
    } elsif ($self->{'fh'}) {
        $ret = syswrite($self->{'fh'}, $buf) or die("Unable to flush buffer to disk: $!");
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
        $ret = sysread($self->{'fh'}, $_[0], $len) or die("Unable to read bucket: $!");
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

    delete $self->{'buf'};
    $self->{'buf'} = '';
    $self->{'size'} = 0;
    $self->{'pos'}  = 0;
}

1;
