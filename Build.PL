# @(#)$Ident: Build.PL 2013-06-21 00:58 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.12.%d', q$Rev: 1 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(IPC::SRLock),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'             => 5.01,
      'namespace::sweep' => 0.006,
      'Class::Null'      => 1.09,
      'Date::Format'     => 2.24,
      'File::DataClass'  => q(0.20.0),
      'IPC::ShareLite'   => 0.17,
      'Moo'              => 1.002,
      'Time::Elapsed'    => 0.29,
      'Try::Tiny'        => 0.09,
      'Type::Tiny'       => 0.006,
      'Unexpected'       => q(0.3.0), },
   recommends            => {
      'Cache::Memcached' => 1.24, },
   configure_requires    => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
   build_requires        => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004,
      'File::DataClass'  => q(0.20.0), },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: SRLock
# mode: perl
# eval: (load-project-state "ipc-srlock")
# tab-width: 3
# End:
