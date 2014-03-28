package Scoop;
use strict;

my $DEBUG = 0;

sub get_themed_blocks {
	my $S = shift;
	my %themed_blocks;

	# get themes in order from base (must be a full set of blocks) to specific
	my @themelist = split ( /,\s*/, $S->{THEME} );
	foreach my $theme ( @themelist ) {
		my %theme = $S->get_blocks("$theme");
		%themed_blocks = (%themed_blocks, %theme);
	}

	return %themed_blocks;
}

sub get_blocks {
	my $S = shift;
	my $theme = shift;
	my $time = time();
	my $blocks;
	
	warn "fetching theme $theme" if $DEBUG;
	if ( my $cached = $S->cache->fetch("blocks_$theme") ) {
		return %{$cached};
	}

	warn "Last update was $S->cache->{LAST_UPDATE}->{blocks_$theme}.\nI think it was $S->cache->{DATA}->{'blocks_$theme'}.\nBlocks cache not valid! Doing select\n" if $DEBUG;

	my ($rv, $sth) = $S->db_select({
		WHAT => 'bid, block',
		FROM => 'blocks',
		WHERE => qq|theme='$theme'|,
		DEBUG => $DEBUG});
	while (my $block_record = $sth->fetchrow_hashref()) {
		$blocks->{"$block_record->{bid}"} = $block_record->{block};
#		if ( $S->{UI}->{VARS}->{block_delimiter_comments} ) {
#			# this really messes up the colours and any block that is 
#			# inside an HTML tag, but works everywhere else.
#			# how to make it work with attributes??? 
#			my $comment_start = qq|<!-- begin block $block_record->{bid} -->|;
#			my $comment_end = qq|<!-- end block $block_record->{bid} -->|;
#			$blocks->{$block_record->{bid}} =~ s/^(.)/$comment_start$1/;
#			$blocks->{$block_record->{bid}} =~ s/(.)$/$1$comment_end/;
#		}
	}
	$sth->finish();
	if ( $blocks ) {
		# Set the global cache
		$S->cache->store("blocks_$theme", $blocks);

		# Return value, not reference so that our changes won't infect the global cache
		return %{$blocks};
	} else {
		return;
	}
}

sub get_vars {
	my $S = shift;
	my $time = time();
	
	if (my $cached = $S->cache->fetch_data({resource => 'vars', 
	                                        element => 'VARS'})) {
		return %{$cached};
	}

	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'vars'});
	
	my $vars;
	if ($rv) {
		while (my $var_record = $sth->fetchrow_hashref) {
			$vars->{$var_record->{name}} = $var_record->{value};
		}
	}
	$sth->finish();

	$S->cache->cache_data({resource => 'vars', 
	                       element => 'VARS', 
	                       data => $vars});
	
	# Return value, not reference so that our changes won't infect the global cache
	return %{$vars};
}

sub get_macros {
# cloned from get_vars above.

	my $S = shift;
	my $time = time();
	
	if (my $cached = $S->cache->fetch_data({resource => 'macros', 
	                                        element => 'MACROS'})) {
		return %{$cached};
	}

	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'macros'});
	
	my $macros;
	if ($rv) {
		while (my $macro_record = $sth->fetchrow_hashref) {
			$macros->{$macro_record->{name}}->{value} = $macro_record->{value};
			$macros->{$macro_record->{name}}->{parameter} = $macro_record->{parameter};
		}
	}
	$sth->finish();

	$S->cache->cache_data({resource => 'macros', 
	                       element => 'MACROS', 
	                       data => $macros});
	
	# Return value, not reference so that our changes won't infect the global cache
	return %{$macros};
}

sub refresh_ui {
	my $S = shift;
	my $UI = {};
	delete $S->{UI};
	#warn '-> Refreshing UI cache...';
	
	my %blocks = $S->get_blocks();
	my %vars = $S->get_vars();
	
	$UI->{BLOCKS} = \%blocks;
	$UI->{VARS} = \%vars;
	
	$S->{UI} = $UI;
	return $UI;
}

# Zones copied out of Time::Timezone
sub _timezone_hash {
	my $S = shift;
	my %zones = (
		"adt" 	=>	"Atlantic Daylight",
		"edt" 	=>	"Eastern Daylight",
		"cdt" 	=>	"Central Daylight",
		"mdt" 	=>	"Mountain Daylight",
		"pdt" 	=>	"Pacific Daylight",
		"ydt" 	=>	"Yukon Daylight",
		"hdt" 	=>	"Hawaii Daylight",
		"bst" 	=>	"British Summer",
		"mest"	=>	"Middle European Summer",
		"sst" 	=>	"Swedish Summer",
		"fst" 	=>	"French Summer",
		"wadt"	=>	"West Australian Daylight",
		"eadt"	=>	"Eastern Australian Daylight",
		"nzdt"	=>	"New Zealand Daylight",
		"gmt"	=>	"Greenwich Mean",
		"utc"	=>	"Universal (Coordinated)",
		"wet"	=>	"Western European",
		"wat"	=>	"West Africa",
		"at" 	=>	"Azores",
		"ast" 	=>	"Atlantic Standard",
		"est" 	=>	"Eastern Standard",
		"cst" 	=>	"Central Standard",
		"mst" 	=>	"Mountain Standard",
		"pst" 	=>	"Pacific Standard",
		"yst"	=>	"Yukon Standard",
		"hst"	=>	"Hawaii Standard",
		"cat"	=>	"Central Alaska",
		"ahst"	=>	"Alaska-Hawaii Standard",
		"nt"	=>	"Nome",
		"idlw"	=>	"International Date Line West",
		"cet"	=>	"Central European",
		"met"	=>	"Middle European",
		"mewt"	=>	"Middle European Winter",
		"swt"	=>	"Swedish Winter",
		"fwt"	=>	"French Winter",
		"eet"	=>	"Eastern Europe, USSR Zone 1",
		"bt"	=>	"Baghdad, USSR Zone 2",
		"zp4"	=>	"USSR Zone 3",
		"zp5"	=>	"USSR Zone 4",
		"zp6"	=>	"USSR Zone 5",
		"wast"	=>	"West Australian Standard",
		"cct"	=>	"China Coast, USSR Zone 7",
		"jst"	=>	"Japan Standard, USSR Zone 8",
		"east"	=>	"Eastern Australian Standard",
		"gst"	=>	"Guam Standard, USSR Zone 9",
		"nzt"	=>	"New Zealand",
		"nzst"	=>	"New Zealand Standard",
		"idle"	=>	"International Date Line East");
	return %zones;
}


1;
	
