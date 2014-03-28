=head1 Utility.pm

This file contains general utilities that are of use to more than one module in
scoop. Thus they have been put in here for easy maintenance.

=cut

package Scoop;
use strict;
use vars qw(%Escapes $Escapes_built);

my $DEBUG = 0;

=over 4

=item * var(name, [value])

This quite simply provides access to the $S->{UI}->{VARS} object through the interface $S->var('foo')

=cut

sub var { $_[2] ? $_[0]->{UI}->{VARS}->{$_[1]} = $_[2] : $_[0]->{UI}->{VARS}->{$_[1]} }

=item * get_file_list($uid, $list_type)

This returns a list of files in the uploads path, depending on on the $list_type
specified.  It defaults to a listing of the files the user uploaded.

=cut

sub get_file_list {
	my $S = shift;
	my $uid = shift || $S->{UID};
	my $list_type = shift || 'user';

	# no messing around at all if we don't allow uploads
	return '' unless $S->var('allow_uploads');

	my (@files, $path);
	if ($list_type eq 'user') {
		$path = $S->var('upload_path_user') . $uid;
	} else {
		# make sure they can upload admin files before even viewing them
		return @files unless $S->have_perm('upload_admin');
		$path = $S->var('upload_path_admin');
	}
	warn "opening dir $path" if $DEBUG ;
	if (opendir (UserDir, $path)) {
		while (my $file = readdir (UserDir)) {
			push(@files, $file) if -f "$path/$file";
		}
		closedir (UserDir);
	}
	return (@files);
}

=item * display_upload_form()

This will display an upload form, depending on the permission that the user has.
It requires the global "allow_uploads" var to be set, and at lease one of the
upload permissions.  If the user has more than one permission a drop-down box
will allow you to choose where you want the file uploaded to.

=cut

sub display_upload_form{
 	my $S = shift;
	my $build_form = shift || 0;
	my $form_type  = shift || 'content';
	my $return;

	if ($S->var('allow_uploads')) {
		my $options_count = 0;
		my $single_option = 'none';
		my $options = qq{
			<select name="file_upload_type" size="1">
			<option value="none">Select Upload Type</option>};

		if ($form_type eq 'content' && $S->have_perm('upload_content')) {
			$options_count++;
			$single_option = 'content';
			$options .= '<option value="content">Upload as content</option> ';
		}
		if ($form_type eq 'files' && $S->have_perm('upload_admin')) {
			$options_count++;
			$single_option = 'admin';
			$options .= '<option value="admin">Upload to Admin area</option> ';
		}
		if ($form_type eq 'files' && $S->have_perm('upload_user')) {
			$options_count++;
			$single_option = 'user';
			$options .= '<option value="user">Upload to User area</option> ';
		}
		if ($options_count>0) {
			$return.=qq{
				%%norm_font%%<B>Upload File:</B>%%norm_font_end%%<br/>
				<INPUT type="file" name="file_upload" size="40"/>
				};
			if ($options_count == 1) {
				$return .= qq{<INPUT type="hidden" name="file_upload_type" value="$single_option">};
			} else {
				$return .= " $options" . '</select>';
			}
		}
		if ($build_form) {
			$return = qq{
				<form NAME="special" ACTION="" METHOD="post" enctype="multipart/form-data">
				$return
				<input TYPE="submit" NAME="write" VALUE="Upload"/>
				</form>};
		}
	}
	return $return;
}

=item * get_file_upload($file_upload type)

This routine checks for an incoming uploaded file.  If the $file_upload_type is
'content' than it will return the contents of the file.  If the
$file_upload_type is set otherwise it will save the file in the approprate
location.

=cut

sub get_file_upload {
	my $S = shift;
	my $file_upload_type = shift;

	return ('', '', 0, '') if $file_upload_type eq 'none';

	my ($save, $path, $file_link);
	$save = 1 unless $file_upload_type eq 'content';
 
	my $upload = $S->{APR}->upload;
	my ($filename, $size) = ($upload->filename, $upload->size);
	$filename =$S->clean_filename($filename);

	return ('returning because of no file to upload', '', 0, '') if $size == 0;

	if ($file_upload_type eq 'user') {
		return ('No permission to write to user path', '', 0, '') 
			unless $S->have_perm('upload_user');
		$save = 1;
		$path = $S->var('upload_path_user') . $S->{UID};
		$file_link .= $S->var('upload_link_user') . $S->{UID} . "/$filename";

		unless(-d $path) {
			return("Couldn't create directory to save upload", '', 0, '')
				unless ( mkdir($path, 0755) );
		}
		
		# check for exceeded disk space before we write the file
		# XXX - this shouldn't depend on an external program
		my $quota = $S->pref('upload_user_quota');
		if ($quota != 0) {
			my $claimed_size = `du -sb $path`;
			my $dummy;
			$claimed_size =~ s/\n+//;
			($claimed_size, $dummy) = split /\s+/, $claimed_size;
			if ( ($claimed_size + $size) > ($quota * 1024) ) {
				return ("Cannot upload, user has exceeded maxiumum disk quota ($quota K)", '', 0, '')
			}
		}

	} elsif ($file_upload_type eq 'admin') {
		return ('No permission to write to admin path', '', 0, '') 
			unless $S->have_perm('upload_admin');
		$save = 1;
		$path = $S->var('upload_path_admin');
		$file_link .= $S->var('upload_link_admin') . "$filename";
	}

	$path .= "/" . $filename;

	if ($DEBUG) {
		warn "name : " . $upload->name;
		warn "filename : " . $upload->filename;
		warn "size : " . $size;
		warn "type : " . $upload->type;
		warn "path : " . $path;
	}

	# we need to check that they don't upload a file that is too big,
	# so get the max kbyte count, and start counting chars
	# within the while() loop.  If they get too big, break, remove
	# the file, and throw an error

	my $max_bytes = $S->pref('upload_max_file_size') * 1024;
	if (($max_bytes < $size) && ($max_bytes ne 0)) {
		return("Sorry, but you can't upload files larger than <b>$max_bytes</b> bytes", '', 0, '');
	}

	if ($save) {
		warn "Saving new file as $path" if $DEBUG;
		unless (open(OUTFH, ">$path")) {
			warn "Couldn't open file $path: $!";
			return ("Couldn't create file to save upload", '', 0, '');
		}
	}

	my $getfile;
	my $uploadfh = $upload->fh;
	my $cur_size = 0;
	my $chunk;
	# read only as much as the client said it's sending, so that it can't try
	# and trick us into getting a file that's too large
	while ($cur_size < $size) {
		my $remaining = $size - $cur_size;
		my $read_size = ($remaining < 4096) ? $remaining : 4096;
		my $length = read($uploadfh, $chunk, $read_size);
		$cur_size += $length;

		if ($save) {
			print OUTFH $chunk;
		} else {
			$getfile .= $chunk;
		}
	}
	close($uploadfh) or warn "Couldn't close upload temporary file: $!";

	if ($save) {
		close(OUTFH) or warn "Couldn't close file $path : $!";
		chmod(0644, $path);
		warn "Finished saving file $path" if $DEBUG;
		
		# Run new upload hook
		$S->run_hook('file_upload', $path);
	}

	# $getfile will be empty unless we are returning content to a form
	return( $getfile, $filename, $size, $file_link);
}

=item * clean_filename($filename)

This will take a passed $filename and clean it up for saving to disk.  The
purpose is to avoid uploading any harmful characters, and will replace them
with the underscore instead.  Thank you jcg for these regexes.

=cut

sub clean_filename {
	my $S = shift;
	my $filename = shift;

	# strip off everything up until the last \ or / -- because of how MSIE handles <input type="file"> uploads
	$filename =~  s#^[A-Za-z]:[\\/].*[\\/]([^\\/]+)$#$1#;
	#
	$filename =~  s/[^\w.]/_/g;
	return $filename;
}


=item * save_file_upload($advertiser_id,$tmpl)

This will get a file though the Apache::Request object, and save it
to the directory $S->{UI}->{VARS}->{ad_files_base}/$advertiser_id/
It returns the filename that it saved it as, the file size in bytes,
and an error message.  The error message will only contain something
if there was an error.

$tmpl is the name of the ad template that this file will display
under (used to check max_file_size)

=cut

sub save_file_upload {
	my $S = shift;
	my $adver_id = shift;
	my $tmpl = shift;

	my $base_path = $S->{UI}->{VARS}->{ad_files_base};
	$base_path =~ s/\/$//;
	my ($filename, $size, $errmsg);

	# first check to see if the output directory exists, if not, create it.
	unless (-d "$base_path/$adver_id") {
		return ('','',"Couldn't create directory to save upload")
			unless $S->make_ad_path($adver_id);
	}

	my $upload = $S->{APR}->upload;

	# don't use their filename!  bad bad bad!
	my $random_fn = $S->rand_stuff(7);
	($filename, $size) = ($upload->filename, $upload->size);
	$filename =~ /\.(\w+)$/;
	$random_fn = "${random_fn}.$1";
	my $abs_filename = "$base_path/$adver_id/$random_fn";
	warn "abs_filename is $abs_filename";

	if ($size eq 0) {
		warn "returning because of no file to upload";
		return ('', 0, '');
	}

	warn "name : " . $upload->name if $DEBUG;
	warn "filename : " . $random_fn if $DEBUG;
	warn "size : " . $size if $DEBUG;
	warn "type : " . $upload->type if $DEBUG;

	# we need to check that they don't upload a file that is too big,
	# so get the max kbyte count, and start counting chars
	# within the while() loop.  If they get too big, break, remove
	# the file, and throw an error
	my $tmpl_info = $S->get_ad_tmpl_info($tmpl);
	my $max_bytes = $tmpl_info->{max_file_size} * 1024;
	if ($size > $max_bytes) {
		return ('', '', "Sorry, but you can't upload files larger than <b>$max_bytes</b> bytes");
	}

	unless (open(OUTFH, ">$abs_filename")) {
		warn "Couldn't open file $abs_filename: $!";
		return ('','',"Couldn't create file to save upload");
	}

	warn "Saving new file as $abs_filename" if $DEBUG;
	my $uploadfh = $upload->fh;
	while (my $line = <$uploadfh>) {
		print OUTFH $line;
	}
	close(OUTFH) or warn "Couldn't close file $abs_filename : $!";
	close($uploadfh) or warn "Couldn't close upload temporary file: $!";

	chmod(0644, $abs_filename);

	warn "Finished saving file $abs_filename" if $DEBUG;

	return ($random_fn, $size, $errmsg);
}

=item * remove_ad_file($adver_id, $filename)

Deletes an ad file from a user's directory

=cut

sub remove_ad_file {
	my $S = shift;
	my ($adver_id, $filename) = @_;

	my $base = $S->{UI}->{VARS}->{ad_files_base};
	$base =~ s/\/$//;

	my $path = "$base/$adver_id/$filename";
	unlink($path) || return $!;

	return 1;
}

=item * make_ad_path($adver_id)

This makes all of the directories necessary to store advertising files

=cut

sub make_ad_path {
	my $S = shift;
	my $adver_id = shift;

	my $path = $S->{UI}->{VARS}->{ad_files_base};
	$path =~ s/\/$//;
	$path .= "/$adver_id";

	warn "Making directory $path\n" if $DEBUG;
	unless( mkdir ($path, 0755) ) {
		warn "Can't create directory $path: $!";
		return 0;
	}

	return 1;
}

=item * time_absolute_to_seconds(string)

Converts a string in the form "yyyy-mm-dd hh:mm:ss" to second since the epoch
and returns that.

=cut

sub time_absolute_to_seconds {
	my $S = shift;
	my $str = shift;

	$str =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;

	my @date = ($6, $5, $4, $3, $2, $1);
	$date[4] -= 1;  # month

	require Time::Local;
	return Time::Local::timelocal(@date);
}

=item * time_relative_to_seconds(string)

Takes a string which represents an interval of time and changes it into
seconds. Example: "1h30m25s" would be 1 hour, 30 minutes, and 25 seconds from
now, or 5425 seconds.

The useable characters are s (seconds), m (minutes), h (hours), d (days), w
(weeks), M (months), and Y (years).

When parsing, spaces are removed, a trailing plus sign (if any) is removed, and
an 's' is added to the end if the last character is a number.

=cut

sub time_relative_to_seconds {
	my $S = shift;
	my $str = shift || return;

	$str =~ s/\s//g;
	$str =~ s/^\+//;
	$str .= 's' if $str =~ /\d$/;

	my $parts = $S->_time_parts_hash();
	my $suffs = join('', '[', keys %{$parts}, ']');

	my $secs = 0;
	while ($str =~ /(\d+)($suffs)/go) {
		$secs += $1 * $parts->{$2};
	}

	return $secs;
}

=item time_seconds_to_relative(integer)

Takes a number of seconds and converts it into the relative form as used by
C<time_relative_to_seconds>. The individual parts will be seperated by spaces.

=cut

sub time_seconds_to_relative {
	my $S = shift;
	my $secs = shift || return;

	my ($divs, $suffix) = $S->_time_parts_array();

	my $idx = 0;
	my @string_parts;

	do {
		my $newval = int($secs/$divs->[$idx]);
		push(@string_parts, ' ', $newval, $suffix->[$idx]) if $newval > 0;
		$secs -= $newval * $divs->[$idx];
		$idx++;
	} while ($secs > 0);

	shift(@string_parts);

	return join('', @string_parts);
}

sub _time_parts_hash {
	my $S = shift;

	my $parts = {};
	my ($divs, $suffs) = $S->_time_parts_array();

	for (my $idx = 0; $idx < scalar(@{$suffs}); $idx++) {
		$parts->{ $suffs->[$idx] } = $divs->[$idx];
	}

	return $parts;
}

sub _time_parts_array {
	return (
		[ 60*60*24*365, 60*60*24*30, 60*60*24*7, 60*60*24, 60*60, 60, 1 ],
		[ qw( Y M w d h m s ) ]
	);
}

=item *
time_localize_array($year,$month,$day,$hour,$min,$sec[,$server_time,$tz])

This takes an array of date/time variables in UTC and returns a similar array
localized to the provided (optional) time zone or the user's chosen timezone.
If the timezone variable is not provided, the current user's preference is
used.

If the date being converted is from the system time, $server_time must be true;
if the date being converted is UTC (ie, from storage) $server_time must be
false.

=cut

sub time_localize_array {
	my $S = shift;
	my $year = shift;
	my $month = shift;
	my $day = shift;
	my $hour = shift;
	my $min = shift;
	my $sec = shift;
	my $server_time = shift;
	my $zone = uc(shift) || uc($S->pref('time_zone'));

	# convert to utc first, if we're fed the server's time
	if ($server_time) {
		($year,$month,$day,$hour,$min,$sec) = $S->time_to_utc_array($year,$month,$day,$hour,$min,$sec,$S->var('time_zone'));
	}

	# get the difference in seconds between the user's time zone and UTC in seconds
	my $user_offset = &Time::Timezone::tz_offset(lc($zone));
	warn "(time_localize_array) localizing UTC to $zone" if $DEBUG;
	warn "(time_localize_array) input time is $year-$month-$day $hour:$min:$sec" if $DEBUG;
	my $epoch = Date::Calc::Date_to_Time($year,$month,$day,$hour,$min,$sec);
	$epoch += $user_offset;
	($year,$month,$day,$hour,$min,$sec) = Date::Calc::Time_to_Date($epoch);
	warn "(time_localize_array) output time is $year-$month-$day $hour:$min:$sec" if $DEBUG;
	
	return ($year,$month,$day,$hour,$min,$sec);
}

=item *
time_to_utc_array($year,$month,$day,$hour,$min,$sec[,$tz])

This takes an array of localized date/time variables plus an optional time zone
and returns an array converted to UTC for storage. If the timezone variable is not
provided, the current user's preference is used.

=cut

sub time_to_utc_array {
	my $S = shift;
	my $year = shift;
	my $month = shift;
	my $day = shift;
	my $hour = shift;
	my $min = shift;
	my $sec = shift;
	my $zone = uc(shift) || uc($S->pref('time_zone'));

	# get the difference in seconds between the user's time zone and UTC in seconds
	my $user_offset = &Time::Timezone::tz_offset(lc($zone));
	warn "(time_to_utc_array) localizing $zone to UTC" if $DEBUG;
	warn "(time_to_utc_array) input time is $year-$month-$day $hour:$min:$sec" if $DEBUG;
	my $epoch = Date::Calc::Date_to_Time($year,$month,$day,$hour,$min,$sec);
	$epoch -= $user_offset;
	($year,$month,$day,$hour,$min,$sec) = Date::Calc::Time_to_Date($epoch);
	warn "(time_to_utc_array) output time is $year-$month-$day $hour:$min:$sec" if $DEBUG;

	return ($year,$month,$day,$hour,$min,$sec);
}

=item *
count_words($string)

This returns the number of words in a string passed to it.  Useful for checking the
number of words in a post or story.  Disregards all html, not the best way 
though, it should probably use HTML::Parser, but for now this is fine.

=cut

sub count_words {
	my $S = shift;
	my $string = shift;

	# First filter HTML for validity.
	$string = $S->filter_comment($string);

	# note that the html checker can result in errors, but we ignore them
	
	# get rid of all html... not very well. someday use HTML::Parser instead
	# the /s is so that . can span newlines
	$string =~ s/<[^>]*?>//sg;
	
	# get all of the words into an array
	my $word_c = my @word_a = split(/ /, $string );

	# return the size of the array
	return $word_c;
}

=item *
count_chars($string)

Returns the number of characters in the string, disregarding html.  Same html parsing problem
as above.

=cut

sub count_chars {
	my $S = shift;
	my $string = shift;
	
	# First filter HTML for validity.
	$string = $S->filter_comment($string);

	# note that the html checker can have errors, but we ignore them

	# get rid of all html 
	# the /s is so that . can span newlines
	$string =~ s/<[^>]*?>//sg;
	
	# get all of the characters into an array
	my $char_c = my @char_a = split( //, $string );

	# return the size of the array
	return $char_c;
}


=item *
make_url($op, $what)

This makes a url, it appears to be unfinished, since there are scalars that are unused.
odd.  We'll see if we can finish it up...   -A 2.23.00

=cut

sub make_url {
    my $S = shift;
    my $op = shift;
    my $what= shift;
    
    my %easy_ops = ("section"		=> 1,
					"topic"			=> 1,
					"displaystory"	=> 1 );

    my %tool_names = (	"admin"			=> "tool",
						"user"			=> "tool",
						"displaystory"	=> "sid",
						"special"		=> "page",
						"section"		=> "section");
		       
    my $path = '';
    my $query = '';

	# doesn't look like this will ever happen...
    if( $S->{UI}->{VARS}->{use_easy_urls} && $easy_ops{$op} ) {

		# this is a technically unnecessary kludge
		$op =~ s/displaystory/story/;
		#ok, done

		$path = "$op/$what";

    } else {

		$query .= sprintf( 'op=%s', $op );
		$query .= sprintf( ';%s=%s;', $tool_names{$op}, $what ) if( $what );

	}
   
	$query .= join( ';', @_ );
	$query = '?' . $query if $query;

	my $url = qq|%%rootdir%%/$path$query|;

	return $url;
}


=item *
make_anchor($op, $what)

This just calls make_url, and encapsulates its return value in <A HREF="">

=cut

sub make_anchor {
    my $S = shift;
    my $url = $S->make_url( @_ );

    return qq|<A HREF="$url">|;
}

=item *
filter_url( $string )

Filters a url for display.  Filters the same as for comment
subjects but ignores the & -> &amp; conversion

=cut

sub filter_url {
	my $S = shift;
	my $url = shift;

	$url = $S->filter_subject($url);
	$url =~ s/&amp;/&/g;

	return $url;
}

=item *
urlify( $string )

This escapes a string, useful for providing links when some of the args in
contain non-alphanumeric characters. Escapes everything except letters,
numbers, underscore, period, and dash.

=cut

sub urlify {
	my $S = shift;
	my $string = shift;

	$S->_build_url_escapes() unless $Escapes_built;

	$string =~ s/([^A-Za-z0-9_.-])/$Escapes{$1}/g;

	return $string;
}

sub _build_url_escapes {
	foreach (0..255) {
		$Escapes{chr($_)} = sprintf("%%%02X", $_);
	}

	$Escapes_built = 1;
}

=item * deurlify( $string )

Does the opposite of C<urlify>, changing hex-encoded characters into their
actual characters.

=cut

sub deurlify {
	my $S = shift;
	my $string = shift;

	$string =~ tr/+/ /;
	$string =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/eg;

	return $string;
}

sub strip_invalid {
	my $S = shift;
	my $string = shift;

	$string =~ s/([\x00-\x1F])/"&#".ord($1).";"/eg;
	$string =~ s/([\x80-\x9F])/"&#".ord($1).";"/eg;

	return $string;
}

sub make_formkey {
	my $S = shift;
	
	my $new_key = $S->{SESSION_KEY}.':'.$S->{REMOTE_IP}.':';
	$new_key .= $S->_random_pass();
	
	return $new_key;
}

sub set_new_formkey {
	my $S = shift;

	my $keys = $S->session('formkeys') || [];

	unshift(@{$keys}, [$S->make_formkey(), time()]);

	$S->session('formkeys', $keys);
	
	return;
}

sub check_formkey {
	my $S = shift;

	# Get the key sent in by the form
	my $input_key = $S->{CGI}->param('formkey');
	return 1 unless $input_key;

	# get the list of formkeys
	my $keys = $S->session('formkeys') || [];

	# look at all of the formkeys, checking for both the specified formkey, and
	# for expired formkeys
	my $found = 0;
	my $time = time();
	my $timeout = $S->{UI}->{VARS}->{formkey_timeout};
	foreach my $k (0..$#{$keys}) {
		if (!$found && ($keys->[$k]->[0] eq $input_key)) {
			$found = 1;
			splice(@{$keys}, $k, 1);
		} elsif (($time - $keys->[$k]->[1]) > $timeout) {
			splice(@{$keys}, $k, 1);
		}
	}
	return 0 unless $found;

	# save the (most likely) changed list of keys
	$S->session('formkeys', $keys);
	
	return 1;
}


sub get_formkey_element {
	my $S = shift;
	
	# Make sure there's a current formkey!
	my $keys = $S->session('formkeys') || [];

	# create a new one if there isn't
	unless (@{$keys}) {
		$S->set_new_formkey();
		$keys = $S->session('formkeys');
	}
	
	my $element = qq|<INPUT TYPE="hidden" NAME="formkey" VALUE="$keys->[0]->[0]">|;

	# make a new formkey, since this one is now used
	$S->set_new_formkey();
	
	return $element;
}

sub make_blowfish_formkey {
	my $S = shift;
	my $now = time();
	my $cipher = new Crypt::CBC($S->{CONFIG}->{site_key}, 'Crypt::Blowfish');
	
	my $key = $cipher->encrypt_hex("$S->{REMOTE_IP}:$now");
	
	return $key;
}

sub check_blowfish_formkey {
	my $S = shift;
	my $key = shift;
	
	my $cipher = new Crypt::CBC($S->{CONFIG}->{site_key}, 'Crypt::Blowfish');
	
	my $d_key = $cipher->decrypt_hex($key);
	my $now = time();
	
	my ($ip, $stamp) = split /:/, $d_key;
	my $time_diff = $now - $stamp;
	
	return 1 if (($ip eq $S->{REMOTE_IP}) && ($time_diff < 1800));
	return 0;
}

=item * plaintext_format( $comment, $noescapetags )

Performs filtering for plain text posting mode on the given comment/story
text. If $noescapetags evaluates to true, then HTML special characters
will not be touched

=cut

sub plaintext_format {
	my $S = shift;
	local $_ = shift;
	my $noescapetags = shift || 0;

	# Remove excess newlines from the front and end of the text
	s#^\n\s*\n##gs;
	s#\n\s*\n$##gs;

	# Perform standard plain-old-text conversions
	unless($noescapetags) {
	s#&#&amp;#g;
	s#"#&quot;#g;
	s#<#&lt;#g;
	s#>#&gt;#g;
	}
	s#\r##gs;
	s#\n\s*\n#<p>\n#gs;
	s#(?<!<p>)\n#<br>\n#gs;
	s#\t#&nbsp;&nbsp;&nbsp; #g;
	s#\xA0#&nbsp;#g;
	s#^ #&nbsp;#gm;
	s#  # &nbsp;#g;
	s#[\x00-\x08\x0B-\x1F]##g; # Nuke control characters
	# Change remaining non-ASCII chars to entities
	s!([^\n\t\x20-\x7E])!'&#'.ord($1).';'!ge unless $noescapetags;
	return $_;
}

=item * auto_format( $comment )

Performs plaintext formatting, and then calls the auto formatting routines
(for bold/italics, links, lists, etc.)

=cut

sub auto_format {
	my $S = shift;
	local $_ = shift;
	my $context = shift;

	# Since we'll be using high-bit characters to mark escaped characters,
	# turn existing ones into entities here.
	s!([\x80-\xFF])!'&#'.ord($1).';'!ge;
	# Escape significant characters preceded by a backslash
	s#\\\\#\xDC#g; # Escape double backslashes first
	s#\\<#\x81#g;
	s#\\>#\x82#g;
	s#\\&#\x83#g;
	s#\\"#\x84#g;
	s#\\(\S)#chr(ord($1)|0x80)#ge; # Mark the high bit
	# Change non-HTML-involved &< into entities
	s/&(?![A-Za-z0-9#]+;)/&amp;/g;
	s#<(?![A-Za-z/])#&lt;#g;
	# Perform plaintext formatting
	$_ = $S->plaintext_format($_, 1);
	# Run the URL linkifier here so that clean_html's word breaking doesn't
	# mess things up
	$_ = $S->_auto_linkify_urls($_);
	# Clean up HTML tags
	my $comment_ref = $S->html_checker->clean_html(\$_, $context);
	$_ = $$comment_ref;

	# Make non-HTML-involved <>&" easier to sniff out.
	s#&lt;#\x01#g; # \x01 == < for now
	s#&gt;#\x02#g; # \x02 == > for now
	s#&amp;#\x03#g; # \x03 == & for now
	s#&quot;#\x04#g; # \x04 == " for now

	# Escape any potentially special chars within tags and URLs exactly as if 
	# the user had escaped them with a backslash
	my $url_regexg = '(?:http|ftp|file)://(?:[^\s<]|\Z)+(?=[\s<]|\Z)';
	my $tag_regex = '<[^><]*?>';

	s!($url_regexg|$tag_regex)!
		my $a = $1;
		$a =~ s#([^a-zA-Z0-9])#chr(ord($1)|0x80)#ge;
		$a
	!ge;

	$_ = $S->_auto_bold_italic($_);
	$_ = $S->_auto_create_ul($_);
	$_ = $S->_auto_create_ol($_);

	# Switch back the marked characters
	s#([\x80-\xFF])#chr(ord($1)&0x7F)#ge;
	s#\x01#&lt;#g;
	s#\x02#&gt;#g;
	s#\x03#&amp;#g;
	s#\x04#&quot;#g;

	return $_;
}

=item * check_url( $url )

Removes characters from URL's that can trigger browser bugs.
As of writing, IE has a bug where a %002 in a url will cause
the status bar to stop displaying the url from that character.
rusty has said that almost any character matching %0\d+ will
trigger the bug.
Changed check to reflect this.

So http://www.cutekittens.org%002@www.cutepuppies.org/

Would display as http://www.cutekittens.org in the status bar.

=cut

sub check_url {
	my $S = shift;
	my $url = shift;

	warn "check_url : $url\n" if $DEBUG; 
	$url =~ s/%0\d+//g;

	return $url;
}

=item * _auto_linkify_urls( $comment )

Turns URLs into HTML links for plaintext mode.

=cut

sub _auto_linkify_urls {
	my $S = shift;
	local $_ = shift;
	# Don't match URLs with <> in them
	my $url_regex = '(?:http|ftp|file)://[^\s<>]+?';
	my $url_regexg = '(?:http|ftp|file)://[^\s<>]+'; # greedy
	
	# Mark URLs that are already in HTML attrs or links so we don't linkify
	# them
	s#(<[^>]+="[^">]*)($url_regex)#$1\x00$2#gso;
	s#(<a\s[^>]*href=[^>]*>[^<]*)($url_regex)#$1\x00$2#gso;

	# Grab expressions in brackets ('[]', '{}', or '<>', not '()')
	# and if they end in a URL, linkify them.
	s#\[([^\[][^]]+?)(?:\s|&nbsp;)*?($url_regex)\]#<a href="\x00$2">$1</a>#gmsio;
	s#{([^{][^}]+?)(?:\s|&nbsp;)*($url_regex)}#<a href="\x00$2">$1</a>#gmsio;

	s#\[($url_regexg)(?:\s|&nbsp;)+([^\[][^]]+?)\]#<a href="\x00$1">$2</a>#gmsio;
	s#{($url_regexg)(?:\s|&nbsp;)+([^{][^}]+?)}#<a href="\x00$1">$2</a>#gmsio;

	# Linkify all the remaining naked URLs
 	s#([^\x00]|^)($url_regex)(?=[.!?_*=]?[\s\n<()\[\]{}\x01\x02]|$)#$1<a href="$2">$2</a>#gmio;

	# Remove placeholder chars
	s#\x00##gs;
	return $_;
}

=item * _auto_bold_italic( $comment )

Makes bold, code, and italic HTML tags for text between asterisks, equal signs
and underscores, respectively.

=cut

sub _auto_bold_italic {
	my $S = shift;
	local $_ = shift;

	# Only match [*=_/] when there's no space between them and the affected
	# text
	s#(?<![A-Za-z0-9])/(\S|\S.*?\S)/(?=[^A-Za-z0-9]|<br>|<p>|$)#<em>$1</em>#gs;
	s#(?<![A-Za-z0-9])\*(\S|\S.*?\S)\*(?=[^A-Za-z0-9]|<br>|<p>|$)#<strong>$1</strong>#gs;
	s#(?<![A-Za-z0-9])=(\S|\S.*?\S)=(?=[^A-Za-z0-9]|<br>|<p>|$)#<code>$1</code>#gs;
	s#(?<![A-Za-z0-9])_(\S|\S.*?\S)_(?=[^A-Za-z0-9]|<br>|<p>|$)#<em>$1</em>#gs;

	# Special chars in URLs and tags have already been properly identified and
	# escaped - no need for these ad-hoc hacks.
		# Don't match '="' as a closing tag, as it is probably an attribute
		# s#(?<![A-Za-z0-9])=(\S|\S.*?\S)=(?=[^A-Za-z0-9"]|<br>|<p>|$)#<code>$1</code>#gs;
		# We have to make sure we don't match the / in closing tags or URLs
		# s#(?<![A-Za-z0-9/:<=])/(\S|\S.*?[^\s<:/])/(?=[^A-Za-z0-9]|<br>|<p>|$)#<em>$1</em>#gs;

	return $_;
}

=item * _auto_create_ul( $comment )

Creates bulleted lists from series of lines beginning in '* '.

=cut

sub _auto_create_ul {
	my $S = shift;
	local $_ = shift;

	# Match series of lines (at least two) beginning in '* ' or '- ',
	# eating up any <br> or <p> tags inserted by plaintext mode
	s#((?:<(?:br|p)>\n)?(?:^[*\-+]\s+.*(?:\n|$)){2,})#
		my $a = $1;
		$a =~ s!^[*\-+]!<li>!gm;
		$a =~ s!<br>(<|$)!$1!gm;
		$a =~ s!<p>(<|$)!$1!gm;
		"\n<ul>\n".$a."\n</ul>\n"
	#gme;
	return $_;
}

=item * _auto_create_ol( $comment )

Creates numbered lists from series of lines beginning in 'n. ', 'n) ' or 'n: ', where
n is a number of decimal radix.

=cut

sub _auto_create_ol {
	my $S = shift;
	local $_ = shift;

	# Match series of lines (at least two) beginning with numbers,
	# eating up any <br> or <p> tags inserted by plaintext mode
	s#((?:<(?:br|p)>\n)?(?:^[0-9]+[.):]\s+.*(?:\n|$)){2,})#
		my $a = $1;
		$a =~ s!^([0-9]+)[.):]\s+!<li value="$1">!gm;
		$a =~ s!<br>(<|$)!$1!gm;
		$a =~ s!<p>(<|$)!$1!gm;
		"\n<ol>\n".$a."\n</ol>\n"
	#gme;

	return $_;
}

=back

=cut

=item * js_quote( $text )

Quotes the given text to make it safe for interpolation into a javascript
string.

=cut

sub js_quote {
	my $S = shift;
	my $string = shift;
	return unless $string;
	# Interpolate the string here, so that %%replaced%% bits get escaped
	# as well
	$string = $S->interpolate($string, $S->{UI}->{BLOCKS});
	$string = $S->interpolate($string, $S->{UI}->{VARS});

	$string =~ s#\\#\\\\#g;
	$string =~ s#\n#\\n#g;
	$string =~ s#\r#\\r#g;
	$string =~ s#\t#\\t#g;
	$string =~ s#'#\\'#g;
	$string =~ s#"#\\"#g;
	$string =~ s#</SCRIPT>#&lt;/SCRIPT&gt;#g;
	$string =~ s#([^\x20-\x7E])#'\\x'.sprintf("%02x",ord($1))#ge;
	return $string;
}

=item $S->admin_save_filter($string)
=item $S->admin_display_filter($string,$db_get)

Does the appropriate filtering for strings that contain those troublesome pipes and %% 
The save filter also does the db quoting.

=cut

sub admin_save_filter {
	my $S = shift;
	my $string = shift;

	$string =~ s/\|/%%/g;
	$string =~ s/\\%%/\|/g;
	$string = $S->dbh->quote($string);

	return $string;
}

sub admin_display_filter {
	my $S = shift;
	my $string = shift;
	my $get = shift;

	$string =~ s/&/&amp;/g;
	$string =~ s/>/&gt;/g;
	$string =~ s/</&lt;/g;
	$string =~ s/"/&quot;/g;
	if ( $get ) {
		$string =~ s/\|/\\|/g;
		$string =~ s/\%\%/\|/g;
	}

	return $string;
}

=item $S->filter_param($val);

Pass through function to $S->filter_subject() to filter out user input.

=cut

sub filter_param {
	my $S = shift;
	my $val = shift;
	return $S->filter_subject($val);
	}

1;
