#!/usr/bin/perl

# WARNING THIS SCRIPT WILL CLOBBER THE DATA IN THE "signal_level" fields of the coins table of the frb database
print "see warning this clobbers the recent field in the coins table\n";
sleep 5;

# load_coins_signal_leve
# copyright 2022 Lars Paul Linden
# version 2.0.2
# get price from data source and then store in "signal_level" field of the coins table
# this price will then serve as a baseline for calculations

# LPL 2022-03-16 initial script to help with freeradiantbunny database managementk

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
print "\n";

# get symbols from database coins table and store in array below
my $symbols_ref = get_symbols_on_watch_list($dbh);
if (! ${ $symbols_ref }[0]) {
    die "watchlist symbols not found\.n";
}

my @symbols_that_failed = ();

my $num = 0;
my $symbol;
foreach $symbol (@{ $symbols_ref }) {
    $num++;
    print "\n";
    print $num . " " . $symbol . " ";
    #print "given symbol = " . $symbol . "\n";
    # zero field
    zero_recent_field_in_database($dbh, $symbol);
    # do curl command to request quote
    # s switch is for silent
    my $trading_pair = $symbol . "USDT";
    sleep 2;
    # to get variables set environment variables
    if (! $ENV{'FRB_DATA_SOURCE_URL'}) {
	die "load_coins_recent.pl ERROR need to set FRB_DATA_SOURCE_URL\n";
    }
    if (! $ENV{'FRB_RAPIDAPI_KEY'}) {
	die "load_coins_recent.pl ERROR need to set FRB_DATA_SOURCE_URL\n";
    }
    my $command = "curl -s --request GET --url '" . $ENV{'FRB_DATA_SOURCE_URL'} . "?symbol=" . $trading_pair . "' --header 'x-rapidapi-host: binance43.p.rapidapi.com' --header 'x-rapidapi-key: " . $ENV{'FRB_RAPIDAPI_KEY'} . "'";
    #print $command . "\n";
    # execute command
    my @results = `$command`;
    # output results  
    my $result;
    foreach $result (@results) {
	# debug
	#print $result . "\n";
	# result in json format, so decode
	my $results_decoded = decode_json($result);
	# print $results_decoded . "\n";
	# now loop through keys of hash
        my @key_value_pairs = keys %{ $results_decoded };
	my $flag = 0;
	my $key;
	foreach $key (@key_value_pairs) {
	    # tests
	    #print $key . "\n";
	    if ($key eq "symbol") {
		if (${ $results_decoded }{'lastPrice'}) {
		    # exists, looks like a value was retrieved from data_source
		    $flag = 1;
		}
		# debug
		#print "symbol:    " . ${ $results_decoded }{'symbol'} . "\n";
		#print "lastPrice:    " . ${ $results_decoded }{'lastPrice'} . "\n";
		print ${ $results_decoded }{'lastPrice'} . " ";
		store_in_database($dbh, $symbol, ${ $results_decoded }{'lastPrice'});
	    }
	}
	# debug
	# another method
	#print "$json->{'response'}->{'mydocs'}";
	if (! $flag) {
	    push(@symbols_that_failed, $symbol);
	}
    }
}
print "\n";
my $s;
foreach $s (@symbols_that_failed) {
    print "failed symbol " . $s . "\n";
}
print "\n";

#
sub zero_recent_field_in_database {
    my $dbh = shift;
    my $symbol = shift;
    # execute SELECT query
    my $sql_statement = "update coins set recent= '0' where ticker='" . $symbol . "';";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
}

#
sub store_in_database {
    my $dbh = shift;
    my $symbol = shift;
    my $lastPrice = shift;
    # execute SELECT query
    my $sql_statement = "update coins set recent= '" . $lastPrice . "' where ticker='" . $symbol . "';";
    #print "\n";
    #print "SQL executing sql_statement: " . $sql_statement . "\n";
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
