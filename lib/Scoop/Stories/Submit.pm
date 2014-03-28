package Scoop;
use strict;

sub submit_story_form {
	my $S = shift;
	my $message = "";    # prevent warnings
	my $preview = $S->{CGI}->param('preview');
	my $posttype = $S->{CGI}->param('posttype');
	my $params = $S->{CGI}->Vars_cloned;
	my $content;

	$S->set_comment_posttype();

	if ($params->{spellcheck} && $S->spellcheck_enabled()) {
		$S->spellcheck_html_delayed();
	}

	foreach my $e (qw(intro body)) {
		my $k = $e . 'text';
		$params->{$k} = $S->filter_comment($params->{$k}, $e, $posttype);
		my $errors = $S->html_checker->errors_as_string("in the $k");
		$message .= $errors if $errors;
	}
	$S->html_checker->clear_text_callbacks() if $params->{spellcheck};

	$params->{title} = $S->filter_subject($params->{title});
	$params->{dept} = $S->filter_subject($params->{dept});

	if ($params->{spellcheck} && $S->spellcheck_enabled()) {
		$params->{title} = $S->spellcheck_string($params->{title});
		$params->{dept} = $S->spellcheck_string($params->{dept});
	}

	if ($preview) {
		# run the standard sanity checks on the story
		my $parms = $S->{CGI}->Vars;
		my($ret, $msg) = $S->_check_story_validity($parms->{sid}, $parms);
		if(! $ret) {
			$message = $msg;
			$S->param->{preview} = 'preview';
		}

                my $tmpsid = 'preview';
                $content .= $S->displaystory($tmpsid, $params);
                $content .= qq|
                        <TR>
                                <TD><FONT face="%%norm_font_face%%" size="%%norm_font_size%%" color="FF0000">$message</FONT></TD>
                        </TR><TR><TD>&nbsp;</TD></TR>|;
        }

	
	my $guidelines = $S->{UI}->{BLOCKS}->{submission_guidelines};
	
	my $form = $S->edit_story_form('public');
	
	return ($content, $form);
}

1;
