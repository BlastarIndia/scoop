=head1 Blocks.pm

This is what generates the Block admin tools menu.  1 public function,
edit_blocks, generates the whole screen

=cut

package Scoop;
use strict;

my $DEBUG = 0;
my $T_DEBUG = 0;

sub edit_blocks {
	my $S = shift;
	my $content;
	my $update_msg;
	my $form_body;
	my $catlist;
	my $themesel;
	my $html;

	my $item =  $S->{CGI}->param('item');
	my $save = $S->{CGI}->param('save');
	my $delete = $S->{CGI}->param('delete');
	my $theme = $S->{CGI}->param('block_theme');
			#the parameter from the individual block edit form
	my $curr_theme = $S->{CGI}->param('theme') || $S->{UI}->{VARS}->{default_theme};
			#the url parameter
	my $mode = $S->{CGI}->param('mode') || 'Add New';
	my $check_html = $S->{CGI}->param('check_html');

	# for the theme overview, pass the request on to manage_themes without any
	# more processing
	return $S->manage_themes() if $mode eq 'overview';

	# do these updates before we get blocks from the db so that they changes
	# made here are reflected when we generate the form
	my $save_multi_blocks = 0;
	if ($save && $save eq 'Save') {
		if ($delete) {
			$update_msg = $S->_delete_block();
		} elsif ($mode eq 'Add New' || $mode eq 'edit') {
			$update_msg = $S->_save_one_block_changes($mode, $check_html, $curr_theme);
		} else {
			# otherwise, save after hitting the db
			$save_multi_blocks = 1;
		}
	}

	warn "Get or Save: \$save is $save" if $DEBUG;
	warn "Getting from params: \$theme is $curr_theme" if $T_DEBUG;
	# first get the info thats not stored in memory
	my ($rv, $sth) = $S->db_select({
						DEBUG	=> $DEBUG,
						FROM	=> 'blocks',
						WHAT	=> 'bid, block, description, category',
						WHERE	=> qq{theme = '$curr_theme'},
						ORDER_BY => 'bid ASC' });
	
	unless( $rv ) {
		warn "Error accessing blocks db";
		return qq| Error accessing blocks db. |;
	}

	# make an array of hashes of blocks and their info
	my @block_array;
	while( my $blockinfo = $sth->fetchrow_hashref() ) {
		push( @block_array, { 	bid		=> $blockinfo->{bid},
					value		=> $blockinfo->{block},
					description	=> $blockinfo->{description},
					category	=> $blockinfo->{category},
					});
	}

	# now try saving changes from many block mode, since we have the old data
	# to compare to
	if ($save_multi_blocks) {
		$update_msg = $S->_save_many_block_changes( \@block_array, $check_html, $curr_theme );
	}
	
	# get the form header and title
	$content .= $S->{UI}->{BLOCKS}->{edit_block}; 

	# links to all categories
	$catlist = $S->_make_blockcat_chooser( \@block_array, $curr_theme );

	# if they click the edit button set the $variables
	if ($S->{CGI}->param('edit') eq 'Get') {
		$mode='edit';
		$item=$S->{CGI}->param('block');
	}

	if( $mode eq 'Add New' || $mode eq 'edit') {
		# if editing only one block, or adding a new block, give the old-style edit form
		$form_body = $S->_make_newblock_tool( \@block_array, $item, $curr_theme);
		
		#redefine the category for the title display
		#$mode=$item;
	
	} else {
		# otherwise make the table of blocks for editing
		$form_body = $S->_make_block_table( \@block_array, $item, $curr_theme );
	}

	# make htmlcheck part of form
	my $html_checked = 'checked="checked"' if $check_html;
	$html = qq{Check HTML <input name="check_html" type="checkbox" $html_checked />};

	$themesel = qq{<p>Select a theme to edit: };
	($rv,$sth) = $S->db_select({
			DISTINCT => 1,
			WHAT => "theme",
			FROM => "blocks", });
	while ( my $t = $sth->fetchrow_hashref() ) {
		my $th = $t->{theme};
		if ($th eq $curr_theme) {
			$themesel .= " $th";
		} elsif ( $mode eq "multi" ) {
			$themesel .= qq{ <a href="%%rootdir%%/admin/blocks/multi/$th/$item">$th</A>};
		} else {
			$themesel .= qq{ <a href="%%rootdir%%/admin/blocks/edit/$th/$item">$th</A>};
		}
	} 
	$item = "Add New" unless $item;
	$themesel .= qq{<br />
		<a href="%%rootdir%%/admin/blocks/overview">Overview of all themes</a></p>};
	# substitute into the html from the block
	$content =~ s/%%catlist%%/$catlist/;
	$content =~ s/%%category%%/$item in theme $curr_theme/g;
	$content =~ s/%%update_msg%%/$update_msg/;
	$content =~ s/%%theme_sel%%/$themesel/;
	$content =~ s/%%html_check%%/$html/;
	$content =~ s/%%form_body%%/$form_body/;
	
	return $content;
}

# This makes an edit form similar to the old block edit form, but with more
# choices
sub _make_newblock_tool {
	my $S = shift;
	my $block_array = shift;
	my $item = shift;	
	my $curr_theme = shift;
	
	my $save = $S->{CGI}->param('save');
	my $content;
	
	$content = $S->{UI}->{BLOCKS}->{edit_one_block};
			
	# if $edit is set, these will contain the values for the block asked for,
	# else, they will be blank.  These are set about 20 lines down from here		
	my ($bid, $blk_theme, $category, $value, $description);

	# if they just changed the block, get it from the cgi params
	# but if they newly added one, clear the form.
	my $blk =  $S->{CGI}->param('block');
	my $del = $S->{CGI}->param('delete');
	
	$blk = $item if $blk eq '';
	warn "\$save is $save, block is $blk, and delete is $del" if $DEBUG;
	if ( $save eq 'Save' && $blk ne 'new' && ! $del ) {
		warn "Getting block data from params" if $DEBUG;
		$bid		= $S->{CGI}->param('name');
		$blk_theme	= $S->{CGI}->param('block_theme') || $curr_theme;
		$category	= $S->{CGI}->param('category');
		my @category    = $S->{CGI}->param('catsel');
		$value          = $S->{CGI}->param('value');
		$description    = $S->{CGI}->param('description');

		$category .= ',' if ( $category );
		foreach my $c ( @category ) {
			$category .= "$c,";
		}
		chop $category;
		warn "Add or change block: \$category is $category" if $DEBUG;
		warn "Add or change block: \$blk_theme is $blk_theme" if $T_DEBUG;
		warn "Add or change block: \$curr_theme is $curr_theme" if $T_DEBUG;
	}

	# build select control
	my $blockselect = qq{
			<input type="hidden" name="mode" value="edit" />
			<input type="hidden" name="item" value="$bid" />
			<select name="block" size="1">
			<option value="new">Add New Block</option>};

	# make the rest of the options and assign the values for the form, if needed
	foreach my $block ( @$block_array ) {
		my $selected;
		my $defaulttheme = $S->{UI}->{VARS}->{default_theme};
				
		# if they are getting a block, get it from the db
		if( $block->{bid} eq $blk && !$save && !$del) {
			warn "Getting block data from array" if $DEBUG;
			$bid 			= $block->{bid};
			$blk_theme		= $curr_theme;
			$category		= $block->{category};
			warn "Get block: \$category is $category" if $DEBUG;
			$value			= $block->{value};
			$description		= $block->{description};
		
			# escape characters
			$value =~ s/\|/\\|/g;
			$value =~ s/\%\%/\|/g;

		}
		
		$selected = $block->{bid} eq $bid ? 'selected="selected"' : '';
		$blockselect .= qq| 
					<option value="$block->{bid}" $selected>$block->{bid}</option>|;

	}
	$blockselect .= "</select>";
	# end select control

	# now build the category chooser
	my $catselect = qq{
			 <select name="catsel" size="3" multiple="multiple">
			};

	my $cat_array = $S->_get_blockcat_array( $block_array );
	foreach my $cat (@$cat_array) {
		my $selected = ( $category =~ /$cat/ ? 'selected' : '' );

		warn "building category select list: \$cat is $cat and \$category is $category $selected" if $DEBUG;
		$catselect .= qq|
					<option value="$cat" $selected>$cat</option>|;
	}
	$catselect .= '</select>';
	# done category chooser

	$value =~ s/&/&amp;/g;
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;
	warn "\$value = $value" if $DEBUG;

	warn "Repopulating form: \$bid is $bid" if $DEBUG;

	# substitute values into html template
	$content =~ s/%%blockselect%%/$blockselect/;
	$content =~ s/%%catselect%%/$catselect/;
	$content =~ s/%%bid%%/$bid/;
	$content =~ s/%%value%%/$value/;
	$content =~ s/%%theme%%/$blk_theme/;
	$content =~ s/%%curr_theme%%/$curr_theme/;
	$content =~ s/%%description%%/$description/g;
	warn "Substitute values: theme is $blk_theme" if $T_DEBUG;

	return $content;
}


