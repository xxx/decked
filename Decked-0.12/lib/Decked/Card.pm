package Decked::Card;
require 5.6.0;
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
		NAME     => undef,
		COLOR    => undef,
		EDITION  => undef,
		P_T      => undef,
		TYPE     => undef,
		COST     => undef,
		TEXT     => undef,
		FLAVOR   => undef,
		LOCATION => undef,
	};
	bless($self, $class);

	return $self;
}

sub name {
	my $this = shift;
	if(@_) {$this->{'NAME'} = shift };
	return $this->{'NAME'};
}

sub color {
	my $this = shift;
	if(@_) {$this->{'COLOR'} = shift };
	return $this->{'COLOR'};
}

sub edition {
	my $this = shift;
	if(@_) {$this->{'EDITION'} = shift };
	return $this->{'EDITION'};
}

sub p_t {
	my $this = shift;
	if(@_) {$this->{'P_T'} = shift };
	return $this->{'P_T'};
}

sub type {
	my $this = shift;
	if(@_) {$this->{'TYPE'} = shift };
	return $this->{'TYPE'};
}

sub cost {
	my $this = shift;
	if(@_) {$this->{'COST'} = shift };
	return $this->{'COST'};
}

sub text {
	my $this = shift;
	if(@_) {$this->{'TEXT'} = shift };
	return $this->{'TEXT'};
}

sub flavor {
	my $this = shift;
	if(@_) {$this->{'FLAVOR'} = shift };
	return $this->{'FLAVOR'};
}

sub location {
	my $this = shift;
	if(@_) {$this->{'LOCATION'} = shift };
	return $this->{'LOCATION'};
}

1;
__END__


=head1 NAME

Decked::Card - Implement a card object to be stored in a
                      L<Decked::Cardbase> object;

=head1 SYNOPSIS

  use Decked::Card;
  my $cardref = Decked::Card->new;
  $cardref->name("Shichifukujin Dragon"); # heh, this is a real card.
  $cardref->(0x08); # colors are just numbers, and translated by a bitmask
  $cardref->edition("PR-R");
  $cardref->p_t("0/0");
  $cardref->type("Creature - Dragon");
  $cardref->cost("6RR");
  $cardref->text("Blah, Blah, Blah");
  $cardref->flavor("");
  $cardref->location("38283"); # location in Apprentice database

=head1 DESCRIPTION

This is just a way to conveniently store data that would be associated with
a single card. The mutator subs listed in the synopsis are accessors as well.

=head1 USAGE

See synopsis. There is very little functionality in this gym mat.

=head1 BUGS

Probably few. This module is rather trivial in design and implementation

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

