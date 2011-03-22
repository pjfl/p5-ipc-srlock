# @(#)$Id$

use strict;
use warnings;
use lib q(inc); # Contains Bob the Module::Build subclass

use Bob;

use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   sign       => 1,
   license    => q(perl),
   module     => q(IPC::SRLock),
   home_page  => q(http://www.roxsoft.co.uk),
   bugtracker => q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=),
   requires   => {
      'perl'                  => 5.008,
      'parent'                => 0.221,
      'version'               => 0.74,
      'Cache::Memcached'      => 1.24,
      'Class::Accessor::Fast' => 0.31,
      'Class::MOP'            => 0.84,
      'Class::Null'           => 1.09,
      'Data::Serializer'      => 0.46,
      'Date::Format'          => 2.22,
      'Exception::Class'      => 1.23,
      'IO::AtomicFile'        => 2.110,
      'IO::File'              => 1.14,
      'IPC::ShareLite'        => 0.17,
      'List::Util'            => 1.19,
      'MRO::Compat'           => 0.11,
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
