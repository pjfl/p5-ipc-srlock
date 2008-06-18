#!/usr/bin/perl

# @(#)$Id$

use strict;
use warnings;
use Module::Build;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

my $requires = { 'perl'                        => '5.8',
                 'version'                     => '0.74',
                 'Cache::Memcached'            => '1.24',
                 'Class::Accessor::Fast'       => '0.31',
                 'Class::Inspector'            => '1.18',
                 'Class::Null'                 => '1.09',
                 'Data::Serializer'            => '0.46',
                 'Date::Format'                => '2.22',
                 'Exception::Class'            => '1.23',
                 'IO::AtomicFile'              => '2.110',
                 'IO::File'                    => '1.14',
                 'IPC::SysV'                   => '1.04',
                 'IPC::SRLock::ExceptionClass' => '0',
                 'List::Util'                  => '1.19',
                 'Readonly'                    => '1.03',
                 'Time::Elapsed'               => '0.10',
                 'Time::HiRes'                 => '1.9711' };
my $build = Module::Build->new
   ( build_requires     => { 'Test::More' => q(0.74), 'version'=> q(0.74) },
     create_makefile_pl => q(traditional),
     create_readme      => 1,
     create_packlist    => 0,
     dist_version_from  => q(lib/IPC/SRLock.pm),
     license            => q(perl),
     module_name        => q(IPC::SRLock),
     notes
        => { cpan_testers      => 1,
             cpan_testers_cond => q($ENV{PATH} =~ m{ srezic }mx) },
     requires           => $requires );

$build->create_build_script();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