# This makes the category link chooser at the top of the edit blocks form
sub _make_blockcat_chooser {
	my $S = shift;
	my $block_array = shift;
	my $theme = shift;

	my $content = "";
	my $catrow;

	$theme = $S->urlify($theme);
	# lets see what categories we got, eh?
	my $cat_hash = {};
	for my $block ( @$block_array ) {

		# if it belongs to more than 1 category split and record both
		if( $block->{category} =~ m|,| ) {

			# split on ',' and record each in a hash
			my @cat_list = split ',', $block->{category};
			for (@cat_list) {
				next if $cat_hash->{$_} == 1;
				$cat_hash->{$_} = 1;
			}
		} else {
			# ok, so its only 1 category, record it if it hasn't been already
			next if $cat_hash->{ $block->{category} } == 1;
			$cat_hash->{ $block->{category} } = 1;
		}
	}

	# now to display all of those categories nice and neat
	# put 'All' and 'Add New' on the first row, alone, for readability
	$catrow = $S->{UI}->{BLOCKS}->{block_category_list};
	$catrow =~ s/%%item_url%%/multi\/$theme\/All/;
	$catrow =~ s/%%item%%/All/;
	unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
		$content .= $catrow;
		$catrow = $S->{UI}->{BLOCKS}->{block_category_list};
	}
	$catrow =~ s/%%item_url%%/Add%20New\/$theme/;
	$catrow =~ s/%%item%%/Add New/;
	while ( $catrow =~ /%%item%%/ ){
		$catrow =~ s/%%item_url%%//;
		$catrow =~ s/%%item%%//;
	}
	$content .= $catrow;
	$catrow = $S->{UI}->{BLOCKS}->{block_category_list};

	# get all the rest of the categories
	my @cat_array = @{ $S->_get_blockcat_array( $block_array ) };
	while( @cat_array > 0 ) {

		my $cat = shift @cat_array;
		my $urlcat = $S->urlify($cat);
		unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
			$content .= $catrow;
			$catrow = $S->{UI}->{BLOCKS}->{block_category_list};
		}
		$catrow =~ s/%%item_url%%/multi\/$theme\/$urlcat/;
		$catrow =~ s/%%item%%/$cat/;


	}
	# finish up the row, if necessary
	while ( $catrow =~ /%%item%%/ ) {
		$catrow =~ s/%%item_url%%//;
		$catrow =~ s/%%item%%//;
	}
	$content .= $catrow;

	return $content;
}


