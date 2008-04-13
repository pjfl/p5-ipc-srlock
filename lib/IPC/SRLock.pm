package IPC::SRLock;

# @(#)$Id$

use strict;
use warnings;
use base qw(Class::Accessor::Fast);
use Class::Inspector;
use Class::Null;
use Date::Format;
use English qw(-no_match_vars);
use IPC::SRLock::Errs;
use NEXT;
use Time::Elapsed qw(elapsed);
use Readonly;
use XML::Simple;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Readonly my %ATTRS =>
   ( debug     => 0,
     lockfile  => 195_911_405,
     log       => undef,
     mode      => oct q(0666),
     name      => (lc join q(_), split m{ :: }mx, __PACKAGE__),
     nap_time  => 0.5,
     num_locks => 100,
     patience  => 0,
     pid       => undef,
     shmfile   => 195_911_405,
     size      => 300,
     time_out  => 300,
     tempdir   => q(/tmp),
     type      => q(fcntl),
     umask     => 0, );

__PACKAGE__->mk_accessors( keys %ATTRS );

my $_lock_obj;

sub new {
   my ($me, @rest) = @_;

   $_lock_obj = $me->_init( @rest ) unless ($_lock_obj);

   return $_lock_obj;
}

sub catch {
   my ($me, @rest) = @_; return IPC::SRLock::Errs->catch( @rest );
}

sub get_table {
   my $me = shift; my ($count, $data, $flds, $lock, $tleft);

   $count = 0;
   $data  = { align  => { id    => 'left',
                          pid   => 'right',
                          stime => 'right',
                          tleft => 'right'},
              count  => $count,
              flds   => [ qw(id pid stime tleft) ],
              labels => { id    => 'Key',
                          pid   => 'PID',
                          stime => 'Lock Time',
                          tleft => 'Time Left' },
              values => [] };

   for $lock (@{ $me->list }) {
      $flds          = {};
      $flds->{id   } = $lock->{key};
      $flds->{pid  } = $lock->{pid};
      $flds->{stime} = time2str( q(%Y-%m-%d %H:%M:%S), $lock->{stime} );
      $tleft         = $lock->{stime} + $lock->{timeout} - time;
      $flds->{tleft} = $tleft > 0 ? elapsed( $tleft ) : 'Expired';
      $flds->{class}->{tleft}
                     = $tleft < 1 ? q(error dataValue) : q(odd dataValue);
      push @{ $data->{values} }, $flds;
      $count++;
   }

   $data->{count} = $count;
   return $data;
}

sub list {
   my $me = shift; return $me->_list;
}

sub reset {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest );

   $me->throw( q(eNoKey) ) unless (my $key = $args->{k});

   return $me->_reset( $key );
}

sub set {
   my ($me, @rest) = @_; my $args = $me->_arg_list( @rest );

   $me->throw( q(eNoKey) )       unless (my $key = $args->{k});
   $me->throw( q(eNoProcessId) ) unless (my $pid = $args->{p} || $me->pid);

   return $me->_set( $key, $pid, $args->{t} || $me->time_out );
}

sub table_view {
   my ($me, $s, $model) = @_; my $data = $me->get_table;

   $model->add_field(    $s, { data   => $data,
                               select => q(left),
                               type   => q(table) } );
   $model->group_fields( $s, { id     => q(lock_table_select), nitems => 1 } );
   $model->add_buttons(  $s, qw(Delete) ) if ($data->{count} > 0);
   return;
}

sub throw {
   my ($me, @rest) = @_; return IPC::SRLock::Errs->throw( @rest );
}

# Private methods

sub _arg_list {
   my ($me, @rest) = @_;

   return $rest[0] && ref $rest[0] ? $rest[0] : { @rest };
}

sub _clear_lock_obj {
   # Only for the test suite to re-initialise the lock instance
   $_lock_obj = 0; return;
}

sub _config_merge {
   my ($me, $l, $r) = @_; return { %{ $l }, %{ $r || {} } };
}

sub _ensure_class_loaded {
   my ($me, $class) = @_; my $error;

   {
## no critic
      local $@;
      eval "require $class;";
      $error = $@;
## critic
   }

   $me->throw( $error ) if ($error);

   $me->throw( error => q(eUndefinedPackage), arg1 => $class )
        unless (Class::Inspector->loaded( $class ));

   return;
}

sub _init {
   my ($me, $app) = @_; $app ||= Class::Null->new();
   my $config     = $app->config || {};
   my $attrs      = $me->_config_merge( \%ATTRS, $config->{lock} );
   my $class      = __PACKAGE__.q(::).(ucfirst $attrs->{type});

   $me->_ensure_class_loaded( $class );

   my $self       = bless $attrs, $class;

   $self->debug( $app->debug || $self->debug );
   $self->log(   $app->log || Class::Null->new() );
   $self->pid(   $PID );
   return $self;
}

sub _list {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(list) );
   return;
}

sub _reset {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(reset) );
   return;
}

sub _set {
   my $me = shift;

   $me->throw( error => q(eNotOverridden), arg1 => q(set) );
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   $app->config( tempdir => q(path_to_tmp_directory) );

   my $lock_obj = IPC::SRLock->new( $app );

   $lock_obj->set( k => q(some_resource_identfier) );

   # This critical region of code is guaranteed to by single threaded

   $lock_obj->reset( k => q(some_resource_identfier) );

=head1 Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

=head1 Subroutines/Methods

=head2 new

Implements the singleton pattern. Construction is done by C<_init_singleton>.

=head2 get_table

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
L<HTML::FormWidgets>

=head2 list

Returns an array of hash refs that represent the current lock table

=head2 reset

=head2 set

=head2 table_view

=head2 _clear_lock_obj

=head2 _get_semid

=head2 _get_shmid

=head2 _init_singleton

=head2 _list_fcntl

=head2 _list_ipc

=head2 _read_shmfile

=head2 _release

=head2 _reset_fcntl

=head2 _reset_ipc

=head2 _set_fcntl

=head2 _set_ipc

=head2 _write_shmfile


=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 4

=item L<Class::Accessor::Fast>

=item L<CatalystX::Usul::Class::Time>

=item L<CatalystX::Usul::Class::Utils>

=item L<Class::Null>

=item L<IO::AtomicFile>

=item L<IPC::SysV>

=item L<Next>

=item L<Time::Elapsed>

=item L<Readonly>

=item L<XML::Simple>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module.

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome.

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2008 Peter Flanigan. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
