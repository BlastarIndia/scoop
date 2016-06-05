
https://dontsuemebro.com/story/2016/4/22/233036/772

Installing scoop on "modern" debian systems +Hotlist
Kuro5hin

By Del Griffith, Section News
Posted on Fri Apr 22, 2016 at 10:30:36 PM CST
Tags: scoop, kuro5hin, DSMB (all tags)
   
Well here we go.

We are going to install and RUN scoop on a modern communist debian system.

And the best part is that it works.... And it's really not that hard to tweak.

I'm using SUN's virtual box, as I have no interest installing Debian on my laptop.

Ok so let's get into materials.

First you'll need debian.
We don't need the 500TB install, or whatever the kids use these days.  We WILL require internet connectivity, so what the hell, get the "tiny cd" for your platform.

For 99% of you that'll be the i386.

http://www.debian.org/distrib/netinst#verysmall

Burn the image to a CDROM for those of you who want a physical machine, the rest of us using virtual box can download it here.

Next you'll need a copy of scoop.  The filename is:

scoop_1.1.8.tar.gz

I've uploaded a 'virgin' copy of it here.. while it lasts...

http://sourceforge.net/projects/scoop-cms/

I should also add that scoop needs RAM, lots of it.. I'm running it with 1gb of ram on my laptop (I have 4gb! get a modern machine).  Although it doesn't need a tonne of disk space, I'm starting with an 8gb virtual disk image.

Ok with all that bullshit out of the way, slap in your CDROM & boot your machine... Or for the virtual people mount your ISO image in the Virtual BOX app, and power the VM up..

Go ahead and slap enter a few dozen times, and build yourself a default machine.  Give it a great name, and some fancy password...  It doesnt matter.

In a few minutes it'll reboot the VM, and you'll be presented with your boring Debian VM.

Assuming you've built it right it'll have network access.  So let's get to the stuff that you'll probably want on a debian machine:

Install these two, and just hit Y where appropriate.  I like to ssh into my machines with something like putty.. it's got great cut&paste support.

apt-get install openssh-server
apt-get install sendmail-bin
Next we are going to install Apache2 along with some of the required bits for scoop.  This should be a snap.

apt-get install apache2.2-common
apt-get install apache2
apt-get install libapache2-mod-perl2
apt-get install expat
With me so far?

I hope so.

Ok so now we've got some barely functional apache system, the next thing we'll need is the mysql database.  This is surprisingly easy to install.

apt-get install mysql-server mysql-client
During the install it'll prompt for a password & stuff.  Make ANOTHER one up.. save it somewhere!  We are going to cheat, and just use the root id all the way through, but this is a demonstration to show that scoop works on apache2.

After a few seconds (if you have a fast internet connection) you'll have your database running.

Now we need all these perl modules...  It's not that hard with debian, I did have a zillion issues with the CPAN install, but screw perl, we are here for scoop.

apt-get install libdbi-perl
apt-get install libdbd-mysql-perl
apt-get install libmd5-perl
apt-get install libapache-dbi-perl
apt-get install libapache2-request-perl
apt-get install libclass-singleton-perl
apt-get install libcrypt-unixcrypt-perl
apt-get install libmail-sendmail-perl
apt-get install libstring-random-perl
apt-get install libtime-modules-perl
apt-get install libdate-calc-perl
apt-get install libxml-parser-perl
apt-get install libcrypt-cbc-perl
apt-get install libcrypt-blowfish-perl
apt-get install libxml-rss-perl
apt-get install libcache-memcached-perl
apt-get install libtext-aspell-perl
Phew, that's a lot of modules, and let me tell you this is a LOT easier then the 'old' days...

Now we need to enable some apache module.

cd /etc/apache2/mods-enabled
ln -s ../mods-available/apreq.load .
Easy, right?

Now for the scoop.

I used the fine utility pscp to transfer my scoop to my virtual machine.  'del' is the user that I had created on the install.  I'm sure you picked out some other witty name.  Use that instead.

pscp scoop_1.1.8.tar.gz del@10.0.1.5
If you don't even know your machine's ip you can find it with:

ifconfig eth0
Ok now with that out of the way, we should extract it...

cd /usr/src
tar -zxvf ~del/scoop_1.1.8.tar.gz
Now we can happily run the install script which will build our database, and then spit out a broken config file which we can mash into apache 2... but we'll get back to that later.

Now there is a few files we need to patch to get running on Apache2..

I know there will be MORE stuff broken then this, but I've found this was enough to get me to login.
---
diff -ruN x/scoop-1.1.8/etc/startup.pl scoop-1.1.8/etc/startup.pl
--- x/scoop-1.1.8/etc/startup.pl        2006-04-26 23:52:47.000000000 -0400
+++ scoop-1.1.8/etc/startup.pl  2009-11-14 19:03:52.000000000 -0500
@@ -1,6 +1,6 @@
 #!/usr/bin/perl
 use strict;
-use mod_perl ();
+use mod_perl2();
 #BEGIN {
 #      eval "use mod_perl ()";
 #}
@@ -17,8 +17,9 @@
 }

 # Die unless we have mod_perl
-$ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/
-       or die "GATEWAY_INTERFACE not Perl!";
+#$ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/
+#       or die "GATEWAY_INTERFACE not Perl!";
+$ENV{MOD_PERL}=~/mod_perl/ or die "MOD_PERL not used!";

 BEGIN { $Crypt::UnixCrypt::OVERRIDE_BUILTIN = 1 }
 use Crypt::UnixCrypt;
diff -ruN x/scoop-1.1.8/lib/Scoop/ApacheHandler.pm scoop-1.1.8/lib/Scoop/ApacheHandler.pm
--- x/scoop-1.1.8/lib/Scoop/ApacheHandler.pm    2004-07-06 02:07:43.000000000 -0400
+++ scoop-1.1.8/lib/Scoop/ApacheHandler.pm      2009-11-14 18:49:56.000000000 -0500
@@ -23,7 +23,7 @@

 sub handler {
        my $r = shift;
-       Apache->request($r);
+       Apache2::RequestUtil->request($r);
        my $time; # = localtime(time());
        warn "\n<<ApacheHandler: $time>> I've got this one...\n" if $DEBUG;
        if ($PARANOID) {
@@ -83,7 +83,7 @@
        unless ($S->{OPS}->{$op} && $S->{OPS}->{$op}->{enabled}) {
             &n bsp;  $S->cleanup();
             &n bsp;  undef $Scoop::_instance;
-             & nbsp; return $Scoop::MP2 ? &Apache::DECLINED : &Apache::Constants::DECLINED;
+             & nbsp; return $Scoop::MP2 ? &Apache2::Const::DECLINED : &Apache::Constants::DECLINED;
        }

        # check to make sure the user has permission to to use this op
diff -ruN x/scoop-1.1.8/lib/Scoop.pm scoop-1.1.8/lib/Scoop.pm
--- x/scoop-1.1.8/lib/Scoop.pm  2006-04-26 23:52:47.000000000 -0400
+++ scoop-1.1.8/lib/Scoop.pm    2009-11-14 18:51:04.000000000 -0500
@@ -816,7 +816,8 @@
 =cut
 sub _set_apache_request {
        my $self = shift;
-       my $r = Apache->request();
+#      my $r = Apache->request();
+       my $r = Apache2::RequestUtil->request();

        # set {APACHE} to the request obj
        $self->{APACHE} = $r;
@@ -835,8 +836,8 @@
 sub _set_request_params {
        my $self = shift;

-       use Apache::Request;
-       my $q = Apache::Request->new( $self->{APACHE} );
+       use Apache2::Request;
+       my $q = Apache2::Request->new( $self->{APACHE} );
        $self->{APR} = $q;

        my $all_args = {};
Save the file into something like scoop.patch, and you can run it as

patch -p1 <scoop.patch
Now we can run the setup script.
# cd /usr/src/scoop-1.1.8/scripts
# ./install.pl
You can follow this session, but you'll get the general idea.
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

Continue? [Y]/n > y

I'm making sure you're running as root or with root
permissions right now...  you are! Excellent.

To aid in the install process, I need to know what directory is
your unpacked scoop tarball.  If you are running this from the
scripts directory then the default should be fine. Otherwise,
specify one below
[/usr/src/scoop-1.1.8] >

Scoop needs some CPAN libraries to operate properly. We're
going to try to fetch and install them for you now.

You must be connected to the internet to do this step. If
you need to connect, please do so, and press return when
you're ready.

Enter "N" if you cannot connect to the net now, or you wish to
skip installing CPAN libs.

Continue? [Y]/n > n

You can't get online? Yipes. Well, now you have a choice. If
you know you have all the modules below, you can try to continue
with the install. Otherwise, you'll have to wait till you
can get online.

Modules needed by Scoop are in the Bundle at  lib/Bundle/Scoop.pm

To install them later, just run scripts/install-cpan.pl

Try to continue installing Scoop anyway? y/[N] > y

Ok, now we're in the part where I set up and configure
your Scoop database. If you already have a Scoop DB, you
can skip this part entirely. Note that if you only want to
do part of the DB configuration, you'll have more chances
to skip stuff below.

Configure database? [Y]/n > y

I need some information to connect to your database. First,
please enter the user you wish to connect as for the
install. This user must have full privileges to create
databases and grant permissions to others. Default is root,
and you're probably best sticking with that. You will be
prompted for the user that apache will use to connect to
scoop's database as in a moment.

Database user I should connect as? [root] >

Ok, now I need the password that root will connect with.
It will not echo to the screen, for security purposes, so
don't be surprised when it doesn't show up when you type.

Password for root? >
Please type your password again for confirmation
password? >

Next, I need to know what hosts you will be running apache on.
Most likely, you're running apache and the SQL server on the
same server, so this will just be localhost. However, if you
have a more complex set up, then you can enter a comma delimited
list of hostnames or IPs that will be connecting to the SQL server.

Apache hosts? [localhost] >

Now I need the host that MySQL is running on.

MySQL host? [localhost] >

And of course the port to address...

MySQL port? [3306] >

Ok, I have a connection to the database. Now, you can either
create a new database from scratch, or you can rebuild an
existing one. Note that rebuilding an old database will
COMPLETELY ERASE the old data. Only choose this option if
you really mean it! Normally, you'll want to create a fresh
database from scratch.

Choose one:
(1) Create a new database?
(2) Drop and rebuild an old database?

Please enter 1 or 2: [1] > 1

Database name? [scoop] >

I need to know where the scoop.sql file is, which contains the
default database dump. Normally, it's located in
scoop/struct/scoop.sql. If you'd like to use a different file,
please enter the path and name below:

DB Dump? [/usr/src/scoop-1.1.8/struct/scoop.sql] >

I need to know the path you'll be accessing Scoop under on your
Apache server. That is, if you plan to run something like:
"http://www.mysite.com/scoop", you'd enter "/scoop" below. If
Scoop will be running as the root path on it's own host, just
leave the following blank.

Scoop URL path? [] >

When you first set up Scoop, we will add a default superuser. What
should this account be named? [scoop] > YOURADMINID

Please enter a password to use for this account below. It must be
at least 8 characters long. This password will not be echoed to the
screen either, as was the database password.

Default password for YOURADMINID? >
Please type your password again for confirmation
password? >

In order for user registrations to work, and admin alerts to be
sent, Scoop needs to know your valid e-mail adress. This can be
changed later, if needed.

Admin email address? [YOURADMIN@YOURDOMAIN.com] >

Ok, now we're going to create your new Scoop database!

Creating scoop...done
Switching to scoop...done
Dumping data into scoop...done
New database inserted, now we'll customize it for your site...

Setting path... done
Setting image path... done
Setting e-mail address... done
Setting password for admin user... done.
Setting realemail for admin user... done.
Setting nickname for admin user... done.
Giving user root@localhost proper permissions to scoop... done.
Ok! Your scoop database is all set up. Only one more phase to
go, and your site will be ready.

Do you want me to help you configure apache for you now?  What
I'll do is output the relevant part of the apache configuration
for you to a file, then you can use 'Include' to include it
in your apache configuration.  Or you can skip this step and
configure apache by hand.
NOTE: if you skipped the database configuration step, then you
will need to edit the file output from this step and add in
the database information.

Configure Apache? [Y]/n > Y

Now we're going to configure your webserver. I see by the path
you entered that you're doing a virtual host based install.
Location installs are for when you want to access your site
via a path after your site name, like http://a.b.com/myscoopsite
Virtual Host installs are for when you set up a separate site
just for scoop. i.e. your usual site is http://www.mysite.com/
but scoop will run on http://scoop.mysite.com/

Do you want a virtual host based install? [Y]/n > y

I'll need to get the sample httpd-vhost.conf file to base your
site configuration on. Again, if you're running this from scripts/
it's probably located in the default below, but enter a different
location if it's not there.  There will be no default below
if I couldn't find the httpd-vhost.conf in the default location.
Remember, this path must be absolute!

Sample httpd-vhost.conf?
[/usr/src/scoop-1.1.8/etc/httpd-vhost.conf] >

Ok, I found it. Now I need to know some more about your site.

For scoop to work fully, I need to know what version of mysql you
are running.  As of right now, the stable versions are 3.23 or 4.0,
and the development is 4.1. If you are running MySQL 4.0x or 4.1x,
you can choose the appropriate database version to allow Scoop to use
features specific to that series. Otherwise, just use 3.23. MySQL 3.22
is still supported but deprecated, so if you're still running 3.22,
you should seriously consider upgrading.

[3.23]>

What are you going to call your site?  This is not necessary for
anything other than a small comment that will go in the apache
config file, just for ease of administration, and my own sense
of completeness :-)

site name [myscoopsite]>

For cookies to be set correctly (which is needed for user accounts)
I need the hostname to set in the cookies.  An ip will work, or a
hostname, but the hostname needs at least 2 dots. i.e.
www.kuro5hin.org and .kuro5hin.org will work, but kuro5hin.org
will not.  This needs to be the name that people use to access your
scoop site.

cookie host [debian.YOURDOMAIN.com] >

To send email out to your users, when they create accounts, or if
they are using the digest feature, I will need a valid smtp server.
Without one, you cannot create any accounts.  This should probably
be the same smtp server you use for your personal email, or the one
that your isp provides you to use.

smtp server [localhost] >

If you are going to run multiple scoop sites, each will need to have
a unique site identifier.  If you are going to only run one scoop
site, the default will be fine.

siteid [myscoopsite]>

I need to know what ip address to attach this virtual host to.
By default it will be 127.0.0.1, which is what you should use
only if you only want to be able to access your scoop site from
this computer.  It will probably be the external ip of your
computer.

IP Address [127.0.0.1]>

Do you have any other virtual hosts already set up on this ip
address?  If you just installed apache, you won't have any set up
currently.

Other vhosts? y/[N] >

What will be the name of this scoop site?  This is what people
will type into their browser to get to your scoop site.

Server Name > bob

Please enter a location for your error logs. You can use the same
location as for another site, but the logs will be mixed.

Error Log [logs/scoop-error_log]>

Now I need the custom log location, this is where all of the regular
requests for scoop will go.

Common Log [logs/scoop-access_log]>

Cool!  It looks like your Apache config is all set up.  I will
output this configuration file to httpd-myscoopsite.conf in this
directory.  To finish configuring Apache, just write a line like
Include /path/to/httpd-myscoopsite.conf at the end of your apache
httpd.conf file.  Usually that file is at /usr/local/apache/conf/httpd.conf.

<More>

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
debian:/usr/src/scoop-1.1.8/scripts#

Now it'll spit out some exciting config that WILL NOT WORK although it's easy to massage into a 'nice' template.
cd /etc/apache2/sites-available
And create a file called scoop. and let's put the following into it:
<VirtualHost *:80>
  ServerAdmin webmaster@localhost
  ServerName SERVERNAME
  DocumentRoot /usr/src/scoop-1.1.8/html
  #ErrorLog logs/scoop-error_log
  #CustomLog logs/scoop-access_log combined
  PerlConfigRequire /usr/src/scoop-1.1.8/etc/startup.pl

  <Location>
        PerlSetVar DBType mySQL
        PerlSetVar mysql_version 3.23
        PerlSetVar db_name scoop
        PerlSetVar db_host localhost
        PerlSetVar db_user root
        PerlSetVar db_pass YOURDBPASSWORD

        PerlSetVar cookie_host debian.YOURNETWORK.com
        PerlSetVar SMTP localhost
        PerlSetVar site_id myscoopsite
        PerlSetVar site_key 3f963d11ec08a87683ce030cece8f6990fd8efd297cd24acd9189606
        PerlSetVar dbdown_page /pages/dbdown.html

    SetHandler perl-script
    PerlHandler Scoop::ApacheHandler
  </Location>

  <Location /images>
    SetHandler default-handler
  </Location>

  <Location /pages>
    SetHandler default-handler
  </Location>

  <Location ~ "^/(robots\.txt|favicon\.ico)$">
    SetHandler default-handler
  </Location>

        ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
        <Directory "/usr/lib/cgi-bin">
             &n bsp;  AllowOverride None
             &n bsp;  Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
             &n bsp;  Order allow,deny
             &n bsp;  Allow from all
        </Directory>

        ErrorLog /var/log/apache2/error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog /var/log/apache2/access.log combined

        Alias /images "/usr/src/scoop-1.1.8/html/images"
        <Directory "/usr/src/scoop-1.1.8/html/images">
        Options Indexes MultiViews FollowSymLinks
        Allow from all
        </Directory>

</VirtualHost>
Ok, now that was fun. Now we have to 'link' this config into apache.
# cd /etc/apache2/sites-enabled
# rm 000-default
# ln -s /etc/apache2/sites-available/scoop 000-default
Ok now we are almost there. Now you just have to simply pull out the relevent bits from the generated httpd conf and put them into 000-default.
Fix the following lines:
These need to be replaced with the values you have in your /usr/src/scoop-1.1.8/scripts/httpd-myscoopsite.conf file.
ServerName SERVERNAME
PerlSetVar db_pass YOURDBPASSWORD

PerlSetVar cookie_host debian.YOURNETWORK.com

PerlSetVar site_key 7017eadb34b9dba0453e9ad824589af50ed88fd28e1432dfd6075d4f

Ok, just a few more things and we should be golden! We are going to link in scoop from apache... I know it's nasty, but who cares? This VM is BORN TO RUN SCOOP!
cd /etc/apache2
ln -s /usr/src/scoop-1.1.8/lib/Scoop.pm .
ln -s /usr/src/scoop-1.1.8/lib/Scoop .

Now we can test our configuration!!!
If all goes well, you'll get:
apache2ctl configtest
Syntax OK

Ok! Let's fire it up!
apache2ctl stop
apache2ctl start

Now if you hit the VM up in a browser you SHOULD see scoop in all its glory. Now if you try to logon and do stuff, it'll all fuck up because you need to create a hosts entry for the SERVERNAME bit above... Otherwise the cookies won't work and it'll constantly demand you to logon.
You can always try to troubleshoot stuff by looking in /var/log/apache2/error.log 