# This makes the table of all of the blocks, and checkboxes, etc. to edit them
sub _make_block_table {
	my $S = shift;
	my $block_array = shift;
	my $item = shift;
	my $curr_theme = shift;

	my $category = $item;
	my $content = qq{
			<input type="hidden" name="item" value="$item" />
			<input type="hidden" name="theme" value="$curr_theme" />
			<input type="hidden" name="mode" value="catedit" />};
	my $save = $S->{CGI}->param('save');

	warn "\$category is $category" if $DEBUG;
	return '' if $category eq 'Add New';

	my $linetemplate = $S->{UI}->{BLOCKS}->{edit_cat_blocks};
	my $line = "";
	warn "got linetemplate" if $DEBUG;

	my ($bid, $value, $description);	# $bid is a link, $value is the form element, $description is text
	my $d = 0 if $DEBUG;

	for my $block (@$block_array) {
	
		# skip the block if its not in the category we're looking for
		next unless ( $category eq 'All' || $block->{category} =~ /$category/ );
		warn "looking at block $block->{bid}" if $DEBUG;

		# if its just after a save, get the value from $S->{CGI}
		if( $save && $save eq 'Save' ) {
			$block->{value} = $S->{CGI}->param( $block->{bid} );
			warn "saving block $block->{bid}" if $DEBUG;
		}
		
		$line = $linetemplate;
		warn "creating table line" if $DEBUG;

		# just escape > and < and ", so that admins can still
		# input html
		$block->{value} =~ s/\>/&gt;/g;
		$block->{value} =~ s/\</&lt;/g;
		$block->{value} =~ s/"/&quot;/g;
		warn "escaped html entities" if $DEBUG;

		# escape | and \| properly
		unless ( $save eq 'Save' ) {
			$block->{value} =~ s/\|/\\|/g;
			$block->{value} =~ s/\%\%/\|/g;
		}

		# then update appropriate values
		$bid = qq| <a href="%%rootdir%%/admin/blocks/edit/$curr_theme/$block->{bid}">$block->{bid}</a> |;
		$value = qq| <textarea name="$block->{bid}" cols="60" rows="20" wrap="soft">$block->{value}</textarea>&nbsp;<input type="hidden" name="inform_$block->{bid}" value="1" /> |;
		$description = "$block->{description}";
		warn "made var values \$bid, \$value, and \$description" if $DEBUG;
		warn "\$description is $description" if $DEBUG;

		$line =~ s/%%name%%/$bid/;
		$line =~ s/%%value%%/$value/;
		$line =~ s/%%description%%/$description/;
		warn "substituted var values" if $DEBUG;

		$content .= $line;
		$d ++ if $DEBUG;
		warn "added line $d to content" if $DEBUG;	
	}
	
	return $content;
}


# returns an array ref of categories
sub _get_blockcat_array {
	my $S = shift;
	my $block_array = shift;

	my $cat_array;
	
	my $cat_hash = {};
	for my $block ( @$block_array ) {

		# if it belongs to more than 1 category split and record both
		if( $block->{category} =~ m|,| ) {

			# spit on ',' and record each in a hash
			my @cat_list = split ',', $block->{category};
			for (@cat_list) {
				next if $cat_hash->{$_} == 1;
				next unless /\w/;		# skip it if all whitespace
				s/^\s+//;  # ignore leading and trailing whitespace
				s/\s+$//;
				$cat_hash->{$_} = 1;
			}
		} else {
			# ok, so its only 1 category, record it if it hasn't been already
			next if $cat_hash->{ $block->{category} } == 1;
			next unless $block->{category} =~ /\w/;		# skip it if all whitespace
			$block->{category} =~ s/^\s+//;  # and skip leading and trailing whitespace, as well
			$block->{category} =~ s/\s+$//;
			$cat_hash->{ $block->{category} } = 1;
		}
	}

	# so they can see all if they please
	#$cat_hash->{All} = 1;
	#$cat_hash->{None} = 1;
	
	@$cat_array = sort keys %$cat_hash;
	
	return $cat_array;
}


# deletes a block
sub _delete_block {
	my $S = shift;
	my $update_msg;
	my $block_to_del = $S->{CGI}->param('block');
	my $curr_theme = $S->{CGI}->param('theme');
	
	# check to make sure they have a block chosen in the block chooser
	if( $block_to_del eq 'new' ) {
		$update_msg = "You can't delete a block without choosing one first";
	} else {
		
		# ok, they chose a block, now lets delete it
		my ($rv, $sth) = $S->db_delete({
			DEBUG	=> $DEBUG,
			FROM	=> 'blocks',
			WHERE	=> qq| bid = '$block_to_del' AND theme = '$curr_theme'|, });

		if( $rv ) {
			$update_msg = qq|<FONT color="green">$block_to_del in theme $curr_theme deleted.</FONT><BR>|;
		} else {
			$update_msg = qq|Error deleting block '$block_to_del'|;
		}
	}

	return $update_msg;
}

