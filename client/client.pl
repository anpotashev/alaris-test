#!/usr/bin/perl -w
use strict;
use IO::Socket;
use threads;
use threads::shared;
use Thread::Queue;
use JSON;
use List::Util qw( min max sum );
BEGIN {
  push( @INC, "../pm/");
}
use ConnSetting;

#Setting
my $clientSetting = ConnSetting->new("client_setting.json");
my %clientProps = %{$clientSetting->getProps()};
#Max timeout before sending next request.
my $range = $clientProps{Range};
#Timeout 'waiting' response.
my $maxRequestLive = $clientProps{MaxRequestLive};
my $maxWaitTime = 10;

#Statistic
#total request
my $counter = 0;
share($counter);
#workingCounter
my $workCounter = 0;
share($workCounter);
#'got response' counter
my $successCounter = 0;
share($successCounter);
#'timed out' request counter
my $faildCounter = 0;
share($faildCounter);
#received timeout
my @successTimes = ();
share(@successTimes);

#Network setting
my $connSetting = ConnSetting->new("client_net.json");
my %connProps = %{$connSetting->getProps()};

#ThreadPool
my $threadQueue = Thread::Queue->new();
my $freeThreadCount = 0;
share($freeThreadCount);
my $minFreeThreadCount = 2;

sub newTask {
  while (1) {
    while (my $arg = $threadQueue->dequeue()) {
      $freeThreadCount--; $counter++; $workCounter++; my $startTime = time();
      my $client = IO::Socket::INET->new(%connProps)
        or die "Couldn't connect to server\n";
      ;
      $client->send(prepareRequest());
      $client->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', $maxRequestLive, 0)) or die "setsockopt: $!";
      printStat();
      my $msg;
      if($client->recv($msg, 1024, 0)) {
        $successCounter++;
        my $workTime = time() - $startTime;
        push @successTimes, $workTime;
      } else {
        $faildCounter++;
      }
      $workCounter--;
      printStat();
      $client->close();
      $freeThreadCount++;
    }
  }
}

sub checkForFreeThreadInQueue {
  while ($freeThreadCount < $minFreeThreadCount) {
    threads->create('newTask');
    $freeThreadCount++;
  }
}


#sleep random time, then send request to 'dispatcher'
sub client {
  while (1) {
    sleep rand($range);
    checkForFreeThreadInQueue();
    $threadQueue->enqueue(1);
  }
}

#prepared jsonString for request to 'dispatcher'
sub prepareRequest {
  my $args = {
	'id'=>$counter
	, 'a'=>rand($range)
	, 'b'=>rand($range)
	, 'c'=>rand($range)
  };
  return encode_json \%$args;
}

#detach finished thread
sub detachFinishedThread {
  while (1) {
    foreach(threads->list()) {
      my $thread = $_;
      if (!$thread->is_running() && $thread->is_joinable()) {
        $thread->detach();
      }
    }
  }
}

#print statistic.
sub printStat {
  my $sum = sum 0, @successTimes;
  my $min = min @successTimes;
  if (!defined $min) { $min = 0; }
  $min = $min + 0;
  my $max = max 0, @successTimes;
  my $avr = 0;
  if ($successCounter > 0) { $avr = sprintf "%.2f", $sum/$successCounter; }
  #https://stackoverflow.com/questions/197933/whats-the-best-way-to-clear-the-screen-in-perl
  print "\033[2J";
  print "\033[0;0H";
  format = 
+-------+---------+------------+--------+---------+---------+---------+
|                count                  |           timeout           |
| total | success | processing | failed | minimum | maximum | average |
+-------+---------+------------+--------+---------+---------+---------+
| @|||| | @|||||| | @||||||||| | @||||| | @|||||| | @|||||| | @|||||| |
$counter, $successCounter, $workCounter, $faildCounter, $min, $max, $avr
+-------+---------+------------+--------+---------+---------+---------+
.
  write; 
}

threads->create('detachFinishedThread');
client();
