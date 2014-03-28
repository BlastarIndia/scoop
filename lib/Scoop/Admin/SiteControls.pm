=head1 SiteControls.pm

This is what generates the Site Controls admin tools menu.  1 public function, edit_vars, generates 
the whole screen

=cut

package Scoop;
use strict;

my $DEBUG = 0;

sub edit_vars {
	my $S = shift;
	my $content;
	my $update_msg;
	my $form_body;
	my $catlist;

	my $item = $S->{CGI}->param('item');
	my $save = $S->{CGI}->param('save');
	my $delete = $S->{CGI}->param('delete');
	my $edit = $S->{CGI}->param('edit');
	my $mode = $S->{CGI}->param('mode') || 'Add New';

	# first get the data fresh from the DB
	# we can't rely on the values in memory because a few of them have been
	# overrided by user prefs
	my ($rv, $sth) = $S->db_select({
						DEBUG	=> $DEBUG,
						FROM	=> 'vars',
						WHAT	=> 'name, value, type, description, category',
						ORDER_BY => 'name ASC'
					});
	
	unless( $rv ) {
		warn "Error accessing vars db";
		return qq| Error accessing vars db. |;
	}
	
	# make an array of hashes of vars and their info
	my @var_array;
	while( my $varinfo = $sth->fetchrow_hashref() ) {
		# if for some reason the var value doesn't exist, skip it
		next unless exists $S->{UI}->{VARS}->{ $varinfo->{name} };
		
		push(@var_array, {
			name        => $varinfo->{name},
			value       => $varinfo->{value},
			description => $varinfo->{description},
			type        => $varinfo->{type},
			category    => $varinfo->{category},
		});
	}
	
	# write changes if there are any
	if ($save && $save eq 'Save') {
		if ($delete) {
			$update_msg = $S->_delete_var();
		} else {
			$update_msg = $S->_save_var_changes(\@var_array, $mode, $item);
		}
	}
	
	# get the form header and title
	$content .= $S->{UI}->{BLOCKS}->{edit_var}; 

	# links to all categories
	$catlist = $S->_make_cat_chooser( \@var_array );

	if ($mode eq 'Add New' || $mode eq 'edit') {
		# if editing only one var, or adding a new var, give the old-style edit form
		$form_body = $S->_make_newvar_tool( \@var_array, $edit, $mode, $item );
	} else {
		# otherwise make the table of vars for editing
		$form_body = $S->_make_var_table( \@var_array, $item );
	}

	# substitute into the html from the block
	$content =~ s/%%catlist%%/$catlist/;
	$content =~ s/%%category%%/$item/g;
	$content =~ s/%%update_msg%%/$update_msg/;
	$content =~ s/%%form_body%%/$form_body/;
	
	return $content;
}



# This makes an edit form similar to the old var edit form, but with more
# choices
sub _make_newvar_tool {
	my $S = shift;
	my $var_array = shift;
	my $edit = shift;
	my $mode = shift;
	my $item = shift;

	my $save = $S->{CGI}->param('save');
	my $content;

	$content = $S->{UI}->{BLOCKS}->{edit_one_var};
		
	# if $edit is set, these will contain the values for the var asked for,
	# else, they will be blank.  These are set about 20 lines down from here

	my ($name, $category, $value, $description, $type);

	# if they just added or changed it, get it from the cgi params
	# but if they newly added one, clear the form.
	my $v = $S->{CGI}->param('var');
	my $del = $S->{CGI}->param('delete');

	$v = $item if $v eq '';
	warn "\$save is $save, var is $v, and delete is $del" if $DEBUG;
	if ( $save eq 'Save' && $v ne 'new' && ! $del ) {
		warn "Getting block data from params" if $DEBUG;
		$name           = $S->{CGI}->param('name');
		$category	= $S->{CGI}->param('category'); #any new categories
		my @category    = $S->{CGI}->param('catsel');
		$value          = $S->{CGI}->param('value');
		warn "Value is $value\n" if $DEBUG;
		$description    = $S->{CGI}->param('description');
		$type           = $S->{CGI}->param('type');

		$category .= "," if ( $category );
		foreach my $c ( @category ) {
			$category .= "$c,";
		}
		chop $category;
		warn "Add or change var: \$category is $category" if $DEBUG;
	}

	# build select control
	my $varselect = qq{
			<input type="hidden" name="mode" value="edit" />
			<input type="hidden" name="item" value="$v" />
			<select name="var" size="1">
			<option value="new">Add New Variable</option>};

	# make the rest of the options and assign the values for the form, if needed
	foreach my $var ( @$var_array ) {
		my $selected;
				
		# if they are getting the var, get it from the db
#		if( $var->{name} eq $S->{CGI}->param('var') && $edit && $edit eq 'Get' ) {
		if( $var->{name} eq $v && (($edit && $edit eq 'Get') || $mode eq 'edit') && !$save) {
			warn "Getting $var->{name} from DB...\n" if $DEBUG;
			$name 			= $var->{name};
			$category		= $var->{category};
			$value			= $var->{value};
			$description	= $var->{description};
			$type			= $var->{type};

		}
		
		$selected = $var->{name} eq $name ? 'selected="selected"' : '';
		$varselect .= qq| 
					<option value="$var->{name}" $selected>$var->{name}</option> |;

	}
	$varselect .= "</select>";
	# end select control

	# now build the category chooser
	my $catselect = qq{
			 <select name="catsel" size="3" multiple="multiple">
			};

	my $cat_array = $S->_get_cat_array( $var_array );
	foreach my $cat (@$cat_array) {
		my $selected = ( $category =~ /$cat/ ? 'selected="selected"' : '' );

		$catselect .= qq|
					<option value="$cat" $selected>$cat|;
	}
	$catselect .= '</select>';
	# done category chooser

	my ($nselect, $bselect, $taselect);
	# choose which to select of the type chooser
	if( $type eq 'bool' ) {
		$bselect = 'selected="selected"';
	} elsif( $type eq 'num' ) {
		$nselect = 'selected="selected"';
	} elsif( $type eq 'tarea' ) {
		$taselect = 'selected="selected"';
	}

	# generate the type chooser
	my $typeselect .= qq|
					<select name="type" size="1">
					<option value="text">Text</option>
					<option value="num"  $nselect>Number</option>
					<option value="bool" $bselect>Boolean</option>
					<option value="tarea" $taselect>Textarea</option>
					</select> |;
	
	warn "Value is $value\n" if $DEBUG;
	# substitute values into html template
	$content =~ s/%%varselect%%/$varselect/;
	$content =~ s/%%catselect%%/$catselect/;
	$content =~ s/%%typeselect%%/$typeselect/;
	$content =~ s/%%name%%/$name/;
	$content =~ s/%%value%%/$value/;
	$content =~ s/%%description%%/$description/g;

	return $content;
}


# This makes the category link chooser at the top of the edit vars form
sub _make_cat_chooser {
	my $S = shift;
	my $var_array = shift;
	my $content = "";
	my $catrow;

	# lets see what categories we got, eh?
	my $cat_hash = {};
	for my $var ( @$var_array ) {

		# if it belongs to more than 1 category split and record both
		if( $var->{category} =~ m|,| ) {

			# spit on ',' and record each in a hash
			my @cat_list = split ',', $var->{category};
			for (@cat_list) {
				next if $cat_hash->{$_} == 1;
				$cat_hash->{$_} = 1;
			}
		} else {
			# ok, so its only 1 category, record it if it hasn't been already
			next if $cat_hash->{ $var->{category} } == 1;
			$cat_hash->{ $var->{category} } = 1;
		}
	}

	# now to display all of those categories nice and neat
	# put 'All' and 'Add New' on the first row, alone, for readability
	$catrow = $S->{UI}->{BLOCKS}->{var_category_list};
	$catrow =~ s/%%item_url%%/multi\/All/;
	$catrow =~ s/%%item%%/All/;
	unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
		$content .= $catrow;
		$catrow = $S->{UI}->{BLOCKS}->{var_category_list};
	}
	$catrow =~ s/%%item_url%%/Add%20New/;
	$catrow =~ s/%%item%%/Add New/;
	while ( $catrow =~ /%%item%%/ ){
		$catrow =~ s/%%item_url%%//;
		$catrow =~ s/%%item%%//;
	}
	$content .= $catrow;
	$catrow = $S->{UI}->{BLOCKS}->{var_category_list};

	# get all the rest of the categories
	my $count = 0;
	my @cat_array = @{ $S->_get_cat_array( $var_array ) };
	while( @cat_array > 0 ) {

		my $cat = shift @cat_array;
		my $urlcat = $S->urlify($cat);
		unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
			$content .= $catrow;
			$catrow = $S->{UI}->{BLOCKS}->{var_category_list};
		}
		$catrow =~ s/%%item_url%%/multi\/$urlcat/;
		$catrow =~ s/%%item%%/$cat/;

		$count++; 

	}
	# finish up the row, if necessary
	while ( $catrow =~ /%%item%%/ ) {
		$catrow =~ s/%%item_url%%//;
		$catrow =~ s/%%item%%//;
	}
	$content .= $catrow;

	return $content;
}


# This makes the table of all of the vars, and checkboxes, etc. to edit them
sub _make_var_table {
	my $S = shift;
	my $var_array = shift;
	my $category = shift;
	my $content;
	my $save = $S->{CGI}->param('save');

	return '' if $category eq 'Add New';

	my $linetemplate = $S->{UI}->{BLOCKS}->{edit_cat_vars};
	my $line = "";

	# now that we have the header, generate the inputs for each var, divided by type
	my ($texts, $nums, $bools, $tareas);
	my ($name, $value, $description);	# $name is a link, $value is the appropriate form element, $description is text
	for my $var (@$var_array) {
	
		# skip the var if its not in the category we're looking for
		next unless ( $category eq 'All' || $var->{category} =~ /$category/ );

		# if its just after a save, get the value from $S->{CGI}
		if( $save && $save eq 'Save' ) {
			$var->{value} = $S->{CGI}->param( $var->{name} );
		}
		
		$line = $linetemplate;

		# just escape > and < and ", so that admins can still
		# input html
		$var->{value} =~ s/\>/&gt;/g;
		$var->{value} =~ s/\</&lt;/g;
		$var->{value} =~ s/"/&quot;/g;

		# now determine type, then update appropriate values
		if( $var->{type} eq 'bool' ) {
			# bool, easy
			
			my $checked = ($var->{value} == 1) ? 'checked="checked"' : '';
			$name = qq|<a href="%%rootdir%%/admin/vars/edit/$var->{name}">$var->{name}</a>|;
			$value = qq|<input type="checkbox" name="$var->{name}" value="1" $checked /><input type="hidden" name="inform_$var->{name}" value="1" />|;
			$description = $var->{description};

			$line =~ s/%%name%%/$name/;
			$line =~ s/%%value%%/$value/;
			$line =~ s/%%description%%/$description/;

			$bools .= $line;

		} elsif( $var->{type} eq 'num' ) {
			# number, so include a little form for the number
			$name = qq|<a href="%%rootdir%%/admin/vars/edit/$var->{name}">$var->{name}</a>|;
			$value = qq|<input type="text" name="$var->{name}" value="$var->{value}" size="3" /><input type="hidden" name="inform_$var->{name}" value="1" />|;
			$description = $var->{description};

			$line =~ s/%%name%%/$name/;
			$line =~ s/%%value%%/$value/;
			$line =~ s/%%description%%/$description/;

			$nums .= $line;

		} elsif( $var->{type} eq 'text' ) {
			# text, so a bigger form for a short string
			$name = qq|<a href="%%rootdir%%/admin/vars/edit/$var->{name}">$var->{name}</a>|;
			$value = qq|<input type="text" name="$var->{name}" value="$var->{value}" size="25" />&nbsp;<input type="hidden" name="inform_$var->{name}" value="1" />|;
			$description = $var->{description};

			$line =~ s/%%name%%/$name/;
			$line =~ s/%%value%%/$value/;
			$line =~ s/%%description%%/$description/;

			$texts .= $line;
		} else {
			# not bool, number, or text, assume textarea
			$name = qq|<a href="%%rootdir%%/admin/vars/edit/$var->{name}">$var->{name}</a>|;
			$value = qq|<input type="hidden" name="inform_$var->{name}" value="1" /><textarea name="$var->{name}" cols="60" rows="20" wrap="soft">$var->{value}</textarea>|;
			$description = $var->{description};

			$line =~ s/%%name%%/$name/;
			$line =~ s/%%value%%/$value/;
			$line =~ s/%%description%%/$description/;

			$tareas .= $line;
		}
	}
	
	$content = qq|
			<input type="hidden" name="item" value="$category" />
			<input type="hidden" name="mode" value="catedit" />
			$bools 
			$nums 
			$texts
			$tareas
		|;

	return $content;
}


