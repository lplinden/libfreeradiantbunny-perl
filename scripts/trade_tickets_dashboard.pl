#!/usr/bin/perl

# trade_tickets_dashboard.pl
# copyright 2022 Lars Paul Linden
# version 2.0.2
# display trade_tickets table data from the freeradiantbunny database

# LPL 2022-03-16 initial script to help with freeradiantbunny database management

use strict;
use warnings;
use Term::ANSIColor;
use DBI;
use DateTime;
use FreeRadiantBunny::TradeTicket;

# set up environement variables to connect to database
my $db = $ENV{'FRB_DB'};
my $user = $ENV{'FRB_USER'};
my $pw = $ENV{'FRB_SPECIAL'};
#print "GIVEN database: " . $db . "\n";
#print "GIVEN user: " . $user . "\n";
my $dbh = DBI->connect("DBI:Pg:dbname=$db;host=localhost", $user, $pw, {'RaiseError' => 1});

# loop
my %stats;
my %markets_tallys;
my $num = 0;
# get all of the trade_tickets from the database
my $trade_tickets_ref = get_trade_tickets($dbh);
my $trade_ticket_obj;
foreach $trade_ticket_obj (@{ $trade_tickets_ref }) {
    $num++;
    print "# " . $num . " trade_tickets ";
    print $trade_ticket_obj->get_trade_state() . " ";
    print "market_id " . $trade_ticket_obj->get_market_id() . " ";
    print $trade_ticket_obj->get_market_name() . " ";
    print "id " . $trade_ticket_obj->get_coin_id() . " ";
    print $trade_ticket_obj->get_coin_name() . "\n";
    # markets tallys
    my $market_name = $trade_ticket_obj->get_market_name();
    if ($markets_tallys{$market_name}) {
	my $count = $markets_tallys{$market_name};
	$count++;
	$markets_tallys{$market_name} = $count;
    } else {
	$markets_tallys{$market_name} = 1;
    }
    # store num
    $stats{'num_count'} = $num;
    # debug
    # print "generated_ts = " . $trade_ticket_obj->get_generated_ts() . " ";
    #print "\n";
}
# output stats
my $stat;
foreach $stat (keys %stats) {
    print $stat . " " . $stats{$stat} . "\n";
}
print "\n";
my $markets_tally;
foreach $markets_tally (keys %markets_tallys) {
    print $markets_tally . " " . $markets_tallys{$markets_tally} . "\n";
}
print "\n";
print "done.\n";

#
sub get_trade_tickets {
    my $dbh = shift;
    my @trade_tickets = ();
    my $trade_tickets_ref = \@trade_tickets;
    # execute SELECT query
    my $sql_statement = "select tt.*, c.name as coin_name, m.name as market_name from trade_tickets tt, coins c, markets m where tt.coin_id = c.id AND tt.market_id = m.id order by tt.id;";
    my $sth = $dbh->prepare($sql_statement);
    $sth->execute();
    my $num = 0;
    while(my $ref = $sth->fetchrow_hashref()) {
	my $trade_ticket_obj = new FreeRadiantBunny::TradeTicket();
	$trade_ticket_obj->set_id($ref->{'id'});
	$trade_ticket_obj->set_name($ref->{'name'});
	$trade_ticket_obj->set_coin_id($ref->{'coin_id'});
	$trade_ticket_obj->set_trading_pair($ref->{'trading_pair'});
	$trade_ticket_obj->set_market_id($ref->{'market_id'});
	$trade_ticket_obj->set_generated_ts($ref->{'generated_ts'});
	$trade_ticket_obj->set_trade_state($ref->{'trade_state'});
	#
	$trade_ticket_obj->set_signal_buy_stories($ref->{'signal_buy_stories'});
	$trade_ticket_obj->set_entry_setup_price($ref->{'entry_setup_price'});
	$trade_ticket_obj->set_target_price($ref->{'target_price'});
	$trade_ticket_obj->set_stoploss_price($ref->{'stoploss_price'});
	$trade_ticket_obj->set_risk_ratio($ref->{'risk_ratio'});
	$trade_ticket_obj->set_amount($ref->{'amount'});
	#
	$trade_ticket_obj->set_coin_name($ref->{'coin_name'});
	$trade_ticket_obj->set_market_name($ref->{'market_name'});

	# store
	push(@{ $trade_tickets_ref }, $trade_ticket_obj);

	# derived
	if (is_number($trade_ticket_obj->get_amount()) && is_number($trade_ticket_obj->get_entry_setup_price()) && is_number($trade_ticket_obj->get_stoploss_price())) {
	    my $possible_loss_cost = $trade_ticket_obj->get_amount() * ($trade_ticket_obj->get_entry_setup_price() - $trade_ticket_obj->get_stoploss_price());
	    $trade_ticket_obj->set_possible_loss_cost($possible_loss_cost);
	    print "possible_loss_cost = " . $possible_loss_cost . "\n";
	}

	return $trade_tickets_ref;
    }
}

#
sub is_number {
    my $input_to_test = shift;
    print "is_number? " . $input_to_test . "\n";
    if ($input_to_test ne '') {
	# variable is defined, so pattern-match
	if ($input_to_test =~ /^[+-]?\d+\.?\d*$/) {
	    # looks like a number
	    return 1;
	}
    }
    return 0;
}
