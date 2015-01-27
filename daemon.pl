#!/usr/bin/env perl

use utf8;
use strict;
use feature 'say';
use AnyEvent;
use Config::JSON;
use Data::Dumper;

use Cron::Gearman;

my $config = Config::JSON->new('config.json');
my $cv = AE::cv;

my $cron;

my $alive_timer = AnyEvent->timer(
    after    => 10,
    interval => 10,
    cb       => sub {
        say time().Dumper($cron->{'timers'});       
    }
);

my $work_cb = sub {
    warn "Command output: ".Dumper(\@_);
};
my $gearman = $config->get('gearman');

$cron = Cron::Gearman->new($config, $gearman);
$cron->start($work_cb);

warn Dumper($cron);

$cv->recv;
