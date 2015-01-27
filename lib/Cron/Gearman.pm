package Cron::Gearman;

use strict;
use utf8;
use version; our $VERSION = qv("0.0.3");

use Carp;
use Algorithm::Cron;
use AnyEvent;
use AnyEvent::Gearman::Client;


use Data::Dumper;
use Cron::Gearman::DB;


sub new {
	my $class = shift;
	my $config = shift; #Объект Config::JSON или что-то с похожим интерфейсом
    my $server = shift; #gearman server addr
	my $base = shift || 'local';

	my $db = Cron::Gearman::DB->new($config);

    my $client = AnyEvent::Gearman::Client->new(
       job_servers => [  $server ],
    ) or croak "Cannot connect to gearman - $@\n";   

	my $self = {
		config => $config,
		base => $base,
		db => $db,
        client => $client,
	};


	bless $self, $class;
}

#Вытаскиваем все итемы из расписания и создаем таймеры для каждого
sub start {
	my $self = shift;
	my $callback = shift; #calback который будет вызываться при срабатывании таймера

	croak ("callback sub required!") unless (ref($callback) eq 'CODE');

	#Получаем список всех задач которые можно выполнять
	my $tasks = $self->_get_tasks();

	#Создаем пул таймеров. По таймеру на каждую задачу
	$self->_set_timers($tasks, $callback);
}

#Получаем список задач
sub _get_tasks {
	my $self = shift;

	my $tasks = $self->{'db'}->get_all_tasks();

	return $tasks;
}

#Проходимся по списку задач, и на каждую задачу выставляем таймер
sub _set_timers {
    my $self = shift;
	my $tasks = shift;
	my $callback = shift;

	croak ("Tasks format is not valid!") unless(ref($tasks) eq 'ARRAY');
	croak ("callback sub required!") unless (ref($callback) eq 'CODE');


	for my $task (@$tasks) {
	    $self->_install_timer($task, $callback); #таймер создается в $self->{'timers'}->{timer_id}
	}


}

#Создаем объект вотчера для заданного задания
sub _install_timer {
	my $self = shift;
	my $task = shift;
    my $callback = shift;

	croak ("callback sub required!") unless (ref($callback) eq 'CODE');

	my $delay = $self->_get_start_timeout($task->{'cron_time'});
	my $command = $task->{'command'};

	#Создаем ключ по которому будет храниться таймер в таблице таймеров
	my $timer_id = sprintf('%d_%d', $delay, int(rand(10000)));

    warn "installing timer [$timer_id][$delay][$command]";
	my $watcher = AnyEvent->timer(after => $delay, cb => sub {
            #Создаем замыкание с клиентом геармана
            my $job;
            $job = $self->{'client'}->add_task(
                $command => '{}',
                on_complete => sub {
                    my $result = $_[1];
                    $callback->($result);
                    undef $job;
                },
                on_fail => sub {
                    my $result = $_[1];
                    $callback->("job failed!".$result);
                    undef $job;
                }
            );
#		$callback->($command); #Выполняем то, что хотел пользователь
		$self->_install_timer($task, $callback); #Переустанавливаем таймер
        delete $self->{'timers'}{$timer_id}; #Удаляем текущий таймер из таблицы таймеров
	});

    $self->{'timers'}->{$timer_id} = $watcher;
	return $timer_id;
}

#Получем кроновый тайминг и рассчитываем время следующего срабатывания от текущего момента времени
sub _get_start_timeout {
	my $self = shift;
	my $shed = shift;
	my $cron = Algorithm::Cron->new(
	   base => $self->{'base'},
   	   crontab => $shed,
	);

    #Получаем время через которое должен сработать таймер
	my $time = ($cron->next_time( time )- time);
	return $time;
}

1;
