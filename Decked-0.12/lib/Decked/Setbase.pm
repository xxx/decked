package Decked::Setbase;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Fcntl qw(SEEK_SET);
use FileHandle;
use Decked::Set;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.10;
	@ISA         = qw (Exporter);
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;

	# first get abbreviation/full name information.
	my $dbfile = $ENV{'EXPAN_DAT'};
	die "EXPAN_DAT env variable not set!" unless $dbfile;
	die "$ENV{'EXPAN_DAT'} is not readable!" unless -r $dbfile;

	my %sets;
	my $handle = FileHandle->new;
	# first get abbreviation and full name of sets from Expan.dat
	$handle->open($dbfile) or die "can't open setbase: $!";
	while(<$handle>) {
		next if /^-/;
		s/^\s+//;
		s/\s+$//;
		chomp;
		my ($abbrev, $name) = split /-/;
		my $set = Decked::Set->new;
		$set->abbrev($abbrev);
		$set->name($name);
		$sets{$abbrev} = $set;
	}
	$handle->close;

	# now get number of cards in each commonality in starters/boosters
	$dbfile = $ENV{'DISTRO_DAT'};
	die "DISTRO_DAT env variable not set!" unless $dbfile;
	die "$ENV{'DISTRO_DAT'} is not readable!" unless -r $dbfile;
	$handle->open($dbfile) or die "can't open setbase: $!";
	my $set; # needs to be saved between while iterations.
	while(<$handle>) {
		if(/^\s+$/) {
			undef $set;
			next;
		}
		s/^\s+//;
		s/\s+$//;
		chomp;
		if(/^\[(\w{2})\]/) {
			my $s = $1;
			$set = $sets{$s};
		}
		elsif(/Starter=(.*)/) {
			return unless $set;
			if($1) {
				my ($r, $u, $c) = split /,/, $1;
				$r = substr $r, 1;
				$u = substr $u, 1;
				$c = substr $c, 1;
				$set->sr($r) if $r;
				$set->su($u) if $u;
				$set->sc($c) if $c;
			}
		}
		elsif(/Booster=(.*)/) {
			return unless $set;
			if($1) {
				my $tmp = $1;
				# need to use a regexp here because some sets don't have
				# rares in their boosters.
				if($tmp =~ /(?:R(\d+),|)U(\d+),C(\d+)/) {
					my ($r,$u,$c);
					$r = $1 || 0; # some older sets don't have rares
					$u = $2;
					$c = $3;
					$set->br($r);
					$set->bu($u);
					$set->bc($c);
				}
			}
		}
	}

	my $self = {
		SETS => \%sets,
	};

	bless($self, $class);
	return ($self);
}

sub sets {
	my $this = shift;
	if (@_) { $this->{'SETS'} = shift }
	return $this->{'SETS'};
}

# add a card to ALL of its sets.
sub add_card {
	my ($this, $cardref) = @_;
	my $sets = $this->sets;
	my $refed = $cardref->edition;
	my $added = 0;
	foreach(keys %{$sets}) {
		# go through all the sets and see if this card is in them.
		# if so, get the rarity and slot the card into the set object
		# for the correct commonality.
		# if a card has a rarity of something like U2 or C8 or whatever,
		# the digit will be stripped off.
		my $match = qr/$_(?:,\w{2})*-{1,2}([CUR])/;
		if($refed =~ /$match/) {
			my $c;
			if($1 eq 'C') {
				$c = $sets->{$_}->commons;
				push @{$c}, $cardref;
				$sets->{$_}->commons($c);
				$added = 1;
			}
			elsif($1 eq 'U') {
				$c = $sets->{$_}->uncommons;
				push @{$c}, $cardref;
				$sets->{$_}->uncommons($c);
				$added = 1;
			}
			elsif($1 eq 'R') {
				$c = $sets->{$_}->rares;
				push @{$c}, $cardref;
				$sets->{$_}->rares($c);
				$added = 1;
			}
			# else not added, and so can't be generated (at all)
		}
	}
	return $added
}

1;
__END__


=head1 NAME

Decked::Setbase - Module to manipulate a Set database.

=head1 SYNOPSIS

  use Decked::Setbase;
  my $sb = Decked::Setbase->new();
  my $sets = $sb->sets;

  my $cardref = $cardbase->get_card_by_name("Shichifukujin Dragon");
  my $sb->add_card($cardref);


=head1 DESCRIPTION

Just a database to hold references to L<Decked::Set> objects.

=head1 USAGE

Usage is simple. Creating a new cardbase takes care of importing the
master database. This hard-coded functionality may be bad software
design, but it makes using the object easy. Once created, cards can be
plucked out of the db easily.

=head2 C<my $sets = $sb-E<gt>sets;>

Takes no parameters.
Returns a reference to a hash with keys being set abbreviations, and values
being references to the L<Decked::Set> object represented by that abbreviation.

=head2 C<$sb-E<gt>add_card($cardref);>

Takes a reference to a card that needs to be slotted into a rarity in
the database.
Returns 1 or 0 depending on if the card was successfully added or not.

=head1 BUGS

Possibly. This module was annoying to test, and I certainly may
have missed something.

=head1 AUTHOR

Michael Dungan <mpd@yclan.net>

=head1 COPYRIGHT

Copyright (c) 2003 Michael Dungan All rights reserved.

This file is free software. It can be modified and/or redistributed under
the same terms as Perl itself. Please see the LICENSE file included in the
distribution.

=head1 SEE ALSO

L<decked>,
L<Decked::Set>

=cut
