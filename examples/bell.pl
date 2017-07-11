#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Amazon::Dash::Button ();
use RPi::WiringPi;
use RPi::WiringPi::Constant qw( :all );
use Time::HiRes qw(usleep);

die
  "You should run this script as root. Please run:\nsudo $0 [en0|eth0|wlan0]\n"
  if $>;

my $device = $ARGV[0] || q{wlan0};

my $pi = RPi::WiringPi->new;
my $pin = $pi->pin(7);
$pin->mode(OUTPUT);
# Default to off when inactive.
$pin->pull(PUD_DOWN);

tlog("set up complete\n");

Amazon::Dash::Button->new( dev => $device, )->add(
    name    => 'Dude',
    mac     => '88:71:e5:e0:98:86',
    onClick => sub {
        tlog("clicked ! from the Dude button\n");
        fire_bell_pin();
    },
    _fork_for_onClick => 0,    # fast enough do not need to fork there
  )->listen;

sub fire_bell_pin {
    # Toggle high, then toggle back low - five times.
    for (1..5) {
       	$pin->write(HIGH);
       	usleep(250000);
       	$pin->write(LOW);
       	usleep(250000);
    }
}

sub tlog {    # dummy helper to print timed log
    print STDERR join( ' ', @_, "\n" );
    return;
}
