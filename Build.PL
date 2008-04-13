#!/usr/bin/perl

# @(#)$Id: Build.PL 62 2008-04-11 01:20:52Z pjf $

use strict;
use warnings;
use Module::Build;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 62 $ =~ /\d+/gmx );

my $dist     = q(lib/CatalystX/Usul.pm);
my $requires = { 'perl'                           => '5.8',
                 'Cache::FastMmap'                => '1.09',
                 'Catalyst'                       => '5.70',
                 'Catalyst::Plugin::FillInForm'   => '0.06',
                 'Catalyst::Plugin::InflateMore'  => '0.1.3',
                 'Catalyst::Plugin::Log::Handler' => '0.07',
                 'Catalyst::Plugin::RequestToken' => '0.04',
                 'Crypt::Twofish_PP'              => '0.17',
                 'Data::Pageset'                  => '1.03',
                 'Data::Validation'               => '0.1.3',
                 'DBIx::Class'                    => '0.07005',
                 'Date::Format'                   => '2.22',
                 'Digest::SHA1'                   => '2.11',
                 'Encode'                         => '2.12',
                 'Encode::Guess'                  => '2.00',
                 'Exception::Class'               => '1.23',
                 'File::Remove'                   => '0.34',
                 'File::ShareDir'                 => '0.05',
                 'File::Temp'                     => '0.20',
                 'Getopt::Mixed'                  => '1.008',
                 'Hash::Merge'                    => '0.08',
                 'HTML::Accessors'                => '0.1.3',
                 'HTML::FormWidgets'              => '0.1.3',
                 'IO::All'                        => '0.38',
                 'IO::AtomicFile'                 => '2.110',
                 'IO::Dir'                        => '1.06',
                 'IO::File'                       => '1.14',
                 'IO::Interactive'                => '0.000003',
                 'IO::Prompt'                     => '0.099004',
                 'IPC::Open3'                     => '1.02',
                 'IPC::SysV'                      => '1.04',
                 'KinoSearch'                     => '0.20_04',
                 'Lingua::EN::NameParse'          => '1.24',
                 'Log::Handler'                   => '0.11',
                 'Module::Build'                  => '0.2805',
                 'Path::Class'                    => '0.16',
                 'Pod::ProjectDocs'               => '0.31',
                 'POSIX'                          => '1.09',
                 'Proc::ProcessTable'             => '0.40',
                 'Readonly'                       => '1.03',
                 'Template::Stash'                => '2.9',
                 'Template'                       => '2.18',
                 'Time::Elapsed'                  => '0.10',
                 'Time::Zone'                     => '2.22',
                 'XML::Simple'                    => '2.14' };
my $build    = Module::Build->new( create_makefile_pl => q(traditional),
                                   create_readme      => 1,
                                   create_packlist    => 0,
                                   dist_version_from  => $dist,
                                   license            => q(perl),
                                   module_name
                                      => q(CatalystX::Usul),
                                   requires           => $requires );

$build->create_build_script();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
