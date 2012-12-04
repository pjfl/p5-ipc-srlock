# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile tmpdir updir);
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
use List::Util qw(first);

use_ok q(IPC::SRLock);

my $lock = IPC::SRLock->new( { type => q(fcntl) } ); my $e;

eval { $lock->reset( k => $PROGRAM_NAME ) };

if ($e = Exception::Class->caught()) {
   ok $e->error eq q(Lock [_1] not set), 'Error not set';
   ok $e->args->[0] eq $PROGRAM_NAME, 'Error args';
}
else {
   ok 0, 'Expected error missing';
}

$lock->set( k => $PROGRAM_NAME );

ok !! (first { $_ eq $PROGRAM_NAME }
       map   { $_->{key} } @{ $lock->list() }), 'Set fcntl';

$lock->reset( k => $PROGRAM_NAME );

ok ! (first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), 'Reset fcntl';

unlink catfile( tmpdir, q(ipc_srlock.lck) );
unlink catfile( tmpdir, q(ipc_srlock.shm) );

unless ($OSNAME eq q(MSWin32) or $OSNAME eq q(cygwin)) {
   $lock = IPC::SRLock->new( { type => q(sysv) } );
   $lock->set( k => $PROGRAM_NAME );

   ok !! (first { $_ eq $PROGRAM_NAME }
          map   { $_->{key} } @{ $lock->list() }), 'Set ipc';

   $lock->reset( k => $PROGRAM_NAME );

   ok ! (first { $_ eq $PROGRAM_NAME }
         map   { $_->{key} } @{ $lock->list() }), 'Reset ipc';

   qx{ ipcrm -M 0x00bad50d };
   qx{ ipcrm -S 0x00bad50d };
}

# Need a memcached server to run these tests
if ($current and $current->notes->{have_memcached}) {
   $lock = IPC::SRLock->new( { patience => 10, type => q(memcached) } );
   $lock->set( k => $PROGRAM_NAME );

   ok !! (first { $_ eq $PROGRAM_NAME }
          map   { $_->{key} } @{ $lock->list() }), 'Set memcached';

   $lock->reset( k => $PROGRAM_NAME );

   ok ! (first { $_ eq $PROGRAM_NAME }
         map   { $_->{key} } @{ $lock->list() }), 'Reset memcached';
}

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
