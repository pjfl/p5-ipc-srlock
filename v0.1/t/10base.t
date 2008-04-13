#!/usr/bin/perl

# @(#)$Id: 11lock.t 62 2008-04-11 01:20:52Z pjf $

use strict;
use warnings;
use English qw(-no_match_vars);
use FindBin qw($Bin);
use List::Util qw(first);
use lib qq($Bin/../lib);
use Test::More tests => 5;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 62 $ =~ /\d+/gmx );

BEGIN { use_ok q(IPC::SRLock) }

{
   package Test::App;

   use base qw(Class::Accessor::Fast);

   __PACKAGE__->mk_accessors( qw(config debug log) );
}

my $app = Test::App->new();

$app->config( { lock => { type => q(fcntl) } } );

my $lock = IPC::SRLock->new( $app );

$lock->set(   k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set fcntl) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset fcntl) );

unlink q(/tmp/ipc_srlock.lck);
unlink q(/tmp/ipc_srlock.shm);

$lock->_clear_lock_obj;

$app->config( { lock => { type => q(sysv) } } );

$lock = IPC::SRLock->new( $app );

$lock->set(   k => $PROGRAM_NAME );

ok( (first { $_ eq $PROGRAM_NAME }
     map   { $_->{key} } @{ $lock->list() }), q(lock set ipc) );

$lock->reset( k => $PROGRAM_NAME );

ok( !(first { $_ eq $PROGRAM_NAME }
      map   { $_->{key} } @{ $lock->list() }), q(lock reset ipc) );
