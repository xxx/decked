package Decked::Cardbase;
use strict;
use warnings;
use integer;
use Carp;
use Data::Dumper;
use Fcntl qw(SEEK_SET);
use FileHandle;
use Decked::Card;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.11;
	@ISA         = qw (Exporter);
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $dbfile = $ENV{'CARDINFO_DAT'};
	croak "CARDINFO_DAT env variable not set!" unless $dbfile;
	croak "$ENV{'CARDINFO_DAT'} is not readable!" unless -r $dbfile;

	my $handle = FileHandle->new;
	$handle->open($dbfile) or die "can't open cardbase: $!";
	my $location = read_int32($handle);
	seek($handle, $location, SEEK_SET) or die "Seek failed! $!";
	my $num_cards = read_int32($handle);
	my $card;
	my @cards;
	for(my $i = 0;$i<$num_cards;++$i) {
		# create new card. shove the info in. add to array.
		$card = Decked::Card->new;
		$card->name(read_pascal_string($handle));
		$card->location(read_int32($handle));
		$card->color(read_int8($handle));
		$card->edition(read_pascal_string($handle));
		read_int8($handle); #dummy
		read_int8($handle); #dummy
		push @cards,$card;
	}
	foreach(@cards) {
		next unless seek($handle, $_->location, SEEK_SET);
		$_->type(read_pascal_string($handle));
		$_->cost(read_pascal_string($handle));
		$_->p_t(read_pascal_string($handle));
		$_->text(read_pascal_string($handle));
		$_->flavor(read_pascal_string($handle));
	}
	$handle->close;
	@cards = sort {$a->name cmp $b->name} @cards;

	my $self = {
		DBFILE => $dbfile,
		CARDS => \@cards
	};

	bless($self, $class);
	return ($self);
}

sub read_int32 {
	my $handle = shift;
	my $i;
	read($handle, $i, 4);
	return unpack('i',$i);
}

sub read_int8 {
	my $handle = shift;
	my $i;
	read($handle, $i, 1);
	return unpack('C',$i);
}

sub read_pascal_string {
	my $handle = shift;
	my $len;
	read($handle, $len, 2); # read 2 bytes to get string length.
	$len = unpack('S',$len);
	my $str;
	read($handle, $str, $len);
	$str =~ tr/\x97/-/;
	$str =~ tr/\x91\x92/'/;
	$str =~ tr/\x93\x94/"/;
	return $str;
}

# this is not a mutator by design.
sub get_all_cards {
	my $this = shift;
	return $this->{'CARDS'};
}

sub get_card_by_globalid {
	my ($this, $index) = @_;
	return $this->{'CARDS'}->[$index];
}

sub get_globalid_by_name {
	my ($this, $n) = @_;
	my ($lo, $hi, $mid, $val);
	my @cards = @{$this->{'CARDS'}};
	$lo = 0;
	$hi = @cards-1;
	while($lo <= $hi) {
		$mid = ($lo+$hi) / 2; # need to truncate.
		$val = lc $cards[$mid]->name cmp lc $n;
		return $mid if $val == 0;
		if($val < 0) {
			$lo = $mid+1;
		}
		else {
			$hi = $mid-1;
		}
	}
	return -1;
}

sub get_card_by_name {
	my ($this, $name) = @_;
	my $id = $this->get_globalid_by_name($name);
	my $card = $this->get_card_by_globalid($id);
	return $card;
}

1;
__END__


=head1 NAME

Decked::Cardbase - Module to read and manipulate Card database files.

=head1 SYNOPSIS

  use Decked::Cardbase;
  my $cardbase = Decked::Cardbase->new();
  my $cards = $cardbase->get_all_cards;
  my $cardref = $cardbase->get_card_by_name("Shichifukujin Dragon");

=head1 DESCRIPTION

This module stores a reference to an array of references to Decked::Card
objects (i.e. it just stores all the cards.)

=head1 USAGE

Usage is simple. Creating a new cardbase takes care of importing the
master database. This hard-coded functionality may be bad software
design, but it makes using the object easy. Once created, cards can be
plucked out of the db easily.

=head2 C<my $cards = $cb-E<gt>get_all_cards;>

Takes no parameters.
Returns a reference to the entire array of cardrefs stored by this object.

=head2 C<my $cardref = $cb-E<gt>get_card_by_globalid(12345);>

Takes the id of the card to find (id is the card's unique ID number in
the Apprentice database.)
Returns reference to the Decked::Card object that the passed ID represents.

I<Note>: This method is likely not very useful, but is included for
completeness' sake, and is used in the C<get_card_by_name> method.

=head2 C<my $gid = $cb-E<gt>get_globalid_by_name("Shichifukujin Dragon");>

Takes the name of the card to find (i.e. a string.)
Returns the globalid of said card.

I<Note>: Like C<get_card_by_globalid>, this method is not very
useful, but is included for the exact same reasons.

=head2 C<my $cardref = $cb-E<gt>get_card_by_name("Shichifukujin Dragon");>

Takes the name of the card to find (i.e. a string.)
Returns a reference to the desired card.
Assumes each card only has one entry in the database, which
is true of the Apprentice databases.

=head1 BUGS

If there are any, they will almost definitely be in the
C<get_globalname_by_id> method. In the past, it has misfired
and come up with the wrong card, so it just returns the last
card in the database. The current implementation works but
could be made to be more robust.

=head1 NOTE

This file was ported from its original C version to Perl by Michael Dungan.
The original C file was written by Salvatore Valente (svalente@mit.edu) for
his software, Mindless Automaton, which is what this software aims to
supplement. This file, while a derivative work, has been explicitly 
permitted to be released under the dual Perl license (see LICENSE
in this distribution.)

=head1 AUTHOR

Michael Dungan <mpd@yclan.net>

=head1 COPYRIGHT

Copyright (c) 2003 Michael Dungan All rights reserved.

This file is free software. It can be modified and/or redistributed under
the same terms as Perl itself. Please see the LICENSE file included in the
distribution.

=head1 SEE ALSO

L<decked>,
L<Decked::Card> 

=cut

