use strict;
use warnings;
use File::Spec::Functions qw( catdir catfile updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English qw( -no_match_vars );
use File::DataClass::Exception;

use_ok 'IPC::SRLock';

my $is_win32 = ($OSNAME eq 'MSWin32') || ($OSNAME eq 'cygwin');

my $lock = IPC::SRLock->new( { tempdir => 't', type => 'fcntl' } ); my $e;

isa_ok $lock, 'IPC::SRLock';

eval { $lock->set() };

if ($e = File::DataClass::Exception->caught()) {
   is $e->error, 'No key specified', 'Error no key';
}
else {
   ok 0, 'Expected set error missing';
}

eval { $lock->reset( k => $PROGRAM_NAME ) };

if ($e = File::DataClass::Exception->caught()) {
   is $e->error, 'Lock [_1] not set', 'Error not set';
   ok $e->args->[ 0 ] eq $PROGRAM_NAME, 'Error args';
}
else {
   ok 0, 'Expected reset error missing';
}

$lock->set( k => $PROGRAM_NAME );

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME,
   'Set - fcntl';

$lock->reset( k => $PROGRAM_NAME );

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset - fcntl';

ok -f catfile( qw( t ipc_srlock.lck ) ), 'Lock file exists - fcntl';
ok -f catfile( qw( t ipc_srlock.shm ) ), 'Shm file exists - fcntl';

unlink catfile( qw( t ipc_srlock.lck ) );
unlink catfile( qw( t ipc_srlock.shm ) );

$lock = IPC::SRLock->new( { debug    => 1,
                            lockfile => catfile( qw( t tlock ) ),
                            shmfile  => catfile( qw( t tshm ) ),
                            tempdir  => 't',
                            type     => 'fcntl' } );

$lock->set( k => $PROGRAM_NAME, p => 100, t => 100 );

is $lock->list->[ 0 ]->{pid}, 100, 'Non default pid - fcntl';

is $lock->list->[ 0 ]->{timeout}, 100, 'Non default timeout - fcntl';

is $lock->get_table->{count}, 1, 'Get table has count - fcntl';

like $lock->_implementation->timeout_error( 0, 0, 0, 0 ),
   qr{ 0 \s set \s by \s 0 }mx, 'Timeout error - fcntl';

is $lock->set( k => $PROGRAM_NAME, async => 1 ), 0, 'Async lock - fcntl';

$lock->reset( k => $PROGRAM_NAME );

is $lock->get_table->{count}, 0, 'Get table has no count - fcntl';

unlink catfile( qw( t tlock ) );
unlink catfile( qw( t tshm  ) );

SKIP: {
   $is_win32 and skip 'tests: OS unsupported', 5;

   my $key = 12244237 + int( rand( 4096 ) );

   eval { $lock = IPC::SRLock->new( { lockfile => $key, type => 'sysv' } ) };

   my $e = $EVAL_ERROR; $e and $e =~ m{ No \s+ space }mx
      and skip 'tests: No shared memory space', 5;

   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME,
      'Set - sysv';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset - sysv';

   $lock = IPC::SRLock->new( { debug => 1, lockfile => $key, type => 'sysv' } );

   is $lock->set( k => $PROGRAM_NAME, p => 100, t => 100 ), 1,
      'Set returns true - sysv';

   is $lock->list->[ 0 ]->{pid}, 100, 'Non default pid - sysv';

   is $lock->list->[ 0 ]->{timeout}, 100, 'Non default timeout - sysv';

   is $lock->get_table->{count}, 1, 'Get table has count - sysv';

   is $lock->set( k => $PROGRAM_NAME, async => 1 ), 0, 'Async lock - sysv';

   $lock->reset( k => $PROGRAM_NAME );

   is $lock->get_table->{count}, 0, 'Get table has no count - sysv';

   qx{ ipcrm -M $key }; qx{ ipcrm -S $key };
}

SKIP: {
   ($ENV{AUTHOR_TESTING} and $ENV{HAVE_MEMCACHED})
      or skip 'author tests: Needs a memcached server', 2;
   $lock = IPC::SRLock->new( { patience => 10, type => 'memcached' } );
   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME,
      'Set - memcached';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef,
      'Reset - memcached';
}

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
