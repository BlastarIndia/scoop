=head1 Debug.pm

This file holds functions that will help developers to debug code.  Right now
all that is included is the assert() function.  If you are not familiar with
asserts, I encourage you to check them out.  Read this, its a good explanation,
and I used some of their ideas in writing Scoop's assert.
http://search.cpan.org/doc/MSCHWERN/Carp-Assert-0.17/lib/Carp/Assert.pm

=head1 Functions

=cut

package Scoop;

use strict;

=pod

=over 4

=item *
assert( test_condition, [$explanation_string[, \%varhash]] )

$explanation_string and \%varhash are optional.

This will raise an assertion if the test_condition is false.  If it is false,
then an error page detailing the file name, line number, and function that the
assert happened in will be displayed to the browser, as well as a line in the
error logs.  If assert() is supplied with an $explanation_string it will print
that to the screen as well.  If its supplied with a \%varhash it will print 
the keys and values formatted nicely as well.

Examples of usage:

C< sub foo { >
C< 	# $var should never be empty, so fail if it is >
C< 	$var = shift; >
C< 	assert( $var ne '' ) if $ASSERT; >
C< 	# do something with $foo >
C< 	return; >
C< } >

If $var is an empty string, foo() was used wrong, so throw an assertion.

Perl will optimize out the whole if() contstruct if $ASSERT is 0, so no need to worry about
it slowing down Scoop.  Be sure to define $ASSERT at the top of the module, as well.

=back

=cut

sub assert($;$$) {
	my $S = shift;
	my $test = shift;

	# return if the assertion is correct
	return if $test;

	my $error = shift;
	my $varhash = shift;
	my $vardump;
	if( defined $varhash ) {
		$vardump = $S->_make_vardump( $varhash );
	}

	$S->{CURRENT_TEMPLATE} = 'error_template';
	$S->{UI}->{BLOCKS}->{ERROR_TYPE} = 'Assertion Failed';
	$S->{UI}->{BLOCKS}->{ERROR_MSG} = $error || 'none';
	$S->{UI}->{BLOCKS}->{VARDUMP} = $vardump || 'none';
	$S->{UI}->{BLOCKS}->{thetime} = localtime();

	my ($package, $filename, $line) = caller;

	$S->{UI}->{BLOCKS}->{package} = $package;
	$S->{UI}->{BLOCKS}->{file} = $filename;
	$S->{UI}->{BLOCKS}->{line} = $line;

	# and send a quick message to the logs
	# first get rid of html nastiness in $vardump, and unescape &lt; and &gt;
	$vardump =~ s/<br>//g;
	$vardump =~ s/&lt;/</g;
	$vardump =~ s/&gt;/>/g;

	warn qq/assert() called from within $package and file $filename, line $line.  Due to "$error".  vars:\n $vardump/;

	$S->page_out;
	Apache::exit(1);

}


sub _make_vardump {
	my $S = shift;
	my $hash = shift;
	my $varstring = ''; 

	return '' unless $hash;

 	for my $key ( sort keys %$hash ) {

		$varstring .= "$key = ". $S->filter_subject($hash->{$key});
		$varstring .= "<br>\n";
	}

	return $varstring;
}


1;
