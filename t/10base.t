#!/usr/bin/perl

# @(#)$Id: 11lock.t 62 2008-04-11 01:20:52Z pjf $

use strict;
use warnings;
use English qw(-no_match_vars);
use FindBin qw($Bin);
use List::Util qw(first);
use lib qq($Bin/../lib);
use Test::More;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 62 $ =~ /\d+/gmx );

my %turkeys = ( qw(cygwin 1 freebsd 1 netbsd 1 solaris 1) );

if ($ENV{AUTOMATED_TESTING} || $turkeys{ $OSNAME }) { plan tests => 3 }
else { plan tests => 5 }

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

exit 0 if ($ENV{AUTOMATED_TESTING} || $turkeys{ $OSNAME });

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
