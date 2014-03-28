package Scoop;
use strict;
my $DEBUG = 0;

###########################################################################
#
# Macros package for Scoop
#
# Hacked and contributed by Steve Linberg, September 2003
#
# Version 1.0
#
# I added this after users on my scoop site bitched about not having "image
# macros", short things they could type to insert a block of HTML because
# they're too damn lazy to type the HTML each time.
#
# the use_macro var (in the Stories category) must be set to 1 for macros
# to work.
#
# Macros are basically like blocks, and we just substitute them when a
# story or comment is displayed.  Macros look like this in text:
#
# ((foo))
#
# if use_macros is defined and 1, ((foo)) will be replaced by the contents
# of the "foo" macro.
#
# Additionally, macros can take arguments:
#
# ((foo [bar] [baz]))
#
# In a macro, [bar] and [baz] will replace ((1)) and ((2)) in the macro
# text.
#
# Macro names are the first parsed word in the macro.  If there is
# additional data not in [x] brackets, it is all taken as the first
# argument.  So:
#
# ((foo bar baz))
#
# ((1)) gets "bar baz".
#
# MACROS DO NOT NEST.  As of now.
#
# To 'escape' a macro and prevent it from rendering, prefix its name with
# '*', as in:
#
# ((*foo do not render me))
#
# This is how macros are rendered in verbose comments.  (Actually, any
# non-space character that would cause the comment 'name' not to be found
# would work fine.)
#
###########################################################################

sub process_macros {

	my $S = shift;
	my $text = shift || '';
	my $context = shift || '';

	return $text unless (exists $S->{UI}->{VARS}->{use_macros} && $S->{UI}->{VARS}->{use_macros});

	$text =~ s{\(\((.*?)\)\)}{ $S->_process_macro($1,$context) }sige;

	return $text;

}

sub _process_macro {

	my $S = shift;
	my $text = shift;
	my $context = shift;

	# If there is no macro with the given name, just return the original text.

	$text =~ /^\s*(\S+)\s*(.*)/s;
	my $macro_name = $1 || '';
	return qq|(($text))| unless defined $S->{UI}->{MACROS}->{$macro_name};

	my $args = $2 || '';

	# get the attributes seperated
	my @parts = split(/\s*,\s*/, $S->{UI}->{MACROS}->{$macro_name}->{parameter});
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
			my $invert = ($v =~ s/^\!(.+)/$1/);
			# allowed groups are seperated by spaces
			my @groups = split(/ /, $v);
			# if the list isn't inverted, then make sure the current group
			# is listed. if it is inverted, make sure it's not listed
			#unless (grep(/^$S->{GID}$/, @groups)) {
			if (
				(!$invert && !grep(/^$S->{GID}$/, @groups)) ||
				($invert && grep(/^$S->{GID}$/, @groups))
			) {
				# skip out of processing the attributes and move to the
				return "";
			}
		} elsif (($p eq '-context') && $v) {
			my @context_a = split(/ /, $v);
			$v = {};
			foreach my $c (@context_a) {
				if ($c =~ s/^\!(.+)/$1/) {
				# if any of the items in context start with !, all of
				# them are considered to be inverse
					$v->{'!'} = 1;
				}
				$v->{$c} = 1;
			}
			if ( ($v->{$context} && $v->{'!'}) || (!$v->{$context} && !$v->{'!'}) ) {
				return "";
			}
		}
	}
	my $macro_text = $S->{UI}->{MACROS}->{$macro_name}->{value} || '';
	$macro_text =~ s/\|/%%/g;
	$macro_text = $S->interpolate($macro_text,$S->{UI}->{BLOCKS},{special =>'true'});
	$macro_text = $S->interpolate($macro_text,$S->{UI}->{VARS},{clear => 'true'});
	
	if ($args) {
		my @args = ();
		if (index($args, '[') == 0) {
			$args =~ s/\[//gs;
			@args = split (']', $S->filter_subject($args));
		} else {
			push @args, $S->filter_subject($args);
		}
		$macro_text =~ s/\(\((\d+)\)\)/$args[$1-1]/ge;
	}

	# Remove any remaining ((\d+)) constructs left over.
	$macro_text =~ s/\(\(\d+\)\)//g if $macro_text;

	# If we're rendering macros verbosely, surround them with a comment
	# delimiting them and containing the original macro text (escaped).

	if (defined $S->{UI}->{VARS}->{macro_render_verbose} && defined $S->{UI}->{VARS}->{macro_render_verbose}) {
		$macro_text = qq(
<!-- MACRO: begin macro '$macro_name' -->
<!-- MACRO: original format: ((*$text)) -->
$macro_text
<!-- MACRO: end macro '$macro_name' -->
);
	}
	
	return $macro_text;

}

###########################################################################
#
# Everything below was swiped verbatim from Admin/SiteControls.pm, and just
# tweaked as needed to edit macros instead of vars.
#
# The main difference between macros and vars is that macros have no
# 'type', and behave like 'text' type vars.
#
###########################################################################

sub edit_macros {
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
						FROM	=> 'macros',
						WHAT	=> 'name, value, description, category, parameter',
						ORDER_BY => 'name ASC'
					});
	
	unless( $rv ) {
		warn "Error accessing macros db";
		return qq| Error accessing macros db. |;
	}
	
	# make an array of hashes of macros and their info
	my @macro_array;
	while( my $macroinfo = $sth->fetchrow_hashref() ) {
#		warn qq(edit_macros: processing macro $macroinfo->{name}) if $DEBUG;
		# if for some reason the macro value doesn't exist, skip it
		next unless exists $S->{UI}->{MACROS}->{ $macroinfo->{name} };
#		warn qq(edit_macros: adding $macroinfo->{name} to array);		
		push(@macro_array, {
			name        => $macroinfo->{name},
			value       => $macroinfo->{value},
			description => $macroinfo->{description},
			category    => $macroinfo->{category},
			parameter   => $macroinfo->{parameter}
		});
	}
        # write changes if there are any
        if ($save && $save eq 'Save') {
                if ($delete) {
			$update_msg = $S->_delete_macro();
                } else {
			$update_msg = $S->_save_macro_changes( \@macro_array, $mode, $item );
                }
        }

	# get the form header and title
	$content .= $S->{UI}->{BLOCKS}->{edit_macro}; 

	# links to all categories
	$catlist = $S->_make_macro_cat_chooser( \@macro_array );

	if ($mode eq 'Add New' || $mode eq 'edit') {
		# if editing only one macro, or adding a new macro, give the old-style edit form
		$form_body = $S->_make_newmacro_tool( \@macro_array, $edit, $item );
	} else {
		# otherwise make the table of macros for editing
		$form_body = $S->_make_macro_table( \@macro_array, $item );
	}
	# substitute into the html from the block
	$content =~ s/%%catlist%%/$catlist/;
	$content =~ s/%%category%%/$item/g;
	$content =~ s/%%update_msg%%/$update_msg/;
	$content =~ s/%%form_body%%/$form_body/;
	
	return $content;
}


sub _make_newmacro_tool {
	my $S = shift;
	my $macro_array = shift;
	my $edit = shift;
	my $mode = shift;
	my $item = shift;
	
	my $save = $S->{CGI}->param('save');
	my $content;
	
	$content = $S->{UI}->{BLOCKS}->{edit_one_macro};
			
	# if $edit is set, these will contain the values for the macro asked for,
	# else, they will be blank.  These are set about 20 lines down from here		
	my ($name, $category, $value, $description, $parameter);
	
	# if they just added or changed it, get it from the cgi params
	# but if they newly added one, clear the form.
	my $v = $S->{CGI}->param('macro');
	my $del = $S->{CGI}->param('delete');

	$v = $item if $v eq '';
	warn "save is [$save], macro is [$v], edit is [$edit], and delete is [$del]" if $DEBUG;
	if ( $save eq 'Save' && $v ne 'new' && ! $del ) {
		warn "Getting block data from params" if $DEBUG;
		$name           = $S->{CGI}->param('name');
		$category	= $S->{CGI}->param('category'); #any new categories
		my @category    = $S->{CGI}->param('catsel');
		$value          = $S->{CGI}->param('value');
		$description    = $S->{CGI}->param('description');
		$parameter	= $S->{CGI}->param('parameter');

		$category .= "," if ( $category );
		foreach my $c ( @category ) {
			$category .= "$c,";
		}
		chop $category;
		warn "Add or change macro: \$category is $category" if $DEBUG;
	}

	# build select control
	my $macroselect = qq{
                        <input type="hidden" name="mode" value="edit" />
                        <input type="hidden" name="item" value="$v" />
			<SELECT NAME="macro" SIZE=1>
			<OPTION VALUE="new">Add New Macro};

	# make the rest of the options and assign the values for the form, if needed
	foreach my $macro ( @$macro_array ) {
		my $selected;

		# if they are getting the macro, get it from the db
		if( $macro->{name} eq $S->{CGI}->param('macro') && $edit && $edit eq 'Get' ) {
			$name 			= $macro->{name};
			$category		= $macro->{category};
			$value			= $macro->{value};
			$description		= $macro->{description};
			$parameter		= $macro->{parameter};

		}
		
		$selected = $macro->{name} eq $name ? 'selected' : '';
		$macroselect .= qq| 
					<OPTION VALUE="$macro->{name}" $selected>$macro->{name} |;

	}
	$macroselect .= "</SELECT>";
	# end select control

	# now build the category chooser
	my $catselect = qq{
			 <SELECT NAME="catsel" SIZE=3 multiple>
			};

	my $cat_array = $S->_get_cat_array( $macro_array );
	foreach my $cat (@$cat_array) {
		my $selected = ( $category =~ /$cat/ ? 'selected' : '' );

		$catselect .= qq|
					<OPTION VALUE="$cat" $selected>$cat|;
	}
	$catselect .= '</SELECT>';
	# done category chooser

        $value =~ s/&/&amp;/g;
        $value =~ s/</&lt;/g;
        $value =~ s/>/&gt;/g;
        $value =~ s/"/&quot;/g;
        $parameter =~ s/&/&amp;/g;
        $parameter =~ s/</&lt;/g;
        $parameter =~ s/>/&gt;/g;
        $parameter =~ s/"/&quot;/g;

	# substitute values into html template
	$content =~ s/%%macroselect%%/$macroselect/;
	$content =~ s/%%catselect%%/$catselect/;
	$content =~ s/%%name%%/$name/;
	$content =~ s/%%value%%/$value/;
	$content =~ s/%%description%%/$description/;
	$content =~ s/%%parameter%%/$parameter/;

	return $content;
}


# This makes the table of all of the macros, and checkboxes, etc. to edit them
sub _make_macro_table {
	my $S = shift;
	my $macro_array = shift;
	my $category = shift;
	my $content;
	my $save = $S->{CGI}->param('save');

	return '' if $category eq 'Add New';

	my $linetemplate = $S->{UI}->{BLOCKS}->{edit_cat_vars};
	my $line = "";

	# now that we have the header, generate the inputs for each macro
	my ($texts, $nums, $bools, $tareas);
	my ($name, $value, $description, $parameter);	# $name is a link, $value is the appropriate form element, $description is text
	for my $macro (@$macro_array) {
	
		# skip the macro if its not in the category we're looking for
		next unless ( $category eq 'All' || $macro->{category} =~ /$category/ );

		# if its just after a save, get the value from $S->{CGI}
		if( $save && $save eq 'Save' ) {
			$macro->{value} = $S->{CGI}->param( $macro->{name} );
		}
		
		$line = $linetemplate;

		# just escape > and < and ", so that admins can still
		# input html
		$macro->{value} =~ s/\>/&gt;/g;
		$macro->{value} =~ s/\</&lt;/g;
		$macro->{value} =~ s/"/&quot;/g;

		# text, so a bigger form for a short string
		$name = qq|<a href="%%rootdir%%/admin/macros/edit/$macro->{name}">$macro->{name}</a>|;
		$value = qq|<INPUT type="hidden" name="inform_$macro->{name}" value="1"><TEXTAREA name="$macro->{name}" cols="60" rows="20" wrap="soft">$macro->{value}</TEXTAREA>|;
		$description = $macro->{description};
		$parameter = $macro->{parameter};

	        $parameter =~ s/&/&amp;/g;
	        $parameter =~ s/</&lt;/g;
	        $parameter =~ s/>/&gt;/g;
	        $parameter =~ s/"/&quot;/g;

		$line =~ s/%%name%%/$name/;
		$line =~ s/%%value%%/$value/;
		$line =~ s/%%description%%/$description/;
		$line =~ s/%%parameter%%/$parameter/;

		$texts .= $line;
	}
	
	$content = qq|
                        <input type="hidden" name="item" value="$category" />
                        <input type="hidden" name="mode" value="catedit" />
 
			$texts
		|;

	return $content;
}


# # returns an array ref of categories
# sub _get_cat_array {
# 	my $S = shift;
# 	my $macro_array = shift;
# 	my $cat_array;
# 	
# 	my $cat_hash = {};
# 	for my $macro ( @$macro_array ) {
# 
# 		# if it belongs to more than 1 category split and record both
# 		if( $macro->{category} =~ m|,| ) {
# 
# 			# spit on ',' and record each in a hash
# 			my @cat_list = split ',', $macro->{category};
# 			for (@cat_list) {
# 				next if $cat_hash->{$_} == 1;
# 				next unless /\w/;		# skip it if all whitespace
# 				s/^\s+//;  # get rid of leading and trailing whitespace
# 				s/\s+$//;
# 				$cat_hash->{$_} = 1;
# 			}
# 		} else {
# 			# ok, so its only 1 category, record it if it hasn't been already
# 			next if $cat_hash->{ $macro->{category} } == 1;
# 			next unless $macro->{category} =~ /\w/;		# skip it if all whitespace
# 			$cat_hash->{ $macro->{category} } = 1;
# 		}
# 	}
# 
# 	# so they can see all if they please
# 	#$cat_hash->{All} = 1;
# 	#$cat_hash->{None} = 1;
# 	
# 	@$cat_array = sort keys %$cat_hash;
# 	
# 	return $cat_array;
# }


# deletes a macro
sub _delete_macro {
	my $S = shift;
	my $update_msg;
	my $macro_to_del = $S->{CGI}->param('macro');
	
	# check to make sure they have a macro chosen in the macro chooser
	if( $macro_to_del eq 'new' ) {
		$update_msg = "You can't delete a macro without choosing one first";
	} else {
		
		# ok, they chose a macro, now lets delete it
		my ($rv, $sth) = $S->db_delete({
			DEBUG	=> $DEBUG,
			FROM	=> 'macros',
			WHERE	=> qq| name = '$macro_to_del' |,
			});

		if( $rv ) {
			$update_msg = qq|<FONT color="green">$macro_to_del deleted.</FONT><BR>\n Note: the macro you just deleted will still be in the list, due to caching.  It will not be there the next time you reload this page, however. |;
		} else {
			$update_msg = qq|Error deleteing macro '$macro_to_del'|;
		}
	}

	return $update_msg;
}


# just updates whats changed in the macro db
sub _save_macro_changes {
	my $S = shift;
	my $macro_array = shift;
	my $mode = shift;
	my $item = shift;
	
	my $update_msg;
	my $error = 0;
	my @updated;
	my $changed;
	my ($rv, $sth);

	# if its a save from the main full macro editor, treat it special
	if( $mode eq 'Add New' || $mode eq 'edit' ) {
	
		my $macro			= $S->{CGI}->param('macro');
		my $value		= $S->{CGI}->param('value');
		my $description	= $S->{CGI}->param('description');
		my $category	= $S->{CGI}->param('category');
		my $parameter	= $S->{CGI}->param('parameter');
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
			return "You need to specify a name to create a new macro";
		}
		
		$description	= $S->{DBH}->quote($description);
		$value		= $S->{DBH}->quote($value);
		$category	= $S->{DBH}->quote($category);
		$parameter	= $S->{DBH}->quote($parameter);
	
	    if ($macro eq 'new') {
			#warn "adding new macro";
			($rv, $sth) = $S->db_insert({
			    DEBUG => 0,
			    INTO => 'macros',
			    COLS => 'name, value, description, category, parameter',
			    VALUES => qq|"$name", $value, $description, $category, $parameter|});
			
			unless( $rv ) {
				$update_msg = "Error creating macro '$name'";
				$error = 1;
			} else {
				push( @updated, $name );
				$changed = 1;
			}
			
			$sth->finish;

	    } elsif( $macro eq $name ) {
			warn "Writing macro record" if $DEBUG;
			($rv, $sth) = $S->db_update({
			    DEBUG => 0,
			    WHAT => 'macros', 
			    SET => qq|value = $value, description = $description, category = $category, parameter = $parameter|,
			    WHERE => qq|name = "$macro"|});
			
			unless( $rv ) {
				$update_msg = "Error updating macro '$name'";
				$error = 1;
			} else {
				push( @updated, $name );
				$changed = 1;
			}
			
			$sth->finish;
			
	    } else {
			$update_msg = "Could not update: '$macro' does not match '$name'";
			$error = 1;
	    }
	
	} else {
		# this is a save from one of the categories, so make sure to update all

		# now for each macro in the form, if it was changed, update it, otherwise
		# ignore it
		for my $macro ( @$macro_array ) {

			# don't try to update if it wasn't in the form
			next unless $S->{CGI}->param( 'inform_' . $macro->{name} );
			warn "trying to update $macro->{name}" if $DEBUG;
			
			my $formval = $S->{CGI}->param($macro->{name});

			# skip it unles they changed it
			next if ( $macro->{value} eq $formval );	
			warn "in $macro->{name}, '$macro->{value}' is not '$formval'" if $DEBUG;
		
			# error checking, so they can't set nums to 'a' for instance, and bools to e, text
			# let them put in what they want
		
			# quote input
			my $quoteval = $S->{DBH}->quote( $formval );
		
			# now update the db
			warn "Updating '$macro->{name}' to $quoteval" if $DEBUG;
			($rv, $sth) = $S->db_update({
					DEBUG	=> $DEBUG,
					WHAT	=> 'macros',
					SET		=> qq| value = $quoteval |,
					WHERE	=> qq| name = '$macro->{name}'|,
				});
			
			if( $rv ) {
				push( @updated, $macro->{name} );
				$changed = 1;
				next;
			}
		
			#if it gets here it didn't update right, return an error
			warn "Error updating $macro->{name} to '$macro->{value}'" if $DEBUG;
			$update_msg = "Error updating $macro->{name} to '$macro->{value}'";		
			last;
		}
	} #end really big if statement
	
	# if there was an error, return and say the error
	return $update_msg if $error;
	
	# make a neat list to display what was updated
	my $macrolist = join ', ', @updated;
	$macrolist =~ s/(, )$//;
	
	# Update the cache if something changed
	# Don't want to refresh UI, as that may 
	# Put us in a conflicting state. It'll happen next request.
	if ($changed) {
		$S->cache->clear({resource => 'macros', element => 'MACROS'});
		$S->cache->stamp_cache('macros', time());
		$S->_set_macros();
		$S->_set_blocks();
	}

	my $notemsg = qq| Note: If you added a new macro or category just now, it will not show yet,
				due to caching.  It will show the next time you reload this page, however. |;

	if ( $mode ne 'Add New' and $macrolist ne '' ) {
		$update_msg = qq|<FONT color="green">Successfully updated macros: $macrolist.</FONT><BR>|;
	} elsif( $mode eq 'Add New' ) {
		$update_msg = qq|<FONT color="green">Successfully updated macro: $macrolist.</FONT><BR>\n$notemsg|;
	}
	
	if( scalar( @updated ) >= 0 ) {
		return $update_msg;
	} else {
		return "No macros have changed! No update performed";
	}
}

