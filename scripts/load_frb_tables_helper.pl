#!/usr/bin/perl

# WARNING THIS SCRIPT WILL CLOBBER THE DATA IN THE errorlogs directory of the freeradiantbunny config
print "see warning this clobbers the errorlogs in freeradiantbunny config\n";
sleep 5;

# load_frb_tables_helper.pl
# copyright 2022 Lars Paul Linden
# version 2.0.2
# this reads the files in the freeradiantbunny node-momdule and finds the sql files and...
# and then loads each found sql files (one by one) using psql for the given database

# LPL 2022-03-16 initial script to help with freeradiantbunny database management

use strict;
use warnings;
use File::stat;
use File::Find;
use Term::ANSIColor;
use Number::Format 'format_number';

# increase integer to slow to debug
my $seconds = 0;

# announce the program
print "running load_frb_tables_helper.pl ...\n";

# user needs set the variables for psql
# this is the user of the database
my $user = $ENV{'FRB_USER'};
# this is the name of the database
my $db = $ENV{'FRB_DB'};
my $pw = $ENV{'FRB_SPECIAL'};

# high level variable to store found filenames
my @found_sql_files;

# models dir in freeradiantbunny
my $model_dir = $ENV{'HOME'} . "/freeradiantbunny.node/node_modules/freeradiantbunny/model";
print "model_dir = " . $model_dir . "\n";
sleep $seconds;

# set up error files
my $freeradiantbunny_config_dir = $ENV{'HOME'} . "/.freeradiantbunny/errorlogs";
print "freeradiantbunny_config_dir = " . $freeradiantbunny_config_dir . "\n";

# loop with numbered iterations
my $num = 0;

opendir (DIR, $model_dir) or die "could not open model_dir " . $model_dir . " " . $!;
while (my $file = readdir(DIR)) {
    if ($file eq ".") {
	# // skip
	print "skip\n";
	next;
    } elsif ($file eq "..") {
	# // skip
	print "skip\n";
	next;
    }
    if ($file =~ /.*\.sql$/) {
	$num++;
	print $num . " " . $file . "\n";
	push(@found_sql_files, $file);
    }
}
closedir(DIR);

# loop through the sql files
print "# loop through the sql files\n";

#reset
$num = 0;
my $file;
foreach $file (@found_sql_files) {
    $num++;
    my $fullpath_file = $model_dir . "/" . $file;
    # note dot error extenshion
    my $fullpath_error = $freeradiantbunny_config_dir . "/" . $file . ".error";
    my $command = "psql -U $user $db < $fullpath_file 2> $fullpath_error";
    print $command . "\n";
    my @output = `$command`;
    my $output_count = @output;
    my $line;
    foreach $line (@output) {
	print $num . " " . $line;
    }
    print "\n";
    sleep $seconds;
}
