# @(#)$Id$

use strict;
use warnings;

use English qw(-no_match_vars);

sub testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
              || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx
              || ($ENV{PERL5LIB} || q()) =~ m{ \A /home/sand }mx) }

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN {
   eval { require 5.008; }; $EVAL_ERROR and whimper 'Perl minimum 5.8';
}

use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use Module::Build;

Module::Build->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), q(IPC-SRLock-*),
                             map { ( '*/' x $_ ) . '*~' } 0..5 ],
     build_requires     => { 'Exception::Class' => 1.23,
                             'List::Util'       => 1.19,
                             'Test::More'       => 0.74, },
     configure_requires => { 'Module::Build'    => 0.32,
                             'version'          => 0.74, },
     create_license     => 1,
     create_packlist    => 0,
     create_readme      => 1,
     dist_version_from  => q(lib/IPC/SRLock.pm),
     license            => q(perl),
     module_name        => q(IPC::SRLock),
     no_index           => { directory  => [ qw(t) ], },
     notes              => { stop_tests => testing,   },
     requires           => {
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
     sign               => 1, )->create_build_script;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
