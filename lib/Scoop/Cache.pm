=head1 Cache

Methods for using and maintaining an in-memory data cache. All cached data is
kept in a hash that can be accessed with through methods, and timestamps used
to keep the cache in sync with the actual data are stored in the database. In
addition to the access methods, there are also a few that exist only for
compatibility with the old cache module. These should never be used when
writing new code, and when possible, old code should be shifted over to the new
methods.

=over 4

=cut

package Scoop::Cache;
use strict;
use vars qw( $Cache );

my $DEBUG = 0;

=item * new($S)

Creates a cache object and returns it. This will automatically initialize the
cache for usage.

=cut

sub new {
	my $pkg = shift;
	my $S = shift || return;

	my $class = ref($pkg) || $pkg;
	my $self  = bless {}, $class;

	$self->{scoop} = $S;
	$self->{id} = $S->CONFIG->{site_id};
	warn "[cache] Initializing for child $$. site_id: $self->{id}\n" if $DEBUG;

	# make sure the cache structure is setup correctly
	$Cache = {} unless $Cache && (ref($Cache) eq 'HASH');
	unless ($Cache->{ $self->{id} } && (ref($Cache->{ $self->{id} }) eq 'HASH')) {
		warn "[cache] Creating cache structure\n" if $DEBUG;
		$Cache->{ $self->{id} } = {
			reqs_since_scan => 0,
			size => 0,
			data => {}
		};
	}
	# easier access to the cache that we need
	$self->{cache} = $Cache->{ $self->{id} };

	# get the global timestamp that's updated every time something else is
	$self->{refresh_all} = $self->_get_refresh_all;
	$self->{refresh} = {};
	warn "[cache] refresh_all: $self->{refresh_all}\n" if $DEBUG;

	warn "[cache] Current size: $self->{cache}->{size}   Last scanned: $self->{cache}->{reqs_since_scan} requests ago\n" if $DEBUG;

	return $self;
}

sub _get_refresh_all {
	my $self = shift;

	my ($rv, $sth) = $self->{scoop}->db_select({
		WHAT    => 'last_update',
		FROM    => 'cache_time',
		WHERE   => q|resource = 'refresh_all'|,
		NOCACHE => 1
	});

	my $time = $sth->fetchrow;
	$sth->finish;

	# if refresh_all isn't set, we'll go ahead and set it to now
	unless ($time) {
		$time = time();
		my ($rv, $sth) = $self->{scoop}->db_insert({
			INTO    => 'cache_time',
			COLS    => 'resource, last_update',
			VALUES  => "'refresh_all', '$time'",
			NOCACHE => 1
		});
	 }

	return $time;
}

=item * fetch(resource)

Looks for the requested resource in the cache and, if available, returns it. If
the resource isn't found or is expired, undef will be returned.

=cut

sub fetch {
	my $self = shift;
	my $resource = shift || return;

	warn "[cache] (fetch) Called for resource $resource\n" if $DEBUG;

	# if we're using memcached, short circuit the rest of the function
	if($self->{scoop}->{MEMCACHED} && $resource ne 'boxes'){
		warn "fetching $resource with memcached...\n" if $DEBUG;
		my $S = $self->{scoop}; # and a flip
		# one nice thing, at least, is that the memcached server
		# seems to handle a lot of the stuff that we'd ordinarily
		# need to worry about ourselves, so this is, at least, a lot
		# simpler.
		my $data = $S->memcached->get($resource);
		return $data->{value};
		}
	# first, check to see if the resource exists in the cache
        return unless $self->{cache}->{data}->{$resource};
	# easy access to this resource
	my $data = $self->{cache}->{data}->{$resource};

	warn "[cache] (fetch) Resource exists\n" if $DEBUG;

	my $now = time();    # only call time() once
	warn "[cache] (fetch) time is $now; resource expires at $data->{expires}" if $DEBUG;
	# next, if the resource has an expiration time set, check it. if the
	# resource is expired, remove it so that it has to be re-fetched
	if ($data->{expires} && $data->{expires} <= $now) {
		warn "[cache] (fetch) Resource is expired. Removing.\n" if $DEBUG;
		$self->remove($resource);
		return;
	}

	# check the cache update time against that of the actual data
	# we check against the global timestamp first to possibly avoid a database
	# hit. if last_update is less than refresh_all, then it will also be less
	# than the resource's timestamp, so we don't need to check it
	warn "[cache] (fetch) last_update ($data->{last_update}) refresh_all ($self->{refresh_all})" if $DEBUG;
	if ($data->{last_update} < $self->{refresh_all}) {
		warn "[cache] (fetch) last_update ($data->{last_update}) is less than refresh_all. Must check timestamp.\n" if $DEBUG;
		# something has changed in the database, so now we get the resource
		# timestamp out to if it was this resource
		my $refresh = $self->refresh_one($resource);
		if ($data->{last_update} < $refresh) {
			warn "[cache] (fetch) Timestamp ($refresh) indicates resource is out of date. Removing.\n" if $DEBUG;
			# if so, remove it from the cache
			$self->remove($resource);
			return;
		}
	}

	# this resource checks out, so it can be returned
	# update the access time first, though
	$data->{last_access} = $now;

	warn "[cache] (fetch) Cache hit. Updating last access. Returning $data->{value}\n" if $DEBUG;

	# cache hit!
	return $data->{value};
}

=item * store(resource, data, [expires])

Places data into the cache using resource as the key to identify it. If expires
is given, then the data will be removed once the expiration period is reached.
The expiration time can be given either in absolute form
(C<yyyy-mm-dd hh:mm:ss>), or relative to the current time (C<+1h30m>).

=cut

sub store {
	my $self = shift;
	my ($resource, $value, $expires) = @_;

	warn "[cache] (store) Started for resource $resource, data $value\n" if $DEBUG;

	return unless $resource && $value;
	my $now = time();
	if($self->{scoop}->{MEMCACHED}){
		my $S = $self->{scoop};
		warn "Storing $resource with value $value with memcached\n" if $DEBUG;
		# do we need to fiddle with expires?
		# might as well
		if($expires){
			if ($expires =~ /^\+\d+\w/) {
                        	my $offset = $self->{scoop}->time_relative_to_seconds($expires);
                        	$expires = $now + $offset;
                	} elsif ($expires =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/) {
                        	$expires = $self->{scoop}->time_absolute_to_seconds($expires);
                	} else {
                        	warn "[cache] (store) Invalid expires time: $expires";
                		}

			}
		# Looks like we have to force some of this stuff in, so
		# the stamping stuff works right
		my $data = {};
		$data->{expires} = $expires;
		$data->{value} = $value;
		$data->{last_update} = $data->{last_access} = $now;
		$self->stamp($resource) unless $self->refresh_one($resource);
		$S->memcached->set($resource, $data, $expires);
		return 1;
		}

	# if this resource doens't exist previously, create a record for it
	$self->{cache}->{data}->{$resource} = {}
		unless $self->{cache}->{data}->{$resource};
	my $data = $self->{cache}->{data}->{$resource};

	# set the timestamps to now
	$data->{last_update} = $data->{last_access} = $now;

	# figure out the data's size, then set it, and add it to the cache's size
	$data->{size} = $self->_calculate_size($value);
	$self->{cache}->{size} += $data->{size};

	warn "[cache] (store) Resource size is $data->{size}. Cache size is now $self->{cache}->{size}\n" if $DEBUG;

	# if an expires time was given, parse and set it
	if ($expires) {
		if ($expires =~ /^\+\d+\w/) {
			my $offset = $self->{scoop}->time_relative_to_seconds($expires);
			$data->{expires} = $now + $offset;
		} elsif ($expires =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/) {
			$data->{expires} = $self->{scoop}->time_absolute_to_seconds($expires);
		} else {
			warn "[cache] (store) Invalid expires time: $expires";
		}
		warn "[cache] (store) Expires is now set to $data->{expires}\n" if $DEBUG;
	}

	# don't forget to save the actual data :)
	$data->{value} = $value;

	# mark the cache as changed so that the size scan will run
	$self->{cache}->{changed} = 1;

	# stamp the cache if there isn't already a stamp in it
	$self->stamp($resource) unless $self->refresh_one($resource);

	return 1;
}

=item * remove(resource)

Removes the resource from the local cache. Has no effect on the database.

=cut

sub remove {
	my $self = shift;
	my $resource = shift || return;

	warn "[cache] (remove) Starting for resource $resource\n" if $DEBUG;

	# once again...
	if($self->{scoop}->{MEMCACHED}){
		warn "Removing $resource from memcached...\n" if $DEBUG;
		# this is really here for completeness
		$self->{scoop}->{MEMCACHED}->delete($resource);
		delete $self->{refresh}->{$resource}; # for completeness -							      # might even be used
		return 1;
		}
	return unless $self->{cache}->{data}->{$resource};

	warn "[cache] (remove) Cache size was $self->{cache}->{size}\n" if $DEBUG;

	$self->{cache}->{size} -= $self->{cache}->{data}->{$resource}->{size};

	delete $self->{cache}->{data}->{$resource};
	delete $self->{refresh}->{$resource};
	
	warn "[cache] (remove) Cache size is $self->{cache}->{size}\n" if $DEBUG;

	return 1;
}

=item * stamp(resource, [time])

Updates the timestamp in the database for resource. Time, if given, should be
in seconds since the epoch. If not given, the current time is used.

=cut

sub stamp {
	my $self     = shift;
	my $resource = shift || return;
	my $time     = shift || time;

	warn "[cache] (stamp) Called for resource $resource. Setting to $time.\n" if $DEBUG;

	my $qr = $self->{scoop}->db->quote($resource);
	my $qt = $self->{scoop}->db->quote($time);

	# first, check to see if there's already a stamp in the db
	my ($rv, $sth) = $self->{scoop}->db_select({
		WHAT    => 'COUNT(*)',
		FROM    => 'cache_time',
		WHERE   => "resource = $qr",
		NOCACHE => 1
	});
	my $exists = $sth->fetchrow;
	$sth->finish;

	if ($exists) {
		warn "[cache] (stamp) Record exists. Updating.\n" if $DEBUG;
		# the record exists, so we need to update both it and refresh_all
		($rv, $sth) = $self->{scoop}->db_update({
			WHAT    => 'cache_time',
			SET     => "last_update = $qt",
			WHERE   => "resource = $qr OR resource = 'refresh_all'",
			NOCACHE => 1
		});
		$sth->finish;
	} else {
		warn "[cache] (stamp) Record doesn't exist. Inserting and updating.\n" if $DEBUG;
		# no record, so we have to add it, then update refresh_all
		($rv, $sth) = $self->{scoop}->db_insert({
			INTO    => 'cache_time',
			COLS    => 'resource, last_update',
			VALUES  => "$qr, $qt",
			NOCACHE => 1
		});
		$sth->finish;

		($rv, $sth) = $self->{scoop}->db_update({
			WHAT    => 'cache_time',
			SET     => "last_update = $qt",
			WHERE   => q|resource = 'refresh_all'|,
			NOCACHE => 1
		});
	}

	warn "+++ OUT OF CHEESE ERROR +++ REDO FROM START +++\n" unless $rv;

	return $time;
}

sub _calculate_size {
	my $self = shift;
	my $data = shift || '';

	if (ref($data) eq 'HASH') {
		return $self->_calculate_size_hash($data);
	} elsif (ref($data) eq 'ARRAY') {
		return $self->_calculate_size_array($data);
	} else {
		return length($data);
	}
}

sub _calculate_size_hash {
	my $self = shift;
	my $data = shift;

	my $size = 0;
	while (my ($k, $v) = each %{$data}) {
		$size += length($k);
		$size += $self->_calculate_size($v);
	}

	return $size;
}

sub _calculate_size_array {
	my $self = shift;
	my $data = shift;

	my $size = 0;
	foreach my $i (@{$data}) {
		$size += $self->_calculate_size($i);
	}

	return $size;
}

sub refresh_one {
	my $self = shift;
	my $resource = shift || return;

	# refresh timestamps are cached in the object for the duration of the
	# request, so check to see if the requested one is in the cache
	return $self->{refresh}->{$resource} if $self->{refresh}->{$resource};

	# if not, pull it out of the db
	my $qr = $self->{scoop}->db->quote($resource);
	my ($rv, $sth) = $self->{scoop}->db_select({
		WHAT  => 'last_update',
		FROM  => 'cache_time',
		WHERE => "resource = $qr"
	});

	my $time = $sth->fetchrow;
	$sth->finish;

	# cache the time, then send it back
	$self->{refresh}->{$resource} = $time;
	return $time;
}

sub check_size {
	my $self = shift;

	return unless $self->{cache}->{changed};

	my $max_size = $self->_find_max_size;

	warn "[cache] (check_size) Starting. Max size: $max_size   Cache size: $self->{cache}->{size}\n" if $DEBUG;

	# if the cache is within limits, we don't have to scan
	return if $self->{cache}->{size} <= $max_size;

	warn "[cache] (check_size) Cache is too large. Must trim.\n" if $DEBUG;

	# start removing the least recently used resources. continue until the
	# cache is small enough
	# order the resources by access time, with the least recently used first
	my $d = $self->{cache}->{data};
	my @ordered = sort {
		$d->{$a}->{last_access} <=> $d->{$b}->{last_access};
	} keys %{$d};

	# as long as the cache is too large, take off the first (least recently
	# used) item and remove it
	while ($self->{cache}->{size} > $max_size) {
		$self->remove( shift(@ordered) );
		warn "[cache] (check_size) Removed item. Size now $self->{cache}->{size}\n" if $DEBUG;
	}

	return 1;
}

sub _find_max_size {
	my $self = shift;

	my %sizes = (
		b => 1,
		k => 1024,
		m => 1024*1024,
		g => 1024*1024*1024
	);
	my $max = $self->{scoop}->{UI}->{VARS}->{max_cache_size};
	$max =~ s/\s//g;
	$max .= 'b' if $max =~ /\d$/;

	my $bytes;
	while ($max =~ /(\d+)([bkmg])/ig) {
		$bytes += $1 * $sizes{ lc($2) };
	}

	return $bytes;
}

sub cleanup {
	my $self = shift;

	$self->{cache}->{reqs_since_scan}++;

	# check to see if we need to scan the cache
	my $scan_interval = $self->{scoop}->{UI}->{VARS}->{cache_scan_interval};
	if ($scan_interval && ($self->{cache}->{reqs_since_scan} >= $scan_interval)) {
		# if so, perform the scan, then reset the counter
		$self->check_size;
		$self->{cache}->{reqs_since_scan} = 0;
		$self->{cache}->{changed} = 0;
	}

	# remove these references so that everything is cleaned up properly
	undef $self->{cache};
	undef $self->{scoop};
}

=back

=head2 Compatibility Methods

The following methods are provided only to be compatible with the old cache
module, and should never be used in new code.

=over 4

=item * fetch_data({resource, element, [item]})

=item * cache_data({resource, element, data})

=item * stamp_cache(resource, timestamp, [first])

=item * clear({resource, element})

=back

=cut

sub fetch_data {
	my $self = shift;
	my $args = shift;

	my $data = $self->fetch($args->{resource}) || return;

	return $args->{item} ? $data->{ $args->{item} } : $data;
}

sub cache_data {
	my $self = shift;
	my $args = shift;

	return $self->store($args->{resource}, $args->{data});
}

sub stamp_cache { return shift->stamp(@_) }

sub clear {
	my $self = shift;
	my $args = shift;

	return $self->remove($args->{resource});
}

1;
