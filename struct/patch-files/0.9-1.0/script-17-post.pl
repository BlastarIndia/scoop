#!/usr/bin/perl
# Post-patch script for the OP Templates Patch

use strict;
use Getopt::Std;
use DBI;

my $args = &get_args();
my $db_user = $args->{u};
my $db_pass = $args->{p};
my $db_port = $args->{o};
my $db_name = $args->{d};
my $db_host = $args->{h};
my $QUIET = $args->{q} || 0;

my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass);

$|++;

print "Loading OPs (from OPs Table)..." unless $QUIET;
my $ops = &load_ops($dbh);
print "done\n" unless $QUIET;

print "Checking to see if conversion already done..." unless $QUIET;
# admin is an op that will definitely have urltemplates defined if the patch
# has already been run
if ($ops->{admin}->{urltemplates} ne '') {
	print "found. Skipping patch.\n" unless $QUIET;
	$dbh->disconnect;
	exit;
}
print "not found.\n" unless $QUIET;

print "Loading OP_Templates (from Site Controls)..." unless $QUIET;
my $op_templates = &load_var($dbh, 'op_templates');
print "done\n" unless $QUIET;

print "Loading OP Aliases (from Site Controls)..." unless $QUIET;
my $op_aliases = &load_var($dbh, 'op_aliases');
print "done\n" unless $QUIET;

print "Reformatting OP Templates..." unless $QUIET;
my $op_templates_new = &reformat_templates($op_templates);
print "done\n" unless $QUIET;

print "Reformatting OP Aliases..." unless $QUIET;
my $op_aliases_new = &reformat_aliases($op_aliases);
print "done\n" unless $QUIET;

# the 'print' OP template is in all default installs, but the 'print' OP is not
delete $op_templates_new->{print} unless $ops->{print};

print "Validating Data Consistency..." unless $QUIET;
my $validity = &validate_data($ops,$op_aliases_new,$op_templates_new);
if($validity){	# If we have errors, stop here
	print "\nPlease fix the above $validity errors then re-run this patch.\n";
	$dbh->disconnect;
	exit(1);	# Send error code
} else { print "done\n" unless $QUIET; }

print "Merging Into OPs Table..." unless $QUIET;
my $ops_updates = &update_ops($dbh, $ops, $op_aliases_new, $op_templates_new);
print "done ($ops_updates OPs updated)\n" unless $QUIET;

print "All done.\n" unless $QUIET;
#-------------------------------------------

sub validate_data {
	my $ops=shift; my $aliases=shift; my $templates=shift; my $errors=0;
	for(keys %$aliases){
		unless($ops->{$_}){
			print "\nAlias without OP: ($_ => $aliases->{$_})";
			$errors++;
		}
	}
	for(keys %$templates){
		unless($ops->{$_}){
			print "\nTemplate without OP: ($_ => $templates->{$_})";
			$errors++;
		}
	}
	return $errors;
}

sub reformat_aliases{
	my $aliases = shift;
	my $return;	# Hashref placeholder
	for(split(/\s*,\s*\n*/,$aliases)){
		s/\s+//g;	# Remove any remaining spaces
		my($alias,$op)=split(/\s*=\s*/);
		$return->{$op}.=($return->{$op})?' '.$alias:$alias;
	}
	return $return;
}

sub reformat_templates{
	my $input=shift;
	my $return;
	for(split(/\s*,\s*\n*/,$input)){
		my $op;	# Placeholder used later
		my($prefix,$template)=split(/\s*=\s*/,$_,2);
		if($prefix=~s/^([^\.]+)\.//){
			$op=$1;	#Keep this for later
			if($prefix=~m/^length$/i){$template="length=$template";}
			elsif($prefix=~m/^\d+$/){$template="element.$prefix=$template";}
		} else { $op = $prefix; }
		$return->{$op}.=($return->{$op})?",\n".$template:$template;
	}
	return $return;
}

sub load_var {
	my ($dbh, $var) = @_;
	my $query = "SELECT value FROM vars WHERE name = " . $dbh->quote($var);
	my $sth = $dbh->prepare($query); $sth->execute;
	my ($contents) = $sth->fetchrow_array;
	$sth->finish; return $contents;
}

sub load_ops {
	my ($dbh)=shift; my $return;
	my $sth = $dbh->prepare("SELECT * FROM ops"); $sth->execute;
	while (my $op=$sth->fetchrow_hashref()) {$return->{$op->{op}}=$op;}
	$sth->finish; return $return;
}

sub update_ops {
	my ($dbh, $ops, $aliases, $templates) = @_;
	my $query = "UPDATE ops SET aliases = ?, urltemplates = ? WHERE op = ?";
	my $sth = $dbh->prepare($query);
	my $counter=0;	# I hate Counters!
	for(keys %$ops){
		my $rv=$sth->execute(
			$aliases->{$_},
			$templates->{$_},
			$_
		);
		$counter+=$rv unless $rv eq '0E0';
	}
	$sth->finish;
	return $counter;
}


sub get_args {
    my %info;
    my @neededargs;

    getopts("u:p:d:h:o:vqD", \%info);

    # now first generate an array of hashrefs that tell us what we
    # still need to get
    foreach my $arg ( qw( u p d h o ) ) {
        next if ( $info{$arg} and $info{$arg} ne '' );

        if( $arg eq 'u' ) {
            push( @neededargs, {arg     => 'u',
                                q       => 'db username? ',
                                default => 'nobody'} );
        } elsif( $arg eq 'p' ) {
            push( @neededargs, {arg     => 'p',
                                q       => 'db password? ',
                                default => 'password'} );
        } elsif( $arg eq 'd' ) {
            push( @neededargs, {arg     => 'd',
                                q       => 'db name? ',
                                default => 'scoop'} );
        } elsif( $arg eq 'h' ) {
            push( @neededargs, {arg     => 'h',
                                q       => 'db hostname? ',
                                default => 'localhost'} );
        } elsif( $arg eq 'o' ) {
            push( @neededargs, {arg     => 'o',
                                q       => 'db port? ',
                                default => '3306'} );
        }
    }

    foreach my $h ( @neededargs ) {
        my $answer = '';
        print "$h->{q}"."[$h->{default}] ";
        chomp( $answer = <STDIN> );
        $answer = $h->{default} unless( $answer && $answer ne '' );
        $info{ $h->{arg} } = $answer;
    }
    return \%info;
}

