use ExtUtils::MakeMaker;

# need to install the script as well.
my $binfile = ['decked'];

WriteMakefile(
    NAME         => 'Decked',
    VERSION_FROM => 'lib/Decked/GUI.pm', # finds $VERSION
    AUTHOR       => 'Michael Dungan (mpd@yclan.net)',
    ABSTRACT     => 'A deck editor/sealed deck generator for '.
                    'online Magic: The Gathering play. Not endorsed by '.
                    'or affiliated with Wizards of the Coast',
    PREREQ_PM    => {
                     'Test::More' => 0.44,
                    },
    # install the decked script to /usr/local/bin by default
    PREFIX       => '/usr/local',
    EXE_FILES    => $binfile
);
