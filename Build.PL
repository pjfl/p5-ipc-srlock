# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   stop_tests => 1,
   module     => q(IPC::SRLock),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
      'perl'                  => 5.008,
      'parent'                => 0.221,
      'version'               => 0.74,
      'Cache::Memcached'      => 1.24,
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
   configure_requires => { 'Module::Build'    => 0.32,
                           'version'          => 0.74, },
   build_requires     => { 'Exception::Class' => 1.23,
                           'List::Util'       => 1.19,
                           'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# tab-width: 3
# End:
