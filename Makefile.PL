use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'Filesys::POSIX',
    'VERSION_FROM'  => 'lib/Filesys/POSIX.pm', # finds \$VERSION
    'AUTHOR'        => 'Erin Schoenhals (erin@cpanel.net)',
    'ABSTRACT'      => 'Provides POSIX filesystem semantics in pure Perl',
    'PREREQ_PM'     => {
        'Test::Simple' => 0.44
    }
);
