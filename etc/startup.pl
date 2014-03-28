#!/usr/bin/perl
use strict;
use mod_perl ();
#BEGIN {
#	eval "use mod_perl ()";
#}
#BEGIN {
#	eval "use mod_perl2 ()";
#}

# first off, check the mod_perl version, so we can change what we pull in
# for now, we have to consider that mod_perl2 is actually >=1.99, not >=2.0
# needs to be in BEGIN so that it gets run before any of the module loads
BEGIN {
	$Scoop::MP2 = $mod_perl::VERSION >= 1.99 ? 1 : 0;
	#$Scoop::MP2 = 1;
}

# Die unless we have mod_perl
$ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/
       or die "GATEWAY_INTERFACE not Perl!";

BEGIN { $Crypt::UnixCrypt::OVERRIDE_BUILTIN = 1 }
use Crypt::UnixCrypt;

# Uncomment for really complete error reports in the logs.
# Warning! This produces *lots* of output.
#use Carp ();
#$SIG{__WARN__} = \&Carp::cluck;
	
# Try to kill off huge httpds, in case of mem leaks.
# This shouldn't be necessary, but uncomment the following if your 
# install is leaking.
#use Apache::SizeLimit;
#$Apache::SizeLimit::MAX_PROCESS_SIZE = 10000; #10M max size

# Stop, then Start the monitoring process
#&Apache::Watchdog::RunAway::stop_monitor();
#&Apache::Watchdog::RunAway::start_detached_monitor();

# Handle dropped connections cleanly. only needed in mod_perl1
# have to wrap this in BEGIN so that it gets processed before loading
# Scoop::ApacheHandler. under mod_perl1, this needs to get loaded first
BEGIN {
	eval "use Apache::SIG" unless $Scoop::MP2;
}

#use Apache::DBI;
# If you want connect-on-init from Apache::DBI, 
# fill in the following variables just like
# in the httpd.conf file, and uncomment the following lines 
#my $db_name = 'scoop';
#my $db_host = 'localhost';
#my $db_user = 'nobody';
#my $db_pass = 'password';
#my $data_source = "DBI:mysql:database=$db_name:host=$db_host";
#Apache::DBI->connect_on_init($data_source, $db_user, $db_pass);

# Same for the archive database, if it exists
#my $archive_db_name = 'scoop_archive';
#my $archive_db_host = 'localhost';
#my $archive_db_user = 'nobody';
#my $archive_db_pass = 'password';
#my $data_source = "DBI:mysql:database=$archive_db_name:host=$archive_db_host";
#Apache::DBI->connect_on_init($data_source, $archive_db_user, $archive_db_pass);


if ($Scoop::MP2) {
	eval "
		use Apache2::RequestRec;
		use Apache2::RequestIO;
		use Apache2::Connection;
		use Apache2::RequestUtil;
		use Apache2::Const;
	";
} else {
	eval "use Apache::Constants ':response'";
}

# Convenient list of other libraries you'll need:
use DBI qw();
#use DBD::Pg qw();
use Mail::Sendmail qw();
use Math::BigFloat qw();	# Included in perl dist
use Text::Wrap qw();			# Included in perl dist
use Class::Singleton qw();
use String::Random qw();
use Time::CTime qw();
use Time::Timezone qw();
use Time::ParseDate qw();
use Date::Calc qw();
use LWP::UserAgent qw();
use HTTP::Request qw();
use Crypt::CBC qw();
use Crypt::Blowfish qw();
use XML::RSS qw();
use MIME::Base64 qw();
# uncomment to use memcached in place of the native Scoop caching system
#use Cache::Memcached qw();

# Trackback support is optional. Load it if it's there.
eval { require Net::TrackBack };
# since we don't require Aspell support for Scoop, this has to be made
# optional, and may not be installed
eval { require Text::Aspell };

# If you're using the Linkpoint LPERL wrapper, first see doc/Linkpoint.howto,
# then, when you get to that step, uncomment the lines below.
#use LPERL::lperl;
#use Scoop::Billing;
#use Scoop::Billing::Linkpoint;
#use Scoop::Billing::Paypal;

# Now load up the local Scoop libs
use Scoop;
use Scoop::ApacheHandler;
use Scoop::Ads;
use Scoop::DB;
use Scoop::DB::SlaveUtils;
use Scoop::Interface;
use Scoop::Boxes;
use Scoop::Comments;
use Scoop::Search;
use Scoop::Hotlist;
use Scoop::CGI;
use Scoop::Polls;
use Scoop::Utility;
use Scoop::Cookies;
use Scoop::Statement;
use Scoop::Cache;
use Scoop::RDF;
use Scoop::Debug;
use Scoop::Cron;
use Scoop::Static;
use Scoop::Spellchecker;
use Scoop::Subscription;
use Scoop::Macros;
use Scoop::Session;
use Scoop::Tags;

use Scoop::Users;
use Scoop::Users::Prefs;
use Scoop::Users::NewUser;

use Scoop::Stories;
use Scoop::Stories::Views;
use Scoop::Stories::Elements;
use Scoop::Stories::Submit;
use Scoop::Stories::List;

use Scoop::Admin;
use Scoop::Admin::AdminStories;
use Scoop::Admin::Ads;
use Scoop::Admin::SiteControls;
use Scoop::Admin::Blocks;
use Scoop::Admin::Topics;
use Scoop::Admin::Users;
use Scoop::Admin::EditUser;
use Scoop::Admin::Sections;
use Scoop::Admin::Special;
use Scoop::Admin::Perms;
use Scoop::Admin::Groups;
use Scoop::Admin::PostThrottle;
use Scoop::Admin::Polls;
use Scoop::Admin::EditBoxes;
use Scoop::Admin::Subscription;
use Scoop::Admin::Ops;
use Scoop::Admin::Hooks;
use Scoop::Admin::Themes;
use Scoop::Admin::Prefs;
use Scoop::Admin::Logging;
use Scoop::Admin::Calendar;

use Scoop::Comments::Format;
use Scoop::Comments::Post;
use Scoop::Comments::Mojo;
use Scoop::Comments::Rate;

use Scoop::Polls::Forms;
use Scoop::Polls::Utils;

use Scoop::HTML::Parser;
use Scoop::HTML::Checker;

use Scoop::Ads::Info;
use Scoop::Ads::Submit;
use Scoop::Ads::Templates;
use Scoop::Ads::Utilities;

use Scoop::Calendar;
use Scoop::Calendar::Views;
use Scoop::Calendar::Events;
use Scoop::Calendar::EditCalendar;

# Coming soon
#use Scoop::Search::VectorSearch;

1;
