=head1 HTML Parser

A simple HTML parser that pulls out tags and text, then uses callbacks to do
something with them. Originally part of Scoop::HTML::Checker, but seperated
because it works better this way.

=head1 Functions

=over 4

=cut

package Scoop::HTML::Parser;
use strict;

=item * new()

Creates a new parser object and returns it.

=cut

sub new {
	my $pkg = shift;

	my $class = ref($pkg) || $pkg;
	my $self = bless {}, $class;

	$self->{_p} = {
		callbacks => {}
	};

	return $self;
}

=item * callbacks([start=>], [end=>], [text=>], [comment=>], [begin=>], [done=>])

Without arguments, returns a hash with the callbacks. With arguments, sets each
callback to whatever is defined. Any not passed are left alone, and any set to
undef are cleared. A callback must be a code reference that can be called.

When a callback is called, the arguments it is passed vary with what the
callback is. However, with all of them, the first argument is the parser
object, which is a hash ref. All of the parser's internal state is kept under
the key _p, so as long as you leave that alone, callbacks are free to store
state in there.

=over 4

=item start (parser, tag, args, raw)

Called when a tag is starting. Tag is the name of the tag (in lower case), and
args is a hash ref with all of the args. The keys are all in lower case. Raw is
the string (minus angle brackets) as was parsed out.

=item end (parser, tag, raw)

Called when a tag finishes. Tag is the same as in with start, as is raw.

=item text (parser, text)

Called on all other plaintext. Text is the actual text.

=item comment (parser, text)

Called when an HTML comment is found. Text is the text within the comment.

=item begin (parser)

Called just before parsing starts. Ideal for setting up some data in the parser
object.

=item done (parser)

Called just after parsing finishes. Ideal for cleaning up the parser object, so
it can be re-used on the next parse.

=back

=cut

sub callbacks {
	my $self = shift;

	if (@_) {
		my %args = @_;
		while (my($k, $v) = each %args) {
			if (defined($v) && (ref($v) eq 'CODE')) {
				$self->{_p}->{callbacks}->{$k} = $v;
			} else {
				delete $self->{_p}->{callbacks}->{$k};
			}
		}
	} else {
		return $self->{callbacks};
	}
}

=item * parse(string)

Parses the given string as HTML, doing callbacks as it goes. It will return
once the entire string has been parsed.

=cut

sub parse {
	my $self = shift;
	my $string = shift;

	$self->_do_callback('begin');

	$string =~ s/(<.*?>)|(<?[^<]+)/$self->_parse_part($1, $2)/egs;

	$self->_do_callback('done');

	return 1;
}

sub _do_callback {
	my $self = shift;
	my $cb   = shift;

	if ($self->{_p}->{callbacks}->{$cb}) {
		return $self->{_p}->{callbacks}->{$cb}->($self, @_);
	}
}

sub _parse_part {
	my $self = shift;
	my ($tag, $text) = @_;

	if ($tag =~ /<!--(.+?)-->/s) {
		$self->_do_callback('comment', $1);
	} elsif ($tag) {
		$self->_parse_tag($tag);
	} else {
		$self->_do_callback('text', $text);
	}
}

sub _parse_tag {
	my $self = shift;
	my $string = shift;

	# get rid of brackets
	$string =~ s/^<//;
	$string =~ s/>$//;

	$string =~ s/^\s+|\s+$//gs;   # remove any extra whitespace
	$string =~ s/\n/ /gs;         # in case the tag was split on lines
	$string =~ s/>/&gt;/g;        # don't let other HTML get snuck in
	$string =~ s/</&lt;/g;        # ditto

	# just strip off XML-style closing shorthand
	$string =~ s/\s*\/$//;

	# parse out the tag name and a string with any arguments it has
	$string =~ /^(\S+)(?:\s+(.+?))?$/;
	my $tag = lc $1;
	my $rest = $2 || "";   # blank string prevents warnings

	# if this is a closing tag, we can do the callback and skip argument
	# parsing
	if ($tag =~ s/^\///) {
		return $self->_do_callback('end', $tag, $string);
	}

	# parse out the args with this friendly regexp :)
	my %args;
	while ($rest =~ /\s*(?:(\S+?)\s*=\s*(?:"+([^"]+)"+|'+([^']+)'+|([^'"\s]+)\S*)|(\S+)(?!=))\s*/g) {
		my $k = $1 || $5; # because of the way parenthesis are used in the
		my $v = $2 || $3 || $4; # regexp, these can be in a couple different
		$args{lc $k} = $v;  # places. it might be fixable, but it's no big deal
	}

	return $self->_do_callback('start', $tag, \%args, $string);
}

=item * parse_fh(fh)

Reads in all of fh, then calls parse with it.

=cut

sub parse_fh {
	my $self = shift;
	my $fh   = shift;

	local $/ = undef;
	my $string = <$fh>;

	return $self->parse($string);
}

=back

=cut

1;
