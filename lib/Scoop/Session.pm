=head1 Session

Contains methods for creating and accessing a session object where data is kept
persistently in the database. A unique session key is used as a per-user
identifier, where a user (logged in or anonymous) may have one or more
sessions. These methods replace the single C<session> method which was used
with Apache::Session, though that method is kept around for backwards
compatibility. It may or may not be removed at a future date.

=over 4

=cut

package Scoop::Session;
use strict;
use Storable ();
use Digest::MD5 ();
use MIME::Base64 ();

my $DEBUG = 0;

=item * new(scoop=>, [session_id=>], [create=>], [ignore_bad_id=>])

=cut

sub new {
	my $pkg = shift;
	my %args = @_;

	return unless $args{scoop} and (ref($args{scoop}) eq 'Scoop');

	my $class = ref($pkg) || $pkg;
	my $self  = bless {}, $class;
	warn "[session] Creating new session object\n" if $DEBUG;

	$self->{scoop} = $args{scoop};

	if ($args{session_id} and $args{create}) {
		warn "[session] Can't specify both session_id and create as options to new\n" if $DEBUG;
	}

	if ($args{session_id}) {
		my $key = $self->session_id($args{session_id});
		# if session_id returns nothing, then the key passed to it is invalid.
		# unless ignore_bad_id is true, fail
		unless ($key or $args{ignore_bad_id}) {
			warn "[session] Can't use session $args{session_id} because it is invalid\n" if $DEBUG;
			return;
		}
	} elsif ($args{create}) {
		$self->create;
	}

	return $self;
}

=item * fetch(item)

Grabs the item given by B<item> from the session and returns it. Deserializing
of data structures is done automatically. If the item is not found, then undef
is returned.

=cut

sub fetch {
	my $self = shift;
	my $item = shift || return;

	# if no session associated with object, then there's nothing to fetch
	return unless $self->session_id;

	warn "[session] Item $item requested\n" if $DEBUG;

	return unless $self->{data}->{$item};
	my $d = $self->{data}->{$item};
	return if $d->{removed};

	warn "[session] Item $item found in session with value $d->{value} (serialized?  $d->{serialized})\n" if $DEBUG;

	if ($d->{serialized}) {
		# if serialized, thaw the data out and keep the thawed copy. update the
		# serialized flag so we don't try and thaw again this request
		$d->{value}      = Storable::thaw(MIME::Base64::decode($d->{value}));
		$d->{serialized} = 0;
	}

	return $d->{value};
}

=item * store(item, value)

Saves B<value> to the session, referenced by B<item>. If B<item> already
exists, it will be updated; otherwise, it will be added to the session. If
B<value> is a reference to a more complex data structure, it will automatically
be serialized before being saved.

=cut

sub store {
	my $self  = shift;
	my $item  = shift || return;
	my $value = shift || return;

	# if there are any other options, then the method is probably being used
	# wrong (passing a hash or array for value, probably)
	if (@_) {
		warn "[session] Too many parameters passed to store\n" if $DEBUG;
		return;
	}

	# if the object has no session associated with it when store is called,
	# then create one to put stuff in. this is used for anonymous users, so
	# that a session is created for them until they actually need one
	$self->create unless $self->session_id;

	warn "[session] Item $item being stored (value: $value)\n" if $DEBUG;

	# re-write or add the item to the hash
	$self->{data}->{$item} = {
		value      => $value,
		changed    => 1,
		removed    => 0,
		serialized => 0
	};
	# set global changed flag so that this gets written out later
	$self->{changed} = 1;

	return 1;
}

=item * remove(item)

Deletes B<item> from the session.

=cut

sub remove {
	my $self = shift;
	my $item = shift || return;

	return unless $self->session_id;
	return unless $self->{data}->{$item};

	$self->{data}->{$item}->{removed} = 1;
	$self->{changed} = 1;

	return 1;
}

=item * reset()

Empties the session object's internal data structures so that the object is no
longer associated with a session.

=cut

sub reset {
	my $self = shift;

	$self->{session_id}  = undef;
	$self->{q_sid}       = undef;
	$self->{data}        = {};
	$self->{changed}     = 0;
	$self->{flushed}     = 0;

	return 1;
}

=item * session_id([session_id])

With no arguments, returns the current session_id. If given an argument,
attempts to switch the object over to use that session instead. Returns the
session_id if it suceeds and nothing if it fails (usually because the session
is invalid).

=cut

sub session_id {
	my $self = shift;
	my $sid  = shift;

	return $self->{session_id} unless $sid;

	my $q_sid = $self->{scoop}->{DBH}->quote($sid);

	my ($rv, $sth) = $self->{scoop}->db_select({
		WHAT  => 'item, value, serialized, last_update',
		FROM  => 'sessions',
		WHERE => "session_id = $q_sid"
	});
	unless ($rv > 0) {
		$sth->finish;
		return;
	}

	$self->reset;   # prepares the data structure
	$self->{session_id} = $sid;
	$self->{q_sid}      = $q_sid;

	while (my($i, $v, $s, $lu) = $sth->fetchrow_array) {
		$self->{data}->{$i} = {
			value       => $v,
			serialized  => $s,
			last_update => $lu,
			changed     => 0,
			removed     => 0
		};
	}
	$sth->finish;

	$self->{scoop}->{SESSION_KEY} = $sid;

	return $sid;
}

=item * create()

Generates a session id and creates a new session for it. Returns the generated
session id. May only be called if the session object is otherwise not
associated with a session.

=cut

sub create {
	my $self = shift;

	return if $self->session_id;

	warn "[session] Creating new session.\n" if $DEBUG;

	$self->reset;

	# generate a new session id. code for this generously ripped off from
	# Apache::Session::Generate::MD5
	my $sid = Digest::MD5::md5_hex(Digest::MD5::md5_hex(time() . {} . rand() . $$));
	my $q_sid = $self->{scoop}->{DBH}->quote($sid);
	my $created = time;
	my $q_created = $self->{scoop}->{DBH}->quote($created);

	my ($rv, $sth) = $self->{scoop}->db_insert({
		INTO   => 'sessions',
		COLS   => 'session_id, item, value, last_update',
		VALUES => "$q_sid, 'created', $q_created, CURRENT_TIMESTAMP"
	});
	$sth->finish;

	$self->{session_id}  = $sid;
	$self->{q_sid}       = $q_sid;
	$self->{data}->{last_update} = {
		value      => $created,
		serialized => 0,
		changed    => 0,
		removed    => 0
	};

	$self->{scoop}->{SESSION_KEY} = $sid;

	return $sid;
}

=item * flush()

Causes all data in the session to be removed.

=cut

sub flush {
	my $self = shift;

	return unless $self->session_id;

	warn "[session] Flushing session\n" if $DEBUG;

	# set a flag so that cleanup() wipes the entire session. also mark the
	# session as changed
	$self->{flushed} = 1;
	$self->{changed} = 1;

	# also loop through the local session copy and mark everything as removed
	foreach my $i (keys %{$self->{data}}) {
		$self->{data}->{$i}->{removed} = 1;
	}

	return 1;
}

=item * sync()

Forces the local copy of the current session to be synchronized with the
database. First writes out any changes, then reads everything back in.

=cut

sub sync {
	my $self = shift;

	$self->_write_changed || return;
	$self->session_id($self->{session_id}) || return;

	return 1;
}

sub _write_changed {
	my $self = shift;

	# nothing to do if the global changed flag isn't set
	return 1 unless $self->{changed};

	# check to see if we need to wipe the entire session
	if ($self->{flushed}) {
		my ($rv, $sth) = $self->{scoop}->db_delete({
			FROM  => 'sessions',
			WHERE => "session_id = $self->{q_sid}"
		});
		$sth->finish;

		return 1;
	}

	while (my($item, $data) = each %{$self->{data}}) {
		next unless $self->{removed} or $self->{changed};
		my $q_item = $self->{scoop}->{DBH}->quote($item);

		if ($data->{removed}) {
			my ($rv, $sth) = $self->{scoop}->db_delete({
				FROM  => 'sessions',
				WHERE => "session_id = $self->{q_sid} AND item = $q_item"
			});
			$sth->finish;
		} elsif ($data->{changed}) {
			if (ref($data->{value})) {
				$data->{value} = MIME::Base64::encode(Storable::nfreeze($data->{value}));
				$data->{serialized} = 1;
			}
			my $q_value = $self->{scoop}->{DBH}->quote($data->{value});

			# try to update first. if that fails, insert a new row
			my ($rv, $sth) = $self->{scoop}->db_update({
				WHAT  => 'sessions',
				SET   => "value = $q_value, serialized = $data->{serialized}, last_update = CURRENT_TIMESTAMP",
				WHERE => "session_id = $self->{q_sid} AND item = $q_item"
			});
			$sth->finish;

			unless ($rv == 1) {
				($rv, $sth) = $self->{scoop}->db_insert({
					INTO   => 'sessions',
					COLS   => 'session_Id, item, value, serialized, last_update',
					VALUES => "$self->{q_sid}, $q_item, $q_value, $data->{serialized}, CURRENT_TIMESTAMP"
				});
				$sth->finish;
			}
		}
	}

	return 1;
}

=item * cleanup()

Cleans up and resets the session object, which includes forgetting the Scoop
object passed to C<new>. This should be called when finished with the session
object, to prevent any circular references.

=cut

sub cleanup {
	my $self = shift;

	$self->_write_changed if $self->session_id;
	$self->{scoop} = undef;
}

=back

=cut

1;
