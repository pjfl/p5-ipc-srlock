package IPC::SRLock::Functions;

use strict;
use warnings;
use parent 'Exporter::Tiny';

use English qw( -no_match_vars );

our @EXPORT_OK = qw( Unspecified hash_from set_args );

sub Unspecified () {
   return sub { 'Unspecified' };
}

sub hash_from  (;@) {
   my (@args) = @_; $args[ 0 ] or return {};

   return ref $args[ 0 ] ? $args[ 0 ] : { @args };
}

sub set_args ($;@) {
   my $self = shift; my $args = hash_from( @_ );

   $args->{k}  or $self->throw( Unspecified, [ 'key' ] ); $args->{k} .= q();
   $args->{p} //= $PID;
   $args->{t} //= $self->time_out;

   return $args;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

IPC::SRLock::Functions - Common functions used by this distribution

=head1 Synopsis

   use IPC::SRLock::Functions qw( Unspecified hash_from set_args );

=head1 Description

Common functions used by this distribution

=head1 Subroutines/Methods

=head2 Unspecified

Returns a subroutine reference which when called returns the string
C<Unspecified>. This is an exception class used as an argument to the
L<throw|IPC::SRLock::Base/throw> method

=head2 hash_from

Returns a hash reference. Accepts a hash reference or a list of keys and
values

=head2 set_args

Default arguments for the C<set> method

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exporter::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=IPC-SRLock.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
# vim: expandtab shiftwidth=3:
