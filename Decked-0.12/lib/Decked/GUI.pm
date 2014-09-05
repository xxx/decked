#!/usr/bin/perl -w
#

# this is a overall software version number
$VERSION = '0.12';

# some things are just easier to keep as a file-scoped lexical.
# things all over the place need to check and set these, and there's no
# reason to start up with more of the __FROMFORM type crap.
my $limited = 0; # are we in limited mode?

my $save = 0; # do we need to save the deck before potentially destroying it?

my $statwin = undef; # ref to stats window, which needs to update itself a lot.
my $statobj = undef; # ref to stats object, which also updates often.


#==============================================================================
#=== This is the 'mainwin' class                              
#==============================================================================
package mainwin;
require 5.000; use strict 'vars', 'refs', 'subs';
use Decked::Cardbase;
use Decked::Setbase;
use Decked::Stats;

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

sub app_run {
    my ($class, %params) = @_;

	my $cb = Decked::Cardbase->new;
	my $sb = Decked::Setbase->new;
	my $r = $cb->get_all_cards; #get ref to big array of cardrefs
    Gtk->init;
    my $window = $class->new;

	# databases need to be accessed by the gui;
	$window->FORM->{'__DB'} = $cb; 
	$window->FORM->{'__SB'} = $sb; 

	# this can take some time.
	$window->FORM->{'pool_list'}->freeze;
	foreach(@{$r}) {
		$window->add_card_to_pool('x',$_);
		$sb->add_card($_);
	}
	$window->FORM->{'pool_list'}->thaw;

	# create the deck generation window so it doesn't have to
	# be regenerated every frickin time.
	my $gendeck = deckgenwin->new;
	$gendeck->FORM->{'__SB'} = $window->FORM->{'__SB'};
	$gendeck->FORM->{'__FROMFORM'} = $window->FORM;
	$gendeck->populate_lists($gendeck->FORM);

	# ditto for add-lands window
	my $addland = landwin->new;
	$addland->FORM->{'__FROMFORM'} = $window->FORM;

	# ditto for add-lands window
	my $stats = statswin->new;
	$stats->FORM->{'__FROMFORM'} = $window->FORM;
	$statwin = $stats; # save global ref

	$window->FORM->{'__GENDECK'} = $gendeck;
	$window->FORM->{'__LANDWIN'} = $addland;

	# initialize the filter tree
	
    $window->TOPLEVEL->show;

    # Put any extra UI initialisation (eg signal_connect) calls here

    # Now let Gtk handle signals
    Gtk->main;


    $window->TOPLEVEL->destroy;

    return $window;

}

#===============================================================================
#=== Below are the default signal handlers for 'mainwin' class
#===============================================================================
sub about_Form {
    my ($class) = @_;
    my $gtkversion = 
        Gtk->major_version.".".
        Gtk->minor_version.".".
        Gtk->micro_version;
    my $name = $0;
    my $message = 
        __PACKAGE__." ("._("version")." $VERSION - $DATE)\n".
        _("Written by")." $AUTHOR \n\n".
        _('No description')." \n\n".
        "Gtk ".     _("version").": $gtkversion\n".
        "Gtk-Perl "._("version").": $Gtk::VERSION\n".
        "Glade-Perl version: $Glade::PerlRun::VERSION\n".
        "\n".
        _("run from file").": $name";
    __PACKAGE__->message_box($message, _("About")." \u".__PACKAGE__, [_('Dismiss'), _('Quit Program')], 1,
        "$Glade::PerlRun::pixmaps_directory/Logo.xpm", 'left' );
} # End of sub about_Form

sub destroy_Form {
    my ($class, $data, $object, $instance) = @_;
    Gtk->main_quit; 
} # End of sub destroy_Form

#==============================================================================
#=== Below are the signal handlers for 'mainwin' class 
#==============================================================================
sub on_mainwin_delete {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_mainwin_delete";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	Gtk->main_quit;

} # End of sub on_mainwin_delete

####
# menu signal handlers
####

sub on_deck_with_unlimited_cardpool1_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deck_with_unlimited_cardpool1_activate";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	if($save) {
		save_dialog->app_run;
		return;
	}
	my $sblist = $form->{'sb_list'};
	my $sbframe = $form->{'sb_frame'};
	my $decklist = $form->{'deck_list'};
	my $deckframe = $form->{'deck_frame'};
	mainwin->empty_list($sblist, $sbframe);
	mainwin->empty_list($decklist, $deckframe);
	if($limited) {
		$form->{'OBJECT'}->unlimited_mode;
		$form->{'OBJECT'}->regenerate_master_pool;
	}

} # End of sub on_deck_with_unlimited_cardpool1_activate

sub on_deck_with_this_cardpool1_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	if($save) {
		save_dialog->app_run;
		return;
	}
	my $decklist = $form->{'deck_list'};
	my $sblist = $form->{'sb_list'};
	my $sbframe = $form->{'sb_frame'};
	my $deckframe = $form->{'deck_frame'};
	my @rows = $decklist->rows;
	# move all cards from deck to sideboard.
	move_one_card($decklist, $sblist, 1);
	# update the frame
	@rows = $sblist->rows;
	my $total = 0;
	for(my $i = 0; $i < $rows[0];++$i) {
		$total += $sblist->get_text($i,0);
	}
	$sbframe->set_label("Sideboard: $total");
	$deckframe->set_label("Deck: 0");
	mainwin->clear_pool_color($form) if $limited;

} # End of sub on_deck_with_this_cardpool1_activate

sub on_import_card_pool_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_import_card_pool_activate";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $fsel = pool_selection->new;
	$fsel->FORM->{'__FROMFORM'} = $form;
	$fsel->FORM->{'__DB'} = $form->{'__DB'};
	$fsel->TOPLEVEL->show;
} # End of sub on_import_card_pool_activate

sub on_import_deck_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $fsel = deck_selection->new;
	$fsel->FORM->{'__FROMFORM'} = $form;
	$fsel->TOPLEVEL->show;
} # End of sub on_import_deck_activate

sub on_export_deck_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $fsel = deck_export_selection->new;
	$fsel->FORM->{'__FROMFORM'} = $form;
	$fsel->TOPLEVEL->show;

} # End of sub on_export_deck_activate

sub on_export_card_pool_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_export_card_pool_activate";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $fsel = pool_export_selection->new;
	$fsel->FORM->{'__FROMFORM'} = $form;
	$fsel->TOPLEVEL->show;
} # End of sub on_export_card_pool_activate

sub on_generate_sealed_deck1_activate {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'__GENDECK'}->TOPLEVEL->show;

} # End of sub on_generate_sealed_deck1_activate

sub on_quit1_activate {
    my ($class, $data, $object, $instance, $event) = @_;

	if($save) {
		save_dialog->app_run;
		return;
	}

	Gtk->main_quit;

} # End of sub on_quit1_activate

####
# button signal handlers
####
sub on_stats_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_stats_button_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$statobj = Decked::Stats->new unless($statobj);
	$statobj->initialize($form->{'__DB'}, $form->{'deck_list'});
	$statwin->update_stats if $statwin;
		
	$statwin->TOPLEVEL->show;

} # End of sub on_stats_button_clicked

sub filter_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->filter_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

    # REPLACE the line below with the actions to be taken when __PACKAGE__."->filter_clicked." is called
    __PACKAGE__->show_skeleton_message($me, \@_, __PACKAGE__, "$Glade::PerlRun::pixmaps_directory/Logo.xpm");

} # End of sub filter_clicked

sub in_deck_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $poollist = $form->{'pool_list'};
	my $decklist = $form->{'deck_list'};
	my $deckframe = $form->{'deck_frame'};
	copy_one_card($poollist, $decklist, $deckframe);

} # End of sub in_deck_clicked

sub in_sb_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $poollist = $form->{'pool_list'};
	my $sblist = $form->{'sb_list'};
	my $sbframe = $form->{'sb_frame'};
	copy_one_card($poollist, $sblist, $sbframe);

} # End of sub in_sb_clicked

sub out_deck_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->out_deck_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $decklist = $form->{'deck_list'};
	my @selected = $decklist->selection;
	return unless @selected;
	my $deckframe = $form->{'deck_frame'};
	remove_one_card($decklist, $deckframe);
} # End of sub out_deck_clicked

sub out_sb_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->out_sb_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $sblist = $form->{'sb_list'};
	my @selected = $sblist->selection;
	return unless @selected;
	my $sbframe = $form->{'sb_frame'};
	remove_one_card($sblist, $sbframe);
} # End of sub out_sb_clicked

sub reset_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->reset_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

    # REPLACE the line below with the actions to be taken when __PACKAGE__."->reset_clicked." is called
    __PACKAGE__->show_skeleton_message($me, \@_, __PACKAGE__, "$Glade::PerlRun::pixmaps_directory/Logo.xpm");

} # End of sub reset_clicked

sub sb2d_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $decklist = $form->{'deck_list'};
	my $sblist = $form->{'sb_list'};
	my @selected = $sblist->selection;
	return unless @selected;

	# colorize the added cards in the card pool list if in limited mode
	if($limited) {
		my $poollist = $form->{'pool_list'};
		my @rows = $poollist->rows;
		my $yellow = Gtk::Gdk::Color->parse_color('yellow');
		my $grey = Gtk::Gdk::Color->parse_color('grey');
		for(my $i = 0;$i<$rows[0];++$i) {
			foreach(@selected) {
				if(lc $poollist->get_text($i,1) eq
						lc $sblist->get_text($_,1)) {
					$poollist->set_background($i,$yellow);
					# set foreground to grey to show we don't have
					# any more of this card to add.
					$poollist->set_foreground($i,$grey)
						if ($sblist->get_text($_,0) == 1);
				}
			}
		}
	}

	my $sbframe = $form->{'sb_frame'};
	my $deckframe = $form->{'deck_frame'};
	$decklist->freeze;
	$sblist->freeze;
	move_one_card($sblist, $decklist, undef, $sbframe, $deckframe);
	$decklist->thaw;
	$sblist->thaw;


} # End of sub sb2d_clicked

sub d2sb_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};
	my $decklist = $form->{'deck_list'};
	my $sblist = $form->{'sb_list'};

	my @selected = $decklist->selection;
	return unless @selected;

	my $sbframe = $form->{'sb_frame'};
	my $deckframe = $form->{'deck_frame'};
	$decklist->freeze;
	$sblist->freeze;
	move_one_card($decklist, $sblist, undef, $deckframe, $sbframe);
	$decklist->thaw;
	$sblist->thaw;

	# colorize the added cards in the card pool list if in limited mode
	# this is so inefficient :( gtkperl may have a better way, but the
	# docs are just so lacking
	if($limited) {
		my $poollist = $form->{'pool_list'};
		my @rows = $poollist->rows;
		my @deckrows = $decklist->rows;
		my $yellow = Gtk::Gdk::Color->parse_color('yellow');
		my $grey = Gtk::Gdk::Color->parse_color('grey');
		#first, reset the pool list to white.
		mainwin->clear_pool_color($form);
		# now re-color all the stuff that's still in the deck to yellow
		for(my $i = 0;$i<$rows[0];++$i) {
			for(my $j = 0; $j<$deckrows[0];++$j) {
				if(lc $poollist->get_text($i,1) eq
					lc $decklist->get_text($j,1)) {
					$poollist->set_background($i,$yellow);
					$poollist->set_foreground($i,$grey)
						if ($decklist->get_text($j,0) ==
							$poollist->get_text($i,0));
				}
			}
		}
	}
} # End of sub d2sb_clicked

sub on_add_lands_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'__LANDWIN'}->TOPLEVEL->show;
} # End of sub on_add_lands_button_clicked

####
# misc. handlers
####
# name is kind of a misnomer. all 3 lists use this sub.
sub on_pool_list_button_press_event {
    my ($class, $data, $object, $instance, $event) = @_;
	use Data::Dumper;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $db = $form->{'__DB'};
	my $clist = $form->{$object};

	my $x = $event->{'x'};
	my $y = $event->{'y'};
	my ($row, $column) = $clist->get_selection_info( $x, $y );
	return unless defined($row) && defined($column);
	my $cardref = $db->get_card_by_name($clist->get_text($row,1));

	# if a double click on the pool list, it copies the card into
	# the deck. in limited mode, it will move a card from the sideboard
	# into the deck, if there are any left to put in.
	if($object eq 'pool_list' && $event->{'button'} == 1 &&
			$event->{'type'} eq '2button_press') { # double left click
		my $decklist = $form->{'deck_list'};
		my $deckframe = $form->{'deck_frame'};
		my $sblist = $form->{'sb_list'};
		my $sbframe = $form->{'sb_frame'};
		if($limited) {
			# colorize the added cards in the card pool list if in limited mode
			my $poollist = $form->{'pool_list'};
			my @rows = $poollist->rows;
			my $yellow = Gtk::Gdk::Color->parse_color('yellow');
			my $grey = Gtk::Gdk::Color->parse_color('grey');
			for(my $i = 0;$i<$rows[0];++$i) {
				if(lc $poollist->get_text($i,1) eq
						lc $cardref->name) {
					$poollist->set_background($i,$yellow);
					my @sbrows = $sblist->rows;
					for(my $j = 0; $j < $sbrows[0]; ++$j) {
						if(lc $sblist->get_text($j,1) eq lc
								$cardref->name) {
							# set foreground to grey to show we don't have
							# any more of this card to add.
							$poollist->set_foreground($i,$grey)
							if ($sblist->get_text($j,0) == 1);
							last;
						}
					}
					last;
				}
			}
			move_one_card_by_name($sblist, $decklist, $sbframe,
					$deckframe, $cardref->name);
		}
		else {
			copy_one_card_by_name($cardref->name,$decklist,$deckframe);
		}
	}
	if($event->{'button'} == 3) { #right click
		view_card($cardref);
	}
} # End of sub on_pool_list_button_press_event

sub view_card {
	my $cardref = shift;
	my $view = viewwin->new;
	$view->setcard($cardref);
	$view->TOPLEVEL->show;
}

# when a column is clicked on the pool list, sort on that column
sub on_pool_list_click_column {
    my ($clist, $data, $object, $instance, $column) = @_;
    my $me = __PACKAGE__."->on_pool_list_click_column";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};
	return if $column == 0; # no reason at this time to sort on number of cards

	my @rows = $clist->rows;
	my @arr;
	for(my $i = 0; $i < $rows[0];++$i) {
		my $num = $clist->get_text($i, 0);
		push @arr,[$num,$clist->get_row_data($i)];
	}
	# now sort @arr on the clicked column;
	@arr = sorter($column, @arr);
	$clist->clear;
	#now put new data back in. this would have been so easy were it not
	# for glade
	foreach(@arr) {
		mainwin->add_card_to_pool_func($form, $_->[0], $_->[1]);
	}

} # End of sub on_pool_list_click_column

# in-class helper function.
sub sorter {
	my ($col, @arr) = @_;
	# translate $col to the correct cardref method
	my @xlate = ('x', 'name', 'cost', 'text', 'p_t', 'type',
			'edition', 'color', 'flavor');
	my $method = $xlate[$col];


	# some fields require a special sort
	return sort color_sort @arr if $method eq 'color';
	return sort cost_sort @arr if $method eq 'cost';
	return sort pt_sort @arr if($method eq 'p_t');

	return sort { $a->[1]->$method cmp $b->[1]->$method || 
		$a->[1]->name cmp $b->[1]->name } @arr;
}

#XXX slightly buggy. considers X spells to be zero cost.
# also lumps anything 7> together. this should be more robust eventually.
sub cost_sort {
		int Decked::Stats->cost_to_key($a->[1]->cost) <=>
			int Decked::Stats->cost_to_key($b->[1]->cost) ||
			$a->[1]->cost cmp $b->[1]->cost ||
			$a->[1]->name cmp $b->[1]->name;
}

sub pt_sort {
	my ($ap,$at) = split /\//, $a->[1]->p_t;
	my ($bp,$bt) = split /\//, $b->[1]->p_t;
	$ap <=> $bp || $ap cmp $bp || $at <=> $bt || $at cmp $bt ||
		$a->[1]->name cmp $b->[1]->name;
}

sub color_sort {
		col_to_str($a->[1]->color) cmp col_to_str($b->[1]->color) ||
			$a->[1]->name cmp $b->[1]->name;
}

####
# helper subs
####
sub move_one_card {
	my ($from, $to, $all, $fromframe, $toframe) = @_;
	my @fromsel;
	$from->select_all if $all;
	@fromsel = $from->selection;
	return unless @fromsel; # only the system can move more than one
	my $number = 1;
	foreach(sort {$b <=> $a} @fromsel) {
		my $numfrom = $from->get_text($_,0);
		my $namefrom = $from->get_text($_,1);
		my @torows = $to->rows;
		my $added = 0;
		$number = $numfrom if $all;

		# if no rows in the dest, just append.
		if($torows[0] == 0) {
			$to->append(1,$namefrom) if $namefrom;
			if($numfrom > 0) { $from->set_text($_,0,$numfrom-=$number) }
			if($numfrom <= 0) { $from->remove($_) }
			next;
		}

		# if already there, increment the number
		for(my $i = 0;$i<$torows[0];$i++) {
			if($to->get_text($i,1) eq $namefrom) {
				my $numto = $to->get_text($i,0);
				$to->set_text($i,0,$numto+=$number);
				$added = 1;
				last;
			}
		}
		$to->append($number,$from->get_text($_,1)) unless $added;
		if($numfrom > 0) { $from->set_text($_,0,$numfrom-=$number) }
		if($numfrom <= 0) { $from->remove($_) }
	}

	#update frames if necessary
	if($toframe && $fromframe) {
		# update the frames.
		my ($title, $numcards) = split /\s+/, $toframe->label;
		$numcards += @fromsel;
		$toframe->set_label("$title $numcards");
		($title, $numcards) = split /\s+/, $fromframe->label;
		$numcards -= @fromsel;
		$fromframe->set_label("$title $numcards");
	}
}

sub move_one_card_by_name {
	my ($from, $to, $fromframe, $toframe, $namefrom) = @_;

	my $fromrow = -1;
	my @fromrows = $from->rows;
	for(my $i = 0; $i < $fromrows[0]; ++$i) {
		if(lc $from->get_text($i,1) eq lc $namefrom) {
			$fromrow = $i;
			last;
		}
	}
	return if $fromrow == -1; # should never happen
	my $number = 1; # we only ever move one card at a time in this sub
	my $numfrom = $from->get_text($fromrow,0);
	my @torows = $to->rows;
	my $added = 0;

	# if no rows in the dest, just append.
	if($torows[0] == 0) {
		$to->append($number,$namefrom) if $namefrom;
		$added = 1;
	}

	# if already there, increment the number
	for(my $i = 0;$i<$torows[0];$i++) {
		if(lc $to->get_text($i,1) eq lc $namefrom) {
			my $numto = $to->get_text($i,0);
			$to->set_text($i,0,$numto+=$number);
			$added = 1;
			last;
		}
	}
	$to->append($number,$from->get_text($fromrow,1)) unless $added;
	if($numfrom > 0) { $from->set_text($fromrow,0,$numfrom-=$number) }
	if($numfrom <= 0) { $from->remove($fromrow) }

	#update frames if necessary
	if($toframe && $fromframe) {
		# update the frames.
		my ($title, $numcards) = split /\s+/, $toframe->label;
		++$numcards;
		$toframe->set_label("$title $numcards");
		($title, $numcards) = split /\s+/, $fromframe->label;
		--$numcards;
		$fromframe->set_label("$title $numcards");
	}
}

sub copy_one_card {
	my ($from, $to, $toframe) = @_;
	my @fromsel = $from->selection;
	return unless @fromsel;
	foreach(sort @fromsel) {
		my $numfrom = $from->get_text($_,0);
		my $namefrom = $from->get_text($_,1);
		my @torows = $to->rows;
		my $added = 0;

		# if no rows in the dest, just append.
		if($torows[0] == 0) {
			$to->append(1,$from->get_text($_,1));
			next;
		}

		for(my $i = 0;$i<$torows[0];$i++) {
			if($to->get_text($i,1) eq $namefrom) {
				my $numto = $to->get_text($i,0);
				$to->set_text($i,0,++$numto);
				$added = 1;
				last;
			}
		}
		$to->append(1,$from->get_text($_,1)) unless $added;
	}
	# update the frame.
	if($toframe) {
		my ($title, $numcards) = split /\s+/, $toframe->label;
		$numcards += @fromsel;
		$toframe->set_label("$title $numcards");
	}
}

sub copy_one_card_by_name { # required because of what i believe is a gtk bug
	my ($namefrom, $to, $toframe) = @_;
	my @torows = $to->rows;
	my $added = 0;

	# if no rows in the dest, just append.
	if($torows[0] == 0) {
		$to->append(1,$namefrom) if $torows[0] == 0;
		$added = 1;
	}

	for(my $i = 0;$i<$torows[0];$i++) {
		if($to->get_text($i,1) eq $namefrom) {
			my $numto = $to->get_text($i,0);
			$to->set_text($i,0,++$numto);
			$added = 1;
		}
	}
	$to->append(1,$namefrom) unless $added;
	# update the frame.
	if($toframe) {
		my ($title, $numcards) = split /\s+/, $toframe->label;
		++$numcards;
		$toframe->set_label("$title $numcards");
	}
}

sub remove_one_card {
	my ($from, $frame) = @_;
	my @fromsel = $from->selection;
	return unless @fromsel;
	foreach(sort {$b <=> $a} @fromsel) {
		my $numfrom = $from->get_text($_,0);
		if($numfrom > 0) { $from->set_text($_,0,--$numfrom) }
		if($numfrom <= 0) { $from->remove($_) }
	}
	# update the frame.
	if($frame) {
		my ($title, $numcards) = split /\s+/, $frame->label;
		$numcards -= @fromsel;
		$frame->set_label("$title $numcards");
	}
}

sub add_cards {
	my ($class, $list, $name, $number, $frame) = @_;
	my @torows = $list->rows;
	my $added = 0;
	for(my $i = 0;$i<$torows[0];$i++) {
		if($list->get_text($i,1) eq $name) {
			my $numto = $list->get_text($i,0);
			$numto += $number;
			$list->set_text($i,0,$numto);
			$added = 1;
			last;
		}
	}
	$list->append($number,$name) unless $added;

	# now update frame
	if($frame) {
		my ($title, $numcards) = split /\s+/, $frame->label;
		$numcards += $number;
		$frame->set_label("$title $numcards");
	}
	
}

sub add_card_to_pool {
    my ($this, $numfill, $card) = @_;
	my $cardpool = $this->FORM->{'pool_list'};
	my @arr;
	push @arr,$card->name;
	push @arr,$card->cost;
	my $text = $card->text;
	$text =~ s/\x0d\x0a/ - /g; # convert embedded CRLFs
	$text =~ s/\x20\x0d/ - /g; # convert other random CR's
	push @arr,$text;
	push @arr,$card->p_t;
	push @arr,$card->type;
	push @arr,$card->edition;
	my $color = $card->color;
	$color = col_to_str($color);
	push @arr,$color;
	push @arr,$card->flavor;
	my $r = $cardpool->append($numfill, @arr);
	$cardpool->set_row_data($r,$card); # this needs to be stored.
}

# functional interface to add a card to the pool
# useful for limited mode.
sub add_card_to_pool_func {
    my ($class, $form, $numfill, $card) = @_;
	my $cardpool = $form->{'pool_list'};
	my @arr;
	push @arr,$card->name;
	push @arr,$card->cost;
	my $text = $card->text;
	$text =~ s/\x0d\x0a/ - /g;
	$text =~ s/\x20\x0d/ - /g;
	push @arr,$text;
	push @arr,$card->p_t;
	push @arr,$card->type;
	push @arr,$card->edition;
	my $color = $card->color;
	$color = col_to_str($color);
	push @arr,$color;
	push @arr,$card->flavor;
	my $r = $cardpool->append($numfill, @arr);
	$cardpool->set_row_data($r, $card); # this needs to be stored.
}

# convert a color bitmask to a string of characters
sub col_to_str {
	my $old = shift;
	# color numbers are based on a bitmask
	# this may break on big-endian machines.
	my $white    = 0x1;
	my $blue     = 0x2;
	my $black    = 0x4;
	my $red      = 0x8;
	my $green    = 0x10;
#	my $multi    = 0x20; #unused in this program
	my $artifact = 0x40;
	my $land     = 0x80;
	my $final = '';
	$final .= 'W' if ($old & $white) == $white;
	$final .= 'U' if ($old & $blue) == $blue;
	$final .= 'B' if ($old & $black) == $black;
	$final .= 'R' if ($old & $red) == $red;
	$final .= 'G' if ($old & $green) == $green;
	$final .= 'A' if ($old & $artifact) == $artifact;
	$final .= 'L' if ($old & $land) == $land;
	return $final;
}

sub empty_list {
	my ($class, $list, $frame) = @_;
	$list->clear;

	if($frame) {
		my ($title, undef) = split /\s+/, $frame->label;
		$frame->set_label("$title 0");
	}
}

# we're using a limited card pool, so cards can only
# be moved back and forth between the deck and sideboard.
sub limited_mode {
	my ($class, $form) = @_;
	$form->{'in_deck_button'}->set_sensitive(0);
	$form->{'out_deck_button'}->set_sensitive(0);
	$form->{'in_sb_button'}->set_sensitive(0);
	$form->{'out_sb_button'}->set_sensitive(0);
	$class->empty_list($form->{'pool_list'}); # caller needs to refill the pool.
	$limited = 1;
}
	
# going back to an unlimited cardpool
sub unlimited_mode {
	my $class = shift;
	my $indeck = $class->FORM->{'in_deck_button'};
	my $outdeck = $class->FORM->{'out_deck_button'};
	my $insb = $class->FORM->{'in_sb_button'};
	my $outsb = $class->FORM->{'out_sb_button'};
	my $decklist = $class->FORM->{'deck_list'};
	my $deckframe = $class->FORM->{'deck_frame'};
	my $sblist = $class->FORM->{'sb_list'};
	my $sbframe = $class->FORM->{'sb_frame'};
	my $poollist = $class->FORM->{'pool_list'};
	$indeck->set_sensitive(1);
	$outdeck->set_sensitive(1);
	$insb->set_sensitive(1);
	$outsb->set_sensitive(1);
	mainwin->empty_list($decklist, $deckframe);
	mainwin->empty_list($sblist, $sbframe);
	mainwin->empty_list($poollist); # up to caller to refill the list.
	$limited = 0;
}

# put the entire database back into the card pool
# used when switching from limited to unlimited mode
sub regenerate_master_pool {
	my $class = shift;
	my $list = $class->FORM->{'sb_list'};
	my $pool = $class->FORM->{'pool_list'};
	my $cb = $class->FORM->{'__DB'};
	my $r = $cb->get_all_cards; #get ref to big array of cardrefs
	$pool->freeze;
	foreach(@{$r}) {
		mainwin->add_card_to_pool_func($class->FORM,'x',$_);
	}
	$pool->thaw;
}

# update the pool with new cards from the sideboard list.
# this sub is meant to be called after turning limited mode on.
# calling it when limited mode is not enabled will cause issues.
sub update_pool {
	my ($class, $form) = @_;
	my $list = $form->{'sb_list'};
	my $pool = $form->{'pool_list'};
	my $db = $form->{'__DB'};
	my @rows = $list->rows;
	return unless @rows;
	$pool->freeze;
	for(my $i=0;$i<$rows[0];++$i) {
		my $cardname = $list->get_text($i,1);
		my $num = $list->get_text($i,0);
		my $cardref = $db->get_card_by_name($list->get_text($i,1));
		mainwin->add_card_to_pool_func($form, $list->get_text($i,0), $cardref);
	}
	$pool->thaw;
}

# call this when you're starting a new deck, to clear that color out
sub clear_pool_color {
	my ($class, $form) = @_;
	my $poollist = $form->{'pool_list'};
	my $white = Gtk::Gdk::Color->parse_color('white');
	my $black = Gtk::Gdk::Color->parse_color('black');
	my @rows = $poollist->rows;
	for(my $i = 0;$i < $rows[0];++$i) {
		$poollist->set_background($i, $white);
		$poollist->set_foreground($i, $black);
	}
}
	
package statswin;
require 5.000; use strict 'vars', 'refs', 'subs';

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'statswin' class 
#==============================================================================
sub on_statswin_dismiss_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$statwin->TOPLEVEL->hide;

} # End of sub on_statswin_dismiss_clicked

####
# miscellanous methods for stats windows
####
sub update_stats {
	my $this = shift;
	return unless defined $statobj;
	my $nc = $statobj->numcolors;

	my $str = '';

	my $numcards = $statobj->numcards;
	unless($numcards) {
		$this->FORM->{'numcolors_label'}->set_text($str);
		$this->FORM->{'creatures_lands_label'}->set_text($str);
		$this->FORM->{'mana_curve_label'}->set_text($str);
		return;
	}

	# set the number of each color's mana symbols
	foreach(keys %{$nc}) {
		$str .= $_.": ".$nc->{$_}."\n" if $nc->{$_} > 0;
	}
	$this->FORM->{'numcolors_label'}->set_text($str);

	# set up number of creatures and lands, along w/ percentages
	$str = '';
	my $creatures = $statobj->creatures;
	my $lands = $statobj->lands;
	$str .= sprintf("%-15s%s\n","Cards in Deck: ",$numcards);
	$str .= sprintf("%-15s%s - %.2f%%\n", "Creatures: ", $creatures,
				($creatures / $numcards) * 100);
	$str .= sprintf("%-15s%s - %.2f%%\n","Lands: ", $lands,
			($lands / $numcards) * 100);
	$this->FORM->{'creatures_lands_label'}->set_text($str);

	# set up mana curve
	$str = '';
	my $curve = $statobj->curve;
	foreach(sort keys %{$curve}) {
		$str .= sprintf("%2s: %3d  %s\n", $_, $curve->{$_}, '#'x$curve->{$_});
	}
	$str .= sprintf("%s %.2f\n", "Average Mana Cost: ",
			$statobj->curvemana / $statobj->curvecards);
	$this->FORM->{'mana_curve_label'}->set_text($str);
}





package viewwin;
require 5.000; use strict 'vars', 'refs', 'subs';
BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'viewwin' class 
#==============================================================================
sub on_view_dismiss_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'viewwin'}->destroy;
} # End of sub on_view_dismiss_button_clicked

# set the information to show the user
# expects a Decked::Card object
sub setcard {
	my($this, $cardref) = @_;
	my $form = $this->{'FORM'};
	$form->{'name_label'}->set_text($cardref->name);
	$form->{'cost_label'}->set_text($cardref->cost);
	$form->{'text_label'}->set_text($cardref->text);
	$form->{'pt_label'}->set_text($cardref->p_t);
	$form->{'type_label'}->set_text($cardref->type);
	$form->{'rarity_label'}->set_text($cardref->edition);
	$form->{'flavor_label'}->set_text($cardref->flavor);
}









#==============================================================================
#=== This is the 'landwin' class                              
#==============================================================================
package landwin;
require 5.000; use strict 'vars', 'refs', 'subs';

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'landwin' class 
#==============================================================================
sub on_forest_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $clist = $form->{'__FROMFORM'}{'deck_list'};
	my $frame = $form->{'__FROMFORM'}{'deck_frame'};
	add_land('Forest', $clist, $frame);
} # End of sub on_forest_button_clicked

sub on_island_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $clist = $form->{'__FROMFORM'}{'deck_list'};
	my $frame = $form->{'__FROMFORM'}{'deck_frame'};
	add_land('Island', $clist, $frame);

} # End of sub on_island_button_clicked

sub on_mountain_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $clist = $form->{'__FROMFORM'}{'deck_list'};
	my $frame = $form->{'__FROMFORM'}{'deck_frame'};
	add_land('Mountain', $clist, $frame);
} # End of sub on_mountain_button_clicked

sub on_plains_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $clist = $form->{'__FROMFORM'}{'deck_list'};
	my $frame = $form->{'__FROMFORM'}{'deck_frame'};
	add_land('Plains', $clist, $frame);
} # End of sub on_plains_button_clicked

sub on_swamp_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $clist = $form->{'__FROMFORM'}{'deck_list'};
	my $frame = $form->{'__FROMFORM'}{'deck_frame'};
	add_land('Swamp', $clist, $frame);
} # End of sub on_swamp_button_clicked

sub add_land {
	my ($land, $clist, $frame) = @_;
	my @rows = $clist->rows;
	my $label = $frame->label;
	my ($title, $numcards) = split /\s+/, $label;
	++$numcards;
	$frame->set_label("$title $numcards");
	# if already in the list, update that and return, else append to end
	for(my $i = 0;$i<$rows[0];$i++) {
		if($clist->get_text($i,1) eq $land) {
			my $num = $clist->get_text($i,0);
			$clist->set_text($i,0,++$num);
			return;
		}
	}
	$clist->append((1,$land));
}

sub on_land_dismiss_button_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'landwin'}->hide;
} # End of sub on_land_dismiss_button_clicked


#==============================================================================
#=== This is the 'deckgenwin' class                              
#==============================================================================
package deckgenwin;
require 5.000; use strict 'vars', 'refs', 'subs';
BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'deckgenwin' class 
#==============================================================================
sub on_add_booster_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $newset = $form->{'booster_combo'}->entry->get_text;
	return unless $newset;
	my $list = $form->{'booster_list'};
	startboost_copy($list, $newset);
} # End of sub on_add_booster_clicked

sub on_add_starter_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $newset = $form->{'starter_combo'}->entry->get_text;
	return unless $newset;
	my $list = $form->{'starter_list'};
	startboost_copy($list, $newset);
} # End of sub on_add_starter_clicked

sub startboost_copy {
	my ($list, $newset) = @_;
	my @rows = $list->rows;
	my $added = 0;
	for(my $i = 0;$i<$rows[0];++$i) {
		my $s = $list->get_text($i,1);
		if($s eq $newset) {
			my $n = $list->get_text($i,0);
			$list->set_text($i, 0, ++$n);
			$added = 1;
			last;
		}
	}
	$list->append('1',$newset) unless $added;
}

sub on_remove_booster_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	remove_startboost($form->{'booster_list'});
} # End of sub on_remove_booster_clicked

sub on_remove_starter_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	remove_startboost($form->{'starter_list'});
} # End of sub on_remove_starter_clicked

sub remove_startboost {
	my $from = shift;
	my @fromsel = $from->selection;
	return unless @fromsel;
	foreach(reverse @fromsel) {
		my $numfrom = $from->get_text($_,0);
		if($numfrom > 0) { $from->set_text($_,0,--$numfrom) }
		if($numfrom <= 0) { $from->remove($_) }
	}
}

sub on_deckgen_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deckgen_cancel_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'deckgenwin'}->hide;
} # End of sub on_deckgen_cancel_clicked

sub on_deckgen_generate_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deckgen_generate_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};
	my $fromform = $form->{'__FROMFORM'};
	my $sb = $form->{'__SB'};
	my $sets = $sb->sets;
	my $starter_list = $form->{'starter_list'};
	my $booster_list = $form->{'booster_list'};

	my @startrows = $starter_list->rows;
	my @boostrows = $booster_list->rows;
	return unless $startrows[0] || $boostrows[0];
	# create starters:
	# walk through starter list
	#	for each starter:
	#		randomly get X of each commonality and add to deck list
	my $deck = undef;
	for(my $i = 0;$i<$startrows[0];++$i) {
		my $numstarters = $starter_list->get_text($i,0);
		my ($starterset, undef) = split /-/, $starter_list->get_text($i,1);
		my $set = $sets->{$starterset};
		my $nc = $set->sc; # get number of commons to generate for this deck
		my $nu = $set->su; # get number of uncommons to generate for this deck
		my $nr = $set->sr; # get number of rares to generate for this deck

		my $thisdeck = undef; # tmp variable. no repeats are allowed in this, as
			                  # opposed to the $deck itself. this is not
                              # how sets are really collated, esp. older ones
		                      # that have multiple art for a single card.

		# this is kind of hairy, and could be written better. but it works.
		# this will loop forever if the set database is somehow corrupted
		# and the size of a starter or booster becomes larger than the
		# size of the set.
		for(1 .. $numstarters) {
			my $j = 0;
			# generate $nc commons
			while($j<$nc) {
				my $list = $set->commons;
				my $newcard = $list->[rand(@{$list})]->name;
				"common! $newcard\n";
				next if(exists $thisdeck->{$newcard}); # already here.
				$thisdeck->{$newcard} = 1;
				++$j;
			}
			$j = 0;
			# generate $nu uncommons
			while($j<$nu) {
				my $list = $set->uncommons;
				my $newcard = $list->[rand(@{$list})]->name;
				"uncommon! $newcard\n";
				next if(exists $thisdeck->{$newcard}); # already here.
				$thisdeck->{$newcard} = 1;
				++$j;
			}
			$j = 0;
			# generate $nr rares
			while($j<$nr) {
				my $list = $set->rares;
				my $newcard = $list->[rand(@{$list})]->name;
				"rare! $newcard\n";
				next if(exists $thisdeck->{$newcard}); # already here.
				$thisdeck->{$newcard} = 1;
				++$j;
			}
			# add all cards to the real deck ($deck)
			foreach(keys %{$thisdeck}) {
				if(exists $deck->{$_}) {
					# card already in main deck. add another one.
					my $n = $deck->{$_};
					$deck->{$_} = ++$n;
				}
				else {
					$deck->{$_} = 1;
				}
			}
			undef $thisdeck;
		}
	}

	# create boosters
	# walk through booster list
	#	for each booster:
	#		randomly get X of each commonality and add to deck list
	for(my $i = 0;$i<$boostrows[0];++$i) {
		my $numboosters = $booster_list->get_text($i,0);
		my ($boosterset, undef) = split /-/, $booster_list->get_text($i,1);
		my $set = $sets->{$boosterset};
		my $nc = $set->bc; # get number of commons to generate for this deck
		my $nu = $set->bu; # get number of uncommons to generate for this deck
		my $nr = $set->br; # get number of rares to generate for this deck
		my $thisdeck = undef; # tmp variable. no repeats are allowed in this, as
			                  # opposed to the %{$deck} itself.

		for(1 .. $numboosters) {
			my $j = 0;
			# generate $nc commons
			while($j<$nc) {
				my $list = $set->commons; # all the commons in this set
				my $newcard = $list->[rand(@{$list})]->name; # pick a random
				next if(exists $thisdeck->{$newcard}); # already in the deck
				$thisdeck->{$newcard} = 1; # not in deck. add it and move on.
				++$j;
			}
			$j = 0;
			# generate $nu uncommons
			while($j<$nu) {
				my $list = $set->uncommons;
				my $newcard = $list->[rand(@{$list})]->name;
				next if(exists $thisdeck->{$newcard}); # already here.
				$thisdeck->{$newcard} = 1;
				++$j;
			}
			$j = 0;
			# generate $nr rares
			while($j<$nr) {
				my $list = $set->rares;
				my $newcard = $list->[rand(@{$list})]->name;
				next if(exists $thisdeck->{$newcard}); # already here.
				$thisdeck->{$newcard} = 1;
				++$j;
			}
			# add all cards to the real deck ($deck)
			foreach(keys %{$thisdeck}) {
				if(exists $deck->{$_}) {
					# card already in main deck. add another one.
					my $n = $deck->{$_};
					$deck->{$_} = ++$n;
				}
				else {
					$deck->{$_} = 1;
				}
			}
			undef $thisdeck;
		}
	}

	# clear out card pool list - finish when limited mode is done.
	$fromform->{'OBJECT'}->limited_mode($fromform);

	# clear out deck and sb lists
	mainwin->empty_list($fromform->{'sb_list'}, $fromform->{'sb_frame'});
	mainwin->empty_list($fromform->{'deck_list'}, $fromform->{'deck_frame'});
		
	# throw this deck into the main window's sideboard.
	my $mainsblist = $fromform->{'sb_list'};
	my $numsb = 0;
	foreach(sort keys %{$deck}) {
		$mainsblist->append($deck->{$_}, $_);
		$numsb += $deck->{$_};
	}
	# set the correct number of cards in the sb frame
	$fromform->{'sb_frame'}->set_label("Sideboard: $numsb");

	# update the main window's card pool
	mainwin->update_pool($form->{'__FROMFORM'});

	# and we're done.
	$form->{'deckgenwin'}->hide;
	
} # End of sub on_deckgen_generate_clicked

