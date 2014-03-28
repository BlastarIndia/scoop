#!/usr/bin/perl -w

=head1 NAME 

cvs-log.pl

=head1 SYNOPSIS

Put in cgi-bin of your webserver and chmod +x it.

=head1 DESCRIPTION

This script sites on a webserver and waits for input from the logtoweb.pl
script (or any script) that should be in the CVSROOT of your cvs repository.
The POST this accepts takes 3 parameters, files, data, and user.  

cvs-log then writes this info into an html file for all to view.  It writes
it right after a <!-- __TOP__ --> marker.

=head1 SEE-ALSO

logtoweb.pl, This is the script I wrote to input the cvs info to this
script

=head1 AUTHOR

Andrew Hurst, April 7, 2001

=cut

use strict;
use CGI qw( :standard );

my $cvsinfo = '/www/scoop/html/cvsinfo.html';

my $files = param('files');
my $data = param('data');
my $user = param('user');
my $password = param('password');
my $remote_host = remote_host();

# this might change... :/
exit unless ( $remote_host eq '216.136.171.252' ||
			 $remote_host eq '63.195.145.16');

my $newentry = &create_new_entry;

open( CVSINFO, "<$cvsinfo" ) or die "Couldn't open $cvsinfo for reading: $!";
my @outfile = <CVSINFO>;
close( CVSINFO );

my $outfile = join '', @outfile;
$outfile =~ s|<!-- __TOP__ -->|<!-- __TOP__ -->\n$newentry\n|g;

open( O_CVSINFO, ">$cvsinfo" ) or die "Couldn't open $cvsinfo for writing: $!";
print O_CVSINFO $outfile;
close( O_CVSINFO );

print "Content-type: text/html\n\n";
print "cvs web submission successful!\n";

exit;

sub create_new_entry {
	my $entry;
	my @entry = <DATA>;
	$entry = join '', @entry;

	$entry =~ s/__FILE__/$files/g;

	my $date = localtime();
	$entry =~ s/__DATE__/$date/g;

	$entry =~ s/__COMMENT__/$data/g;

	$entry =~ s/__USER__/$user/g;

	return $entry;
}

__DATA__

Files: __FILE__, : __DATE__<BR>
Committed by: __USER__<BR>
<BR>

<pre>
__COMMENT__
</pre>
<BR>
<hr noshade><BR>

