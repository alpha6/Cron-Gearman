#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Config::JSON;

use Test::More;
use Cron::Gearman::DB;

my $config = Config::JSON->new('config_backend_file.json') or die "Test config not found!";

subtest 'creates correct object' => sub {
    isa_ok(Cron::Gearman::DB->new($config), 'Cron::Gearman::DB');
};

done_testing;
