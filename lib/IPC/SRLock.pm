# @(#)$Ident: SRLock.pm 2013-05-05 11:10 pjf ;

package IPC::SRLock;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev: 2 $ =~ /\d+/gmx );
use parent qw(Class::Accessor::Fast);

use Class::MOP;
use Class::Null;
use Date::Format;
use English qw(-no_match_vars);
use IPC::SRLock::Exception;
use Time::Elapsed qw(elapsed);
use Try::Tiny;

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
   my $attrs = __hash_merge( \%ATTRS, $args );
   my $class = __PACKAGE__.q(::).(ucfirst $attrs->{type});

   $self->_ensure_class_loaded( $class ); # Load factory subclass

   my $new = bless $attrs, $class;

   $new->log  ( $new->log || Class::Null->new() );
   $new->pid  ( $PID );
   $new->_init( $args ); # Initialise factory subclass
   return $new;
}

sub get_table {
   my $self  = shift;
   my $count = 0;
   my $data  = { align  => { id    => 'left',
                             pid   => 'right',
                             stime => 'right',
                             tleft => 'right'},
                 count  => $count,
                 fields => [ qw(id pid stime tleft) ],
                 hclass => { id => q(most) },
                 labels => { id    => 'Key',
                             pid   => 'PID',
                             stime => 'Lock Time',
                             tleft => 'Time Left' },
                 values => [] };

   for my $lock (@{ $self->list }) {
      my $fields = {};

      $fields->{id   } = $lock->{key};
      $fields->{pid  } = $lock->{pid};
      $fields->{stime} = time2str( q(%Y-%m-%d %H:%M:%S), $lock->{stime} );

      my $tleft = $lock->{stime} + $lock->{timeout} - time;

      $fields->{tleft} = $tleft > 0 ? elapsed( $tleft ) : 'Expired';
      $fields->{class}->{tleft}
                       = $tleft < 1 ? q(error dataValue) : q(odd dataValue);
      push @{ $data->{values} }, $fields;
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

   my $key = $args->{k} or $self->throw( 'No key specified' );

   return $self->_reset( q().$key );
}

sub set {
   my ($self, @rest) = @_; my $args = $self->_arg_list( @rest );

   $args->{k}   = q().$args->{k} or $self->throw( 'No key specified' );
   $args->{p} ||= $self->pid; $args->{p} or $self->throw( 'No pid specified' );
   $args->{t} ||= $self->time_out;

   return $self->_set( $args );
}

sub throw {
   my ($self, @rest) = @_; return IPC::SRLock::Exception->throw( @rest );
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
   my ($self, @rest) = @_; $rest[ 0 ] or return {};

   return ref $rest[ 0 ] ? $rest[ 0 ] : { @rest };
}

sub _ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return 1;

   try   { Class::MOP::load_class( $class ) }
   catch { $self->throw( $_ ) };

   $package_defined->() and return 1;

   my $e = 'Class [_1] loaded but package undefined';

   $self->throw( error => $e, args => [ $class ] );
   return; # Never reached
}

sub _init {
   return;
}

sub _list {
   my $self = shift;

   $self->throw( error => 'Method [_1] not overridden in [_2]',
                 args  => [ q(_list), ref $self || $self ] );
   return;
}

sub _reset {
   my $self = shift;

   $self->throw( error => 'Method [_1] not overridden in [_2]',
                 args  => [ q(_reset), ref $self || $self ] );
   return;
}

sub _set {
   my $self = shift;

   $self->throw( error => 'Method [_1] not overridden in [_2]',
                 args  => [ q(_set), ref $self || $self ] );
   return;
}

# Private subroutines

sub __hash_merge {
   return { %{ $_[ 0 ] }, %{ $_[ 1 ] || {} } };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

This documents version v0.10.$Rev: 2 $ of L<IPC::SRLock>

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

=item C<debug>

Turns on debug output. Defaults to 0

=item C<log>

If set to a log object, it's C<debug> method is called if debugging is
turned on. Defaults to L<Class::Null>

=item C<name>

Used as the lock file names. Defaults to C<ipc_srlock>

=item C<nap_time>

How long to wait between polls of the lock table. Defaults to 0.5 seconds

=item C<patience>

Time in seconds to wait for a lock before giving up. If set to 0 waits
forever. Defaults to 0

=item C<pid>

The process id doing the locking. Defaults to this processes id

=item C<time_out>

Time in seconds before a lock is deemed to have expired. Defaults to 300

=item C<type>

Determines which factory subclass is loaded. Defaults to C<fcntl>

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

Resets the lock referenced by the C<k> attribute.

=head2 set

   $lock_obj->set( k => q(some_resource_key) );

Sets the specified lock. Attributes are:

=over 3

=item C<k>

Unique key to identify the lock. Mandatory no default

=item C<p>

Explicitly set the process id associated with the lock. Defaults to
the current process id

=item C<t>

Set the time to live for this lock. Defaults to five minutes. Setting
it to zero makes the lock last indefinitely

=back

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

=head2 _init

Called by the constructor. Optionally overridden in the factory
subclass. This allows subclass specific initialisation

=head2 _list

Should be overridden in the factory subclass

=head2 _reset

Should be overridden in the factory subclass

=head2 _set

Should be overridden in the factory subclass

=head2 __hash_merge

   my $hash = __hash_merge( { key1 => val1 }, { key2 => val2 } );

Simplistic merging of two hashes

=head1 Diagnostics

Setting C<debug> to true will cause the C<set> methods to log
the lock record at the debug level

=head1 Dependencies

=over 3

=item L<Class::Accessor::Fast>

=item L<Class::MOP>

=item L<Class::Null>

=item L<Date::Format>

=item L<IPC::SRLock::ExceptionClass>

=item L<Time::Elapsed>

=back

=head1 Incompatibilities

The C<Sysv> subclass will not work on C<MSWin32> and C<cygwin> platforms

=head1 Bugs and Limitations

Testing of the C<memcached> subclass is skipped on all platforms as it
requires C<memcached> to be listening on the localhost's default
memcached port C<localhost:11211>

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
