# @(#)$Ident: 10test_script.t 2013-05-19 11:31 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.12.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile updir);
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $reason;

BEGIN {
   my $builder = eval { Module::Build->current };

   $builder and $reason = $builder->notes->{stop_tests};
   $reason  and $reason =~ m{ \A TESTS: }mx and plan skip_all => $reason;
}

use English qw( -no_match_vars );
use IPC::SRLock::Exception;

my $is_win32 = ($OSNAME eq q(MSWin32)) || ($OSNAME eq q(cygwin));

use_ok 'IPC::SRLock';

my $lock = IPC::SRLock->new( { tempdir => q(t), type => q(fcntl) } ); my $e;

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

ok -f catfile( qw(t ipc_srlock.lck) ), 'Lock file exists';
ok -f catfile( qw(t ipc_srlock.shm) ), 'Shm file exists';

unlink catfile( qw(t ipc_srlock.lck) );
unlink catfile( qw(t ipc_srlock.shm) );

SKIP: {
   $is_win32 and skip 'tests: OS unsupported', 2;
   $reason and $reason =~ m{ \A tests: }mx and skip $reason, 2;
   $lock = IPC::SRLock->new( { type => q(sysv) } );
   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME, 'Set ipc';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset ipc';

   qx{ ipcrm -M 0x00bad50d }; qx{ ipcrm -S 0x00bad50d };
}

SKIP: {
   ($ENV{AUTHOR_TESTING} and $ENV{HAVE_MEMCACHED})
      or skip 'author tests: Needs a memcached server', 2;
   $lock = IPC::SRLock->new( { patience => 10, type => q(memcached) } );
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
