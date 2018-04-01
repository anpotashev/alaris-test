#!/usr/bin/perl -w
use strict;
use IO::Socket;
use threads;
use Thread::Suspend; 
use Thread::Queue;
use threads::shared;
BEGIN {
  push( @INC, "../pm/");
}
use ConnSetting;
use JSON;

#Setting
my $calcSetting = ConnSetting->new("calculator_setting.json");
my %calcProps = %{$calcSetting->getProps()};
#min time for calculationg
my $minCalcDelay = $calcProps{MinCalcDelay};
#max time for calculationg
my $maxCalcDelay = $calcProps{MaxCalcDelay};
my $deltaCalcDelay = $maxCalcDelay - $minCalcDelay;
#max timeout for calculator 'death'
my $notWorkingMaxTimeout = $calcProps{NotWorkingMaxTimeout};
#probability for dead service
my $notWorkingProbability = $calcProps{NotWorkingProbability};
#timeout beetwen two 'ping'
my $pingTimeout = $calcProps{PingTimeout};

#net-setting for connecting to 'dispatcher'
my $dispatcherSetting = ConnSetting->new("dispatcher_net.json");
my %dispatcherProps = %{$dispatcherSetting->getProps()};
my $dispatcher = IO::Socket::INET->new(%dispatcherProps)
  or die "Couldn't connect to server\n";
##############
#'calculator' net-settings
my $connSetting = ConnSetting->new("calculator_net.json");
my %connProps = %{$connSetting->getProps()};
if (defined $ARGV[0]) {
  print "$ARGV[0]\n";
  $connProps{LocalPort} = $ARGV[0];
}
my $server = IO::Socket::INET->new(%connProps)
  or die "Couldn't create server";

my %address = ();
$address{PeerPort} = $connProps{'LocalPort'};
$address{Proto} = $connProps{'Proto'};
#'ping' text
my $addressJson = encode_json \%address;

my $msg;
my $isAlive = 1;
share($isAlive);

#ThreadPool
my $threadQueue = Thread::Queue->new();
my $freeThreadCount = 0;
share($freeThreadCount);
my $minFreeThreadCount = 2;

sub processGettedMessages() {
  while (1) {
    while (my $arg = $threadQueue->dequeue()) {
      $freeThreadCount--;
      calculate($arg);
      $freeThreadCount++;
    }
  }
}

sub checkForFreeThreadInQueue {
  while ($freeThreadCount < $minFreeThreadCount) {
    threads->create('processGettedMessages');
    $freeThreadCount++;
  }
}


sub readSocket {
  while ($server->recv($msg, 1024)) {
    if ($isAlive) {
      checkForFreeThreadInQueue();
      $threadQueue->enqueue($msg);
    }
  }
}

#every $pingTimeout send 'ping' to dispatcher
sub pingDispatcher {
  while (1) {
    $dispatcher->send($addressJson);
    sleep $pingTimeout; 
  }
}

#sleep random time and send request to 'dispatcher'
sub calculate {
  my ($arg) = @_;
  my $timeout = $minCalcDelay + rand($deltaCalcDelay);
  sleep $timeout;
  my %v = %{decode_json($arg)};
  my %result = kvur($v{a},$v{b},$v{c});
  $result{id} = $v{id};
  my $jsonRes = encode_json \%result;
  while (!$isAlive) { sleep 1; }
  if ($isAlive) {
    $server->send($jsonRes);
  }
}

#solve equation
sub kvur {
  my ($a, $b, $c) = @_;
  my %result = ();
  if ($a == 0) { return %result; } 
  my $d = $b*$b - 4*$a*$c;
  if ($d < 0) { return %result; }
  if ($d == 0) {
    $result{x1} = -$b/(2*$a);
    return %result;
  }
  $d = sqrt($d);
  $result{x1} = (-$b + $d)/(2*$a);
  $result{x2} = (-$b - $d)/(2*$a);
  return %result;
}

#emulate 'death' for random timeout.
sub pauseWork {
  my @threads = @_;
  while('true') {
    if (rand(1)<$notWorkingProbability) {
      my $timeout = rand($notWorkingMaxTimeout);
      $isAlive = 0;
      for (@threads) {
        $_->suspend();
      }
      sleep($timeout);
      $isAlive = 1;
      for (@threads) {
        $_->resume();
      }
    }
    sleep 1;
  }
}

#print statistic.
sub printState {
  while (1) {
    print "\033[2J";
    print "\033[0;0H";
    my $state = $isAlive ? "running" : "dead";
    format  = 
Listening on port: @<<<<<<<
$connProps{LocalPort}
State: @<<<<<<<<<
$state
.
    write;
    sleep 1;
  }
}


my $thread = threads->create('readSocket');
my $pingThread = threads->create('pingDispatcher');
threads->create('pauseWork', $pingThread);
threads->create('printState');

sleep;
