#!/usr/bin/perl -w

use strict;
use warnings;

use lib 'lib';
use DCMain;
use DCData;

sub get_timestamp
{
    my ($s, $m, $h, $D, $M, $Y) = localtime;
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}

# Do not forget to specify host, username, and password!
my $dcpp = DCMain->new(host => "", nick => "", password => "");
my $db = new DCData;

if ($dcpp->connect)
{
    while (my ($to, $from, $message, $status) = $dcpp->receive)
    {
        if ($message && $status < 2)
        {
            $db->add_message(get_timestamp(), $from, $message, $status);
            print "<$from> $message\n";
        }
    }
    $dcpp->disconnect;
} else
{
    print "DC++ connection error\n";
}
