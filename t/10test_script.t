# @(#)$Ident: 10test_script.t 2013-08-16 23:13 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.14.%d', q$Rev: 3 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English qw( -no_match_vars );

use_ok 'IPC::SRLock::Exception';
use_ok 'IPC::SRLock';

my $is_win32 = ($OSNAME eq 'MSWin32') || ($OSNAME eq 'cygwin');

my $lock = IPC::SRLock->new( { tempdir => 't', type => 'fcntl' } ); my $e;

eval { $lock->reset( k => $PROGRAM_NAME ) };

if ($e = IPC::SRLock::Exception->caught()) {
   ok $e->error eq 'Lock [_1] not set', 'Error not set';
   ok $e->args->[ 0 ] eq $PROGRAM_NAME, 'Error args';
}
else {
   ok 0, 'Expected error missing';
}

$lock->set( k => $PROGRAM_NAME );

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME, 'Set fcntl';

$lock->reset( k => $PROGRAM_NAME );

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset fcntl';

ok -f catfile( qw( t ipc_srlock.lck ) ), 'Lock file exists';
ok -f catfile( qw( t ipc_srlock.shm ) ), 'Shm file exists';

unlink catfile( qw( t ipc_srlock.lck ) );
unlink catfile( qw( t ipc_srlock.shm ) );

SKIP: {
   $is_win32 and skip 'tests: OS unsupported', 2;

   my $key = 12244237 + int( rand( 4096 ) );

   $lock = IPC::SRLock->new( { lockfile => $key, type => 'sysv' } );
   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME, 'Set ipc';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset ipc';

   qx{ ipcrm -M $key }; qx{ ipcrm -S $key };
}

SKIP: {
   ($ENV{AUTHOR_TESTING} and $ENV{HAVE_MEMCACHED})
      or skip 'author tests: Needs a memcached server', 2;
   $lock = IPC::SRLock->new( { patience => 10, type => 'memcached' } );
   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME,
      'Set memcached';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset memcached';
}

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
