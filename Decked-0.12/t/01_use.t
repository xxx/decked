# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 11;

BEGIN {
	require_ok( '5.6.0' );
	use_ok( 'Decked::Cardbase' );
	use_ok( 'Decked::Card' );
	use_ok( 'Decked::Setbase' );
	use_ok( 'Decked::Set' );
	use_ok( 'Decked::GUI' );
	use_ok( 'Gtk' );
	use_ok( 'Fcntl' );
	use_ok( 'Data::Dumper' );
	use_ok( 'FileHandle' );
	use_ok( 'Carp' );
}

