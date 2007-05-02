package Sub::Information;

use warnings;
use strict;

use Scalar::Util ();

use 5.006;    # need the warnings pragma :(

=head1 NAME

Sub::Information - Get subroutine information

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use Sub::Information as => 'inspect';

    my $code_info = inspect(\&code);
    print $code_info->name;
    print $code_info->package;
    print $code_info->code;
    print $code_info->address;
    # etc.

=head1 DESCRIPTION

Typically, if we need to get information about code references, we have to
remember which of myriad modules to load.  Need to know if it's blessed?
C<Scalar::Util> will do that.  Package it was declared in:  C<Sub::Identify>.
Source code:  C<Data::Dump::Streamer>.  And so on ...

This module integrates those together so that you don't have to remember them.

=head1 EXPORT

By default, we export the C<inspect> function.  This function, when called on
a code reference, will 'inspect' the code reference and return a
C<Sub::Information> object.  If you already have an C<inspect> function, you can
rename the function by specifying C<< as => 'other_func' >> in the import
list.  The following are equivalent:

 use Sub::Information;                # exports 'inspect'
 my $info = inspect($coderef);

Or:

 use Sub::Information ();             # don't import anything
 my $info = Sub::Information->new($coderef);

Or:
 
 use Sub::Information as => 'peek';   # exports 'peek'
 my $info = peek($coderef);

=head1 FUNCTIONS

=head2 C<inspect>

 my $info = inspect($coderef);

Given a code reference, this function returns a new C<Sub::Information>
object.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $info = Sub::Information->new($coderef);

Returns a new C<Sub::Information> object.

=head2 Instance Methods

Unless otherwise stated, all methods cache their return values and the modules
they rely on are I<not> loaded until needed.  Please see the documentation of
the original module for more information about how the method behaves.

=head3 C<address>

 my $address = $info->address;

Returns the memory address, in decimal, of the original code reference.

From:  C<Scalar::Util::refaddr>

=head3 C<blessed> 

 my $blessed = $info->blessed;

Returns the package name a coderef is blessed into.  Returns undef if the
coderef is not blessed.

From: C<Scalar::Util::blessed>

=head3 C<code>

 my $source_code = $info->code;

Returns the source code of the code reference.  Because of how it's generated,
it should be equivalent in functionality to the original code reference, but
may appear different.  For example:

 sub add_2 { return 2 + shift }
 print inspect(\&add_2)->code;

 __END__
 # output
 $CODE1 = sub {
   use strict 'refs';
   return 2 + shift(@_);
 };

From: C<Data::Dump::Streamer::Dump>

=head3 C<dump>

 $info->dump;

Returns the internals information regarding the coderef as generated by
C<Devel::Peek::Dump> to STDERR.  This method is experimental.  Let me know if
it doesn't work.

From:  C<Devel::Peek>

=head3 C<fullname>

 my $fullname = $info->fullname;

Returns the fully qualified subroutine name (package + subname) of the
coderef.

From:  C<Sub::Identify::sub_fullname>

=head3 C<name>

 my $name = $info->name;

Returns the name of the subroutine.  If the subroutine is an anonymous
subroutine, it may return C<__ANON__>.  However, you can name anonymous
subroutines with:

 local *__ANON__ = 'name::of::anonymous::subroutine';

From: C<Sub::Identify::sub_name>

=head3 C<package>

 my $package = $info->package;

Returns the name of the package the subroutine was declared in.

From: C<Sub::Identify::stash_name>

=head3 C<variables>

 my $variables = $info->variables;

Returns all C<my> variables found in the code reference (whether declared
their or outside of the code reference).  The return value is a hashref whose
keys are the names (with sigils) of the variables and whose values are the
values of said variable.

Note that those values will be undefined unless the code is currently "in use"
(e.g., you're calling C<variables()> from inside the sub or in a call stack
the sub is currently in).

The returned values are not cached.

From:  C<PadWalker::peek_sub>

=head1 CAVEATS

This is ALPHA code.

=over 4

=item * Memory requirements

Some modules, such as L<Devel::Size>, can be very expensive to load.  Thus,
none are loaded until such time as they are needed.

=item * Caching

To avoid overhead, we cache all results unless otherwise noted.

=item * Return values

Returns values are not calculated until such time as they are requested.
Thus, it's possible that the value returns is not identical to the value for
the code reference at the time the new C<Sub::Information> instance was
created.

=item * Refcount

The C<Sub::Information> instance stores a reference to the coderef, thus
incrementing its refcount by 1.

=back

=cut

sub import {
    my ( $class, %arg_for ) = @_;
    my $caller = caller;
    unless (%arg_for) {
        no strict 'refs';
        *{"$caller\::inspect"} = \&inspect;
    }
    if ( defined( my $sub = delete $arg_for{as} ) ) {
        chomp $sub;
        unless ( $sub =~ /^\w+$/ ) {
            $class->_croak("Sub '$sub' is not a valid subroutine name");
        }
        no strict 'refs';
        *{"$caller\::$sub"} = \&inspect;
    }
    if (%arg_for) {
        my @keys = keys %arg_for;
        local $" = ", ";
        $class->_croak("Unknown keys to import list:  (@keys)");
    }
}

