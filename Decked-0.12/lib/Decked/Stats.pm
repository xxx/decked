package Decked::Stats;
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
		NUMCOLORS => { #hashref, keys are colors, values are # of symbols
			             W => 0,
			             U => 0,
			             B => 0,
			             R => 0,
			             G => 0
		             },
		#hashref, keys are numbers, values are number of cards w/ that cost
		CURVE => {
			             0    => 0,
			             1    => 0,
			             2    => 0,
			             3    => 0,
			             4    => 0,
			             5    => 0,
			             6    => 0,
			             '7+' => 0,
			             X    => 0,
		             },
		CURVECARDS => 0,	# number of cards to count for avg. cost
		CURVEMANA => 0,		# total cost of all curvecards
		LANDS     => 0,     # number of lands in the deck
		CREATURES => 0,     # number of creatures in the deck
		DECK      => undef, # reference to the deck to do stats on
		CB        => undef, # reference to the cardbase
	};
	my $closure = sub {
		my $field = shift;
		$self->{$field} = shift if @_;
		return $self->{$field};
	};
		
	bless($closure, $class);

	return $closure;
}

sub numcolors { &{ $_[0] }("NUMCOLORS",  @_[ 1 .. $#_ ]) }
sub curve { &{ $_[0] }("CURVE",  @_[ 1 .. $#_ ]) }
sub curvecards { &{ $_[0] }("CURVECARDS",  @_[ 1 .. $#_ ]) }
sub curvemana { &{ $_[0] }("CURVEMANA",  @_[ 1 .. $#_ ]) }
sub lands { &{ $_[0] }("LANDS",  @_[ 1 .. $#_ ] ) }
sub creatures { &{ $_[0] }("CREATURES",  @_[ 1 .. $#_ ]) }
sub deck { &{ $_[0] }("DECK",  @_[ 1 .. $#_ ]) }
sub cb { &{ $_[0] }("CB",  @_[ 1 .. $#_ ]) }

sub numcards { #get the total number of cards in the deck
	my $this = shift;
	my $deck = $this->deck;
	return 0 unless $deck;
	my $total = 0;
	foreach(keys %{$deck}) {
		$total += $deck->{$_}->[1];
	}
	return $total;
}

# convert a cost string to a string corresponding to what would be
# used in the mana curve structure
sub cost_to_key {
	my ($this, $cost) = @_;
	$cost =~ s/^\s+//;
	$cost =~ s/\s+$//;
	my $key = undef;
	return -1 unless length $cost; # lands, etc have no cost at all
	# get X spells first.
	return 'X' if $cost =~ /X/;
	my ($colorless, $colored) = $cost =~ /(\d*)([[:alpha:]]*)$/;
	$colorless = 0 unless $colorless;
	$key = $colorless + length $colored;
	#$key = '7+' if $key >= 7;
	return $key;
}

# initialize the stats object using information from a deck list.
sub initialize {
	my($this,$cb,$clist) = @_;
	return unless $cb && $clist;
	$this->cb($cb);
	#loop through clist, get cardref for each card, 
	# create array [cardref, number], and set deck{name} to the ref;
	my %deck;
	my @rows = $clist->rows;
	for(my $i=0;$i<$rows[0];++$i) {
		my @arr;
		my $num = $clist->get_text($i,0);
		my $name = $clist->get_text($i,1);
		my $cardref = $cb->get_card_by_name($name);
		push @arr, ($cardref,$num);
		$deck{$name} = \@arr;
	}
	$this->deck(\%deck);

	$this->get_stats;
}

# this is not meant to be a public method.
# XXX eventually parse out the deck's mana curve as well.
sub get_stats {
	my $this = shift;
	my $deck = $this->deck;
	return unless defined $deck;
	my $w = 0;
	my $u = 0;
	my $b = 0;
	my $r = 0;
	my $g = 0;
	my $lands = 0;
	my $creatures = 0;
	my $tmpcurve = {
		0  => 0,
		1  => 0,
		2  => 0,
		3  => 0,
		4  => 0,
		5  => 0,
		6  => 0,
		'7+'  => 0,
		X  => 0,
	};
	my $curvecards = 0;
	my $curvemana = 0;

	foreach(keys %{$deck}) {
		my $cardref = $deck->{$_}->[0];
		my $cardnum = $deck->{$_}->[1];
		#first get number of mana symbols of each color
		my $cost = $cardref->cost;

		my $name = $cardref->name;

		$w += ((length $1) * $cardnum) if($cost =~ /(W+)/);
		$u += ((length $1) * $cardnum) if($cost =~ /(U+)/);
		$b += ((length $1) * $cardnum) if($cost =~ /(B+)/);
		$r += ((length $1) * $cardnum) if($cost =~ /(R+)/); 
		$g += ((length $1) * $cardnum) if($cost =~ /(G+)/);

		# check for creatures
		my $cardtype = $cardref->type;
		$creatures += $cardnum if $cardtype =~ /^(?:Artifact |)Creature/;

		# check for lands
		my $color = $cardref->color;
		# 0x80 == land in the cardbase
		# see col_to_str sub in GUI.pm
		$lands += $cardnum if (($color & 0x80) == 0x80);

		# get the mana curve
		my $key = $this->cost_to_key($cost);
		next if sprintf("%s",$key) eq '-1'; # is there a better way?
		unless($key eq 'X') {
			$curvecards += $cardnum;
			$curvemana += ($key * $cardnum);
			$key = '7+' if $key >= 7;
		}
		next unless $key eq '0' || $key eq 'X' || substr $key, 0, 1 >= 0;
		my $tmpval = $tmpcurve->{$key};
		$tmpval += $cardnum;
		$tmpcurve->{$key} = $tmpval;
	}
	# update the object
	$this->numcolors->{'W'} = $w;
	$this->numcolors->{'U'} = $u;
	$this->numcolors->{'B'} = $b;
	$this->numcolors->{'R'} = $r;
	$this->numcolors->{'G'} = $g;
	$this->creatures($creatures);
	$this->lands($lands);
	$this->curve($tmpcurve);
	$this->curvecards($curvecards);
	$this->curvemana($curvemana);
}

1;
__END__


=head1 NAME

Decked::Stats - Generate statistics on a deck.

=head1 SYNOPSIS

  use Decked::Stats;

XXX: this needs to be filled in. this module is in a state of flux
right now, and some functionality will be broken into at least one
other module, possibly 2.

=head1 DESCRIPTION

An object that can generate various statistics on a given deck.

=head1 USAGE

XXX: blah blah


=head1 BUGS

Maybe. This module was rather well tested, however.

=head1 AUTHOR

Michael Dungan <mpd@yclan.net>

=head1 COPYRIGHT

Copyright (c) 2003 Michael Dungan All rights reserved.

This file is free software. It can be modified and/or redistributed under
the same terms as Perl itself. Please see the LICENSE file included in the
distribution.

=head1 SEE ALSO

L<decked>

=cut
