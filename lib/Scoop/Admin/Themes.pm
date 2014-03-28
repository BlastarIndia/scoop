=head1 Themes.pm

This is some extra administrative stuff to make dealing with themes 
easier.

One public function, manage_themes, generates the whole screen.

=cut

package Scoop;
use strict;

my $DEBUG = 0;

sub manage_themes {
	my $S = shift;
	my $content;
	my $list;
	my $delete = $S->{CGI}->param('delete');

	# get master list of block ids
	my @master_list;
	my ($rv,$sth) = $S->db_select({
			DEBUG	=> $DEBUG,
			DISTINCT => 1,
			WHAT	=> 'bid',
			FROM	=> 'blocks',
			ORDER_BY => 'bid ASC' });
	unless( $rv ) {
		warn "Error accessing blocks db";
		return qq| Error accessing blocks db. |;
	}
	push @master_list, "theme_name";	
		# gets the theme name at the top of the list for later display
	while ( my $bid = $sth->fetchrow_hashref() ) {
		push @master_list, $bid->{bid};
	}

	my @themeblocks;

	# get list of themes
	my ($rv_th,$sth_th) = $S->db_select({
			DEBUG => $DEBUG,
			DISTINCT => 1,
			WHAT => "theme",
			FROM => "blocks",
			ORDER_BY => 'theme ASC' });

	unless( $rv_th ) {
		warn "Error accessing blocks db";
		return qq| Error accessing blocks db. |;
	}
	my $themesel = "<P>\n";
	my $n = -1;
	while ( my $t = $sth_th->fetchrow_hashref() ) {
		$n++;
		my $selected;
		my $th = $t->{theme};
		if ( $S->{CGI}->param("theme_$th") ) {
			$selected = qq{ checked="checked"};
			# get all blocks for this theme, since it was requested
			my ($rv2, $sth2) = $S->db_select({DEBUG	=> $DEBUG,
						FROM	=> 'blocks',
						WHAT	=> 'bid',
						WHERE	=> qq{theme='$th'},
						ORDER_BY => 'bid ASC' });
	
			unless( $rv2 ) {
				warn "Error accessing blocks db";
				return qq| Error accessing blocks db. |;
			}
			my $block_list;
			$block_list->{"theme_name"} = $th;
			while ( my $b = $sth2->fetchrow_hashref() ) {
				$block_list->{"$b->{bid}"} = 1;
			}
			push @themeblocks, $block_list;
		}
		$themesel .= qq{ <INPUT type="checkbox" name="theme_$th"$selected>$th<BR>\n };
		warn "list all themes: theme is $th\n" if $DEBUG;
	} 
	$themesel .= qq{</P>\n\n};

	my $num_sel = @themeblocks;
	foreach my $bid (@master_list) {
		$list .= "<TR>";
		for ( $n = 0; $n < $num_sel; $n++ ) {
			my $exists = $themeblocks[$n]{$bid};
			if ( $bid eq "theme_name" ) { 
				$list .= qq|<TH>$exists</TH>|; 
			} elsif ( $exists ) { 
				my $th = $themeblocks[$n]{"theme_name"};
				$list .= qq|<TD><A href="%%rootdir%%/admin/blocks/edit/$th/$bid">$bid</A></TD>|; 
			} else {
				$list .= qq|<TD>&nbsp;</TD>|;
			}
		}
		$list .= "</TR>\n";
	}

	# get the form header and title
	$content .= $S->{UI}->{BLOCKS}->{theme_list}; 

	
	# substitute into the html from the block
	$content =~ s/%%themesel%%/$themesel/;
	$content =~ s/%%list%%/$list/;
	
	return $content;
}



1;