# returns an array ref of categories
sub _get_cat_array {
	my $S = shift;
	my $var_array = shift;
	my $cat_array;
	
	my $cat_hash = {};
	for my $var ( @$var_array ) {

		# if it belongs to more than 1 category split and record both
		if( $var->{category} =~ m|,| ) {

			# spit on ',' and record each in a hash
			my @cat_list = split ',', $var->{category};
			for (@cat_list) {
				next if $cat_hash->{$_} == 1;
				next unless /\w/;		# skip it if all whitespace
				s/^\s+//;  # get rid of leading and trailing whitespace
				s/\s+$//;
				$cat_hash->{$_} = 1;
			}
		} else {
			# ok, so its only 1 category, record it if it hasn't been already
			next if $cat_hash->{ $var->{category} } == 1;
			next unless $var->{category} =~ /\w/;		# skip it if all whitespace
			$cat_hash->{ $var->{category} } = 1;
		}
	}

	# so they can see all if they please
	#$cat_hash->{All} = 1;
	#$cat_hash->{None} = 1;
	
	@$cat_array = sort keys %$cat_hash;
	
	return $cat_array;
}


# deletes a var
sub _delete_var {
	my $S = shift;
	my $update_msg;
	my $var_to_del = $S->{CGI}->param('var');

	# check to make sure they have a var chosen in the var chooser
	if( $var_to_del eq 'new' ) {
		$update_msg = "You can't delete a variable without choosing one first";
	} else {
		
		# ok, they chose a var, now lets delete it
		my ($rv, $sth) = $S->db_delete({
			DEBUG	=> $DEBUG,
			FROM	=> 'vars',
			WHERE	=> qq| name = '$var_to_del' |,
			});

		if( $rv ) {
			$update_msg = qq|<font color="green">$var_to_del deleted.</font><br />\n Note: the var you just deleted will still be in the list, due to caching.  It will not be there the next time you reload this page, however. |;
		} else {
			$update_msg = qq|Error deleteing var '$var_to_del'|;
		}
	}

	return $update_msg;
}