my %PACKAGE_FOR;

sub new {
    my ( $class, $coderef ) = @_;
    my $self = bless {
        coderef     => $coderef,
        package_for => \%PACKAGE_FOR,
    } => $class;
    return $self;
}

sub inspect {
    unless ( 'CODE' eq Scalar::Util::reftype $_[0] ) {
        __PACKAGE__->_croak(
            "Argument to Sub::Information::inspect() must be a code ref");
    }
    return __PACKAGE__->new(shift);
}

sub _croak {
    shift;
    require Carp;
    Carp::croak(@_);
}

sub _carp {
    shift;
    require Carp;
    Carp::carp(@_);
}

BEGIN {
    my %sub_information = (
        address => {
            code => sub { Scalar::Util::refaddr(shift) }
        },
        blessed => {
            code => sub { Scalar::Util::blessed(shift) }
        },
        code => {
            code => sub { Data::Dump::Streamer::Dump(shift)->Indent(0)->Out }
        },
        fullname => {
            code => sub { Sub::Identify::sub_fullname(shift) }
        },
        name => {
            code => sub { Sub::Identify::sub_name(shift) }
        },
        package => {
            code => sub { Sub::Identify::stash_name(shift) }
        },
        variables => {
            code => sub { PadWalker::peek_sub(shift) }
        },

        # XXX I suspect these are useless
        #size       => { code => sub { Devel::Size::size(shift) } },
        #total_size => { code => sub { Devel::Size::total_size(shift) } },
    );
    $sub_information{variables}{dont_cache} = 1;

    #$sub_information{size}{dont_cache}       = 1;
    #$sub_information{total_size}{dont_cache} = 1;

    my %function_from = (
        'Scalar::Util'         => [qw/address blessed/],
        'Data::Dump::Streamer' => ['code'],
        'Sub::Identify'        => [qw/full_name name package/],
        'PadWalker'            => [qw/variables/],

        #'Devel::Size'          => [qw/size total_size/],
    );

    while ( my ( $package, $methods ) = each %function_from ) {
        foreach my $method (@$methods) {
            $PACKAGE_FOR{$method} = $package;
        }
    }

    while ( my ( $method, $value_for ) = each %sub_information ) {
        no strict 'refs';
        *$method = sub {
            my $self = shift;
            if ( my $package = $PACKAGE_FOR{$method} ) {
                eval "use $package";
                if ( my $error = $@ ) {
                    $self->_carp(
                        "Skipping $method.  Could not load source package $package: $error"
                    );
                    return;
                }
            }
            unless ( exists $self->{value_for}{$method} ) {
                my $result = $value_for->{code}( $self->{coderef} );
                return $result if $value_for->{dont_cache};
                $self->{value_for}{$method} = $result;
            }
            return $self->{value_for}{$method};
        };
    }
}

{

    my $peek_loaded;

    sub _require_devel_peek {
        my $self = shift;
        return 1 if $peek_loaded;
        eval <<'        LOAD_DEVEL_PEEK';
        package Sub::Information::_Internal;
        use Devel::Peek;
        LOAD_DEVEL_PEEK
        if ( my $error = $@ ) {
            $self->_carp(
                "Skipping dump.  Could not load source package Devel::Peek: $error"
            );
            return;
        }
        return $peek_loaded = 1;
    }
}

# $stderr = _capture_stderr({ code to be executed })
#
sub _capture_stderr {
    my $code = shift;
    die "undef code !?" unless $code;

    my $stderr;    # XXX " open H, '>', \$var " requires 5.8+

    no warnings 'once';    # perl thinks SAVEERR is used just once

    # save STDERR for restoring later
    open SAVEERR, "<&=STDERR" or die "error duping STDERR: $!";
    close STDERR or die "error closing STDERR: $!";
    {
        local *STDERR;

        # open STDERR to in-memory file
        open STDERR, ">", \$stderr
          or die "error opening STDERR to in-memory file: $!";    # XXX

        $code->();

        close STDERR or die "error closing in-memory file: $!";
    }

    # restore STDERR
    open STDERR, ">&=SAVEERR" or die "error restoring STDERR: $!";

    return $stderr;
}

sub dump {
    my $self = shift;
    return unless $self->_require_devel_peek;

    return _capture_stderr sub {
        no warnings 'uninitialized';
        Sub::Information::_Internal::Dump( $self->{coderef} );
    };    # XXX STDERR may be borken

}

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-sub-information@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sub-Information>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 TODO

Probably lots.  Send patches, ideas, criticisms, whatever.

=head1 SEE ALSO

Several of the following modules are either used internally or may be of
further interest to you.

=over 4

=item * L<B::Deparse>

=item * L<Devel::Peek>

=item * L<Devel::Size>

=item * L<Data::Dump::Streamer>

=item * L<PadWalker>

=item * L<Sub::Identify>

=item * L<Scalar::Util>

=back

=head1 THANKS

Much appreciation to Adriano Ferreira for providing two very useful patches.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Curtis "Ovid" Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Sub::Information