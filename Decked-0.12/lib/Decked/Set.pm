package Decked::Set;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.01;
	@ISA         = qw (Exporter);
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

sub new {
	my ($proto, $name) = @_;
	my $class = ref($proto) || $proto;

	my $self = {
		NAME      => undef,
		ABBREV    => undef,
		SC        => undef, # commons in starter
		SU        => undef, # uncommons in starter
		SR        => undef, # rares in starter
		BR        => undef, # commons in booster
		BR        => undef, # uncommons in booster
		BR        => undef, # rares in booster
		COMMONS   => [], # arrayref containing refs to all commons in set
		UNCOMMONS => [],
		RARES     => []
	};
	my $closure = sub {
		my $field = shift;
		$self->{$field} = shift if @_;
		return $self->{$field};
	};
		
	bless($closure, $class);

	return $closure;
}

sub name { &{ $_[0] }('NAME',  @_[ 1 .. $#_ ]) }
sub abbrev { &{ $_[0] }('ABBREV',  @_[ 1 .. $#_ ]) }
sub sc { &{ $_[0] }('SC',  @_[ 1 .. $#_ ]) }
sub su { &{ $_[0] }('SU',  @_[ 1 .. $#_ ]) }
sub sr { &{ $_[0] }('SR',  @_[ 1 .. $#_ ]) }
sub bc { &{ $_[0] }('BC',  @_[ 1 .. $#_ ]) }
sub bu { &{ $_[0] }('BU',  @_[ 1 .. $#_ ]) }
sub br { &{ $_[0] }('BR',  @_[ 1 .. $#_ ]) }
sub commons { &{ $_[0] }('COMMONS',  @_[ 1 .. $#_ ]) }
sub uncommons { &{ $_[0] }('UNCOMMONS',  @_[ 1 .. $#_ ]) }
sub rares { &{ $_[0] }('RARES',  @_[ 1 .. $#_ ]) }

1;
__END__


=head1 NAME

Decked::Set - Implement a Card set to be used in the Decked sealed generator

=head1 SYNOPSIS

  use Decked::Set;
  my $setref = Decked::Set->new;
  $setref->name("Set Name");
  $setref->abbrev("SN");
  $setref->sc(26); # number of commons in a starter deck
  $setref->su(9);  # number of uncommons in a starter deck
  $setref->sr(3);  # number of rares in a starter deck
  $setref->bc(11); # number of commons in a booster
  $setref->bu(3);
  $setref->br(1);

  # set reference to array of L<Decked::Card> objects representing the
  # (?:(?:un|)common|rare)s in this set
  $setref->commons(\@arr);
  $setref->uncommons(\@arr);
  $setref->rares(\@arr);

=head1 DESCRIPTION

Stores information relating to a set, for use with the sealed deck generator.

=head1 USAGE

See SYNOPSIS. Mutators are accessors, too.

=head1 BUGS

Probably few.

=head1 AUTHOR

Michael Dungan <mpd@yclan.net>

=head1 COPYRIGHT

Copyright (c) 2003 Michael Dungan All rights reserved.

This file is free software. It can be modified and/or redistributed under
the same terms as Perl itself. Please see the LICENSE file included in the
distribution.

=head1 SEE ALSO

L<Decked::Setbase> 

=cut
