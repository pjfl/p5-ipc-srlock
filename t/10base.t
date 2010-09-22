# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.5.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Exception::Class ( q(TestException) => { fields => [ qw(args) ] } );
use English qw( -no_match_vars );
use Test::More;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 7;
}

use List::Util qw(first);

use_ok q(IPC::SRLock);

my $lock = IPC::SRLock->new( { type => q(fcntl) } ); my $e;

eval { $lock->reset( k => $PROGRAM_NAME ) };

if ($e = Exception::Class->caught()){
   ok( $e->error eq 'Lock [_1] not set', q(lock not set) );
   ok( $e->args->[0] eq $PROGRAM_NAME, q(lock error args) );
}

$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set fcntl) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset fcntl) );

unlink q(/tmp/ipc_srlock.lck);
unlink q(/tmp/ipc_srlock.shm);

$lock = IPC::SRLock->new( { type => q(sysv) } );
$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set ipc) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset ipc) );

exit 0;

# Need a memcached server to run these tests
$lock = IPC::SRLock->new( { patience => 10, type => q(memcached) } );
$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set memcached) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset memcached) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
