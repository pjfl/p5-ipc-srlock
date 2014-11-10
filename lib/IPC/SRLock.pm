package IPC::SRLock;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moo;
use File::DataClass::Types  qw( HashRef LoadableClass Object );
use Type::Utils             qw( enum );

my $Lock_Type = enum 'Lock_Type' => [ qw( fcntl memcached sysv ) ];

# Public attributes
has 'type'                  => is => 'ro',   isa => $Lock_Type,
   default                  => 'fcntl';

# Private attributes
has '_implementation'       => is => 'lazy', isa => Object, builder => sub {
   $_[ 0 ]->_implementation_class->new( $_[ 0 ]->_get_attr ) },
   handles                  => [ qw( debug get_table list reset set ) ],
   init_arg                 => undef;

has '_implementation_attr'  => is => 'ro',   isa => HashRef,
   default                  => sub { {} };

has '_implementation_class' => is => 'lazy', isa => LoadableClass,
   builder                  => sub { __PACKAGE__.'::'.(ucfirst $_[ 0 ]->type) },
   init_arg                 => undef;

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
sub _get_attr {
   return { name => (lc join '_', split m{ :: }mx, __PACKAGE__),
            %{ $_[ 0 ]->_implementation_attr }, };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

IPC::SRLock - Set/reset locking semantics to single thread processes

=head1 Version

This documents version v0.24.$Rev: 1 $ of L<IPC::SRLock>

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

Implements a factory pattern, three implementations are provided. The
LCD option L<IPC::SRLock::Fcntl> which works on non Unixen,
L<IPC::SRLock::Sysv> which uses System V IPC, and
L<IPC::SRLock::Memcached> which uses C<libmemcache> to implement a
distributed lock manager

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

=head2 BUILDARGS

Extracts the C<type> attribute from those passed to the factory subclass

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

=item L<File::DataClass>

=item L<Moo>

=item L<Type::Tiny>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
