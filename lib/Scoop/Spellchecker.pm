=head1 Spellcheck

Module to do spellchecking and highlighting of mis-spelled words. This is used
anywhere spell checking needs to be done, and works by interfacing with Aspell.
If the Aspell.pm module is not installed, then spellchecking will transparently
fail.

=over 4

=cut

package Scoop;
use strict;
use vars qw($Have_aspell);
my $DEBUG = 0;

# try to load Aspell. if we can't, then disable spellchecking
BEGIN {
	$Have_aspell = 1;
	eval { require Text::Aspell };
	$Have_aspell = 0 if $@ =~ /^Can't locate Text\/Aspell\.pm in \@INC/i;
}

=item * spellcheck_enabled()

Returns true if spell checking is available, enabled, and useable by the
current user. This checks both for the spell checking module, and to see
if the admin has enabled it.

=cut

sub spellcheck_enabled {
	my $S = shift;

	return 0 unless $Have_aspell;
	return 0 unless $S->{UI}->{VARS}->{spellcheck_enabled};
	return 0 unless $S->have_perm('use_spellcheck');
	return 1;
}

=item * spellcheck_string(string, [callback])

Performs spell check on the given string, and by default surrounds any
mis-spelled words with the contents of the blocks spell_err and spell_err_end.
However, if callback is given and is a valid code reference, then that will be
called each time a mis-spelled word is found, passing the word to it. The
callback should return what to put in the word's place (most likely the same
word).

Return value is the (possibly) modified string.

=cut

sub spellcheck_string {
	my $S = shift;
	my $string = shift;
	my $callback = shift;
	warn "Spellchecking string\n" if $DEBUG;

	return $string unless $S->spellcheck_enabled();
	$S->_spellcheck_init();   # set up unless we already have
	warn "Init done\n" if $DEBUG;

	my $url_regexg = '(?:http|ftp|file)://(?:[^\s<]|$)+(?=[\s<]|$)';
	my $entity_regexg = '&#?\w+;';
	my $word_regexg = '[\w\'\|]+';

	$callback = undef unless ref($callback) && (ref($callback) eq 'CODE');
	warn "Set callback\n" if $DEBUG;

	# Split string into URLs and entities, which are returned verbatim, and words, which are spellchecked
	$string =~ s#($url_regexg)|($entity_regexg)|($word_regexg)#$1 . $2 . $S->_spellcheck_word($3,$callback)#eg;
	warn "String checked\n" if $DEBUG;
	
	return $string;
}

sub _spellcheck_word {
	my $S = shift;
	my $word = shift;
	my $cb = shift;
	warn "Checking word $word\n" if $DEBUG;
	return $word if $word =~ /^\||\|$/;  # ignore blocks/boxes/etc.

	warn "Word $word is not a template variable\n" if $DEBUG;
	if ($S->spellchecker->check($word)) {
		warn "Word $word checks out\n" if $DEBUG;
		return $word;
	} else {
		warn "Word $word not found\n" if $DEBUG;
	
		if ($cb) {
			return $cb->($word);
		} else {
			return $S->{UI}->{BLOCKS}->{spell_err} . $word .
				$S->{UI}->{BLOCKS}->{spell_err_end};
		}
	}
}

sub spellchecker { $_[0]->{spellchecker}; }

=item * spellcheck_html(string, [callback])

The same as spellcheck_string, except it runs the string through the HTML
parser, and only spellchecks text. It keeps everything else intact, however.

=cut

sub spellcheck_html {
	my $S = shift;
	my $string = shift;
	my $callback = shift;

	return $string unless $S->spellcheck_enabled();

	# set up parser can callbacks (anonymous subs works just fine here)
	my $parser = Scoop::HTML::Parser->new();
	$parser->callbacks(
		# sets up a place to hold the result. first arg is parser
		begin => sub {
			$_[0]->{result} = "";
		},
		# put tag back on, unmodified
		start => sub {
			$_[0]->{result} .= '<' . $_[3] . '>';
		},
		# same with end tags
		end => sub {
			$_[0]->{result} .= '</' . $_[2] . '>';
		},
		# same with comments
		comment => sub {
			$_[0]->{result} .= '<!--' . $_[1] . '-->';
		},
		# finally, call spellcheck_string on text
		text => sub {
			$_[0]->{result} .= $S->spellcheck_string($_[1], $callback);
		}
	);

	# do the parsing
	$parser->parse($string);

	return $parser->{result};
}

=item * spellcheck_html_delayed([callback])

This is similar to spellcheck_html, but notice it takes no string. What it does
instead is register itself into the HTML checker so that the next time HTML is
checked, it will also be spellchecked. Because of this, the checked HTML will
also have any changes in it.

Note that you'll probably want to call $S->html_checker->clear_text_callback()
afterwards to clear it out. Otherwise you could end up spellchecking something
you didn't want checked.

The callback that this can optionally take is the same as above.

This returns undef if spellchecking is disabled, otherwise it will return true.

=cut

sub spellcheck_html_delayed {
	my $S = shift;
	my $callback = shift;

	return unless $S->spellcheck_enabled();

	$S->html_checker->add_text_callback(sub {
		warn "spellcheck_html_delayed: callback here" if $DEBUG;
		return $S->spellcheck_string(shift, $callback);
	});

	return 1;
}

sub _spellcheck_init {
	my $S = shift;

	return if $S->{_spellcheck_init};

	my $speling = lc($S->pref('speling'));
	warn "language variant is $speling" if $DEBUG;
	my $checker = Text::Aspell->new;

	return unless $checker;

	my %langs = (
		american => 'en_US',
		canadian => 'en_CA',
		british  => 'en_GB'
	);
	$checker->set_option('lang', $langs{$speling});

	warn "Spellcheck initialized\n" if $DEBUG;
	$S->{spellchecker} = $checker;
	$S->{_spellcheck_init} = 1;
}


1;
