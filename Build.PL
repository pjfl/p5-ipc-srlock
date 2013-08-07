# @(#)$Ident: Build.PL 2013-08-07 00:35 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.13.%d', q$Rev: 2 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'IPC::SRLock',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'             => 5.010001,
      'namespace::sweep' => 0.006,
      'Class::Null'      => 1.09,
      'Date::Format'     => 2.24,
      'File::DataClass'  => q(0.22.0),
      'IPC::ShareLite'   => 0.17,
      'Moo'              => 1.003,
      'Time::Elapsed'    => 0.29,
      'Try::Tiny'        => 0.09,
      'Type::Tiny'       => 0.012,
      'Unexpected'       => q(0.6.0), },
   recommends            => {
      'Cache::Memcached' => 1.24, },
   configure_requires    => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
   build_requires        => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004,
      'File::DataClass'  => q(0.22.0), },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: SRLock
# mode: perl
# eval: (load-project-state "ipc-srlock")
# tab-width: 3
# End:
