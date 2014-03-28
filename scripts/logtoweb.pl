#!/usr/bin/perl -w

=head1 NAME

logtweb.pl

=head1 SYNOPSIS

./logtoweb.pl <filelist> <url_to_POST_to>

=head1 DESCRIPTION

This is just a small script that takes the files changed on
the command line, and the commit message on stdin, then POST's
the result to a web form.

NOTE: There is not error checking built-in yet.  So make sure you
call it right ;)  I will add in error checking later

Much of the algorithm for doing this taken from synmcmail,
a python program for emailing on all cvs updates, available
here:
http://cvs.sourceforge.net/cgi-bin/cvsweb.cgi/CVSROOT/syncmail?cvsroot=mailman

=head1 SEE-ALSO

cvs-log.pl, This is the script I wrote to take the output of this this
script and post into a web page

=head1 AUTHOR

Andrew Hurst, April 7, 2001

=cut

use LWP::UserAgent;
use strict;

# first figure out who we are
my $username = $ENV{USER};
my $password = 'TmToWtDi';  # to keep people from spamming the web form

# now get the updated file list and the url to POST to
my ($files, $url) = &parse_args;

exit 0 if $files =~ /VERSION/g;

# get the data
my @data = <STDIN>;
my $data = join '' , @data;

$data = clean_data($data);

# now we need to send this off to the script
# note: the following is directly from perldoc LWP
my $ua = new LWP::UserAgent;
$ua->agent("logtoweb.pl/0.1" . $ua->agent);

# Create a new request
my $req = new HTTP::Request POST => $url;
$req->content_type('application/x-www-form-urlencoded');
$req->content("files=$files;data=$data;user=$username");

#  Pass request to the user agent and get a response back
my $res = $ua->request($req);

# Check the outcome of the response
if ($res->is_success) {
	print $res->content;
} else {
	print "Bad luck this time\n";
}

exit;

# clean out the data so it doesn't get all wonky
# in the url
sub clean_data {
	my $data = shift;	

	# so that these don't mess with the url
	$data =~ s/&/%26/g;
	$data =~ s/=/%3D/g;
	$data =~ s/;/%3B/g;
	$data =~ s/@/%40/g;

	return $data;
}


sub parse_args {
	my ($files, $url);

	$files = $ARGV[0];
	$url = $ARGV[1];

	$files =~ s/,$//;
	$files =~ s/^scoop //;

	return ($files, $url);
}



