package Cron::Gearman::DB;

use strict;
use utf8;
use version; our $VERSION = qv("0.0.1");

use Carp;

sub new {
	my $class = shift;
	my $config = shift;

	my $tasks_list = $config->get('tasks/storage');

	my $self = {
		tasks_list => $tasks_list,
	};

	bless $self, $class;
}

sub get_all_tasks {
	my $self = shift;

	return $self->{'tasks_list'};
}

1;
