#!/usr/bin/perl -w

=head1 upgrade-db.pl

When you run this script it will apply all needed patches from the 
scoop/struct/patch-files/current directory.  When you first run it, 
you may see a few warnings about patches that have already been
applied, or about conflicts in the database, this is normal, and ok.

After you have run this once, every other time you run it it will
only apply the patches that need to be applied.

=head1 USAGE

cd into the base directory of your scoop install.  Then run the script as

B<upgrade-db.pl> 
S<[-u dbuser]>
S<[-p dbpass]>
S<[-d dbname]>
S<[-h dbhost]>
S<[-o dbport]>
S<[-P patch dir]>
S<[-v]>
S<[-q]>
S<[-D]>

If you don't include any of the db args, it will prompt you for them.
-v turns on verbosity, so it will tell you what its doing, while -q will tell
it to be quiet, and -D turns on debugging.

=cut

use Getopt::Std;
use Cwd;
use DBI;

use strict;

use vars qw($SCOOPDIR);

my $DEBUG = 0;
my $DEBUG_DB = 0;

my $VERBOSE = 0;
my $QUIET = 0;

my $latestScoop = '0_7';
my $S_VERSION;
my $SCOOPDIR;
my $PATCHDIR;
my $current_patch = -1;
my $dbh;
my $applied_patches = 0;

#print "ACK!  I'm in development.  Don't use me yet.  You'll get an email when you can. otherwise, we take absolutely no repsonsibility for messed up db's.  well. we don't anyway.. but you know what I mean ;-)\n";
#exit 1;

if ($ARGV[0] && ($ARGV[0] =~ /^--?h/)) {
	&usage;
	exit 0;
}

my $args = &get_args();
my $msgs = &messages();

$VERBOSE = 1 if $args->{v};
$QUIET   = 1 if $args->{q};
$DEBUG   = 1 if $args->{D};

=head1 HOW

1) find the scoop rootdir
2) figure out the scoop version and directory to scan for patches

=cut


print $msgs->{intro} unless $QUIET;

&set_rootdir;
&set_patchdir;

print "
Version -> $S_VERSION
rootdir -> $SCOOPDIR
patchdir -> $PATCHDIR
QUIET = $QUIET ; VERBOSE = $VERBOSE
dbinfo{q} = $args->{q} ; dbinfo{v} = $args->{v}\n\n" if $DEBUG;

=pod

3) figure out what was the last patch applied for this version
4) set $patchnum == last applied + 1

=cut

&db_connect;
&get_patchinfo;

=pod

5) get and apply latest patches
6) cleanup

=cut

if( $VERBOSE ) {
	print "I will now try to apply all of the patches I find.  If this is
your first time running this script, you will likely see lots of
errors, and an error above saying it couldn't find table patches.
That is OK, it will fix it up as it runs.
-- Continue --";
	<STDIN>;
	print "\n";
}

&apply_patches;
&cleanup;

exit 0;

sub set_rootdir {
	$SCOOPDIR = cwd();

	if (-e "$SCOOPDIR/VERSION") {
		return if $QUIET;
	} else {
		$SCOOPDIR =~ s|/\w+$||;
		return if (-e "$SCOOPDIR/VERSION") && $QUIET;
	}

	my $sd_response = '';
	while( ! -e "$sd_response/VERSION" ) {
		my $wherescoop = $msgs->{where_scoop_dir};
		$wherescoop =~ s/__SCOOPDIR__/$SCOOPDIR/g;
		print $wherescoop;
	
		chomp( $sd_response = <STDIN> );
		$sd_response = $SCOOPDIR unless ($sd_response =~ /\w/);
		print $msgs->{no_scoop_there} unless (-e "$sd_response/VERSION");
	}
	$SCOOPDIR = $sd_response;

}


sub set_patchdir {

	$PATCHDIR = $args->{P} || "$SCOOPDIR/struct/patch-files/current";

	unless (-d $PATCHDIR && $QUIET) {
		my $response = '';
		while( ! -d $response ) {
			my $wherepatches = $msgs->{check_patchdir};
			$wherepatches =~ s/__PATCHDIR__/$PATCHDIR/g;
			print $wherepatches;

			chomp( $response = <STDIN> );
			$response = $PATCHDIR unless ($response =~ /\w/);
			print $msgs->{no_patch_there} unless (-d $response);
		}

		$PATCHDIR = $response;
	}

	if( $VERBOSE ) {
		print "\nDetermining Scoop version...\n";
	}

	my $version = do "$PATCHDIR/VERSION" || die "Couldn't execute $PATCHDIR/VERSION as valid perl.  Make sure that it is up to date, and try again";
	$S_VERSION = $version;

	if( $VERBOSE ) { 
		print "Scoop version is set to $S_VERSION\n\n";
	}
}


# selects from the database the max patch num applied to see
# which is the last patch applied
sub get_patchinfo {

	my $parray = db_select("select patch_type,max(patch_num) as pnum from patches where scoop_ver = '$S_VERSION' group by patch_type order by pnum desc");

	# figure out if the last applied was sql or a script if there is
	# more than 1 for this patch_num
	my $p = {};
	$p->{pnum} = -10;
	if( scalar(@$parray) > 1 ) {
		foreach my $a ( @$parray ) {
			next if( $p->{pnum} > $a->{pnum} );

			if( $a->{patch_type} eq 'post' ) {
				$p = $a;
				last;
			} elsif( $a->{patch_type} eq 'pre' && $p->{patch_type} ne 'sql' ) {
				$p = $a;
			} else {
				$p = $a;
			}

		}
	} else {
		$p = $parray->[0];
	}

	# check if they don't have any applied yet
	if( scalar( @$parray ) == 0 ) {
		$current_patch = 0;
		return;
	}

	if( scalar(@$parray) && $VERBOSE ) {
		print 'It looks like your last applied patch was ';
		if( $p->{patch_type} eq 'sql' ) {
			print 'patch-'. $p->{pnum} ."\n";
		} else {
			print 'script-'. $p->{pnum} .'-'. $p->{patch_type} .".pl\n";
		}
	} elsif( $VERBOSE ) {
		print $msgs->{empty_patchtable};
	}

	$current_patch = $p->{pnum} + 1;

}


=pod

4) get all files in $PATCHDIR in a hash, with the key being
   filename, value being 1
  while(1)
  a. test for a script-$patchnum-pre.pl
	i. run it if it exists
	ii. record in db
  b. test for patch-$patchnum-(\w+).sql
	i. apply to db if exists
	ii. record in db
  c. test for script-$patchnum-post.pl
	i. run it if it exists
	ii. record in db
  d. if none of the above existed, last();
  e. otherwise, $patchnum++


=cut

sub apply_patches {

	my $patchfiles = &get_patchfiles;

	if( $current_patch == -1 ) {
		print $msgs->{none_to_apply} unless $QUIET;
		return;
	}

	my $foundpatch = 1;
	while( $foundpatch ) {

		$foundpatch = 0;

		# first, check for pre-script and run it
		$foundpatch = &run_script( 'pre', $current_patch, $patchfiles );

		my $found2 = &apply_patch( $current_patch, $patchfiles );
		$foundpatch = $foundpatch || $found2;

		my $found3 = &run_script( 'post', $current_patch, $patchfiles );
		$foundpatch = $foundpatch || $found3;

		# if patch 00 isn't found, we don't worry about it and go on
		if (($current_patch == 0) && !$foundpatch) {
			$foundpatch = 1;
		}

		$current_patch++;
	}

}


# returns a hash of the names of the patch files
sub get_patchfiles {
	my $patches = {};

	print "Getting all patchfiles in\n$PATCHDIR\n" if $VERBOSE;

	opendir( PDIR, $PATCHDIR ) or die "Couldn't open the patchdir [$PATCHDIR]: $!";
	my $file;
	while( defined ($file = readdir PDIR  )) {

		# skip . and ..
		next if $file =~ /^\.\.?$/;
		# skip README, VERSION and CVS
		next if $file =~ /(README|CVS|VERSION)/;
		# skip it if its the upgrade patch too
		#next if $file eq 'patch-00-Upgrades.sql';

		$patches->{ $file } = 1;
		print "added file $file\n" if $DEBUG;
	}
	closedir( PDIR );

	return $patches;
}


sub run_script {
	my $type = shift;
	my $num = shift;
	my $patchhash = shift;

	# if its less than 10 it needs a leading 0
	$num = sprintf( "%02d", $num );
	my $script = "script-$num-$type.pl";
	my $scriptargs = &args_as_string;

	print "\ntrying to find script $script\n" if $DEBUG;
	$patchhash->{$script} = $patchhash->{$script} || 0;
	return 0 unless( $patchhash->{$script} == 1 );
	print "found $script\n" if $DEBUG;

	print "Running $script...\n" if $VERBOSE;
	print "Args: $scriptargs\n" if $DEBUG;
	system( "$PATCHDIR/$script $scriptargs" );
	print "Script returned code $?\n" if $VERBOSE;

	unless( $QUIET || $? == 0 ) {
		my $msg = $msgs->{script_fail};
		$msg =~ s/__SCRIPT__/$script/;
		print $msg;

		chomp( my $y = <STDIN> );
		exit 1 unless( $y =~ /y/i );
	}

	db_generic( qq| insert into patches values( '$S_VERSION', $num, NULL, '$type' )| );
	$applied_patches++;

	return 1;
}

