# @(#)$Ident: 10test_script.t 2013-09-11 20:29 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 1 $ =~ /\d+/gmx );
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

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME, 'Set fcntl';

$lock->reset( k => $PROGRAM_NAME );

is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset fcntl';

ok -f catfile( qw( t ipc_srlock.lck ) ), 'Lock file exists';
ok -f catfile( qw( t ipc_srlock.shm ) ), 'Shm file exists';

unlink catfile( qw( t ipc_srlock.lck ) );
unlink catfile( qw( t ipc_srlock.shm ) );

$lock = IPC::SRLock->new( { debug    => 1,
                            lockfile => catfile( qw( t tlock ) ),
                            shmfile  => catfile( qw( t tshm ) ),
                            tempdir  => 't',
                            type     => 'fcntl' } );

$lock->set( k => $PROGRAM_NAME, p => 100, t => 100 );

is $lock->list->[ 0 ]->{pid}, 100, 'Non default pid';

is $lock->list->[ 0 ]->{timeout}, 100, 'Non default timeout';

is $lock->get_table->{count}, 1, 'Get table has count';

like $lock->_implementation->timeout_error( 0, 0, 0, 0 ),
   qr{ 0 \s set \s by \s 0 }mx, 'Timeout error';

$lock->reset( k => $PROGRAM_NAME );

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
      'Set sysv';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset sysv';

   $lock = IPC::SRLock->new( { debug => 1, lockfile => $key, type => 'sysv' } );

   $lock->set( k => $PROGRAM_NAME, p => 100, t => 100 );

   is $lock->list->[ 0 ]->{pid}, 100, 'Non default pid - sysv';

   is $lock->list->[ 0 ]->{timeout}, 100, 'Non default timeout - sysv';

   is $lock->get_table->{count}, 1, 'Get table has count - sysv';

   $lock->reset( k => $PROGRAM_NAME );

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
