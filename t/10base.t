#!/usr/bin/perl

# @(#)$Id$

use strict;
use warnings;
use English qw(-no_match_vars);
use File::Spec::Functions;
use FindBin  qw( $Bin );
use lib (catdir( $Bin, updir, q(lib) ));
use Test::More;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx
       || ($ENV{PERL5_CPANPLUS_IS_RUNNING} && $ENV{PERL5_CPAN_IS_RUNNING})) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 5;
}

use_ok q(IPC::SRLock);

my $lock = IPC::SRLock->new( { type => q(fcntl) } );

$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set fcntl) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset fcntl) );

unlink q(/tmp/ipc_srlock.lck);
unlink q(/tmp/ipc_srlock.shm);

$lock->clear_lock_obj;
$lock = IPC::SRLock->new( { type => q(sysv) } );
$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set ipc) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset ipc) );

exit 0;

$lock->clear_lock_obj;
$lock = IPC::SRLock->new( { patience => 10, type => q(memcached) } );
$lock->set( k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set memcached) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset memcached) );
