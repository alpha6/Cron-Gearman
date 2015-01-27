use strict;
use Module::Build;
my $builder = Module::Build->new(
    dist_name => 'Cron-Gearman',
    dist_version_from => 'lib/Cron/Gearman.pm',
    dist_abstract => 'Run Gearman jobs with Cron syntax',
   	requires => {
		'version' => 0,
		'AnyEvent' => 0,
		'JSON' => 0,
		'Config::JSON' => 0,
		'Algorithm::Cron' => 0,
		'Carp' => 0,
        'AnyEvent::Gearman::Client' => 0,

   	}
);

$builder->create_build_script;
