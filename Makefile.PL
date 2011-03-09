use ExtUtils::MakeMaker;

WriteMakefile
(
    'NAME'         => 'Compare::Directory',
    'VERSION_FROM' => 'lib/Compare/Directory.pm',
    'clean'        => { FILES => 'Compare-Directory-*' },
    'PREREQ_PM'    => {
        'CAM::PDF'          => '1.52',
        'File::Compare'     => '0',
        'Module::Build'     => '0.36',
        'Readonly'          => '0',
        'Test::Deep'        => '0',
        'Test::Excel'       => '1.11',
        'Test::More'        => '0',
        'XML::SemanticDiff' => '1'
    },
);