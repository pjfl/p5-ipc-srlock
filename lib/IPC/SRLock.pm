package IPC::SRLock;

# @(#)$Id$

use strict;
use warnings;
use parent qw(Class::Accessor::Fast);
use Class::Inspector;
use Class::Null;
use Date::Format;
use English qw(-no_match_vars);
use IPC::SRLock::ExceptionClass;
use Time::Elapsed qw(elapsed);

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev$ =~ /\d+/gmx );

my %ATTRS = ( debug    => 0,
              log      => undef,
              name     => (lc join q(_), split m{ :: }mx, __PACKAGE__),
              nap_time => 0.1,
              patience => 0,
              pid      => undef,
              time_out => 300,
              type     => q(fcntl), );

__PACKAGE__->mk_accessors( keys %ATTRS );

sub new {
   my ($self, @rest) = @_;

   my $args  = $self->_arg_list( @rest );
   my $attrs = $self->_hash_merge( \%ATTRS, $args );
   my $class = __PACKAGE__.q(::).(ucfirst $attrs->{type});

   $self->_ensure_class_loaded( $class );

   my $new   = bless $attrs, $class;

   $new->log(   $new->log || Class::Null->new() );
   $new->pid(   $PID );
   $new->_init( $args );
   return $new;
}

sub catch {
   my ($self, @rest) = @_; return IPC::SRLock::ExceptionClass->catch( @rest );
}

