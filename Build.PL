# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   module     => q(IPC::SRLock),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
      'perl'                  => 5.010,
      'parent'                => 0.221,
      'version'               => 0.74,
      'Class::Accessor::Fast' => 0.31,
      'Class::Null'           => 1.09,
      'Data::Serializer'      => 0.46,
      'Date::Format'          => 2.22,
      'Exception::Class'      => 1.23,
      'IO::AtomicFile'        => 2.110,
      'IO::File'              => 1.14,
      'IPC::ShareLite'        => 0.17,
      'List::Util'            => 1.19,
      'Moose'                 => 2.0402,
      'Storable'              => 2.15,
      'Time::Elapsed'         => 0.10,
      'Time::HiRes'           => 1.9711,
      'Try::Tiny'             => 0.06, },
   recommends                 => {
      'Cache::Memcached'      => 1.24, },
   configure_requires => { 'Module::Build'    => 0.38,
                           'version'          => 0.74, },
   build_requires     => { 'Exception::Class' => 1.23,
                           'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# eval: (load-project-state "ipc-srlock")
# mode: perl
# tab-title: SRLock
# tab-width: 3
# End:
