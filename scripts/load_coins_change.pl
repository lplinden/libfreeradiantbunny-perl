#!/usr/bin/perl

# WARNING THIS SCRIPT WILL CLOBBER THE DATA IN THE "change" fields of the coins table of the frb database
print "see warning: this will clobber coins.change field in database\n";
sleep 10;
print "\n";
exit;

# load_coins_change
# copyright 2022 Lars Paul Linden
# version 2.0.2
# get signal_level and recent from freeradiantbunny db
# then calculate change and then store the result in coins "change" field

# LPL 2022-03-16 initial script to help with freeradiantbunny database management

use strict;
use warnings;
use Term::ANSIColor;
use JSON;
use DBI;

# set up environement variables to connect to database
my $db = $ENV{'FRB_DB'};
my $user = $ENV{'FRB_USER'};
my $pw = $ENV{'FRB_SPECIAL'};
print "GIVEN database: " . $db . "\n";
print "GIVEN user: " . $user . "\n";
my $dbh = DBI->connect("DBI:Pg:dbname=$db;host=localhost", $user, $pw, {'RaiseError' => 1});

# get symbols from database coins table and store references in array below
my $symbols_ref = get_symbols_on_watch_list($dbh);
if (! ${ $symbols_ref }[0]) {
    die "watchlist symbols not found\.n";
}

# loop through symbols
my $num = 0;
my $symbol;
foreach $symbol (@{ $symbols_ref }) {
    $num++;
    print "num = " . $num . "\n";
    print "symbol                   = " . $symbol . "\n";
    # get signal_field
    my $field = "signal_level";
    my $signal_level = get_from_database($dbh, $symbol, $field);
    # current change
    $field = "change";
    my $change = get_from_database($dbh, $symbol, $field);
    my $change_previous = $change;
    print "change_previous          = " . $change_previous . "\n";
    store_in_database($dbh, $symbol, "change_previous", $change_previous);
    # acceleration
    $field = "acceleration";
    my $acceleration = get_from_database($dbh, $symbol, $field);
    my $acceleration_previous = $acceleration;
    print "acceleration_previous    = " . $acceleration_previous . "\n";
    # store
    store_in_database($dbh, $symbol, "acceleration_previous", $acceleration_previous);
    # zero change field
    # empty to show that data was attempted
    zero_change_field_in_database($dbh, $symbol);
    # get recent field
    $field = "recent";
    my $recent = get_from_database($dbh, $symbol, $field);
    # generated variables derived from other variables
    # avoid division by zero
    if ($recent && $recent > 0) {
	# show math
	print "recent                   = " . $recent . "\n";
	print "signal_level             = " . $signal_level . "\n";
	my $difference = $recent - $signal_level;
	print "difference               = " . $difference . "\n";	
	my $percent_change = ($difference / $signal_level) * 100;
	print "percent_change           = " . $percent_change . "\n";
	# format for readable decimal
	my $percent_change_formatted = sprintf('%.2f', $percent_change);
	print "percent_change_formatted = " . $percent_change_formatted . "\n";
	# calculate
	$acceleration = $percent_change_formatted - $change_previous;
	$acceleration = sprintf('%.2f', $acceleration);
	print "acceleration             = " . $acceleration . "\n";
	#
	store_in_database($dbh, $symbol, "change", $percent_change_formatted);
	store_in_database($dbh, $symbol, "acceleration", $acceleration);
	# one more variable to calculate
	my $acceleration_change = $acceleration - $acceleration_previous;
	my $acceleration_change_description = "";
	if ($acceleration < 0 && $acceleration_previous < 0 && $acceleration_previous < $acceleration) {
	    $acceleration_change_description = "<br />less brakes";
	} elsif ($acceleration > 0 && $acceleration_previous < 0 && $acceleration_previous < $acceleration) {
	    $acceleration_change_description = "<br />brakes to gas";
	} elsif ($acceleration > 0 && $acceleration_previous > 0 && $acceleration_previous < $acceleration) {
	    $acceleration_change_description = "<br />stepping gas";
	}
	$acceleration_change .= $acceleration_change_description;
	print "acceleration_change      = " . $acceleration_change . "\n";
        store_in_database($dbh, $symbol, "acceleration_change", $acceleration_change);
	sleep 1;
    } else {
	# clear field
	my $null_string = "";
	store_in_database($dbh, $symbol, "change", $null_string);
	store_in_database($dbh, $symbol, "acceperation", $null_string);
    }
    print "\n";
}
# close database connection
$dbh->disconnect();

#
sub get_from_database {
    my $dbh = shift;
    my $symbol = shift;
    my $field = shift;
    # execute SELECT query
    my $sql_statement = "select " . $field . " from coins where ticker='" . $symbol . "';";
    #print "executing sql_statement: " . $sql_statement . "\n";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
    if($result < 0) {
	# error when executing sql_statement
	print "load_coins_change.pl error : " . $DBI::errstr;
    }
    my $field_result_found;
    while(my $ref = $sth->fetchrow_hashref()) {
	$field_result_found = $ref->{$field};
    }
    if ($field_result_found) {
	#print $field_result_found . "\n";
	return $field_result_found;
    }
    return "";
}

#
sub zero_change_field_in_database {
    my $dbh = shift;
    my $symbol = shift;
    # execute SELECT query
    my $sql_statement = "update coins set change= '' where ticker='" . $symbol . "';";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
}

#
sub store_in_database {
    my $dbh = shift;
    my $symbol = shift;
    my $field = shift;
    my $value = shift;
    # execute SELECT query
    my $sql_statement = "update coins set " . $field . "='" . $value . "' where ticker='" . $symbol . "';";
    #print "executing sql_statement: " . $sql_statement . "\n";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
    #print "result = " . $result . "\n";
    #print "\n";
}

#
sub get_symbols_on_watch_list {
    my $dbh = shift;
    my @symbols = ();
    my $symbols_ref = \@symbols;
    # execute SELECT query
    my $sql_statement = "select ticker from coins where watch='true' order by ticker;";
    my $sth = $dbh->prepare($sql_statement);
    $sth->execute();
    my $num = 0;
    while(my $ref = $sth->fetchrow_hashref()) {
	my $ticker = $ref->{'ticker'};
	push(@{ $symbols_ref }, $ticker);
    }
    return $symbols_ref;
}