sub args_as_string {
	my %skip = ( P => 1 );

	my $str;
	while (my($k, $v) = each %{$args}) {
		next if $skip{$k};
		$str .= "-$k ";
		$v =~ s/(['\\])/\\$1/g;
		$str .= "'$v' " if $v && ($v ne '1');
	}

	return $str;
}

sub apply_patch {
	my $num = shift;
	my $patchhash = shift;

	my $mysqlargs = qq| --user=$args->{u} --password=$args->{p} --host=$args->{h} --port=$args->{o} --database=$args->{d} |;

	# if its less than 10 it needs a leading 0
	$num = sprintf( "%02d", $num );
	my $patch = "patch-$num";

	print "\ntrying to find patch $patch\n" if $DEBUG;
	# see if we can find a matching patch in the patchhash
	my $found = 0;
	for my $k ( keys %$patchhash ) {
		unless( $k =~ /$patch/) { next; }
		$patch = $k;
		$found = 1;
		print "Found patch $patch\n" if $DEBUG;
	}
	return 0 unless($found == 1);

	$patch =~ /^patch-\d+-(.*?).sql$/;
	my $name = $1;

	print "Applying $patch...\n" if $VERBOSE;
	#my $systemcall = qq| mysql $mysqlargs < "$PATCHDIR/$patch"|;
	#system( $systemcall );
	dump_in( "$PATCHDIR/$patch" );

	unless( $QUIET || $? == 0 ) {
		my $msg = $msgs->{patch_fail};
		$msg =~ s/__PATCH__/$patch/g;
		print $msg;

		my $r = <STDIN>;
		exit 0 if( $r =~ /n/i );
	}

	db_generic( qq| insert into patches values( '$S_VERSION', $num, '$name', 'sql' )| );
	$applied_patches++;
	return 1;
}


sub dump_in {
	my $file = shift;

	open(DBF, "<$file") || die "couldn't open $file: $!";
	my $query;
	my $reading = 0;
	while (my $l = <DBF>) {
		next if $l =~ /^#/;
		if ($reading) {
			$query .= $l;
			$reading = 0 if $l =~ /;\s*$/;
		} else {
			$query = $l;
			$reading = 1 unless $l =~ /;\s*$/;
		}

		if ($query && ($reading == 0)) {
			$query =~ s/;\s*$//;
			my $rv = $dbh->do($query);
			print "Error running [$query] in file $file: $DBI::errstr\n" unless $rv;
		}
	}
	close(DBF) || die "couldn't close $file: $!";
}


sub cleanup {

	if( $VERBOSE ) {
		my $done = $msgs->{done};
		$done =~ s/__NUM__/$applied_patches/;
		print $done;
	} else {
		print "done!\n" unless $QUIET;
	}

	$dbh->disconnect;
}


sub get_args {
	my %info;
	my @neededargs;

	getopts("u:p:d:h:o:vqDP:", \%info);

	# now first generate an array of hashrefs that tell us what we
	# still need to get
	foreach my $arg ( qw( u p d h o ) ) {
		next if ( $info{$arg} and $info{$arg} ne '' );

		if( $arg eq 'u' ) {
			push( @neededargs, {arg		=> 'u',
								q		=> 'db username? ',
								default	=> 'nobody'} );
		} elsif( $arg eq 'p' ) {
			push( @neededargs, {arg		=> 'p',
								q		=> 'db password? ',
								default	=> 'password'} );
		} elsif( $arg eq 'd' ) {
			push( @neededargs, {arg		=> 'd',
								q		=> 'db name? ',
								default	=> 'scoop'} );
		} elsif( $arg eq 'h' ) {
			push( @neededargs, {arg		=> 'h',
								q		=> 'db hostname? ',
								default	=> 'localhost'} );
		} elsif( $arg eq 'o' ) {
			push( @neededargs, {arg		=> 'o',
								q		=> 'db port? ',
								default	=> '3306'} );
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


sub db_connect {

	print "Connecting to db\n" if $DEBUG;

	my $dsn = "DBI:mysql:database=$args->{d}:host=$args->{h}:port=$args->{o}";
	$dbh = DBI->connect($dsn, $args->{u}, $args->{p});

	print "Connected to database\n" if($DEBUG || $VERBOSE);
}


# db utility, performs a db select and returns and array ref of the
# tuples
sub db_select {
	my $query = shift;
	my $retval = [];
	
	print "Running query [$query]\n" if $DEBUG_DB;
	
	# prepare and execute query
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	#	die "Couldn't run query [$query]: $!";

	print "query returned $rv\n" if $DEBUG_DB;
	
	return $retval unless $rv;

	while( my $hash = $sth->fetchrow_hashref() ) {
		push( @$retval, $hash );
	}

	return $retval;
}


# db utility, performs a generic db query, which only expects a 
# boolean value as the return.  so insert, delete, update, etc
sub db_generic {
	my $query = shift;
	
	print "Running query [$query]\n" if $DEBUG_DB;
	
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	#	die "Couldn't run query [$query]: $!";

	print "query returned $rv\n" if $DEBUG_DB;

	return $rv;
}

sub usage {
	print "$0 [-u user] [-p pass] [-d database] [-h host] [-o port] [-P patch dir] [-v] [-q] [-D]
$0 -h

When run, this script will do it's best to connect to the db, figure out the
state of patches applied to it, and apply any that are needed. Usually, it'll
prompt for input along the way, but if you specify all of the args that take
args, along with -q, it should make no output, and take no input.

-h             get this help message

-u user        the user to connect to the db as
-p pass        password to use for said user
-d database    database to work with
-h host        db host
-o port        db port
-P patch dir   directory containing patches
-v             be more verbose
-q             be quiet
-D             turn on debugging
";
}

sub messages {
	my $msgs = {};

	$msgs->{intro} = qq|
This is the scoop database upgrade tool.  It will apply all of the
needed patches for your scoop site, to bring your database up to
date with your code.  Before you run this, make sure you upgrade
your code via cvs, usually with 'cvs update -d' from the scoop base
directory.

If you are running this from the scoop base directory, then it should
determine most things easily.  If you are trying to upgrade between
2 versions, you will need to do it in 2 parts, i.e. from 0.5->0.6 then
from 0.6->0.8.  Scoop will prompt you for the appropriate patch
directory later.  If you need to stop, hit ^C at anytime.  I will warn
you when its not safe to hit ^C anymore (when I start applying patches)
|;

	$msgs->{where_scoop_dir} = qq|
To help me find the scoop version, patch directory, etc I need to know
the location of the scoop base directory, probably where you have the
unpacked tarball.
[__SCOOPDIR__] > |;

	$msgs->{no_scoop_there} = qq|
There doesn't seem to be a scoop VERSION file there. Please try again.
|;

	$msgs->{check_patchdir} = qq|
Ok, I think I found the patch directory, but I want to make sure. If
this is correct, just hit enter, if not, type in the correct patch
dir.
[__PATCHDIR__] > |;

	$msgs->{no_patch_there} = qq|
That doesn't seem to be a directory, try again please.
|;

	$msgs->{empty_patchtable} = qq|
  Your patches table in your scoop database appears to be empty for this
scoop version.  Either you haven't applied any patches yet, or this is
your first time running this script.  I will now try to apply all
patches I find in the patch directory.
  If this is your first time running this script, you may see warnings
about various conflicts, and blocks, vars, etc already existing.  This
is OK.  I'm just building up a little table of what has already been
applied.
|;

	$msgs->{none_to_apply} = qq|
Doesn't look like you have any patches or scripts to apply.  You should
be all up to date.
|;

	$msgs->{script_fail} = qq|
Odd, it appears __SCRIPT__ failed to run cleanly.  You should have
seen the error message above.  If you want to continue, hit Y, if
you don't want to, just hit enter and you can fix whatever error that
was.  If you continue, I will mark this script as applied in the
database.
Continue? [y\|N] > |;

	$msgs->{patch_fail} = qq|
It appears __PATCH__ failed to run cleanly.  You should have
seen the error message above.  If you don't want to continue, hit N
if you want to, just hit enter.  If this is the first time you're
running the upgrader, then its probably just catching up with what
you've already applied by hand.  If its an error like "table
already exists" or "duplicate entry" then the patch has already been
applied, and its safe to continue.
Continue? [Y\|n] > |;

	$msgs->{done} = qq|
Thats it!  You had __NUM__ patches and scripts applied to your
database, your database should be all up to date now.
|;
	return $msgs;
}