sub _save_one_block_changes {
	my $S = shift;
	my $mode = shift;
	my $html_check = shift;
	my $curr_theme = shift;

	my $update_msg;
	my $error = 0;
	my $changed;
	my $save_this = 1;	# innocent until proven guilty
	my $err_string;
	my ($rv, $sth);

	# if its a save from the main full block editor, treat it special
	my $block       = $S->{CGI}->param('block');
	my $blk_theme   = $S->{CGI}->param('block_theme') || $curr_theme;
	my $value       = $S->{CGI}->param('value');
	my $description = $S->{CGI}->param('description');
	my $category    = $S->{CGI}->param('category');
	my @catsel      = $S->{CGI}->param('catsel');
	warn "@catsel and ". $#catsel if $DEBUG;
	warn "Saving changes: theme is $blk_theme" if $T_DEBUG;

	$category .= ',' . join( ',', @catsel);

	# get rid of any trailing ',' or spaces in the category list, and leading ones
	$category =~ s/\s*,+\s*/,/g;
	$category =~ s/,$//;
	$category =~ s/^,//;
	$category =~ s/^\s+//;
	$category =~ s/\s+$//;

	# sanity checks.  Make sure they have a bid chosen
	my $bid = $S->{CGI}->param('name');

	warn "Saving form: \$bid is $bid and \$block is $block" if $DEBUG;

	if ($bid eq '') {
		return "You need to specify a bid to create a new block";
	}

	$value =~ s/\|/%%/g;
	$value =~ s/\\%%/\|/g;

	my $q_blk_theme = $S->{DBH}->quote($blk_theme);
	my $q_bid = $S->{DBH}->quote($bid);
	$description    = $S->{DBH}->quote($description);
	$value          = $S->{DBH}->quote($value);
	$category       = $S->{DBH}->quote($category);
	warn "Save, after quoting: theme is $q_blk_theme" if $T_DEBUG;

	if ( $html_check ) {
		( $err_string, $save_this ) = $S->_html_check_block($bid, $value);
	}

	if ($block eq 'new' && $save_this ) {
		warn "adding new block" if $DEBUG;
		($rv, $sth) = $S->db_insert({
		    DEBUG => $DEBUG,
		    INTO => 'blocks',
		    COLS => 'bid, theme, block, description, category, aid',
		    VALUES => qq|$q_bid, $q_blk_theme, $value, $description, $category, $S->{UID}|, });

		unless( $rv ) {
			$update_msg .= "Error creating block '$bid'";
			$error = 1;
		} else {
			$changed = 1;
		}

		$sth->finish;

	} elsif ( $block eq $bid && $save_this ) {
		warn "updating block record" if $DEBUG;
		($rv, $sth) = $S->db_update({
		    DEBUG => $DEBUG,
		    WHAT => 'blocks', 
		    SET => qq|block = $value, description = $description, category = $category, theme = $q_blk_theme|,
		    WHERE => qq|bid = '$block' AND theme = $q_blk_theme|, });
		warn "rv is $rv for block update" if $DEBUG;
		unless( $rv ne "0E0" ) {
			$update_msg .= "Error updating block '$bid'";
			$error = 1;
		} else {
			$changed = 1;
		}
		
		$sth->finish;

	} elsif ( $err_string ) {
		warn "html error in block '$bid'" if $DEBUG;
		$update_msg .= $err_string;
		$error = 1;
	} else {
		$update_msg .= "Could not update: '$block' does not match '$bid'";
		$error = 1;
	}
	
	# if there was an error, return and say the error
	return $update_msg if $error;
	
	# Update the cache if something changed
	# Don't want to refresh UI, as that may 
	# Put us in a conflicting state. It'll happen next request.
	if ($changed) {
		$S->cache->remove("blocks_$curr_theme");
		$S->cache->stamp("blocks_$curr_theme");
		$S->cache->remove("blocks_$blk_theme");
		$S->cache->stamp("blocks_$blk_theme");
		$S->_set_vars();
		$S->_set_blocks();
	}

	$update_msg .= qq|<FONT color="green">Successfully updated block: $bid in theme $blk_theme.</FONT><BR>|;
	
	if ($changed) {
		return $update_msg;
	} else {
		return "No blocks have changed! No update performed";
	}
}

