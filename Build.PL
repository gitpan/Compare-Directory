use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Compare::Directory',
    license             => 'perl',
    dist_author         => q{Mohammad S Anwar <mohammad.anwar@yahoo.com>},
    dist_version_from   => 'lib/Compare/Directory.pm',
    build_requires => {
        'Test::More'        => 0,
        'Test::Deep'        => 0,
        'Readonly'          => 0,
        'Module::Build'     => 0.36,
        'Test::Excel'       => 1.04,
        'CAM::PDF'          => 1.52,
        'File::Compare'     => 0,
        'XML::SemanticDiff' => 1.0
    },
    add_to_cleanup      => [ 'Compare-Directory-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();