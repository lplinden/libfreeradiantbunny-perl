#!/usr/bin/perl

# trade_tickets_edit.pl
# copyright 2022 Lars Paul Linden
# version 2.0.2
# helper to make it easier to update fields for trade_tickets table in freeradiantbunny database

# LPL 2022-03-16 initial script to help with freeradiantbunny database managementk

use strict;
use warnings;
use Term::ANSIColor;
use DBI;
use DateTime;
use FreeRadiantBunny::TradeTicket;

# set up environement variables to connect to database
my $user = $ENV{'FRB_USER'};
my $pw = $ENV{'FRB_SPECIAL'};
#print "GIVEN database: " . $db . "\n";
#print "GIVEN user: " . $user . "\n";
my $dbh = DBI->connect("DBI:Pg:dbname=$db;host=localhost", $user, $pw, {'RaiseError' => 1});

# user sets portfolio size
my $portfolio = $ENV{'FRB_PORTFOLIO'};
if (! $ENV{'FRB_PORTFOLIO'}) {
    die "trade_tickets_update.pl ERROR environment variable portflio not set\n";
}

# get all of the trade_tickets from the database
my $trade_tickets_ref = get_trade_tickets($dbh);
my $trade_ticket_obj;
foreach $trade_ticket_obj (@{ $trade_tickets_ref }) {
    print "generated_ts = " . $trade_ticket_obj->get_generated_ts() . " ";
    print "trade_state = " . $trade_ticket_obj->get_trade_state() . "\n";
    my $trade_ticket_id = $trade_ticket_obj->get_id();
    print "id " . $trade_ticket_id . " ";
    my $name = $trade_ticket_obj->get_name();
    print "name " . $name . " ";
    print "coin_id " . $trade_ticket_obj->get_coin_id() . " ";
    print "trading_pair " . $trade_ticket_obj->get_trading_pair() . " ";
    print "market_id " . $trade_ticket_obj->get_market_id() . "\n";
    # deal with risk-related fields (see array below);
    my @fields = qw(signal_buy_stories stoploss_price target_price entry_setup_price risk_ratio amount);
    my $update_flag = update();
    while ($update_flag) {
	# loop only once
	$update_flag = 0;
	print "first field...\n";
	#print_risk_values($trade_ticket_obj, $name);
	my $field;
	foreach $field (@fields) {
	    my $coin_id = $trade_ticket_obj->get_coin_id();
	    print "field "  . $field . " coin_id " . $coin_id . "\n";
	    # user input
	    my $exit_value = 1;
	    while ($exit_value) {
		$exit_value = 0;
		print_risk_values($trade_ticket_obj, $name);
		my $field_value = update_trade_ticket($coin_id, $field);
		if ($field_value) {
		    print "set " . $field . " = " . $field_value . "\n";
		    if ($field eq "signal_buy_stories") {
			$trade_ticket_obj->set_signal_buy_stories($field_value);
		    } elsif ($field eq "entry_setup_price") {
			$trade_ticket_obj->set_entry_setup_price($field_value);
		    } elsif ($field eq "target_price") {
			$trade_ticket_obj->set_target_price($field_value);
		    } elsif ($field eq "stoploss_price") {
			$trade_ticket_obj->set_stoploss_price($field_value);
		    } elsif ($field eq "amount") {
			$trade_ticket_obj->set_amount($field_value);
		    }
		    generate_risk_ratio($dbh, $trade_ticket_obj);
		    generate_possible_loss_cost($trade_ticket_obj);
		    generate_trade_cost_gross($trade_ticket_obj);
		    store_field_in_database($dbh, $trade_ticket_id, $field, $field_value);
		    print "update database\n";
		    print "next field...\n";
		}
	    }
	    print_risk_values($trade_ticket_obj, $name);
	}
	print "fields completed.\n";
	$update_flag = update();
    }

    # wishlist under development
    # the table fields as follows:
    # entry_price_actual
    # stoploss_triggered_ts
    # enter_transaction_id
    # trade_ts
    # signal_sell_stories
    # exit_transaction_id
    # partial_trade-ticket_id
    # performance_measure
    
    print "\n";
}

#
sub store_field_in_database {
    my $dbh = shift;
    my $trade_ticket_id = shift;
    my $field = shift;
    my $field_value = shift;
    # execute SELECT query
    my $sql_statement = "update trade_tickets set " . $field . "='" . $field_value . "' where id=" . $trade_ticket_id . ";";
    #print "SQL executing sql_statement: " . $sql_statement . "\n";
    my $sth = $dbh->prepare($sql_statement);
    my $result = $sth->execute();
    print "result = " . $result . "\n";
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
	# derived (despite being a field in database
	# this is where risk ratio is recalculated
	generate_risk_ratio($dbh, $trade_ticket_obj);
	#
	$trade_ticket_obj->set_amount($ref->{'amount'});
	generate_possible_loss_cost($trade_ticket_obj);
	generate_trade_cost_gross($trade_ticket_obj);
	# store
	push(@{ $trade_tickets_ref }, $trade_ticket_obj);
    }
    return $trade_tickets_ref;
}

#
sub update {
    print "edit (y/n)?";
    my $user_input = <>;
    chomp($user_input);
    #print "found " . $user_input . "\n";
    if ($user_input eq "y") {
	print "edit fields\n";
	return 1;
    }
    return 0;
}

