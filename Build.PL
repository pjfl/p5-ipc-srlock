# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );

use Module::Build;

my $requires = { 'perl'                  => '5.008',
                 'parent'                => '0.221',
                 'version'               => '0.74',
                 'Cache::Memcached'      => '1.24',
                 'Class::Accessor::Fast' => '0.31',
                 'Class::MOP'            => '0.84',
                 'Class::Null'           => '1.09',
                 'Data::Serializer'      => '0.46',
                 'Date::Format'          => '2.22',
                 'Exception::Class'      => '1.23',
                 'IO::AtomicFile'        => '2.110',
                 'IO::File'              => '1.14',
                 'IPC::SysV'             => '1.04',
                 'IPC::ShareLite'        => '0.13',
                 'List::Util'            => '1.19',
                 'Storable'              => '2.15',
                 'Time::Elapsed'         => '0.10',
                 'Time::HiRes'           => '1.9711' };
my $build = Module::Build->new
   ( add_to_cleanup     => [ 'Debian_CPANTS.txt',
                             'IPC-SRLock-*',
                             map { ( '*/' x $_ ) . '*~' } 0..5 ],
     build_requires     => { 'Exception::Class'    => q(1.23),
                             'List::Util'          => q(1.19),
                             'Test::More'          => q(0.74) },
     configure_requires => { 'ExtUtils::MakeMaker' => q(6.42),
                             'version'             => q(0.74) },
     create_makefile_pl => q(traditional),
     create_readme      => 1,
     create_packlist    => 0,
     dist_version_from  => q(lib/IPC/SRLock.pm),
     license            => q(perl),
     module_name        => q(IPC::SRLock),
     notes              => { cpan_testers_version => 1 },
     requires           => $requires,
     sign               => 1, );

$build->create_build_script();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