sub populate_lists {
	my ($this, $form) = @_;
	my $sets = $form->{'__SB'}->sets;
	my @st;
	my @bo;
	foreach(sort keys %{$sets}) {
		# heuristic. if starters/boosters have commons in them, they must exist.
		push @st,$_.'-'.$sets->{$_}->name if $sets->{$_}->sc > 0;
		push @bo,$_.'-'.$sets->{$_}->name if $sets->{$_}->bc > 0;
	}
	my $slist = $form->{'starter_combo'};
	$slist->set_popdown_strings(@st);
	$slist = $form->{'booster_combo'};
	$slist->set_popdown_strings(@bo);
}
	





#==============================================================================
#=== This is the 'save_dialog' class                              
#==============================================================================
package save_dialog;
require 5.000; use strict 'vars', 'refs', 'subs';
use Carp;
BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

sub app_run {
    my ($class, $continue) = @_;

	croak "save_dialog->app_run was not passed a coderef!"
		unless $continue && ref $continue eq 'CODE';

    my $window = $class->new;
    $window->TOPLEVEL->show;
    return $window;
} # End of sub app_run

#==============================================================================
#=== Below are the signal handlers for 'save_dialog' class 
#==============================================================================
sub on_save_dialog_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_save_dialog_cancel_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

    # REPLACE the line below with the actions to be taken when __PACKAGE__."->on_save_dialog_cancel_clicked." is called
    __PACKAGE__->show_skeleton_message($me, \@_, __PACKAGE__, "$Glade::PerlRun::pixmaps_directory/Logo.xpm");

} # End of sub on_save_dialog_cancel_clicked

sub on_save_dialog_no_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_save_dialog_no_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

    # REPLACE the line below with the actions to be taken when __PACKAGE__."->on_save_dialog_no_clicked." is called
    __PACKAGE__->show_skeleton_message($me, \@_, __PACKAGE__, "$Glade::PerlRun::pixmaps_directory/Logo.xpm");

} # End of sub on_save_dialog_no_clicked

sub on_save_dialog_yes_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_save_dialog_yes_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

    # REPLACE the line below with the actions to be taken when __PACKAGE__."->on_save_dialog_yes_clicked." is called
    __PACKAGE__->show_skeleton_message($me, \@_, __PACKAGE__, "$Glade::PerlRun::pixmaps_directory/Logo.xpm");

} # End of sub on_save_dialog_yes_clicked




#==============================================================================
#=== This is the 'error_dialog' class                              
#==============================================================================
package error_dialog;
require 5.000; use strict 'vars', 'refs', 'subs';

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

sub new_err {
    my ($class, $msg) = @_;
    my $window = $class->new;
	$window->FORM->{'error_dialog_label'}->set_text($msg);
    $window->TOPLEVEL->show;
    return $window;
} # End of sub new_err

#==============================================================================
#=== Below are the signal handlers for 'error_dialog' class 
#==============================================================================
sub on_error_dialog_dismiss_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'error_dialog'}->destroy;
} # End of sub on_error_dialog_dismiss_clicked








#==============================================================================
#=== This is the 'deck_selection' class                              
#==============================================================================
package deck_selection;
require 5.000; use strict 'vars', 'refs', 'subs';

use Carp;

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#===============================================================================
#=== Below are the signal handlers for 'deck_selection' class
#===============================================================================
sub on_deck_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deck_cancel_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'deck_selection'}->destroy;
} # End of sub on_deck_cancel_clicked

sub on_deck_ok_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deck_ok_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $decklist = $form->{'__FROMFORM'}{'deck_list'};
	my $sblist = $form->{'__FROMFORM'}{'sb_list'};
	my $deckframe = $form->{'__FROMFORM'}{'deck_frame'};
	my $sbframe = $form->{'__FROMFORM'}{'sb_frame'};

	my $fsel = $form->{'deck_selection'};
	my $filename = $fsel->get_filename;
	unless(-r $filename) {
		error_dialog->new_err("$filename not readable!\n");
		return;
	}

	if($save) { # yes, we need to save
		save_dialog->app_run;
		return;
	}
	if($limited) { # in limited mode. let's get out.
		$form->{'__FROMFORM'}->{'OBJECT'}->unlimited_mode;
		$form->{'__FROMFORM'}->{'OBJECT'}->regenerate_master_pool;
	}

	# clear out the deck and sideboard lists;
	mainwin->empty_list($decklist, $deckframe);
	mainwin->empty_list($sblist, $sbframe);

	open(INFILE,$filename) or croak "Can't open $filename: $!";
	while(<INFILE>) {
		#strip whitespace
		chomp;
		s/^\s+//;
		s/\s+$//;
		# skip commented lines
		next if m!^//!;
		if(/^(SB:\s+|)(\d+)\s+(.*)$/) {
			my $number = $2;
			my $cardname = $3;
			next unless $number && $cardname;
			if($1) { # this is a sideboard card
				mainwin->add_cards($sblist,$cardname,$number,$sbframe);
			}
			else { # not in sb. add to deck instead.
				mainwin->add_cards($decklist,$cardname,$number,$deckframe);
			}
		}
	}
	close INFILE;
	
	$form->{'deck_selection'}->destroy;
} # End of sub on_deck_ok_clicked

#==============================================================================
#=== This is the 'deck_export_selection' class                              
#==============================================================================
package deck_export_selection;
require 5.000; use strict 'vars', 'refs', 'subs';
use Carp;

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'deck_export_selection' class 
#==============================================================================
sub on_deck_export_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deck_export_cancel_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'deck_export_selection'}->destroy;

} # End of sub on_deck_export_cancel_clicked

sub on_deck_export_ok_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_deck_export_ok_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $decklist = $form->{'__FROMFORM'}{'deck_list'};
	my $sblist = $form->{'__FROMFORM'}{'sb_list'};

	my $fsel = $form->{'deck_export_selection'};
	my $filename = $fsel->get_filename;

	return unless $filename;
	# XXX test the filename for write access, etc.
	if(-e $filename) {
		if(! -w $filename) {
			error_dialog->new_err(
					"$filename exists but isn't writable by you.");
			return;
		}
	}

	open(OUTFILE,">$filename") or croak "Can't open $filename: $!";
	my @rows = $decklist->rows;
	for(my $i = 0;$i<$rows[0];++$i) {
		print OUTFILE
			$decklist->get_text($i,0).' '.$decklist->get_text($i,1)."\n";
	}
	my @rows = $sblist->rows;
	for(my $i = 0;$i<$rows[0];++$i) {
		print OUTFILE
			'SB: '.$sblist->get_text($i,0).' '.$sblist->get_text($i,1)."\n";
	}
	close OUTFILE;
	
	$form->{'deck_export_selection'}->destroy;
} # End of sub on_deck_export_ok_clicked

#==============================================================================
#=== This is the 'pool_selection' class                              
#==============================================================================
package pool_selection;
require 5.000; use strict 'vars', 'refs', 'subs';

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'pool_selection' class 
#==============================================================================
sub on_pool_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_pool_cancel_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'pool_selection'}->destroy;
} # End of sub on_pool_cancel_clicked

sub on_pool_ok_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $decklist = $form->{'__FROMFORM'}{'deck_list'};
	my $sblist = $form->{'__FROMFORM'}{'sb_list'};
	my $deckframe = $form->{'__FROMFORM'}{'deck_frame'};
	my $sbframe = $form->{'__FROMFORM'}{'sb_frame'};

	my $fsel = $form->{'pool_selection'};
	my $filename = $fsel->get_filename;
	unless(-r $filename) {
		error_dialog->new_err("$filename not readable!\n");
		return;
	}
	# turn on limited mode.
	$form->{'__FROMFORM'}->{'OBJECT'}->limited_mode($form->{'__FROMFORM'});
	my $db = $form->{'__DB'};

	# clear out the deck and sideboard lists;
	mainwin->empty_list($decklist, $deckframe);
	mainwin->empty_list($sblist, $sbframe);

	open(INFILE,$filename) or die "Can't open $filename: $!";
	while(<INFILE>) {
		#strip whitespace
		chomp;
		s/^\s+//;
		s/\s+$//;
		# skip commented lines
		next if m!^//!;
		if(/^(?:SB:\s+|)(\d+)\s+(.*)$/) {
			my $number = $1;
			my $cardname = $2;
			next unless $number && $cardname;
			# all cards in a card pool are put into the sb initially.
			mainwin->add_cards($sblist,$cardname,$number,$sbframe);
		}
	}
	close INFILE;
	# update the pool w/ database info.
	mainwin->update_pool($form->{'__FROMFORM'});
	
	$form->{'pool_selection'}->destroy;
} # End of sub on_deck_ok_clicked

#==============================================================================
#=== This is the 'pool_export_selection' class                              
#==============================================================================
package pool_export_selection;
require 5.000; use strict 'vars', 'refs', 'subs';

BEGIN {
    use Decked::GUIUI;
} # End of sub BEGIN

#==============================================================================
#=== Below are the signal handlers for 'pool_export_selection' class 
#==============================================================================
sub on_pool_export_cancel_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	$form->{'pool_export_selection'}->destroy;
} # End of sub on_pool_export_cancel_clicked

sub on_pool_export_ok_clicked {
    my ($class, $data, $object, $instance, $event) = @_;
    my $me = __PACKAGE__."->on_pool_export_ok_clicked";
    # Get ref to hash of all widgets on our form
    my $form = $__PACKAGE__::all_forms->{$instance};

	my $poollist = $form->{'__FROMFORM'}->{'pool_list'};

	my $fsel = $form->{'pool_export_selection'};
	my $filename = $fsel->get_filename;

	# XXX test the filename for write access, etc.

	open(OUTFILE,">$filename") or die "Can't open $filename: $!";
	my @rows = $poollist->rows;
	for(my $i = 0;$i<$rows[0];++$i) {
		# all cards in a cardpool start in the sideboard
		print OUTFILE
			'SB: '.$poollist->get_text($i,0).' '.$poollist->get_text($i,1)."\n";
	}
	close OUTFILE;
	
	$form->{'pool_export_selection'}->destroy;
} # End of sub on_pool_export_ok_clicked

1;

__END__

#===============================================================================
#==== Documentation
#===============================================================================
=pod

=head1 NAME

Decked::GUI

Implementation of signal handlers and most other application
logic (that should be modularized) for the Decked deck editor.

=head1 SYNOPSIS

 use GUI;

 To construct the window object and show it call
 
 Gtk->init;
 my $window = mainwin->new;
 $window->TOPLEVEL->show;
 Gtk->main;
 
 OR use the shorthand for the above calls
 
 mainwin->app_run;


 The above stuff was pre-generated. Anyway, it's highly unlikely
 that anyone will ever need this code, as it's very application
 specific, and much of it was generated by Glade. The code would
 likely be cleaner had I not used Glade to create the interface,
 but this project would have never got off the ground had that
 been the case. Supa!

=head1 DESCRIPTION

Several packages make up this file. A quick description each one
follows, along with a listing of their functions.

I<Note:> Much of this functionality will be moved into modules at a later date.

=head2 mainwin

The main window that's shown to the user when the program begins.

=head2 landwin

Window used to add basic lands to a deck. Useful for limited card pools.

=head2 deckgenwin

Window used to generate sealed decks and boosters.

=head2 viewwin

Window used to view a card when it's right-clicked on.

=head2 statswin

Window used to view some statistics about the current deck (defined by
cards that are in the deck list. The sideboard is not included.)

=head2 Import/Export file selections

=over 4

=item B<deck_import_selection>

=item B<deck_export_selection>

=item B<pool_import_selection>

=item B<pool_export_selection>

These should be fairly obvious.

=back

=head2 Dialogs

=over 4

=item B<error_dialog>

Error messages for the user.

=item B<save_dialog> (currently unimplemented)

Comes up when an operation is initiated that would wipe out the
current deck. Asks the user if they would like to save first.

=back

=head1 AUTHOR

Michael Dungan <mpd@yclan.net>

=head1 COPYRIGHT

Copyright (c) 2003 Michael Dungan All rights reserved.

This file is free software. It can be modified and/or redistributed under
the same terms as Perl itself. Please see the LICENSE file included in the
distribution.

=cut
