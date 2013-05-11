# @(#)$Ident: Build.PL 2013-05-11 12:43 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev: 12 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(IPC::SRLock),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                         => 5.01,
      'namespace::autoclean'         => 0.13,
      'Class::Null'                  => 1.09,
      'Date::Format'                 => 2.24,
      'File::DataClass'              => q(0.20.0),
      'IPC::ShareLite'               => 0.17,
      'Moose'                        => 2.0802,
      'MooseX::Types'                => 0.35,
      'MooseX::Types::Common'        => 0.001008,
      'MooseX::Types::LoadableClass' => 0.008,
      'Time::Elapsed'                => 0.29,
      'Try::Tiny'                    => 0.09,
      'Unexpected'                   => q(0.1.0), },
   recommends                        => {
      'Cache::Memcached'             => 1.24, },
   configure_requires                => {
      'version'                      => 0.88,
      'Module::Build'                => 0.38, },
   build_requires                    => {
      'version'                      => 0.88,
      'Module::Build'                => 0.38,
      'File::DataClass'              => q(0.20.0), },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: SRLock
# mode: perl
# eval: (load-project-state "ipc-srlock")
# tab-width: 3
# End:
