package Scoop::Statement;
use strict;
use vars qw( $AUTOLOAD );
$AUTOLOAD = undef;
#@Scoop::Statement::ISA = qw(Class::Singleton);

my $DEBUG = 0;

#sub _new_instance {
#	my $pkg = shift;
#	
#	my $class = ref( $pkg ) || $pkg;
#	my $self = bless( {}, $class );
	
#	return $self;
#}

sub new {
	my $pkg = shift;
	my $class = ref( $pkg ) || $pkg;
	my $data = shift;
	my $names = shift;
	
	warn "New $class\n" if $DEBUG;
	
	my $self = bless( {}, $class );
	
	$self->{NEXT_REC} = 0;
	$self->{DATA} = $data;
	$self->{NAME} = $names;
	
	warn "Next record is $self->{NEXT_REC}\n" if $DEBUG;
	
	return $self;
}

sub fetchrow {
	my $self = shift;
	undef my @ret;
	
	warn "Fetchrow called.\n" if $DEBUG;
	
	if ($self->{NEXT_REC} > $#{$self->{DATA}}) {
		return ();
	}
	
	foreach my $name (@{$self->{NAME}}) {
		warn "\tName: $name, Item: $self->{DATA}->[$self->{NEXT_REC}]->{$name}\n" if $DEBUG;
		push @ret, $self->{DATA}->[$self->{NEXT_REC}]->{$name};
	}
	
	$self->advance_pointer();
	
	warn "fetchrow Returning:\n" if $DEBUG;
	foreach my $val (@ret) {
		warn "\t$val\n" if $DEBUG;
	}
	
	wantarray ? @ret : $ret[0];
}

sub fetchrow_hashref {
	my $self = shift;
	my $ret = $self->{DATA}->[$self->{NEXT_REC}] || undef;
	$self->advance_pointer();
	warn "Fetchrow_hashref called\n" if $DEBUG;
	return $ret;
}

sub fetchrow_arrayref {
	my $self = shift;
	
	my @ret = $self->fetchrow();
	warn "Fetchrow_arrayref called\n" if $DEBUG;
	return \@ret;
}


sub finish {
	my $self = shift;
	#undef $self;
	return;
}


sub advance_pointer {
	my $self = shift;
	$self->{NEXT_REC}++;
	warn "Current sth pointer is: $self->{NEXT_REC}\n" if $DEBUG;
	
	return $self->{NEXT_REC};
}

sub DESTROY {
	my $self = shift;
	warn "<<Another ", ref( $self ), " bites the dust>>\n"	if $DEBUG;
}

sub AUTOLOAD {
	my $self = shift;
	my $request = $AUTOLOAD;
	
	warn "  (Scoop::Statement::AUTOLOAD) Trying to fulfill $request from ", ref( $self ),"\n" if ($DEBUG);
	$request =~ s/.*://;
	$request = uc($request) unless ($request =~ /destroy/i);
	
	if (exists($self->{$request})) {
		warn "  (Scoop::Statement::AUTOLOAD): Fulfilling request because it's a parameter.\n"                   if ( $DEBUG );	
		warn "  (Scoop::Statement::AUTOLOAD): Returning data from AUTOLOAD\n"                                   if ( $DEBUG );
		return $self->{$request}
	} 
	
	my $error_msg = "Cannot access the method $request via <<" . ref( $self ) .
                 ">> with the parameters " . join ' ', @_;
	warn "  (Scoop::Statement::AUTOLOAD): AUTOLOAD Error: $error_msg\n";
	return undef;
}

1;