sub _save_many_block_changes {
	my $S = shift;
	my $block_array = shift;
	my $html_check = shift;
	my $curr_theme = shift;

	my $update_msg;
	my $error = 0;
	my @updated;
	my $changed;
	my $err_string;
	my ($rv, $sth);

	# now for each block in the form, if it was changed, update it, otherwise
	# ignore it
	for my $block ( @$block_array ) {
		my $save_this = 1;
		# don't try to update if it wasn't in the form
		next unless $S->{CGI}->param( 'inform_' . $block->{bid} );

		my $value = $block->{value};
		my $blockname = $block->{bid};
		warn "trying to update $block->{bid}" if $DEBUG;

		my $formval = $S->{CGI}->param( $block->{bid} );

		$formval =~ s/\|/%%/g;
		$formval =~ s/\\%%/\|/g;

		# skip it unless they changed it
		next if ( $block->{value} eq $formval );	

		# html check
		my $html_err_string;
		my $html_save_this = 1;
		if ( $html_check ) {
			( $html_err_string, $html_save_this ) = $S->_html_check_block($blockname, $formval);
		}
		unless ($html_save_this) {
			$err_string = "$html_err_string";
			warn "error: $err_string" if $DEBUG;
			$save_this = 0;
			$error = 1;
		}

		if ( $save_this ) {
			warn " '$block->{value}' is not '$formval'" if $DEBUG;
		
			# quote input
			my $quoteval = $S->{DBH}->quote( $formval );
	
			# now update the db
			warn "Updating '$block->{bid}' to $quoteval" if $DEBUG;
			($rv, $sth) = $S->db_update({
					DEBUG	=> $DEBUG,
					WHAT	=> 'blocks',
					SET	=> qq| block = $quoteval |,
					WHERE	=> qq| bid = '$block->{bid}' AND theme = '$curr_theme'| });
			
			if( $rv ) {
				push( @updated, $block->{bid} );
				warn "blocks updated so far: @updated" if $DEBUG;
				$changed = 1;
				next;
			}
	
			#if it gets here it didn't update right, return an error
			warn "Error updating $block->{bid} to '$block->{value}'" if $DEBUG;
			$update_msg .= "Error updating $block->{bid} in theme $curr_theme to '$block->{value}'";		
			last;
		} else {
			warn "html error in '$block->{bid}'" if $DEBUG;
			$update_msg .= "$err_string\n";
		}
	} # end for loop

	# if there was an error, return and say the error
	return $update_msg if $error;
	
	# make a neat list to display what was updated
	my $blocklist = join ', ', @updated;
	warn "blocks updated: $blocklist" if $DEBUG;
	$blocklist =~ s/(, )$//;

	# Update the cache if something changed
	# Don't want to refresh UI, as that may 
	# Put us in a conflicting state. It'll happen next request.
	if ($changed) {
		$S->cache->remove("blocks_$curr_theme");
		$S->cache->stamp("blocks_$curr_theme");
		$S->_set_vars();
		$S->_set_blocks();
	}

	$update_msg .= qq|<FONT color="green">Successfully updated blocks: $blocklist in theme $curr_theme.</FONT><BR>|;
	
	if ($changed) {
		return $update_msg;
	} else {
		return "No blocks have changed! No update performed";
	}

}

# HTML Check
sub _html_check_block {
	my $S = shift;
	my $blockname = shift;
	my $value = shift;

	my $save_this = 1;  # innocent until proven guilty
	my $errs = "";
	my $errstr;

	warn "Checking HTML of $value" if $DEBUG;

	my $block_ref = $S->html_checker->clean_html(\$value, '', 1);
	$value = $$block_ref;
	$errstr = $S->html_checker->errors_as_string;
	if ( $errstr ) {
		$errs = "HTML Errors in block $blockname:\n $errstr";
		warn "errs: $errs" if $DEBUG;
		$save_this = 0;
	}

	return ( $errs, $save_this );
}

1;