# This makes the category link chooser at the top of the edit vars form
sub _make_macro_cat_chooser {
	my $S = shift;
	my $macro_array = shift;
	my $content = "";
	my $catrow;

	# lets see what categories we got, eh?
	my $cat_hash = {};
	for my $macro ( @$macro_array ) {

		# if it belongs to more than 1 category split and record both
		if( $macro->{category} =~ m|,| ) {

			# spit on ',' and record each in a hash
			my @cat_list = split ',', $macro->{category};
			for (@cat_list) {
				next if $cat_hash->{$_} == 1;
				$cat_hash->{$_} = 1;
			}
		} else {
			# ok, so its only 1 category, record it if it hasn't been already
			next if $cat_hash->{ $macro->{category} } == 1;
			$cat_hash->{ $macro->{category} } = 1;
		}
	}

	# now to display all of those categories nice and neat
	# put 'All' and 'Add New' on the first row, alone, for readability
	$catrow = $S->{UI}->{BLOCKS}->{macro_category_list};
	$catrow =~ s/%%item_url%%/multi\/All/;
	$catrow =~ s/%%item%%/All/;
	unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
		$content .= $catrow;
		$catrow = $S->{UI}->{BLOCKS}->{macro_category_list};
	}
	$catrow =~ s/%%item_url%%/Add%20New/;
	$catrow =~ s/%%item%%/Add New/;
	while ( $catrow =~ /%%item%%/ ){
		$catrow =~ s/%%item_url%%//;
		$catrow =~ s/%%item%%//;
	}
	$content .= $catrow;
	$catrow = $S->{UI}->{BLOCKS}->{macro_category_list};

	# get all the rest of the categories
	my $count = 0;
	my @cat_array = @{ $S->_get_cat_array( $macro_array ) };
	while( @cat_array > 0 ) {

		my $cat = shift @cat_array;
		my $urlcat = $S->urlify("$cat");
		unless ( $catrow =~ /%%item%%/ ){ # if the row is finished, get a new row to fill in
			$content .= $catrow;
			$catrow = $S->{UI}->{BLOCKS}->{macro_category_list};
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

1;
