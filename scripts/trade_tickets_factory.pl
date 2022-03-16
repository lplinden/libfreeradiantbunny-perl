#!/usr/bin/perl

# trade_tickets_factory
# copyright 2022 Lars Paul Linden
# version 2.0.2
# insert data into database as a new row of the trade_tickets table of a freeradiantbunny database

# LPL 2022-03-16 initial script to help with freeradiantbunny database management

use strict;
use warnings;
use Term::ANSIColor;
use JSON;
use DBI;
use DateTime;

# use sample_ident to group the creation of a set of trade_tickets
my $sample_ident = "A";

# set up environement variables to connect to database
my $db = $ENV{'FRB_DB'};
my $user = $ENV{'FRB_USER'};
my $pw = $ENV{'FRB_SPECIAL'};
print "GIVEN database: " . $db . "\n";
print "GIVEN user: " . $user . "\n";
my $dbh = DBI->connect("DBI:Pg:dbname=$db;host=localhost", $user, $pw, {'RaiseError' => 1});

# store the data of an instance of a trade_tickets in this variable (a perl hash)
my %trade_ticket;

# make a handy reference of the trade_ticket instance data
my $trade_ticket_ref = \%trade_ticket;

# make a batch of tickets
# so get the watchlist
# and then loop
# get symbols from database coins table and store in array below
my $symbols_ref = get_symbols_on_watch_list($dbh);
if (! ${ $symbols_ref }[0]) {
    die "watchlist symbols not found\.n";
}

# loop
my $num = 0;
my $id;
my $symbol;
# cycle because the array has 3 pieces of data for each element
my $cycle = 1;
foreach $symbol (@{ $symbols_ref }) {
    if ($cycle == 1) {
	$id = $symbol;
	$cycle = 2;
    } elsif ($cycle == 2) {
	$num++;
	#print $dbh . "\n";
	#print $trade_tickets_ref . "\n";
	#print "sample_ident = " . $sample_ident . "\n";
	#print "id = " . $id . "\n";
	#print "name = " . $name . "\n";
	#print "symbol = " . $symbol . "\n";
	print "GENERATE: #" . $num . " id=" . $id . " " . $symbol . "\n";
	print "-------------------------------------\n";
	# create a trade_tickets row for this symbol
	insert_trade_tickets_row_into_database($dbh, $trade_ticket_ref, $sample_ident, $id, $symbol);
	print "inserted " . $symbol . "\n";
	sleep 1;
	print "\n";
	#get_trade_tickets($dbh);
	#sleep 1;
	# start cycle
	$cycle = 1;
    }
}
# close database connection
print "disconnecting from db.\n";
$dbh->disconnect();
print "done.\n";

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
sub insert_trade_tickets_row_into_database {
    my $dbh = shift;
    my $trade_tickets_ref = shift;
    my $sample_ident = shift;
    my $coin_id = shift;
    my $symbol = shift;
    # execute SELECT query

    # name
    ${ $trade_tickets_ref }{'name'} = ' sample ' . $sample_ident . " trade " . $symbol;
    print "name = " . ${ $trade_tickets_ref }{'name'} . "\n";

    # coin_id
    ${ $trade_tickets_ref }{'coin_id'} = $coin_id;
    print "coin_id = " . ${ $trade_tickets_ref }{'coin_id'} . "\n";

    # status
    ${ $trade_tickets_ref }{'status'} = "2022";
    print "status = " . ${ $trade_tickets_ref }{'status'} . "\n";

    # sort
    ${ $trade_tickets_ref }{'sort'} = "Y 2022-03-13";
    print "sort = " . ${ $trade_tickets_ref }{'sort'} . "\n";
    
    # generated_ts
    ${ $trade_tickets_ref }{'generated_ts'} = DateTime->now(time_zone => 'local');
    print "generated_ts = " . ${ $trade_tickets_ref }{'generated_ts'} . "\n";

    # base_coin_id
    ${ $trade_tickets_ref }{'base_coin_id'} = 204;
    print "base_coin_id = " . ${ $trade_tickets_ref }{'base_coin_id'} . "\n";

    # base_coin_name
    ${ $trade_tickets_ref }{'base_coin_name'} = "USD";
    print "base_coin_name = " . ${ $trade_tickets_ref }{'base_coin_name'} . "\n";

    # trading_pair
    ${ $trade_tickets_ref }{'trading_pair'} = $symbol . ${ $trade_tickets_ref }{'base_coin_name'};
    print "trading_pair = " . ${ $trade_tickets_ref }{'trading_pair'} . "\n";

    # market_id
    # dev here

    # market_name
    # dev here
    
    # create sql statement
    my $sql_statement = "INSERT INTO trade_tickets (name, sort, generated_ts, status, coin_id , base_coin_id, trading_pair, market_id) VALUES ('" . ${ $trade_tickets_ref }{'name'} . "', '" . ${ $trade_tickets_ref }{'sort'} . "', '" . ${ $trade_tickets_ref }{'generated_ts'} . "', '" . ${ $trade_tickets_ref }{'status'} . "', " . ${ $trade_tickets_ref }{'coin_id'} . ", " . ${ $trade_tickets_ref }{'base_coin_id'} . ", '" . ${ $trade_tickets_ref }{'trading_pair'} . "', " . ${ $trade_tickets_ref }{'market_id'} . ");";
    print "executing sql_statement: " . $sql_statement . "\n";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
    print "result = " . $result . "\n";
    print "\n";
}

#
sub get_trade_tickets {
    my $dbh = shift;
    my @trade_tickets = ();
    my $trade_tickets_ref = \@trade_tickets;
    # execute SELECT query
    my $sql_statement = "select * from trade_tickets order by id;";
    my $sth = $dbh->prepare($sql_statement);
    $sth->execute();
    my $num = 0;
    while(my $ref = $sth->fetchrow_hashref()) {
	my $trade_ticket_data_string = $ref->{'id'} . " " . $ref->{'name'};
	push(@{ $trade_tickets_ref }, $trade_ticket_data_string);
    }
    return $trade_tickets_ref;
}

#
sub get_symbols_on_watch_list {
    my $dbh = shift;
    my @symbols = ();
    my $symbols_ref = \@symbols;
    # execute SELECT query
    my $sql_statement = "select id, name, ticker from coins where watch='true' and notes='T' order by ticker;";
    my $sth = $dbh->prepare($sql_statement);
    $sth->execute();
    my $num = 0;
    while(my $ref = $sth->fetchrow_hashref()) {
	my $id = $ref->{'id'};
	my $ticker = $ref->{'ticker'};
	push(@{ $symbols_ref }, $id);
	push(@{ $symbols_ref }, $ticker);
    }
    return $symbols_ref;
}
