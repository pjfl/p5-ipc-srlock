#!/usr/bin/perl

# @(#)$Id$

use strict;
use warnings;
use Module::Build;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

my $dist     = q(lib/IPC/SRLock.pm);
my $requires = { 'perl'                           => '5.8',
                 'Class::Accessor::Fast'          => '0.31',
                 'Class::Inspector'               => '1.18',
                 'Class::Null'                    => '1.09',
                 'Date::Format'                   => '2.22',
                 'Exception::Class'               => '1.23',
                 'IO::AtomicFile'                 => '2.110',
                 'IO::File'                       => '1.14',
                 'IPC::SysV'                      => '1.04',
                 'List::Util'                     => '1.19',
                 'NEXT'                           => '0.60',
                 'Readonly'                       => '1.03',
                 'Time::Elapsed'                  => '0.10',
                 'Time::HiRes'                    => '1.9711',
                 'XML::Simple'                    => '2.14' };
my $build    = Module::Build->new( create_makefile_pl => q(traditional),
                                   create_readme      => 1,
                                   create_packlist    => 0,
                                   dist_version_from  => $dist,
                                   license            => q(perl),
                                   module_name        => q(IPC::SRLock),
                                   requires           => $requires );

$build->create_build_script();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
