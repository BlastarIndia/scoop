#!/usr/bin/perl

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
my ($query, $sth);

print "Grabbing op_templates..." unless $QUIET;
$query = "SELECT block FROM blocks WHERE bid = 'op_templates'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($block) = $sth->fetchrow_array;
$sth->finish;
print "done\n" unless $QUIET;

print "Checking to see if user-dir patch already appplied..." unless $QUIET;
if ($block =~ /m\/\^~\(\.\+\)\$\//) {
	print "yes\n" unless $QUIET;
} else {
	print "no\n\tApplying patch..." unless $QUIET;
	my $replace = join("\n",
		q|  } elsif ($S->cgi->param('caller_op') =~ m/^~(.+)$/) {|,
		q|    unshift @path\\, $1;|
	);
	$block =~ s/(unshift \@path\\, \$S->\{NICK\};)/$1\n$replace/;
	print "done\n" unless $QUIET;
}

print "Checking to see if adinfo patch already applied..." unless $QUIET;
if ($block =~ /\$p->\{op\}\s*=\s*["']adinfo["']/) {
	print "yes\n" unless $QUIET;
} else {
	print "no\n\tApplying patch..." unless $QUIET;
	my $replace = join("\n",
		q|  } elsif ($path[1] eq 'ads') {|,
		q|    $p->{op}      = 'adinfo';|  ,
		q|    $p->{ad_id}   = "uid:$uid";|
	);
	$block =~ s/(\$p->\{string\}\s*=\s*\$path\[0\];)/$1\n$replace/;
	print "done\n" unless $QUIET;
}

print "Putting updated block back in..." unless $QUIET;
$query = q|UPDATE blocks SET block = ? WHERE bid = 'op_templates'|;
$sth = $dbh->prepare($query);
$sth->execute($block);
$sth->finish;
print "done\n" unless $QUIET;

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