#
sub update_trade_ticket {
    my $symbol = shift;
    my $field = shift;
    print "update coin_id " . $symbol . " " . $field . "(y/n)?";
    my $user_input = <>;
    chomp($user_input);
    #print "found " . $user_input . "\n";
    if ($user_input eq "y") {
	print $symbol . " " . $field . " = ";
	my $user_input = <>;
	chomp($user_input);
	#print "found " . $user_input . "\n";
	#sleep 3;
	return $user_input;
    }
    return 0;
}

#
sub print_risk_values {
    my $trade_ticket_obj = shift;
    my $name = shift;
    # column (so out put is mix-up)
    # column 1 and column 2 alternate
    # row 1
    my $narrow = 22;
    my $wide = 28;
    print "\n";
    # print name as a heading
    print $name . "\n";
    # print data in columns
    print_as_column("signal_buy_stories", $narrow);
    print_as_column($trade_ticket_obj->get_signal_buy_stories(), $wide);
    print "     ";
    print_as_column("trade_cost_gross", $narrow);
    print_as_column($trade_ticket_obj->get_trade_cost_gross(), $wide);
    print "\n";
    # row 2
    print_as_column( "target_price", $narrow);
    print_as_column($trade_ticket_obj->get_target_price(), $wide);
    print "     ";
    print_as_column("risk_ratio", $narrow);
    print_as_column($trade_ticket_obj->get_risk_ratio(), $wide);
    print "\n";
    # row 3
    print_as_column("entry_setup_price", $narrow);
    print_as_column($trade_ticket_obj->get_entry_setup_price(), $wide);
    print "     ";
    print_as_column("amount", $narrow);
    print_as_column($trade_ticket_obj->get_amount(), $wide);
    print "\n";
    # row 4
    print_as_column("stoploss_price", $narrow);
    print_as_column($trade_ticket_obj->get_stoploss_price(), $wide);
    print "     ";
    print_as_column("possible_loss_cost", $narrow);
    print_as_column($trade_ticket_obj->get_possible_loss_cost(), $wide);
    print "\n";
    # row 5
    print_as_column("    ", $narrow);
    print_as_column("", $wide);
    print "     ";
    print_as_column("percent_of_portfolio", $narrow);
    my $percent_of_portfolio = ($trade_ticket_obj->get_possible_loss_cost() / $portfolio) * 100;
    $percent_of_portfolio = sprintf('%.3f', $percent_of_portfolio);
    print_as_column($percent_of_portfolio, $wide);
    print "\n";
    # end space
    print "\n";
}

#
sub print_as_column {
    my $string = shift;
    my $width = shift;
    my $length = length($string);
    my $space = $width - $length;
    if ($space > 0) {
	while ($space) {
	    $space--;
	    print " ";
	}
    }
    print $string;
}

#
sub generate_risk_ratio {
    my $dbh = shift;
    my $trade_ticket_obj = shift;
    # calculate
    if (is_number($trade_ticket_obj->get_entry_setup_price()) &&
	is_number($trade_ticket_obj->get_target_price()) &&
	is_number($trade_ticket_obj->get_stoploss_price())) {
	# risk ratio is possible loss over possible gain
	my $possible_loss = $trade_ticket_obj->get_entry_setup_price() - $trade_ticket_obj->get_stoploss_price();
	my $possible_gain = $trade_ticket_obj->get_target_price() - $trade_ticket_obj->get_entry_setup_price();
	my $risk_ratio = $possible_gain / $possible_loss;
	$risk_ratio = sprintf('%.1f', $risk_ratio);
	print "calculated risk_ratio = " . $risk_ratio . "\n";
	$trade_ticket_obj->set_risk_ratio($risk_ratio);
	my $trade_ticket_id = $trade_ticket_obj->get_id();
	my $field = "risk_ratio";
	store_field_in_database($dbh, $trade_ticket_id, $field, $risk_ratio);
    }
}

#
sub generate_possible_loss_cost {
    my $trade_ticket_obj = shift;
    # calculate
    if (is_number($trade_ticket_obj->get_amount()) && is_number($trade_ticket_obj->get_entry_setup_price()) && is_number($trade_ticket_obj->get_stoploss_price())) {
	my $possible_loss_cost = $trade_ticket_obj->get_amount() * ($trade_ticket_obj->get_entry_setup_price() - $trade_ticket_obj->get_stoploss_price());
	$trade_ticket_obj->set_possible_loss_cost($possible_loss_cost);		    
	print "calculated possible_loss_cost = " . $possible_loss_cost . "\n";
    }
}

#
sub generate_trade_cost_gross {
    my $trade_ticket_obj = shift;
    # calculate
    if (is_number($trade_ticket_obj->get_amount()) && is_number($trade_ticket_obj->get_entry_setup_price())) {
	my $trade_cost_gross = $trade_ticket_obj->get_amount() * $trade_ticket_obj->get_entry_setup_price();
	$trade_ticket_obj->set_trade_cost_gross($trade_cost_gross);		    
	print "calculated trade_cost_gross = " . $trade_cost_gross . "\n";
    }
}

#
sub is_number {
    my $input_to_test = shift;
    #print "is_number? " . $input_to_test . "\n";
    if ($input_to_test ne '') {
	# variable is defined, so pattern-match
	if ($input_to_test =~ /^[+-]?\d+\.?\d*$/) {
	    # looks like a number
	    return 1;
	}
    }
    return 0;
}
