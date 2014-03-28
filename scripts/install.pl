#!/usr/bin/perl
#########################
# Simple scoop installer
#########################
use strict;
use CPAN;
use Cwd;
use Net::Domain qw(hostfqdn);

# Get user interaction messages (down at the bottom, skippy)
my $msgs = &messages();
my $continue;

# if they supply an argument, they're using it wrong, so tell
# them how to use it
if(@ARGV) {
  show_help();
  exit;
}

# Ok, start off with a little explanation...
print $msgs->{intro};
chomp($continue = <STDIN>); 
if ($continue && $continue !~ /y/i) {
	print $msgs->{no_continue};
	exit;	
}

# Now do a check for root privs...
use vars qw($IS_ROOT);
print $msgs->{check_root};
if (&root_check) {
	# running as root
	$IS_ROOT = 1;
	print $msgs->{is_root};
} else {
	# not root. give them a choice of to continue or not
	$IS_ROOT = 0;
	print $msgs->{isnt_root};
	chomp($continue = <STDIN>);
	if ($continue && $continue !~ /y/i) {
		# they chose not to continue
		print $msgs->{no_continue};
		exit;
	}
}

# now get an idea of where the scoop tarball is
use vars qw($SCOOPDIR);   # yes, our() better, but is perl 5.6+ only
$SCOOPDIR = cwd();

unless (-e "$SCOOPDIR/VERSION") {
	$SCOOPDIR =~ s|/\w+$||;
}

my $sd_response;
while( ! -e "$sd_response/VERSION" ) {
	my $wherescoop = $msgs->{where_scoop_dir};
	$wherescoop =~ s/__SCOOPDIR__/$SCOOPDIR/g;
	print $wherescoop;

	chomp( $sd_response = <STDIN> );
	$sd_response = $SCOOPDIR unless ($sd_response =~ /\w/);
	print $msgs->{no_scoop_there} unless (-e "$sd_response/VERSION");
}
$SCOOPDIR = $sd_response;

#########################
# Do CPAN module installs
#########################
if ($IS_ROOT) {
	my $cur_dir = cwd();
	&install_cpan_modules($msgs);
	chdir($cur_dir);
} else {
	print $msgs->{skipping_cpan};
}

# I assume we have these installed by now.
eval {
	require DBI;
	require DBD::mysql;
	require Crypt::UnixCrypt;
	require Term::ReadKey;
};

if ($@ && ($@ =~ /^Can't locate /)) {
	if ($IS_ROOT) {
		print $msgs->{modules_not_installed_root};
	} else {
		print $msgs->{modules_not_installed_notroot};
	}
	exit;
}

# don't forget to import!
import DBI;
import DBD::mysql;
import Crypt::mysql;
import Term::ReadKey;


#########################
# Do DB Creation
#########################
my ($path, $dbhash) = &create_scoop_db($msgs);


#########################
# Do httpd.conf customization
#########################
&customize_httpd($msgs, $path, $dbhash);


#########################
# Done!
#########################
print $msgs->{end_message};
exit(0);

#####################################
# Main program segment subroutines
#####################################

# Rusty suffered through difficult and failed module installs,
# so you don't have to! All worship the One Who CPAN'ed for your 
# sins.
#
# Try to install all the CPAN modules we need.
sub install_cpan_modules {
	my $msgs = shift;

	# First, we need to make sure the libs are installed and up to date
	# Tell the user, and give them a chance to respond
	print $msgs->{libs_intro};
	chomp(my $continue = <STDIN>); 

	# If they cannot get online, see if they want to try to 
	# go ahead anyway.
	if ($continue =~ /n/i) {
		print $msgs->{not_connected};
		chomp($continue = <STDIN>);
		unless ($continue =~ /y/i) {
			print $msgs->{no_continue};
			exit;
		}
		return;
	}

	# The required libs...
	# first get a good full path

	#my $libdir = cwd();
	#my @cwd = split( '/', $libdir );
	#$cwd[$#cwd] = 'lib/';
	#$libdir = join( '/', @cwd );

	my $libdir = $SCOOPDIR . '/lib';	
	my $lmsg = $msgs->{libs_required};
	$lmsg =~ s/__LIBDIR__/$libdir/g;
	print $lmsg;
	chomp( my $newlibdir = <STDIN>);
	$libdir = $newlibdir || $libdir;

	if ($libdir) {
		push @INC, $libdir;
		warn "Added $libdir to \@INC\n";
	} else {
		print $msgs->{no_continue};
		exit;
	}	

	# Ok, try to install the required modules
	my $i = 0;
	print $msgs->{install_cpan};
	while ($i <= 100) {
		&install_modules();
		print $msgs->{cpan_finished};
		chomp($continue = <STDIN>);
		last if ($continue =~ /y/i);
		$i++;
	}
	
	# Ok, we ought to be done now. Just warn them to 
	# not be too cocky about how that went...
	print $msgs->{modules_done};
	chomp($continue = <STDIN>);
	if ($continue && $continue !~ /y/i) {
		print $msgs->{no_continue};
		exit;	
	}
	return;
}


# Collect DB info, get a DB handle, and try to create the new scoop db.
sub create_scoop_db {
	my $msgs = shift;
	print $msgs->{db_intro};
	chomp(my $continue = <STDIN>);
	if ($continue =~ /n/i) {
		print $msgs->{db_skip};
		return;	
	}

	# Now we'll collect the DB user info
	my ($db_root_user, $db_root_pass, $db_user, $db_pass, $db_host, $db_port, @apache_hosts) = &get_db_info($msgs);

	# And try to get a db handle...
	my $dbh = &get_db_handle($msgs, $db_root_user, $db_root_pass, $db_host, $db_port);

	# Ok, now they need to choose if they want to rebuild
	# an old DB, or just create a new one.
	print $msgs->{db_new_or_existing};
	chomp($continue = <STDIN>);
	
	# Either way, we need to know the name of the DB.
	print $msgs->{db_get_db_name};
	chomp(my $dbname = <STDIN>);
	$dbname = 'scoop' unless $dbname;

	# Now get the rest of the config info
	my ($file, $email, $path, $scoop_admin, $pass) = &get_db_config_info($msgs);
	
	# If they want to rebuild an old db, we'll just connect to it, 
	# drop it, and then go ahead with a normal build.
	if ($continue =~ /2/i) {
		print $msgs->{db_use_old};
		&rebuild_old_db($msgs, $dbh, $dbname);
	}

	print $msgs->{db_make_new};
	&create_new_db($msgs, $dbh, $dbname, $file);
	
	print $msgs->{db_setup};
	&setup_new_db($msgs, $dbh, $dbname, $email, $path, $scoop_admin, $pass);

	#setup new user
	&setup_new_db_user($msgs, $dbh, $dbname, $db_user, $db_pass, @apache_hosts);
	
	print $msgs->{db_done};
	$dbh->disconnect();

	# make a hash of the db info for easy use and config
	my $dbhash = {	name	=> $dbname,
					host	=> $db_host,
					port	=> $db_port,
					user	=> $db_user,
					pass	=> $db_pass,
					root_user => $db_root_user,
					root_pass => $db_root_pass
					};
	
	return ($path, $dbhash);
}

sub customize_httpd {
	my ($msgs, $path, $dbhash) = @_;

	print $msgs->{do_httpd_config};
	chomp( my $answer = <STDIN> );
	$answer = ($answer ? $answer : 'y' );

	unless( $answer =~ /y/ig ) {
		print $msgs->{no_do_httpd_config};
		return;
	}
	
	my $lochost = ($path) ? 'location' : 'virtual host';

	# we need to verify that they are doing the right kind of install,
	# so they don't get a location when they want a vhost etc..
	my $intro = $msgs->{httpd_begin};
	$intro =~ s/__LOCHOST__/$lochost/g;
	print $intro;
	chomp( my $correct = <STDIN> );

	$correct = ( $correct ? $correct : 'y' );
	unless( $correct =~ /y/ig ) {

		# if we guessed wrong, switch
		if( $lochost =~ /location/ ) {
			$lochost = 'virtual host';
		} else {
			$lochost = 'location';
		}
	}

	my $filetype = 'httpd-location.conf';
	$filetype = 'httpd-vhost.conf' if ($lochost eq 'virtual host');

	my $file = "$SCOOPDIR/etc/$filetype";
	if (! -e $file) {
		my $failmsg = $msgs->{couldnt_find_ex_httpd};
		$failmsg =~ s/__FILE__/$file/g;
		print $failmsg;
		$file = '';
	}

	
	my $getfilemsg = $msgs->{httpd_begin_cont}.$msgs->{httpd_sample_file};
	
	$getfilemsg =~ s/__LOCHOST__/$lochost/g;
	$getfilemsg =~ s/__HTTPDCONF__/$filetype/g;
	$getfilemsg =~ s/__LOC__/$file/g;
	
	print $getfilemsg;
	chomp(my $newfile = <STDIN>);
	$file = $newfile if ($newfile =~ /\w/);
	while (! -e $file || -d $file) {
		print $msgs->{httpd_file_err};
		$msgs->{httpd_sample_file} =~ s/__HTTPDCONF__/$filetype/g;
		$msgs->{httpd_sample_file} =~ s/__LOC__//g;
		print $msgs->{httpd_sample_file};
		chomp($newfile = <STDIN>);
		$file = $newfile if ($newfile =~ /\w/);
	}
	
	print $msgs->{httpd_found_file};
	
	my $file_text = &get_httpd_conf($file);
	my $siteid;
	
	if ($lochost =~ /location/) {
		($file_text, $siteid) = &httpd_location_conf($msgs, $file_text, $path, $SCOOPDIR, $dbhash);
	} else {
		($file_text, $siteid) = &httpd_vhost_conf($msgs, $file_text, $SCOOPDIR, $dbhash);
	}
	
	&save_httpd_conf($file_text, $siteid);
	
}


#####################################
# Utility subroutines
#####################################

sub root_check {
	if ($> != 0 || $< != 0) {
		return 0;
	}
	return 1;
}

sub install_modules {
	my $rv = CPAN::Shell->install('Bundle::Scoop');
}


sub get_db_info {
	my $msgs = shift;
	my @apache_hosts;
	
	# Print the intro to DB info.
	
	#get db root user information
	my ($db_root_user, $db_root_pass) = &get_db_auth_info($msgs, $msgs->{db_get_root_user}, 'root');

	#get user that apache should connect to the DB as
	 
	 my ($db_user, $db_pass) = &get_db_auth_info($msgs, $msgs->{db_get_user}, 'scoop');

	#get the host names of the apache servers

	print $msgs->{apache_hosts};
	chomp(my $apache_hosts_raw = <STDIN>);
	if ($apache_hosts_raw) {
		#trim any leading whitespace
		$apache_hosts_raw =~ s/^\s*//;
		@apache_hosts = split /,\s*/, $apache_hosts_raw;
	} else {
		push @apache_hosts, 'localhost';
	}

	# Good, now get the host and port.
	print $msgs->{db_host};
	chomp(my $db_host = <STDIN>);
	$db_host = 'localhost' unless $db_host;
	
	print $msgs->{db_port};
	chomp(my $db_port = <STDIN>);
	$db_port = '3306' unless $db_port;
	
	return ($db_root_user, $db_root_pass, $db_user, $db_pass, $db_host, $db_port, @apache_hosts);
}

sub get_db_auth_info {

	my ($msgs, $user_msg, $default_username ) = @_;

	print $user_msg;
	# Get the username
	chomp(my $username = <STDIN>);
	$username = $default_username unless $username;
	
	#don't modify the msgs hash, as we use them for other usernames later
	my $message = $msgs->{db_get_pass};
	$message =~ s/__user__/$username/g;
	my $message_harangue = $msgs->{db_pass_harangue};
	$message_harangue =~ s/__user__/$username/g;

	my $password = "";
	
	while (!$password) {
		$password = &get_pass($message);

		# they tried to give us an empty password. This is dumb. Politely
		# inform them of the error of their ways and demand a better password.
		if (!$password) {
			print $message_harangue;
		}
	}

	return ($username, $password);
}

sub get_pass {

	my $message = shift;

	my ($db_pass, $db_pass2) = ('not', 'equal');
	while( $db_pass ne $db_pass2 ) {	
		print $message;
	
		# Get the password
		ReadMode('noecho');
		$db_pass = ReadLine(0);
		chomp $db_pass;

		print $msgs->{get_password_repeat};
		$db_pass2 = ReadLine(0);
		chomp $db_pass2;

		# let them know if the passwords didn't match, and try again
		if( $db_pass ne $db_pass2 ) {
			print $msgs->{password_no_match};

		} 
	}

	ReadMode('normal');
	#insert the newline that was hidden with the 'noecho'
	print "\n";

	return $db_pass;
}

# Try to connect to the DB. Bail if we can't,
# otherwise, return a db handle
sub get_db_handle {
	my ($msgs, $db_user, $db_pass, $db_host, $db_port) = @_;
	
	my $dsn = "DBI:mysql:host=$db_host:port=$db_port";
	my $dbh = DBI->connect($dsn, $db_user, $db_pass) ||
		die "$msgs->{no_db_connect} $DBI::errstr";
	
	return $dbh;
}

sub get_db_config_info {
	my $msgs = shift;
	
	my $file = "$SCOOPDIR/struct/scoop.sql";
	my $email = '';
	my $path = '';
	my $pass = '';
	
	my $toprint = $msgs->{db_get_file};
	$toprint =~ s/__SCOOPDIR__/$SCOOPDIR/g;
	print $toprint;
	chomp(my $newfile = <STDIN>);
	$file = $newfile if ($newfile =~ /\w/);
	
	while (! -e $file || -d $file) {
		print $msgs->{db_get_file_failed};
		print $toprint;
		chomp(my $newfile = <STDIN>);
		$file = $newfile if ($newfile =~ /\w/);
	}
	
	print $msgs->{db_get_path};
	chomp($path = <STDIN>);
	$path =~ s/\/+$//g;
	
	#find out what they want the admin account named
	print $msgs->{db_get_scoop_admin};
	chomp(my $scoop_admin = <STDIN>);
	$scoop_admin = 'scoop' unless $scoop_admin;	

	# get the password for the new scoop user
	my $message = $msgs->{db_get_scoop_pass};
	$message =~ s/__ADMIN_ACCT__/$scoop_admin/g;

	$pass = &get_pass($message);

	while( $pass !~ /.{8,}/) {
		# the passwords matched, but they were too short, let them know
		# reset the 2 passwords, and try again
		print $msgs->{db_password_error};
		$pass = &get_pass($message);
	}
	
	my $message = $msgs->{db_get_email};
	$message =~ s/__USER__/$scoop_admin/g;
	my $hostname = hostfqdn();
	$message =~ s/__HOSTNAME__/$hostname/g;

	print $message;
	chomp($email = <STDIN>);
	$email = "$scoop_admin\@$hostname" unless $email;
	
	while ($email !~ /\@/) { 
		print $msgs->{db_email_error};
		print $message;
		chomp($email = <STDIN>);
		$email = "$scoop_admin\@$hostname" unless $email;
	}

	return ($file, $email, $path, $scoop_admin, $pass);
}
		
sub rebuild_old_db {
	my ($msgs, $dbh, $db) = @_;	
	print "\nDropping $db...";
	my $rv = $dbh->do("DROP DATABASE $db");
	if (!$rv) {
		print "\nError dropping $db: $DBI::errstr\n";
	} else {
		print "done";
	}
	
	return;
}

sub create_new_db {
	my ($msgs, $dbh, $db, $file) = @_;	
	my $rv;
	
	print "\nCreating $db...";
	$rv = $dbh->do("CREATE DATABASE $db");
	die "\nError creating $db: $DBI::errstr\n" unless $rv;
	print "done";

	print "\nSwitching to $db...";
	$rv = $dbh->do("USE $db");
	die "\nError switching to $db: $DBI::errstr\n" unless $rv;
	print "done";

	print "\nDumping data into $db...";
	&dump_in($dbh, $file);
	print "done";

	return;
}

sub setup_new_db {
	my ($msgs, $dbh, $db, $email, $path, $admin_user, $pass) = @_;
	my $rv;
	my $c_pass = crypt_pass($pass);
	
	print "\nSetting path...";
	$rv = $dbh->do("UPDATE vars SET value='$path' WHERE name='rootdir'");
	die "\nError setting path to $path: $DBI::errstr\n" unless $rv;
	print " done";

	print "\nSetting image path...";
	$rv = $dbh->do("UPDATE vars SET value='$path/images' WHERE name='imagedir'");
	die "\nError setting imagedir to $path/images: $DBI::errstr\n" unless $rv;
	print " done";

	print "\nSetting e-mail address...";
	$rv = $dbh->do("UPDATE vars SET value='$email' WHERE name='local_email'");
	die "\nError setting var 'local_email' to $email: $DBI::errstr\n" unless $rv;
	$rv = $dbh->do("UPDATE blocks SET block='$email' WHERE bid='admin_alert'");
	die "\nError setting block 'admin_alert' to $email: $DBI::errstr\n" unless $rv;
	print " done";

	print "\nSetting password for admin user...";
	$rv = $dbh->do("UPDATE users set passwd = '$c_pass' WHERE nickname = 'scoop'");
	die "\nError setting password to $c_pass: $DBI::errstr\n" unless $rv;
	print " done.";

	print "\nSetting realemail for admin user...";
	$rv = $dbh->do("UPDATE users set realemail = '$email' WHERE nickname = 'scoop'");
	die "\nError setting realemail to $email: $DBI::errstr\n" unless $rv;
	print " done.";

	print "\nSetting nickname for admin user...";
	$rv = $dbh->do("UPDATE users set nickname = '$admin_user' WHERE nickname = 'scoop'");
	die "\nError setting nickname to $admin_user: $DBI::errstr\n" unless $rv;
	print " done.";

	return;
	
}

sub setup_new_db_user {
	my ($msgs, $dbh, $dbname, $db_user, $db_pass, @apache_hosts) = @_;
	my ($rv, $db_host);

	foreach $db_host (@apache_hosts)
	{
		print"\nGiving user $db_user\@$db_host proper permissions to $dbname...";
		$rv = $dbh->do("GRANT insert, update, delete, select ON $dbname.*"
				. " TO $db_user\@$db_host IDENTIFIED BY '$db_pass'");
		die "\nError adding permissions for user $db_user\@$db_host: $DBI::errstr\n" unless $rv;
		print " done.";
	}

	return;
}

##############################
# Simple password encryption scheme. Takes a word, 
# perl crypt()'s it with itself, and cuts off the first 2 
# characters, which will be the salt-- that is, the first
# 2 chars of the word in plaintext. It always worries me
# having that plaintext lying arounbd, so I chop it.
##############################
sub crypt_pass {
	my $p_pass = shift;
	Crypt::UnixCrypt::crypt($p_pass, $p_pass) =~ /..(.*)/;
	my $c_pass = $1;
	return $c_pass;
}

sub dump_in {
	my ($dbh, $file) = @_;

	open(DBF, "<$file") || die "couldn't open $file: $!";
	my $query;
	my $reading = 0;
	while (my $l = <DBF>) {
		next if $l =~ /^#/;
		if ($reading) { 
			$query .= $l;
			$reading = 0 if $l =~ /;$/;
		} else {
			$query = $l;
			$reading = 1 unless $l =~ /;$/;
		}

		if ($query && ($reading == 0)) {
			$query =~ s/;$//;
			my $rv = $dbh->do($query);
			die "Error running [$query]: $DBI::errstr\n" unless $rv;
		}
	}
	close(DBF) || die "couldn't close $file: $!";
}

sub get_httpd_conf {
	my $file = shift;
	my $txt;
	
	open(HTTPD, "<$file") || die "couldn't open $file: $!";
	foreach my $l (<HTTPD>) { $txt .= $l }
	close HTTPD || die "couldn't close $file: $!";
	
	return $txt;
}

sub httpd_location_conf {
	my ($msgs, $f, $path, $root, $dbhash) = @_;
	my $siteid;

	unless ($path) {    # if we didn't get it earlier, then get it now
		print $msgs->{db_get_path};
		chomp($path = <STDIN>);
		$path =~ s/\/+$//g;
	}

	# first get the common stuff out of the way, stuff thats done in both
	# location and vhost
	($f, $siteid) = &httpd_common_conf( $msgs, $f, $root, $dbhash, $path );

	# Now do the images alias
	$f =~ s{Alias /scoop/images/ "/www/scoop/html/images/"}{Alias $path/images/ "$root/html/images/"}g;
	
	# And the images location
	$f =~ s{<Location /scoop/images>}{<Location $path/images>}g;

	return ($f, $siteid);
}

sub httpd_vhost_conf {
	my ($msgs, $f, $root, $dbhash) = @_;
	my $siteid;

	# first get the common stuff out of the way, stuff thats done in both
	# location and vhost
	($f, $siteid) = &httpd_common_conf( $msgs, $f, $root, $dbhash );

	# get the ip address and update $f
	my $ip;
	while( $ip !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
		print $msgs->{what_ip_address};
		chomp( $ip = <STDIN> );
		$ip = '127.0.0.1' if ( $ip eq '' );

		last if $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
	
		# if they got here, they put in a wrong ip, tell them
		print $msgs->{bad_ip_address};	
	}


	# if there are other virtual hosts already, we don't need the
	# NameVirtualHost directive
	my $nvh = '';			# nvh eq NameVirtualHost
	print $msgs->{other_vhosts};
	chomp( my $others = <STDIN> );
	if( $others =~ /y/ig ) {
		$nvh = '';
	} else {
		$nvh = "NameVirtualHost $ip";
	}	

	# now do the substitutions
	$f =~ s/__SERVER_IP__/$ip/g;

	# get the ServerName
	my $server_name;
	while( $server_name !~ /\w/ ) {
		print $msgs->{get_server_name};
		chomp( $server_name = <STDIN> );

		last if $server_name =~ /\w/;
		
		# if they got here, bad server name, tell them
		print $msgs->{redo_server_name};
	}

	$f =~ s/__SERVER_NAME__/$server_name/;

	# log files 
	my $error_log;
	my $custom_log;

	print $msgs->{get_error_log};
	chomp( $error_log = <STDIN> );
	$error_log = 'logs/scoop-error_log' unless( $error_log =~ /\w/ );

	print $msgs->{get_custom_log};
	chomp( $custom_log = <STDIN> ); 
	$custom_log = 'logs/scoop-access_log' unless( $custom_log =~ /\w/ );

	$f =~ s/__ERROR_LOG__/$error_log/;
	$f =~ s/__CUSTOM_LOG/$custom_log/;

	return ($f, $siteid);
}

sub httpd_common_conf {
	my ($msgs, $f, $root, $dbhash, $path) = @_;

	$path = '/' unless ($path && $path ne '');

	# First replace all refs to '/www/scoop' with the
	# local root path
	$f =~ s{/www/scoop}{$root}g;

	$f =~ s/__URL_PATH__/$path/g;

	print $msgs->{get_mysql_version};
	chomp( my $mysql_version = <STDIN> );
	$mysql_version = '3.23' unless $mysql_version =~ /\w/;
	while( $mysql_version !~ /^\d+\.\d+$/ ) {
		print $msgs->{mysql_version_error};
		print $msgs->{get_mysql_version};
		chomp( $mysql_version = <STDIN> );
		$mysql_version = '3.23' unless $mysql_version =~ /\w/;
	}

	# now replace the mysql version with the correct one
	$f =~ s/__MYSQL_VER__/$mysql_version/g;

	unless ($dbhash->{user}) {   # if user isn't set, then db isn't configed
		my ($root_user, $root_pass, $user, $pass, $host, $port) = &get_db_info($msgs);
		$dbhash->{root_user} = $root_user;
		$dbhash->{root_pass} = $root_pass;
		$dbhash->{user} = $user;
		$dbhash->{pass} = $pass;
		$dbhash->{host} = $host;
		$dbhash->{port} = $port;

		print $msgs->{db_get_db_name};
		chomp($dbhash->{name} = <STDIN>);
		$dbhash->{name} = 'scoop' unless $dbhash->{name};
	}

	# DB stuff, name, pass, etc
	$f =~ s/__DBNAME__/$dbhash->{name}/g;
	$f =~ s/__DBUSER__/$dbhash->{user}/g;
	$f =~ s/__DBHOST__/$dbhash->{host}/g;
	$f =~ s/__DBPASS__/$dbhash->{pass}/g;

	# get a name for this site, to put in a comment
	print $msgs->{get_sitename};
	chomp( my $sitename = <STDIN>);
	$sitename = 'myscoopsite' unless $sitename =~ /\w/;

	$f =~ s{# THIS IS NOT A COMPLETE APACHE CONFIG FILE!!!!}{# Begin of configuration for $sitename}g;

	# get the cookie host, and update
	my $cookie_host_msg = $msgs->{get_cookie_host};
	my $hostname = hostfqdn();
	$cookie_host_msg =~ s/__HOSTNAME__/$hostname/g;

	print $cookie_host_msg;
	chomp( my $cookie_host = <STDIN> );
	$cookie_host = $hostname unless $cookie_host;

	# if it was empty input or it didn't contain 2 dots
	while( $cookie_host !~ /\w/ || $cookie_host !~ /.*\..+\..+/ ) {
		print $msgs->{bad_cookie_host};
		print $cookie_host_msg;
		chomp( $cookie_host = <STDIN> );
		$cookie_host = $hostname unless $cookie_host;
	}

	
	$f =~ s/__COOKIE_HOST__/$cookie_host/g;

	# smtp server, get and update
	print $msgs->{get_smtp_server};
	chomp( my $smtp = <STDIN> );
	$smtp = 'localhost' unless $smtp;

	# if it was just whitespace, get it again
	while( $smtp !~ /\w/ ) {
		print $msgs->{bad_smtp_server};
		print $msgs->{get_smtp_server};
		chomp( $smtp = <STDIN> );
		$smtp = 'localhost' unless $smtp;
	}

	$f =~ s/__SMTP_SERVER__/$smtp/g;

	# site id, get an update
	print $msgs->{get_site_id};
	chomp( my $siteid = <STDIN> );
	$siteid = 'myscoopsite' if $siteid !~ /\w/;
	while( $siteid =~ /\s/ ) {
		print $msgs->{bad_site_id};
		print $msgs->{get_site_id};
		chomp( $siteid = <STDIN> );
		$siteid = 'myscoopsite' if $siteid !~ /\w/;
	}

	$f =~ s/__SITE_ID__/$siteid/g;

	my $gen_key = $SCOOPDIR . '/scripts/gen_key.pl';
	chomp(my $key = `$gen_key`);
	$f =~ s/__SITE_KEY__/$key/g;

	# thats it on the common stuff

	return ($f, $siteid);
}

sub save_httpd_conf {
	my $filetext = shift;
	my $siteid = shift;

	my $msg = $msgs->{output_httpd_stuff};
	$msg =~ s/__SITEID__/$siteid/g;
	print $msg;
	
	open  OUTFILE, ">httpd-$siteid.conf" 	or die "Couldn't open httpd-scoop.conf: $!";
	print OUTFILE $filetext;
	close OUTFILE 							or die "couldn't close outfile: $!";

	my $more = <STDIN>;    # wait for a keystroke

	return;	
}

# case unknown or -help  use endcode.pl and decode.pl to decipher.
# ummm.. This is all rusty's fault.  you can see it about 5 lines down
# in that mess.  It says "I am Rusty and I did this muahahah!"
sub show_help {

	print "\nUsage: ./install.pl  (as root)\n\n";

}

sub messages {
	# msgs will hold all our user prompts, so they
	# don't clutter up the code.
	my $msgs = {};

	$msgs->{intro} = qq|
Welcome to the Scoop Installer!

This is a simple installer script for Scoop. It will 
ask you some questions about your system, and how you 
want to set up Scoop, and then will attempt to install 
and configure Scoop for you.

Before we start, you should be sure you have installed 
Apache and mod_perl, and that you have installed MySQL. 
MySQL should be running and accessable right now, for 
the easiest install. Additionally, you will need to know 
the root password for MySQL, so that we can initialize 
your Scoop database.

Continue? [Y]/n > |;

	$msgs->{no_continue} = qq|
You don't want to continue? Ok, try again when you're ready, 
and thank you for using Scoop!

|;

	$msgs->{check_root} = qq|
I'm making sure you're running as root or with root 
permissions right now... |;

	$msgs->{is_root} = qq| you are! Excellent.
|;

	$msgs->{isnt_root} = qq| you're not.

The installer can still run without being root, but you won't
be able to install the necessary perl modules. However, if
you have already installed them, then we can go ahead.

Continue? [Y]/n) > |;

	$msgs->{where_scoop_dir} = qq|
To aid in the install process, I need to know what directory is
your unpacked scoop tarball.  If you are running this from the 
scripts directory then the default should be fine. Otherwise,
specify one below
[__SCOOPDIR__] > |;

	$msgs->{no_scoop_there} = qq|
Sorry, you need to specify a valid directory as the location
of the untarred scoop tarball.  Please try again.
|;

	$msgs->{skipping_cpan} = qq|
Skipping module installation since you're not running as root.
|;

	$msgs->{libs_intro} = qq|
Scoop needs some CPAN libraries to operate properly. We're 
going to try to fetch and install them for you now. 

You must be connected to the internet to do this step. If 
you need to connect, please do so, and press return when 
you're ready.

Enter "N" if you cannot connect to the net now, or you wish to 
skip installing CPAN libs.

Continue? [Y]/n > |;

	$msgs->{libs_required} = qq|
I will now install or update libraries required for Scoop.
Any libraries that are already up to date will simply be left 
alone.
To do this, I need to know where your scoop lib/ directory is.
Make sure this is the full path.  If you're running this from the
scoop/scripts directory, it should be correct, and you can just
press return. If you're doing something else, enter the absolute
path below. 

Lib directory? [__LIBDIR__] > |;

	$msgs->{not_connected} = qq|
You can't get online? Yipes. Well, now you have a choice. If 
you know you have all the modules below, you can try to continue 
with the install. Otherwise, you'll have to wait till you 
can get online.

Modules needed by Scoop are in the Bundle at  lib/Bundle/Scoop.pm

To install them later, just run scripts/install-cpan.pl

Try to continue installing Scoop anyway? y/[N] > |;

	$msgs->{install_cpan} = qq|
Running CPAN to install modules. You'll see a bunch of CPAN 
output scroll by now. Keep an eye out for errors!

|;

	$msgs->{cpan_finished} = qq|
Well, I bet that was fun. The easiest way to see if all that 
was successful is just to run it until you get a list of success 
messages. So, if you just saw a list of output consisting entirely 
of "[Foo::Bar] is up to date.", then enter yes below. Otherwise, 
I'll run through that again to make sure.

Is everything up to date? y/[N] > |;

	$msgs->{modules_done} = qq|
Ok! You should be done with the CPAN phase of the install. 
Be warned -- if you saw errors above, some modules may not 
have installed right. There's no easy way for me to know 
if they have or not (hey, I'm just a script!). If you saw 
errors, I really recommend you exit this script now, and 
install the modules by hand. in the lib/ directory, 
"perldoc Bundle::Scoop" will give you the whole list of 
modules we need.

Otherwise, let's get on with it!

Continue? [Y]/n > |;

	$msgs->{modules_not_installed_root} = qq|
Oops, looks like some of the required modules aren't installed.
Try re-running this script's module installation, or installing
the missing ones by hand.

|;

	$msgs->{modules_not_installed_notroot} = qq|
Oops, looks like some of the required modules aren't installed.
Either become root and re-run this script so that it can install
them, or install the modules by hand.

|;

	$msgs->{db_intro} = qq|
Ok, now we're in the part where I set up and configure 
your Scoop database. If you already have a Scoop DB, you 
can skip this part entirely. Note that if you only want to 
do part of the DB configuration, you'll have more chances 
to skip stuff below.

Configure database? [Y]/n > |;

	$msgs->{db_skip} = qq|
Skipping database configuration...
|;

	$msgs->{db_get_root_user} = qq|
I need some information to connect to your database. First, 
please enter the user you wish to connect as for the 
install. This user must have full privileges to create 
databases and grant permissions to others. Default is root, 
and you're probably best sticking with that. You will be
prompted for the user that apache will use to connect to 
scoop's database as in a moment.

Database user I should connect as? [root] > |;

	$msgs->{db_get_user} = qq|
What user should Apache use to connect to your database?
This username and password will be stored in your apache
configuration, so it's best that it only have access to 
the scoop database.

Database user that apache should connect as? [scoop] > |;

	$msgs->{db_get_pass} = qq|
Ok, now I need the password that __user__ will connect with.
It will not echo to the screen, for security purposes, so 
don't be surprised when it doesn't show up when you type.

Password for __user__? > |;

	$msgs->{db_pass_harangue} = qq|
I'm sorry, that just won't do. You really do need to have a 
password set on most accounts! I know MySQL doesn't *require* 
it, but it's just foolish not to have a password set, and 
frankly, I'll not be a party to it!

To set a password for mysql, try:
mysqladmin -u __user__ password [newpass]

Now, if you need to, go set a password, and then come on back 
and enter it. I'll wait.
|;

	$msgs->{apache_hosts} = qq|

Next, I need to know what hosts you will be running apache on.
Most likely, you're running apache and the SQL server on the
same server, so this will just be localhost. However, if you
have a more complex set up, then you can enter a comma delimited
list of hostnames or IPs that will be connecting to the SQL server.

Apache hosts? [localhost] > |;

	$msgs->{db_host} = qq|
Now I need the host that MySQL is running on. 

MySQL host? [localhost] > |;

	$msgs->{db_port} = qq|
And of course the port to address...

MySQL port? [3306] > |;
	
	$msgs->{no_db_connect} = qq|
Error! I can't connect to the database. I'm going to exit now -- 
please try to fix whatever's wrong and try again. DBI said the 
error was: |;

	$msgs->{db_new_or_existing} = qq|
Ok, I have a connection to the database. Now, you can either 
create a new database from scratch, or you can rebuild an 
existing one. Note that rebuilding an old database will 
COMPLETELY ERASE the old data. Only choose this option if 
you really mean it! Normally, you'll want to create a fresh 
database from scratch.

Choose one:
(1) Create a new database?
(2) Drop and rebuild an old database?

Please enter 1 or 2: [1] > |;

	$msgs->{db_get_db_name} = qq|
Database name? [scoop] > |;

	$msgs->{db_use_old} = qq|
Ok, first we'll need to drop the old database. This is the 
fastest way of clearing a database with MySQL. All the 
permissions that related to the DB will persist, however.

If the old database doesn't exist, you will see an error 
to that effect below. This can be safely ignored (unless 
you mis-typed the name of the old DB!)
|;
	
	$msgs->{db_get_file} = qq|
I need to know where the scoop.sql file is, which contains the 
default database dump. Normally, it's located in 
scoop/struct/scoop.sql. If you'd like to use a different file, 
please enter the path and name below:

DB Dump? [__SCOOPDIR__/struct/scoop.sql] > |;

	$msgs->{db_get_file_failed} = qq|
Hm. I can't seem to find that file. Please try again.
|;

	$msgs->{db_get_path} = qq|
I need to know the path you'll be accessing Scoop under on your 
Apache server. That is, if you plan to run something like:
"http://www.mysite.com/scoop", you'd enter "/scoop" below. If 
Scoop will be running as the root path on it's own host, just 
leave the following blank.

Scoop URL path? [] > |;

	$msgs->{db_get_email} = qq|
In order for user registrations to work, and admin alerts to be 
sent, Scoop needs to know your valid e-mail adress. This can be 
changed later, if needed.

Admin email address? [__USER__\@__HOSTNAME__] > |;

	$msgs->{db_email_error} = qq|
Hmm. That doesn't look like a valid email. We really do need this 
for Scoop to work right. Please try again.
|;

	$msgs->{db_get_scoop_admin} = qq|
When you first set up Scoop, we will add a default superuser. What
should this account be named? [scoop] > |;

	$msgs->{db_get_scoop_pass} = qq|
Please enter a password to use for this account below. It must be
at least 8 characters long. This password will not be echoed to the
screen either, as was the database password.

Default password for __ADMIN_ACCT__? > |;

	$msgs->{get_password_repeat} = qq|
Please type your password again for confirmation
password? > |;

	$msgs->{password_no_match} = qq|
The passwords you entered did not match, please try again
|;

	$msgs->{db_password_error} = qq|
Whoops! Your password must be at least 8 characters! Please try again.
|;

	$msgs->{db_make_new} = qq|
Ok, now we're going to create your new Scoop database!
|;

	$msgs->{db_setup} = qq|
New database inserted, now we'll customize it for your site...
|;

	$msgs->{db_done} = qq|
Ok! Your scoop database is all set up. Only one more phase to 
go, and your site will be ready.
|;

	$msgs->{do_httpd_config} = qq|
Do you want me to help you configure apache for you now?  What
I'll do is output the relevant part of the apache configuration
for you to a file, then you can use 'Include' to include it
in your apache configuration.  Or you can skip this step and 
configure apache by hand.
NOTE: if you skipped the database configuration step, then you
will need to edit the file output from this step and add in
the database information.

Configure Apache? [Y]/n > |;

	$msgs->{no_do_httpd_config} = qq|
Ok, I see how it is, you don't trust me.  Fine then.  Well 
just make sure you follow the examples in the 
scoop/etc/httpd-location.conf and httpd-vhost.conf files, and
edit them to taste, then stop and start apache.
|;

	$msgs->{httpd_begin} = qq|
Now we're going to configure your webserver. I see by the path 
you entered that you're doing a __LOCHOST__ based install. 
Location installs are for when you want to access your site
via a path after your site name, like http://a.b.com/myscoopsite
Virtual Host installs are for when you set up a separate site
just for scoop. i.e. your usual site is http://www.mysite.com/
but scoop will run on http://scoop.mysite.com/

Do you want a __LOCHOST__ based install? [Y]/n > |;

	$msgs->{httpd_begin_cont} = qq|
I'll need to get the sample __HTTPDCONF__ file to base your 
site configuration on. Again, if you're running this from scripts/ 
it's probably located in the default below, but enter a different 
location if it's not there.  There will be no default below
if I couldn't find the __HTTPDCONF__ in the default location.
Remember, this path must be absolute!
|;

	$msgs->{httpd_sample_file} = qq|
Sample __HTTPDCONF__? 
[__LOC__] > |;

	$msgs->{httpd_file_err} = qq|
Either I can't find that file or you entered a directory
name. Please try again.
|;

	$msgs->{couldnt_find_ex_httpd} = qq|
I couldn't find the sample file, I looked here:
__FILE__ 
So you'll have to specify it manually.  Use the
full path please.
|;

	$msgs->{httpd_found_file} = qq|
Ok, I found it. Now I need to know some more about your site.
|;

	$msgs->{get_mysql_version} = qq|
For scoop to work fully, I need to know what version of mysql you
are running.  As of right now, the stable versions are 3.23 or 4.0,
and the development is 4.1. If you are running MySQL 4.0x or 4.1x,
you can choose the appropriate database version to allow Scoop to use
features specific to that series. Otherwise, just use 3.23. MySQL 3.22
is still supported but deprecated, so if you're still running 3.22,
you should seriously consider upgrading. 

[3.23]> |;

	$msgs->{mysql_version_error} = qq|
The version number you entered for mysql was invalid.  It must be
of the format <number>.<number>  Please try again
|;

	$msgs->{get_cookie_host} = qq|
For cookies to be set correctly (which is needed for user accounts)
I need the hostname to set in the cookies.  An ip will work, or a
hostname, but the hostname needs at least 2 dots. i.e. 
www.kuro5hin.org and .kuro5hin.org will work, but kuro5hin.org
will not.  This needs to be the name that people use to access your
scoop site.

cookie host [__HOSTNAME__] > |;

	$msgs->{bad_cookie_host} = qq|
Sorry, but the cookie_host you entered will not work either because 
you didn't enter one, or because it didn't contain at least 2 dots
in the name.  Please try again.
|;

	$msgs->{get_smtp_server} = qq|
To send email out to your users, when they create accounts, or if
they are using the digest feature, I will need a valid smtp server.
Without one, you cannot create any accounts.  This should probably
be the same smtp server you use for your personal email, or the one
that your isp provides you to use.

smtp server [localhost] > |;

	$msgs->{bad_smtp_server} = qq|
Sorry, but the smtp server you entered was invalid. You must enter
a name for the smtp server.
|;

	$msgs->{get_site_id} = qq|
If you are going to run multiple scoop sites, each will need to have
a unique site identifier.  If you are going to only run one scoop
site, the default will be fine.

siteid [myscoopsite]> |;

	$msgs->{bad_site_id} = qq|
Sorry, but it appears the siteid you entered was invalid.  It 
can't contain spaces.  Please try again
|;

	$msgs->{get_sitename} = qq|
What are you going to call your site?  This is not necessary for 
anything other than a small comment that will go in the apache
config file, just for ease of administration, and my own sense
of completeness :-)

site name [myscoopsite]> |;

	$msgs->{what_ip_address} = qq|
I need to know what ip address to attach this virtual host to.
By default it will be 127.0.0.1, which is what you should use 
only if you only want to be able to access your scoop site from
this computer.  It will probably be the external ip of your 
computer.

IP Address [127.0.0.1]> |;

	$msgs->{bad_ip_address} = qq|
The ip address you entered was invalid, it was not of the form
<0-255>.<0-255>.<0-255>.<0-255>  Please try again.
|;

	$msgs->{get_server_name} = qq|
What will be the name of this scoop site?  This is what people
will type into their browser to get to your scoop site.

Server Name > |;

	$msgs->{redo_server_name} = qq|
The server name you entered was invalid, please try again
|;

	$msgs->{get_error_log} = qq|
Please enter a location for your error logs. You can use the same
location as for another site, but the logs will be mixed.

Error Log [logs/scoop-error_log]> |;

	$msgs->{get_custom_log} = qq|
Now I need the custom log location, this is where all of the regular
requests for scoop will go.

Common Log [logs/scoop-access_log]> |;

	$msgs->{other_vhosts} = qq|
Do you have any other virtual hosts already set up on this ip
address?  If you just installed apache, you won't have any set up
currently.

Other vhosts? y/[N] > |;

	$msgs->{output_httpd_stuff} = qq|
Cool!  It looks like your Apache config is all set up.  I will 
output this configuration file to httpd-__SITEID__.conf in this
directory.  To finish configuring Apache, just write a line like
Include /path/to/httpd-__SITEID__.conf at the end of your apache
httpd.conf file.  Usually that file is at /usr/local/apache/conf/httpd.conf. 

<More>|;

	$msgs->{end_message} = qq|
That's it!  You've finished!  Now you will need to stop and start
Apache, to see if it worked.  Don't do 'apachectl restart,' since
that has problems recompiling the perl, it just doesn't do it all.
You will need to run 'apachectl stop' then 'apachectl start' to fully
recompile the code.

If it doesn't work, you can get help on the scoop-help mailing list;
go to http://sourceforge.net/mail/?group_id=4901 to get signed up.
The archive is at http://sourceforge.net/mailarchive/forum.php?forum_id=4121
Most problems people run into during installs have already 
been answered there.

If you are more fond of IRC, then check out #scoop and #kuro5hin
on irc.kuro5hin.org.  Generally some Scoop users and developers
are in #scoop; if its empty, look in #kuro5hin for help

Thanks for using Scoop!  We of the Scoop dev team hope you like it,
and if you have any problems with it, please let us know.
|;

	$msgs->{done} = qq|
done!|;

	return $msgs;
}