sub get_table {
   my $self  = shift;
   my $count = 0;
   my $data  = { align  => { id    => 'left',
                             pid   => 'right',
                             stime => 'right',
                             tleft => 'right'},
                 count  => $count,
                 flds   => [ qw(id pid stime tleft) ],
                 hclass => { id => q(most) },
                 labels => { id    => 'Key',
                             pid   => 'PID',
                             stime => 'Lock Time',
                             tleft => 'Time Left' },
                 values => [] };

   for my $lock (@{ $self->list }) {
      my $flds       = {};
      $flds->{id   } = $lock->{key};
      $flds->{pid  } = $lock->{pid};
      $flds->{stime} = time2str( q(%Y-%m-%d %H:%M:%S), $lock->{stime} );
      my $tleft      = $lock->{stime} + $lock->{timeout} - time;
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
   my $self = shift; return $self->_list;
}

sub reset {
   my ($self, @rest) = @_; my $args = $self->_arg_list( @rest );

   $self->throw( q(eNoKey) ) unless (my $key = $args->{k});

   return $self->_reset( $key );
}

sub set {
   my ($self, @rest) = @_; my $args = $self->_arg_list( @rest );

   $self->throw( q(eNoKey) )       unless (my $key = $args->{k});
   $self->throw( q(eNoProcessId) ) unless (my $pid = $args->{p} || $self->pid);

   return $self->_set( $key, $pid, $args->{t} || $self->time_out );
}

sub table_view {
   my ($self, $model) = @_; my $data = $self->get_table;

   $model->add_field( { data => $data, select => q(left), type => q(table) } );
   $model->group_fields( { id => q(lock_table.select), nitems => 1 } );
   $model->add_buttons( qw(Delete) ) if ($data->{count} > 0);
   return;
}

sub throw {
   my ($self, @rest) = @_; return IPC::SRLock::ExceptionClass->throw( @rest );
}

sub timeout_error {
   my ($self, $key, $pid, $when, $after) = @_; my $text;

   $text  = 'Timed out '.$key.' set by '.$pid;
   $text .= ' on '.time2str( q(%Y-%m-%d at %H:%M), $when );
   $text .= ' after '.$after.' seconds'."\n";
   return $text;
}

# Private methods

sub _arg_list {
   my ($self, @rest) = @_;

   return {} unless ($rest[0]);

   return ref $rest[0] ? $rest[0] : { @rest };
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; my $error;

   return 1 if (!$opts->{ignore_loaded} && Class::Inspector->loaded( $class ));

   ## no critic
   {  local $EVAL_ERROR; eval "require $class;"; $error = $EVAL_ERROR; }
   ## critic

   $self->throw( $error ) if ($error);

   $self->throw( error => q(eUndefinedPackage), arg1 => $class )
      unless (Class::Inspector->loaded( $class ));

   return 1;
}

sub _hash_merge {
   my ($self, $l, $r) = @_; return { %{ $l }, %{ $r || {} } };
}

sub _init {
   return;
}

sub _list {
   my $self = shift;

   $self->throw( error => q(eNotOverridden), arg1 => q(list) );
   return;
}

sub _reset {
   my $self = shift;

   $self->throw( error => q(eNotOverridden), arg1 => q(reset) );
   return;
}

sub _set {
   my $self = shift;

   $self->throw( error => q(eNotOverridden), arg1 => q(set) );
   return;
}

1;

__END__

=pod

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

0.2.$Revision$

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { tempdir => q(path_to_tmp_directory), type => q(fcntl) };

   my $lock_obj = IPC::SRLock->new( $config );

   $lock_obj->set( k => q(some_resource_identfier) );

   # This critical region of code is guaranteed to be single threaded

   $lock_obj->reset( k => q(some_resource_identfier) );

=head1 Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

=head1 Configuration and Environment

This class defines accessors and mutators for these attributes:

=over 3

=item debug

Turns on debug output. Defaults to 0

=item log

If set to a log object, it's C<debug> method is called if debugging is
turned on. Defaults to L<Class::Null>

=item name

Used as the lock file names. Defaults to I<ipc_srlock>

=item nap_time

How long to wait between polls of the lock table. Defaults to 0.5 seconds

=item patience

Time in seconds to wait for a lock before giving up. If set to 0 waits
forever. Defaults to 0

=item pid

The process id doing the locking. Defaults to this processes id

=item time_out

Time in seconds before a lock is deemed to have expired. Defaults to 300

=item type

Determines which factory subclass is loaded. Defaults to I<fcntl>

=back

=head1 Subroutines/Methods

=head2 new

This constructor implements the singleton pattern, ensures that the
factory subclass is loaded in initialises it

=head2 catch

Expose the C<catch> method in L<IPC::SRLock::ExceptionClass>

=head2 get_table

   my $data = $lock_obj->get_table;

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
L<HTML::FormWidgets>

=head2 list

   my $array_ref = $lock_obj->list;

Returns an array of hash refs that represent the current lock table

=head2 reset

   $lock_obj->reset( k => q(some_resource_key) );

Resets the lock referenced by the B<k> attribute.

=head2 set

   $lock_obj->set( k => q(some_resource_key) );

Sets the specified lock. Attributes are:

=over 3

=item B<k>

Unique key to identify the lock. Mandatory no default

=item B<p>

Explicitly set the process id associated with the lock. Defaults to
the current process id

=item B<t>

Set the time to live for this lock. Defaults to five minutes. Setting
it to zero makes the lock last indefinitely

=back

=head2 table_view

   $lock_obj->table_view( $model );

The C<$model> object's methods store the result of calling
C<< $lock_obj->get_table >> on the C<<$model->context->stash >>
hash ref. The model should be a L<CatalystX::Usul::Model> object

=head2 throw

Expose the C<throw> method in C<IPC::SRLock::ExceptionClass>

=head2 timeout_error

Return the text of the the timeout message

=head2 _arg_list

   my $args = $self->_arg_list( @rest );

Returns a hash ref containing the passed parameter list. Enables
methods to be called with either a list or a hash ref as it's input
parameters

=head2 _ensure_class_loaded

   $self->_ensure_class_loaded( $some_class );

Require the requested class, throw an error if it doesn't load

=head2 _hash_merge

   my $hash = $self->_hash_merge( { key1 => val1 }, { key2 => val2 } );

Simplistic merging of two hashes

=head2 _init

Called by the constructor. Optionally overridden in the factory
subclass. This allows subclass specific initialisation

=head2 _list

Should be overridden in the factory subclass

=head2 _reset

Should be overridden in the factory subclass

=head2 _set

Should be overridden in the factory subclass

=head1 Diagnostics

Setting B<debug> to true will cause the C<set> methods to log
the lock record at the debug level

=head1 Dependencies

=over 3

=item L<Class::Accessor::Fast>

=item L<Class::Inspector>

=item L<Class::Null>

=item L<Date::Format>

=item L<IPC::SRLock::ExceptionClass>

=item L<Time::Elapsed>

=back

=head1 Incompatibilities

The B<sysv> subclass will not work on cygwin

=head1 Bugs and Limitations

Testing of the B<memcached> subclass is skipped on all platforms as it
requires C<memcached> to be listening on the localhost's default
memcached port I<localhost:11211>

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2008 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
