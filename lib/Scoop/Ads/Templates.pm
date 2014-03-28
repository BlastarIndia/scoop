=head1 Ads/Templates.pm

This contains the functions for getting information about the ad templates.
All functions for editing ad templates are in Admin/Ads.pm.

=head1 AUTHOR

Andrew Hurst <andrew@hurstdog.org>

=head1 FUNCTIONS

=over 4

=cut

package Scoop;

use strict;

my $DEBUG = 0;


=item *
is_valid_ad_tmpl($tmpl)

Takes a template and returns 1 if the template exists, and 0 if the template
doesn't exist

=cut

sub is_valid_ad_tmpl {
	my $S = shift;	
	my $tmpl = shift;

	if( defined($tmpl) && exists( $S->{UI}->{BLOCKS}->{$tmpl} ) ) {
		return 1;
	} else {
		return 0;
	}
}


=item *
get_ad_reqd_fields($ad_tmpl)

This returns hashref of the required fields for the given ad type.
The keys are the field name, the values are 1.

=cut

sub get_ad_reqd_fields {
	my $S = shift;
	my $tmpl_name = shift;
	my $tmpl = $S->{UI}->{BLOCKS}->{$tmpl_name};
	my %reqd = ();

	return {} unless defined $tmpl;

	# now just an ugly chunk of if()s to determine which are required
	# and a little trick with local to save typing
	# yes, this local isn't required, but its safer
	{
		local $_;
		$_ = $tmpl;
		$reqd{ad_text1}	= 1 if( /%%TEXT1%%/		);
		$reqd{ad_text2}	= 1 if( /%%TEXT2%%/		);
		$reqd{ad_url}	= 1 if( /%%LINK_URL%%/	);
		$reqd{ad_title}	= 1 if( /%%TITLE%%/		);
		$reqd{ad_file}	= 1 if( /%%FILE_PATH%%/ );
	}
	return \%reqd;
}


=item *
get_ad_tmpl_info($tmpl)

Given an ad template name (i.e. a block with _ad_template as the
last part of its name) it will return a hashref of all of the
information the database has on this template from the ad_types
table.  Basically a 'select * from ad_types where type_template=$tmpl'

=cut

sub get_ad_tmpl_info {
	my $S = shift;
	my $tmpl = shift;
	my $ad_hash = {};

	# didn't just save, must be a GET, get from db.
	$tmpl = $S->{DBH}->quote($tmpl);

	my($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'ad_types',
		WHAT	=> '*',
		WHERE	=> qq| type_template = $tmpl |,
	});

	if( $rv ) {
		$ad_hash = $sth->fetchrow_hashref();
	}

	if( defined $ad_hash ) {
		return $ad_hash;
	} else {
		return {};
	}
}


=item *
get_example_ad($tmpl)

Given an ad template name this returns the example ad for that template

=cut

sub get_example_ad {
	my $S = shift;
	my $tmpl = shift;
	my $ex_hash = {};

	$tmpl = $S->{DBH}->quote($tmpl);

	my($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'ad_info',
		WHAT	=> '*',
		WHERE	=> qq| ad_tmpl = $tmpl and example = 1 |,
	});

	if( $rv ) {
		$ex_hash = $sth->fetchrow_hashref();
	}

	return $ex_hash;
}


=item *
get_ad_tmpl_list()

Returns a listref of all of the ad templates, i.e. all of the 
possible ad types for a user to submit. (note, just the names,
not any other info about them).  Doesn't return any ad templates
that start with preview_, since those shouldn't be used for
examples, and submitting anyway.  They are just previews of normal
templates. 

=cut

sub get_ad_tmpl_list {
	my $S = shift;
	my @list = ();

	# get a list of all ad templates, from the blocks table
	my ($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'bid',
		FROM	=> 'blocks',
		WHERE	=> q{ bid like '%\_ad_template' },
		});

	if( $rv ) {
		while( my $bid = $sth->fetchrow_hashref() ) {
			# don't return preview templates, no need for what this is used for.
			next if( $bid->{bid} =~ /^preview_/ );
			push @list, $bid->{bid};
		}
	}

	$sth->finish();
	return \@list;
}


=item *
get_ad_tmpl_examples

For use when making the ad template listing.  Returns
a hashref of the example ad templates.  The key is the template
name, the value is an array ref, with 2 indexes.  
Index 0 is the number of ads that use this template.
Index 1 is the number of the example.

=cut

sub get_ad_tmpl_examples {
	my $S = shift;
	my %t_hash = ();

	# first get the list of templates and their count
	my ($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'ad_info',
		WHAT	=> 'count(ad_id) as c, ad_tmpl',
		GROUP_BY	=> 'ad_tmpl',
		});

	if( $rv ) {
		while( my $t = $sth->fetchrow_hashref ) {
			warn "pushing $t->{c} onto key $t->{ad_tmpl} in get_ad_tmpl_examples" if $DEBUG;
			push( @{$t_hash{ $t->{ad_tmpl} }}, $t->{c} );
		}
	} else {
		return \%t_hash;
	}
	$sth->finish();

	# now that we have the template names, we need the example
	# ad numbers.
	($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'ad_info',
		WHAT	=> 'ad_id, ad_tmpl',
		WHERE	=> 'example = 1',
		});

	if( $rv ) {
		while( my $t = $sth->fetchrow_hashref ) {
			warn "pushing $t->{ad_id} onto key $t->{ad_tmpl} in get_ad_tmpl_examples" if $DEBUG;
			push( @{$t_hash{ $t->{ad_tmpl} }}, $t->{ad_id} );
		}
	}

	return \%t_hash;
}


=item *
get_most_used_adtmpl()

Returns the ad template what is used by the most ads.

=cut

sub get_most_used_adtmpl {
	my $S = shift;
	my $tmpl = '';

	my ($rv,$sth) = $S->db_select({
		WHAT		=> 'ad_tmpl,count(ad_tmpl) as c',
		FROM		=> 'ad_info',
		GROUP_BY	=> 'ad_tmpl',
		ORDER_BY	=> 'c desc',
		LIMIT		=> 1,
		});

	if( $rv ) {
		my $ret = $sth->fetchrow_hashref();
		$tmpl = $ret->{ad_tmpl} if( defined($ret) );
	}

	return $tmpl;
}

=back

=cut

1;
