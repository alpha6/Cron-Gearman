package Cron::Gearman;

use strict;
use utf8;
use version; our $VERSION = qv("0.0.2");

use Carp;
use Algorithm::Cron;
use AnyEvent;

use Cron::Gearman::DB;

sub new {
	my $class = shift;
	my $config = shift; #Объект Config::JSON или что-то с похожим интерфейсом
	my $base = shift || 'local';

	my $db = Cron::Gearman::DB->new($config);

	my $self = {
		config => $config,
		base => $base,
		db => $db,
	};

	bless $self, $class;
}

#Вытаскиваем все итемы из расписания и создаем таймеры для каждого
sub start {
	my $self = shift;
	my $callback = shift; #calback который будет вызываться при срабатывании таймера

	#Получаем список всех задач которые можно выполнять
	my $tasks = $self->_get_tasks();

	#Создаем пул таймеров. По таймеру на каждую задачу
	$self->{'timers'} = $self->_set_timers($tasks, $callback);
}

#Получаем список задач
sub _get_tasks {
	my $self = shift;

	my $tasks = $self->{'db'}->get_all_tasks();

	return $tasks;
}

#Проходимся по списку задач, и на каждую задачу выставляем таймер
sub _set_timers {
	my $tasks = shift;
	my $callback = shift;

	croak ("Tasks format is not valid!") unless(ref($tasks) eq 'ARRAY');
	croak ("callback sub required!") unless (ref($callback) eq 'CODE');

#Possible memory leak issue!
	for my $task (@$tasks) {
		my $timer_id = $self->_install_timer($task); #таймер создается в $self->{'timers'}->{timer_id}
	}


}

#Создаем объект вотчера для заданного задания
sub _install_timer {
	my $self = shift;
	my $task = shift;

	my $delay = $self->_get_start_timeout($task->{'cron_time'});
	my $command = $task->{'command'};

	#Создаем ключ по которому будет храниться таймер в таблице таймеров
	my $timer_id = sprintf('%d_%d', $delay, int(rand(10000)));

	my $watcher = AnyEvent->timer(after => $delay, cb => sub { 
		$callback->($command); #Выполняем то, что хотел пользователь
		$self->_install_timer($task); #Переустанавливаем таймер
		undef $self->{'timers'}{$timer_id}; #Удаляем текущий таймер из таблицы таймеров
	});

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

	my $time = $cron->next_time( time );
	return $time;
}

1;