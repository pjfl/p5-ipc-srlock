# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile updir);
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $current;

BEGIN {
   $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use English qw( -no_match_vars );
use Exception::Class ( q(TestException) => { fields => [ qw(args) ] } );

use_ok 'IPC::SRLock';

my $lock = IPC::SRLock->new( { tempdir => q(t), type => q(fcntl) } ); my $e;

eval { $lock->reset( k => $PROGRAM_NAME ) };

if ($e = Exception::Class->caught()) {
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

unless ($OSNAME eq q(MSWin32) or $OSNAME eq q(cygwin)) {
   $lock = IPC::SRLock->new( { type => q(sysv) } );
   $lock->set( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], $PROGRAM_NAME, 'Set ipc';

   $lock->reset( k => $PROGRAM_NAME );

   is [ map { $_->{key} } @{ $lock->list() } ]->[ 0 ], undef, 'Reset ipc';

   qx{ ipcrm -M 0x00bad50d };
   qx{ ipcrm -S 0x00bad50d };
}

# Need a memcached server to run these tests
if ($current and $current->notes->{have_memcached}) {
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
