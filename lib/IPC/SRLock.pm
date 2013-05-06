# @(#)$Ident: SRLock.pm 2013-05-06 14:25 pjf ;

package IPC::SRLock;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev: 4 $ =~ /\d+/gmx );

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::LoadableClass qw(LoadableClass);
use MooseX::Types::Moose         qw(HashRef Object);

enum __PACKAGE__.'::Type'   => qw(fcntl memcached sysv);

# Public attributes
has 'type'                  => is => 'ro', isa => __PACKAGE__.'::Type',
   default                  => 'fcntl';

# Private attributes
has '_implementation'       => is => 'ro', isa => Object,
   builder                  => '_build__implementation',
   handles                  => [ qw(debug get_table list reset set) ],
   init_arg                 => undef, lazy => 1;

has '_implementation_attr'  => is => 'ro', isa => HashRef,
   default                  => sub { {} };

has '_implementation_class' => is => 'ro', isa => LoadableClass, coerce => 1,
   builder                  => '_build__implementation_class',
   init_arg                 => undef, lazy => 1;

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $type = delete $attr->{type}; $attr = { _implementation_attr => $attr };

   $type and $attr->{type} = $type; return $attr;
};

sub BUILD {
   my $self = shift; $self->_implementation; return;
}

# Private methods
sub _build__implementation {
   my $self = shift;
   my $attr = { name => (lc join '_', split m{ :: }mx, __PACKAGE__),
                %{ $self->_implementation_attr }, };

   return $self->_implementation_class->new( $attr );
}

sub _build__implementation_class {
   my $self = shift; return __PACKAGE__.'::'.(ucfirst $self->type);
}

1;

__END__

=pod

=encoding utf8

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

This documents version v0.11.$Rev: 4 $ of L<IPC::SRLock>

=head1 Synopsis

   use IPC::SRLock;

   my $config   = { tempdir => 'path_to_tmp_directory', type => 'fcntl' };

   my $lock_obj = IPC::SRLock->new( $config );

   $lock_obj->set( k => 'some_resource_identfier' );

   # This critical region of code is guaranteed to be single threaded

   $lock_obj->reset( k => 'some_resource_identfier' );

=head1 Description

Provides set/reset locking methods which will force a critical region
of code to run single threaded

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<debug>

Mutable attribute if true will log lock set events at the debug level

=item C<type>

Determines which factory subclass is loaded. Defaults to C<fcntl>, can
be; C<fcntl>, C<memcached>, or C<sysv>

=back

=head1 Subroutines/Methods

=head2 BUILD

Called after an instance is created this subroutine triggers the lazy
evaluation of the concrete subclass

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

=head1 Diagnostics

Setting C<debug> to true will cause the C<set> methods to log
the lock record at the debug level

=head1 Dependencies

=over 3

=item L<Moose>

=item L<Moose::Util::TypeConstraints>

=item L<MooseX::Types::LoadableClass>

=item L<MooseX::Types::Moose>

=back

=head1 Incompatibilities

The C<sysv> subclass type will not work on C<MSWin32> and C<cygwin> platforms

=head1 Bugs and Limitations

Testing of the C<memcached> subclass type is skipped on all platforms as it
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