# just updates whats changed in the var db
sub _save_var_changes {
	my $S = shift;
	my $var_array = shift;
	my $mode = shift;
	my $item = shift;
	
	my $update_msg;
	my $error = 0;
	my @updated;
	my $changed;
	my ($rv, $sth);

	# if its a save from the main full var editor, treat it special
	if( $mode eq 'Add New' || $mode eq 'edit' ) {
		my $var			= $S->{CGI}->param('var');
		my $value		= $S->{CGI}->param('value');
		my $description	= $S->{CGI}->param('description');
		my $category	= $S->{CGI}->param('category');
		my $type		= $S->{CGI}->param('type');
		my @catsel		= $S->{CGI}->param('catsel');
		warn "@catsel and ". $#catsel if $DEBUG;
	
		$category .= ',' . join( ',', @catsel);
	
		# get rid of any trailing ',' or spaces in the category list, and leading ones
		$category =~ s/\s*,+\s*/,/g;
		$category =~ s/,$//;
		$category =~ s/^,//;
		$category =~ s/^\s+//;
		$category =~ s/\s+$//;
	
		# sanity checks.  Make sure they have a name chosen
		my $name = $S->{CGI}->param('name');
		if( $name eq '' ) {
			return "You need to specify a name to create a new var";
		}
		
		$description	= $S->{DBH}->quote($description);
		$value			= $S->{DBH}->quote($value);
		$category		= $S->{DBH}->quote($category);
		$type			= $S->{DBH}->quote($type);
	
	    if ($var eq 'new') {
			#warn "adding new var";
			($rv, $sth) = $S->db_insert({
			    DEBUG => 0,
			    INTO => 'vars',
			    COLS => 'name, value, description, category, type',
			    VALUES => qq|"$name", $value, $description, $category, $type|});
			
			unless( $rv ) {
				$update_msg = "Error creating var '$name'";
				$error = 1;
			} else {
				push( @updated, $name );
				$changed = 1;
			}
			
			$sth->finish;

	    } elsif( $var eq $name ) {
			warn "Writing var record" if $DEBUG;
			my $q_var = $S->dbh->quote($var);
			($rv, $sth) = $S->db_update({
			    DEBUG => 0,
			    WHAT => 'vars', 
			    SET => qq|value = $value, description = $description, category = $category, type = $type|,
			    WHERE => qq|name = $q_var|});
			
			unless( $rv ) {
				$update_msg = "Error updating var '$name'";
				$error = 1;
			} else {
				push( @updated, $name );
				$changed = 1;
			}
			
			$sth->finish;
			
	    } else {
			$update_msg = "Could not update: '$var' does not match '$name'";
			$error = 1;
	    }
	
	} else {
		# this is a save from one of the categories, so make sure to update all

		# now for each var in the form, if it was changed, update it, otherwise
		# ignore it
		for my $var ( @$var_array ) {

			# don't try to update if it wasn't in the form
			next unless $S->{CGI}->param( 'inform_' . $var->{name} );
			warn "trying to update $var->{name}" if $DEBUG;
			
			my $formval = $S->{CGI}->param($var->{name});

			# skip it unles they changed it
			# special case for bools
			if( $var->{type} eq 'bool' ) {
				# next unless the value has changed, so we have 1,0 or 0,1
				next unless ( ( $var->{value} || $formval ) &&
								( $var->{value} != $formval ) );
			} else { 
				# its not a bool, so just compare the values
				next if ( $var->{value} eq $formval );	
			}
			warn "in $var->{name}, '$var->{value}' is not '$formval'" if $DEBUG;
		
			# error checking, so they can't set nums to 'a' for instance, and bools to e, text
			# let them put in what they want
			if ( ( $var->{type} eq 'bool' ) 		&&		# if its a bool
				( $S->{CGI}->param($var->{name}) != 0 )	&&		# and the value is not a 0
				( $S->{CGI}->param($var->{name}) != 1 ) ) {		# or a 1
			
				# not a 0 or a 1!  for a bool! something fishy!
				$update_msg .= "Error updating $var->{name}, value is not boolean";
				$error = 1;
				last;
				
			} elsif( $var->{type} eq 'num' ) {				# if its a num type
					unless( $formval =~ /^-?\d+\.?\d*%?$/ ) {
						# bad chars in number value
						$update_msg .=  "Error updating $var->{name}, Decimal value includes improper
								chars! Only -, %, . and numbers allowed in decimal values";
						$error = 1;
						last;
					}
			}
			# if its a text or textarea, let them put what they want, so no tests for it
		
			# quote input
			my $quoteval = $S->{DBH}->quote( $formval );
		
			# now update the db
			warn "Updating '$var->{name}' to $quoteval" if $DEBUG;
			($rv, $sth) = $S->db_update({
					DEBUG	=> $DEBUG,
					WHAT	=> 'vars',
					SET		=> qq| value = $quoteval |,
					WHERE	=> qq| name = '$var->{name}'|,
				});
			
			if( $rv ) {
				push( @updated, $var->{name} );
				$changed = 1;
				next;
			}
		
			#if it gets here it didn't update right, return an error
			warn "Error updating $var->{name} to '$var->{value}'" if $DEBUG;
			$update_msg = "Error updating $var->{name} to '$var->{value}'";		
			last;
		}
	} #end really big if statement
	
	# if there was an error, return and say the error
	return $update_msg if $error;
	
	# make a neat list to display what was updated
	my $varlist = join ', ', @updated;
	$varlist =~ s/(, )$//;
	
	# Update the cache if something changed
	# Don't want to refresh UI, as that may 
	# Put us in a conflicting state. It'll happen next request.
	if ($changed) {
		warn "Var changed. Refreshing.\n" if $DEBUG;
		$S->cache->remove('vars');
		$S->cache->stamp('vars');
		$S->_set_vars();
		$S->_set_blocks();
	}

	my $notemsg = qq| Note: If you added a new var or category just now, it will not show yet,
				due to caching.  It will show the next time you reload this page, however. |;

	if ( $mode ne 'Add New' and $varlist ne '' ) {
		$update_msg = qq|<FONT color="green">Successfully updated vars: $varlist.</FONT><BR>|;
	} elsif( $mode eq 'Add New' ) {
		$update_msg = qq|<FONT color="green">Successfully updated var: $varlist.</FONT><BR>\n$notemsg|;
	}
	
	if( scalar( @updated ) >= 0 ) {
		return $update_msg;
	} else {
		return "No vars have changed! No update performed";
	}
}


1;
