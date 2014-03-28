package Scoop::CGI;
use strict;

##############################
# A couple utility methods to replace CGI.pm, since I
# don't use it for enough to justify the memory it uses!
##############################

my $DEBUG = 0;

sub new {
	my $pkg = shift;
	my $class = ref( $pkg ) || $pkg;
	my $self = bless( {}, $class );

	return $self;
}

sub param {
	my $self = shift;
	my $param = shift;

	my $S = Scoop->instance();
	
	if (!defined $S->param->{$param}) {
		undef $S;
		return (wantarray) ? () : undef;
	}
	my $ret = $S->param->{$param};
	undef $S;

	if( wantarray() ) {
		if( ref($ret) eq 'ARRAY' ) {
			return @$ret;
		} else {
			return ($ret);
		}
	} else {
		return $ret;
	}
}

sub Vars {
	my $self = shift;
	my $S = Scoop->instance();
	my $ret = $S->param;
	undef $S;
	return $ret;
}

sub Vars_cloned {
	my $self = shift;
	my $S = Scoop->instance();

	my %p = %{ $S->param };
	undef $S;
	return \%p;
}

sub DESTROY {
	my $self = shift;
	warn "<<Another ", ref( $self ), " bites the dust>>\n"	if $DEBUG;
}


1;
