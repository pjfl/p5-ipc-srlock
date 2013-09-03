# @(#)$Ident: Exception.pm 2013-09-02 14:47 pjf ;

package IPC::SRLock::Exception;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.16.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moo;
use Unexpected::Types qw( Str );

extends q(Unexpected);
with    q(Unexpected::TraitFor::ErrorLeader);

has 'out' => is => 'ro', isa => Str, default => q();

1;

__END__

=pod

=encoding utf8

=head1 Name

IPC::SRLock::Exception - Exception class

=head1 Version

This documents version v0.16.$Rev: 1 $

=head1 Synopsis

   use IPC::SRLock::Exception;

   IPC::SRLock::Exception->throw( 'This is going to die' );

=head1 Description

Implements throw and catch error semantics. Inherits from L<Unexpected>

=head1 Configuration and Environment

Defines these attributes;

=over 3


=item C<out>

A string containing the output from whatever was being called before
it threw

=back

=head1 Subroutines/Methods

=head2 as_string

   $printable_string = $e->as_string

What an instance of this class stringifies to

=head2 caught

   $e = IPC::SRLock::Exception->caught( $error );

Catches and returns a thrown exception or generates a new exception if
C<EVAL_ERROR> has been set or if an error string was passed in

=head2 stacktrace

   $lines = $e->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping zero lines of output
Skips anonymous stack frames, minimalist

=head2 throw

   IPC::SRLock::Exception->throw( $error );

Create (or re-throw) an exception to be caught by the L</caught> method. If
the passed parameter is a reference it is re-thrown. If a single scalar
is passed it is taken to be an error message code, a new exception is
created with all other parameters taking their default values. If more
than one parameter is passed the it is treated as a list and used to
instantiate the new exception. The C<error> attribute must be provided
in this case

=head2 throw_on_error

   IPC::SRLock::Exception->throw_on_error( $error );

Calls L</caught> and if the was an exception L</throw>s it

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
The default ignore package list should be configurable.
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
