#!/usr/bin/perl

# @(#)$Id$

use strict;
use warnings;
use Module::Build;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

my $requires = { 'perl'                  => '5.008',
                 'version'               => '0.74',
                 'Cache::Memcached'      => '1.24',
                 'Class::Accessor::Fast' => '0.31',
                 'Class::Inspector'      => '1.18',
                 'Class::Null'           => '1.09',
                 'Data::Serializer'      => '0.46',
                 'Date::Format'          => '2.22',
                 'Exception::Class'      => '1.23',
                 'IO::AtomicFile'        => '2.110',
                 'IO::File'              => '1.14',
                 'IPC::SysV'             => '1.04',
                 'IPC::ShareLite'        => '0.13',
                 'List::Util'            => '1.19',
                 'Readonly'              => '1.03',
                 'Storable'              => '2.15',
                 'Time::Elapsed'         => '0.10',
                 'Time::HiRes'           => '1.9711' };
my $build = Module::Build->new
   ( add_to_cleanup     => [ 'IPC-SRLock-*',
                             map { ( '*/' x $_ ) . '*~' } 0..5 ],
     build_requires     => { 'Test::Harness'       => q(2.64),
                             'Test::More'          => q(0.74),
                             'Test::Pod'           => q(1.14) },
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
     sign               => 1 );

$build->create_build_script();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
