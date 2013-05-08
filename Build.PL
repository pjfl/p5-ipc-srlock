# @(#)$Ident: Build.PL 2013-05-08 20:23 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev: 9 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(IPC::SRLock),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                         => 5.010,
      'parent'                       => 0.221,
      'version'                      => 0.74,
      'Class::Null'                  => 1.09,
      'Date::Format'                 => 2.22,
      'File::DataClass'              => q(0.20.0),
      'IPC::ShareLite'               => 0.17,
      'Moose'                        => 2.0402,
      'MooseX::Types'                => 0.25,
      'MooseX::Types::Common'        => 0.001008,
      'MooseX::Types::LoadableClass' => 0.007,
      'Storable'                     => 2.39,
      'Time::Elapsed'                => 0.10,
      'Time::HiRes'                  => 1.9711,
      'Try::Tiny'                    => 0.06,
      'Unexpected'                   => q(0.1.0), },
   recommends                        => {
      'Cache::Memcached'             => 1.24, },
   configure_requires                => {
      'version'                      => 0.74,
      'Module::Build'                => 0.38, },
   build_requires                    => {
      'File::DataClass'              => q(0.20.0),
      'Test::More'                   => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: SRLock
# mode: perl
# eval: (load-project-state "ipc-srlock")
# tab-width: 3
# End:
