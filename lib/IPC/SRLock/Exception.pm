# @(#)$Ident: Exception.pm 2013-05-08 06:57 pjf ;

package IPC::SRLock::Exception;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.11.%d', q$Rev: 8 $ =~ /\d+/gmx );

use Moose;
use MooseX::Types::Moose qw(Str);

extends q(File::DataClass::Exception);

File::DataClass::Exception->add_roles( 'ErrorLeader' );

has '+class' => default => __PACKAGE__;

has 'out'    => is => 'ro', isa => Str, default => q();

1;

__END__

=pod

=head1 Name

IPC::SRLock::Exception - Exception class

=head1 Version

This documents version v0.11.$Rev: 8 $

=head1 Synopsis

   use IPC::SRLock::Exception;

   IPC::SRLock::Exception->throw( 'This is going to die' );

=head1 Description

Implements throw and catch error semantics. Inherits from
L<File::DataClass::Exception>

=head1 Configuration and Environment

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

=item L<File::DataClass::Exception>

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
