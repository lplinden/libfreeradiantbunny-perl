#!/usr/bin/perl

# performance_summary.pl
# copyright 2022 Lars Paul Linden
# version 2.0.2
# this displays trade_tickets table data from the freeradiantbunny database

# LPL 2022-03-16 initial script to help with freeradiantbunny database management

use strict;
use warnings;
use Term::ANSIColor;
use FreeRadiantBunny::TradeTicket;
#use JSON;
use DBI;

# database credentials
my $db = $ENV{'FRB_DB'};
my $user = $ENV{'FRB_USER'};
my $pw = $ENV{'FRB_SPECIAL'};
print "GIVEN database: " . $db . "\n";
print "GIVEN user: " . $user . "\n";
my $dbh = DBI->connect("DBI:Pg:dbname=$db;host=localhost", $user, $pw, {'RaiseError' => 1});
print "\n";

print "performance summary\n";
my $trade_tickets_ref = get_trade_tickets($dbh);

# performance measurements
# wishlist and
# under development
my $trade_tickets_count = 0;
my $total_net_profit = "";
my $gross_profit = "";
my $total_trades_count = "";
my $winning_trades_count = "";
my $largest_winning_trade = "";
my $average_profit_loss_trade = "";
my $ratio_winners_to_losers_trades = "";
my $maximum_consecutive_winners = "";
my $open_positions_profit_loss = "";
my $gross_loss = "";
my $number_of_winning_trades = "";
my $numbe_of_losing_trades = "";
my $percentage_winning_trade_count_over_losers_trade_count = "";
my $largest_losing_trade = "";
my $average_trade = "";
my $total_risked_amount = "";
my $percent_risked_of_portfolio = "";

# loop
my $trade_ticket_obj;
foreach $trade_ticket_obj (@{ $trade_tickets_ref }) {
    $trade_tickets_count++;
    print "id = " . $trade_ticket_obj->get_id() . "\n";
    print "name = " . $trade_ticket_obj->get_name() . "\n";
}

# results
print "trade_tickets_count = " . $trade_tickets_count . "\n";
print "done.\n";

sub get_trade_tickets {
    my $dbh = shift;
    my @trade_tickets = ();
    my $trade_tickets_ref = \@trade_tickets;
    # execute SELECT query
    my $sql_statement = "select * from trade_tickets;";
    my $sth = $dbh->prepare($sql_statement);
    $sth->execute();
    # loop
    my $num = 0;
    while(my $ref = $sth->fetchrow_hashref()) {

	# deal with object
	my $trade_ticket_obj = new FreeRadiantBunny::TradeTicket();
	push(@{ $trade_tickets_ref }, $trade_ticket_obj);

	# store data in object
	$trade_ticket_obj->set_id($ref->{'id'});
	$trade_ticket_obj->set_name($ref->{'name'});
    }
    return $trade_tickets_ref;
}
