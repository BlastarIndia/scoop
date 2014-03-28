package Scoop::HTML::Checker;
use Scoop::HTML::Parser;
use strict;

sub new {
	my $pkg = shift;
	my $S   = shift;

	my $class = ref $pkg || $pkg;
	my $self  = bless {}, $class;

	$self->{stack}   = [];
	$self->{errors}  = [];
	$self->{scoop}   = $S;
	# what's this? the not allowed cache. basically, if a tag or arg is marked
	# not allowed, then that fact is saved here. that keeps us from spewing out
	# the same error several times
	$self->{nacache} = {};

	# this is where the code ref for the additional text callback is kept. by
	# default, there isn't one. this is here for the spellchecker, mainly. and
	# now it's used for the long-line wrapper
	$self->{more_text} = [];

	# this is based on the current group, and is probably a subset of HTML. if
	# needed, we will automatically generate another (ghtml) with all HTML tags
	# in it, for checking blocks, special pages, etc.
	$self->{ahtml} = $self->generate_allowed_html();

	$self->{parser} = Scoop::HTML::Parser->new();
	$self->{parser}->callbacks(
		start => \&_tag_start,
		end   => \&_tag_end,
		text  => \&_text,
		begin => \&_p_init
	);

	return $self;
}

sub generate_allowed_html {
	my $self = shift;
	my $block = shift; # not a block anymore, but I didn't feel like renaming variables

	# included for compatibility with old way of allowing different groups
	# different tags
	unless ($block) {
		# look for a block names allowed_html_<currentgroup>. if not found,
		# just use the default of allowed_html
		my $gbn = "allowed_html_" . $self->{scoop}->{GID};
		$block = $self->{scoop}->{UI}->{VARS}->{$gbn} ? $gbn : 'allowed_html';
	}

	my $allowed = {};
	# each tag is on a seperate line
	foreach my $i (split(/\n/, $self->{scoop}->{UI}->{VARS}->{$block})) {
		$i =~ s/\r//g;  # I had a problem with these sneaking in...
		next if (!$i || ($i =~ /^\s*#/));    # blank line or comment
		my @parts = split(/\s*,\s*/, $i);    # get the attributes seperated
		my $t = shift @parts;    # the tag itself is first
		$t = lc $t;      # case insensitive match
		$allowed->{$t} = {};
		foreach my $p (@parts) {
			my $v;
			# if the attrib has a value, seperate it off
			($p, $v) = split(/\s*=\s*/, $p);
			if ($v) {
				# remove optional quotes around the value
				$v =~ s/^["']//;
				$v =~ s/["']$//;
				# escape any slashes
				$v =~ s/\//\\\//g;
			}
			$p = lc $p;  # case-insensitive once again
			# check to see if the current group is allowed to use this tag. if
			# the value isn't set (or the attrib isn't set at all), then all
			# groups can use the tag
			if (($p eq '-groups') && $v) {
				$v =~ s/^(!)//;
				my $invert = $1 ? 1 : 0;
				# allowed groups are seperated by spaces
				my @groups = split(/ /, $v);
				# if the list isn't inverted, then make sure the current group
				# is listed. if it is inverted, make sure it's not listed
				#unless (grep(/^$self->{scoop}->{GID}$/, @groups)) {
				if (
					(!$invert && !grep(/^$self->{scoop}->{GID}$/, @groups)) ||
					($invert && grep(/^$self->{scoop}->{GID}$/, @groups))
				) {
					# remove the reference to the tag
					delete $allowed->{$t};
					# skip out of processing the attributes and move to the
					# next tag
					last;
				}
			} elsif (($p eq '-context') && $v) {
				my @context = split(/ /, $v);
				$v = {};
				foreach my $c (@context) {
					if ($c =~ s/^\!(.+)/$1/) {
						# if any of the items in context start with !, all of
						# them are considered to be inverse
						$v->{'!'} = 1;
					}
					$v->{$c} = 1;
				}
			}
			$allowed->{$t}->{$p} = $v;   # stash it all away
		}
	}

	$self->{ahtml_string} = "";    # force regen

	return $allowed;
}

sub clean_html {
	my $self = shift;
	my $html = shift;
	my $context = shift;
	my $use_all = shift;

	# if this is true, then instead of using the allowed_html block (which is a
	# limited subset of HTML to prevent abuse), the all_html block is used.
	# This comes with all HTML tags and attributes listed, so it can check the
	# validity of HTML
	if ($use_all) {
		# parse all_html block, unless we already have
		$self->{ghtml} = $self->generate_allowed_html('all_html')
			unless $self->{ghtml};
		# shuffle references so that the correct one is used
		$self->{ahtml_bak} = $self->{ahtml};
		$self->{ahtml} = $self->{ghtml};
		# set this so that errors are done slightly different
		$self->{use_all} = 1;
	}

	$self->reset();     # empty stack and clear errors
	# remember the current context
	$self->{cur_context} = $context;
	# store a copy of ourselves in the parser, so we can access stack, cache,
	# etc.
	$self->{parser}->{checker} = $self;  # yes, this is a circular reference

	# do the actual parsing
	$self->{parser}->parse($$html);

	# clear that circular reference (memory leaks baaadddd)
	$self->{parser}->{checker} = undef;

	# grab the result, then remove it
	$$html = $self->{parser}->{result};
	$self->{parser}->{result} = undef;

	$self->empty_stack();    # adds any other errors that have been found

	if ($use_all) {
		# re-shuffle references so that it's ready for next check
		$self->{ahtml} = $self->{ahtml_bak};
		undef $self->{ahtml_bak};
		$self->{use_all} = undef;
	}

	return $html;
}

# starting here, these subs are actually callbacks

sub _p_init {
	my ($parser) = @_;

	$parser->{result} = "";
}

sub _text {
	my ($parser, $text) = @_;

	# quote any angle brackets that slipped through
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;

	# if an additonal text handler has been set, call it, and replace our text
	# with it
	if (@{ $parser->{checker}->{more_text} }) {
		foreach my $cb (@{ $parser->{checker}->{more_text} }) {
			$text = $cb->($text);
		}
	}

	$parser->{result} .= $text;
}

sub _tag_start {
	my ($parser, $tag, $args, $string) = @_;
	my $self = $parser->{checker};

	# if we are checking for abuse, then not allowed is the phrase to use. but
	# if we're checking validity, then we want to be kinder
	my $err_words = $self->{use_all} ? 'unknown' : 'not allowed';

	my $new_tag;
	# now for actually figuring out if this tag is legal
	if ($self->{ahtml}->{$tag} && $self->_check_context($tag)) {
		$new_tag = "<$tag ";
		# look at each of the arguments, if any
		foreach my $a (keys %{$args}) {
			# filter out any javascript: URLs
			next if $args->{$a} =~ /^[\s\w]*script\b/;

			# check URL's for browser bug triggering characters
			if (($tag eq 'a') && ($a eq 'href')) {
				if ($args->{$a} ne $self->{scoop}->check_url($args->{$a})) {
					push(@{ $self->{errors} }, "Value ($args->{$a}) for attribute " . uc($a) . " in tag " . uc($tag) . " is $err_words");
				}
				$args->{$a} = $self->{scoop}->check_url($args->{$a});
			}

			# is this argument allowed and has a constraint on its value?
			if ($self->{ahtml}->{$tag}->{$a}) {
				# if so, does the arg have a value, and does its value fit the
				# constraint given?
				if ($args->{$a} && ($args->{$a} =~ /$self->{ahtml}->{$tag}->{$a}/)) {
					$new_tag .= $a;
					$new_tag .= qq~="$args->{$a}"~ if defined($args->{$a});
					$new_tag .= " ";
				# if it doesn't, report an error
				} else {
					push(@{ $self->{errors} }, "Value ($args->{$a}) for attribute " . uc($a) . " in tag " . uc($tag) . " is $err_words");
				}
			# check if this argument is allowed, but doesn't have any
			# constraints on its value
			} elsif (exists $self->{ahtml}->{$tag}->{$a}) {
				$new_tag .= $a;
				$new_tag .= qq~="$args->{$a}"~ if defined($args->{$a});
				$new_tag .= " ";
			# if it's here, then the argument isn't allowed
			} else {
				# check to see if we've already mentioned that this argument
				# isn't allowed
				unless ($self->{nacache}->{$tag}->{$a}) {
					# if we haven't, mention it now
					push(@{ $self->{errors} }, "Attribute " . uc($a) . " for tag " . uc($tag) . " is $err_words");
					# and note that we did mention it
					$self->{nacache}->{$tag} = {} unless $self->{nacache}->{$tag};
					$self->{nacache}->{$tag}->{$a} = 1;
				}
			}
		}
		chop($new_tag);   # remove trailing space
		$new_tag .= ">";  # and close the tag

		# before we return the new tag, let's see about validating closing tags
		$self->_check_stack($tag, 0);  # 0 means not a closing tag

		$parser->{result} .= $new_tag;
	} else {
		if ($self->{use_all}) {
			unless ($self->{nacache}->{$tag}) {
				push(@{ $self->{errors} }, "Tag " . uc($tag) . " is unknown");
				$self->{nacache}->{$tag} = 1;
			}
		} else {
			# replace with an escaped version
			$parser->{result} .=  "&lt;$string&gt;";
		}
	}
	# if we ever get here (shouldn't), then the tag will just be removed
}

sub _tag_end {
	my ($parser, $tag, $string) = @_;
	my $self = $parser->{checker};

	if ($self->{ahtml}->{$tag} && $self->_check_context($tag)) {
		$parser->{result} .= "</$tag>";
		$self->_check_stack($tag, 1);  # 1 means closing tag
	} else {
		if ($self->{use_all}) {
			if (!$self->{nacache}->{$tag}) {
				push(@{ $self->{errors} }, "Tag " . uc($tag) . "is unknown");
				$self->{nacache}->{$tag} = 1;
			}
		} else {
			$parser->{result} .= "&lt;$string&gt";
		}
	}
}

# end callbacks

sub _check_context {
	my $self = shift;
	my $tag = shift;
	my $cur_context = shift || $self->{cur_context};

	my $tag_context = $self->{ahtml}->{$tag}->{'-context'};
	# if there's no context to check against, then the tag is okay
	return 1 unless $cur_context && $tag_context;
	
	if (
		(!$tag_context->{'!'} && $tag_context->{$cur_context})
		|| ($tag_context->{'!'} && !$tag_context->{$cur_context})
	) {
		return 1;
	} else {
		return 0;
	}
}

sub _check_stack {
	my $self    = shift;
	my $tag     = shift;
	my $closing = shift;

	if (exists $self->{ahtml}->{$tag}->{'-close'}) {
		if ($closing) {
			my $last_tag = pop(@{ $self->{stack} });
			if (!$last_tag) {
				push(@{ $self->{errors} }, "No opening tag found for closing tag " . uc($tag));
			} elsif ($tag ne $last_tag) {
				push(@{ $self->{errors} }, "Closing tag (" . uc($tag) . ") does not match last opening tag (" . uc($last_tag) . ").");
			}
		} else {
			push(@{ $self->{stack} }, $tag);  # save it to check later
		}
	}
}

sub empty_stack {
	my $self = shift;

	foreach my $i (@{ $self->{stack} }) {
		push(@{ $self->{errors} }, "No closing tag found for opening tag " . uc($i));
	}
}

sub errors       { $_[0]->{errors};  }
sub allowed_html { $_[0]->{ahtml};   }
sub nacache      { $_[0]->{nacache}; }

sub allowed_html_as_string {
	my $self = shift;
	my $context = shift || '';

	return $self->{"ahtml_string_$context"} if $self->{"ahtml_string_$context"};

	my $astring = qq|
%%norm_font%%%%html_primer%%Allowed HTML%%html_primer_end%%:
	<font size="1">\n|;
	while (my($tag, $args) = each %{ $self->{ahtml} }) {
		next unless $self->_check_context($tag, $context);
		$tag = uc $tag;
		$astring .= "<nobr>&lt;$tag ";
		foreach my $a (keys %{$args}) {
			next if $a =~ /^-/;
			$a = uc $a;
			$astring .= "[$a";
			$astring .= qq~="$args->{$a}"~ if $args->{$a};
			$astring .= "] ";
		}
		chop($astring);     # remove trailing space
		$astring .= "&gt;";
		$astring .= "&lt;/$tag&gt;" if exists $args->{'-close'};
		$astring .= "</nobr> ";

	}
	chop($astring) if $astring;   # remove trailing space

	$astring .= qq|
	</font>
	%%norm_font_end%%\n|;

	$self->{"ahtml_string_$context"} = $astring;

	return $astring;
}

sub errors_as_string {
	my $self = shift;
	my $where = shift || "";

	return unless $self->{errors}->[0];

	my $errors = (@{ $self->{errors} } == 1 ? "error" : "errors");
	my $string = "Your HTML has the following $errors $where:<BR>\n<UL>\n";
	foreach my $e (@{ $self->{errors} }) {
		$string .= "<LI>$e<BR>\n";
	}
	$string .= "</UL>\n";

	return $string;
}

sub reset {
	my $self = shift;

	$self->{stack}   = [];
	$self->{errors}  = [];
	$self->{nacache} = {};
}

sub add_text_callback {
	my $self = shift;
	my $cb   = shift;

	return unless ref($cb) eq 'CODE';

	push(@{ $self->{more_text} }, $cb);
}

sub text_callbacks {
	my $self = shift;

	return wantarray ? @{ $self->{more_text} } : $self->{more_text};
}

sub clear_text_callbacks {
	my $self = shift;

	$self->{more_text} = [];
}

1;
