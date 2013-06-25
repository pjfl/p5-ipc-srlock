# @(#)Ident: Base.pm 2013-06-21 01:06 pjf ;

package IPC::SRLock::Base;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.12.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Date::Format;
use English                 qw( -no_match_vars );
use IPC::SRLock::Exception;
use Moo;
use Unexpected::Types       qw( Bool ClassName Int LoadableClass
                                NonEmptySimpleStr Num Object PositiveInt );
use Time::Elapsed           qw( elapsed );

# Public attributes
has 'debug'           => is => 'rw',   isa => Bool, default => 0;

has 'exception_class' => is => 'ro',   isa => ClassName,
   default            => 'IPC::SRLock::Exception';

has 'log'             => is => 'lazy', isa => Object,
   default            => sub { $_[ 0 ]->_null_class->new };

has 'name'            => is => 'ro',   isa => NonEmptySimpleStr, required => 1;

has 'nap_time'        => is => 'ro',   isa => Num, default => 0.1;

has 'patience'        => is => 'ro',   isa => Int, default => 0;

has 'pid'             => is => 'ro',   isa => PositiveInt, default => $PID;

has 'time_out'        => is => 'ro',   isa => PositiveInt, default => 300;

# Private attributes
has '_null_class'     => is => 'lazy', isa => LoadableClass,
   default            => 'Class::Null', init_arg => undef;

# Public methods
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
   my ($self, @args) = @_; my $args = __hash_from( @args );

   my $key = $args->{k} or $self->throw( 'No key specified' );

   return $self->_reset( q().$key );
}

sub set {
   my ($self, @args) = @_; my $args = __hash_from( @args );

   $args->{k}   = q().$args->{k} or $self->throw( 'No key specified' );
   $args->{p} ||= $self->pid; $args->{p} or $self->throw( 'No pid specified' );
   $args->{t} ||= $self->time_out;

   return $self->_set( $args );
}

sub throw {
   my ($self, @args) = @_; return $self->exception_class->throw( @args );
}

sub timeout_error {
   my ($self, $key, $pid, $when, $after) = @_; my $text;

   $text  = "Timed out ${key} set by ${pid} on ";
   $text .= time2str( q(%Y-%m-%d at %H:%M), $when );
   $text .= " after ${after} seconds\n";
   return $text;
}

# Private functions
sub __hash_from {
   my (@args) = @_; $args[ 0 ] or return {};

   return ref $args[ 0 ] ? $args[ 0 ] : { @args };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

IPC::SRLock::Base - Common lock object attributes and methods

=head1 Synopsis

   package IPC::SRLock::<some_new_mechanism>;

   use Moo;

   extents 'IPC::SRLock::Base';

=head1 Version

This documents version v0.12.$Rev: 1 $ of L<IPC::SRLock::Base>

=head1 Description

This is the base class for the factory subclasses of L<IPC::SRLock>. The
factory subclasses all inherit from this class

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<debug>

Turns on debug output. Defaults to 0

=item C<exception_class>

Class used to throw exceptions

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

=back

=head1 Subroutines/Methods

=head2 get_table

   my $data = $lock_obj->get_table;

Returns a hash ref that contains the current lock table contents. The
keys/values in the hash are suitable for passing to
L<HTML::FormWidgets>

=head2 list

   my $array_ref = $lock_obj->list;

Returns an array of hash refs that represent the current lock table

=head2 reset

   $lock_obj->reset( k => 'some_resource_key' );

Resets the lock referenced by the C<k> attribute.

=head2 set

   $lock_obj->set( k => 'some_resource_key' );

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

=head2 _list

Should be implemented in the factory subclass

=head2 _reset

Should be implemented in the factory subclass

=head2 _set

Should be implemented in the factory subclass

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<Class::Usul>

=item L<Date::Format>

=item L<IPC::SRLock::Exception>

=item L<Moo>

=item L<Time::Elapsed>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
