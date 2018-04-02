#!/usr/bin/perl -w
use strict;
use IO::Socket;
use threads;
use threads::shared;
use Thread::Queue;
use JSON;
BEGIN {
  push( @INC, "../pm/");
}
use ConnSetting;

#configuration
my $calcSetting = ConnSetting->new("dispatcher_setting.json");
my %calcProps = %{$calcSetting->getProps()};
#max time for waiting asnwer from calculator
my $maxWaitTime = $calcProps{MaxWaitTime};
#max time for processing request
my $maxRequestLive = $calcProps{MaxRequestLive};
#timeout after than calculator is lost
my $pingDelay = $calcProps{PingDelay};

#net configuration
my $connSetting = ConnSetting->new("dispatcher_net.json");
my %connProps = %{$connSetting->getProps()};
#print "starting on port: $connProps{LocalPort}\n";
my $server = IO::Socket::INET->new(%connProps)
  or die "Couldn't create server";
#############
my $msg;
my %calculators = ();
share(%calculators);

#ThreadPool
my $threadQueue = Thread::Queue->new();
my $freeThreadCount = 0;
share($freeThreadCount);
my $minFreeThreadCount = 2;

#client requests
my %clientResp = ();
#Statistic
my $totalCounter = 0;
share($totalCounter);
my $runningCounter = 0;
share($runningCounter);
my $totalSuccessCounter = 0;
share($totalSuccessCounter );
my $totalFailedCounter = 0;
share($totalFailedCounter );

sub processGettedMessages {
  while (1) {
    while (my $arg = $threadQueue->dequeue()) {
      my ($msg, $otherHost) = @$arg;
      $freeThreadCount--;
      gotPing($otherHost, $msg);
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

sub dispatcher {
  while ($server->recv($msg, 1024, 0)) {
    my($port, $ipaddr) = sockaddr_in($server->peername);
    my $otherHost = gethostbyaddr($ipaddr, AF_INET);
    if (isPing($msg)) {
      my @arg = ($msg, $otherHost);
      checkForFreeThreadInQueue();
      $threadQueue->enqueue(\@arg);
    } else {
      threads->create('sendResponse',$server, $msg);
    }
  }
}

#Return TRUE if arg is a 'ping' from 'calculator'
sub isPing {
  my ($arg) = @_;
  my %v = %{decode_json($arg)};
  if (defined $v{PeerPort}) { return 1; }
  return 0;
}

#update information about active 'calculators'
sub gotPing {
  my ($host, $arg) = @_;
  my %v = %{decode_json($arg)};
  my $url = "$host:$v{PeerPort}";
  $calculators{$url} = time();
  printCurrentAliveCalculators();
}

#show statistic
sub printCurrentAliveCalculators {
  print "\033[2J";
  print "\033[0;0H";
  my $text = join "\n", (keys %calculators);
  format = 
Listening on port: @<<<<<<<
$connProps{LocalPort}
+------------------------+
|       alive host       |
+------------------------+
| ^||||||||||||||||||||| |
  $text
| ^||||||||||||||||||||| | ~~
  $text
+------------------------+

Request:
+-------+--------+---------+--------+
| total | running| success | failed |
+-------+--------+---------+--------+
| @|||| | @||||| | @|||||| | @||||| |
$totalCounter, $runningCounter, $totalSuccessCounter, $totalFailedCounter
+-------+--------+---------+--------+
.
  write;
}

#Every second check list of 'calculators' for 'dead'
sub checkAliveCalculators {
  while (1) {
  foreach (keys %calculators) {
    my $url = $_;
    if (time() > $calculators{$url} + $pingDelay) {
      delete $calculators{$url};
    }
  }
  sleep 1;
  }
}

#Forward request to random 'calculator' and send response to client.
sub sendResponse {
  my ($srv, $msg) = @_;
  $totalCounter++;
  $runningCounter++;
  my $endTime = time() + $maxRequestLive;
  my $done = 0;
  while (!$done && time() < $endTime) {
    while ((time() < $endTime) &&(keys %calculators == 0)) {
      sleep 1;
    }
    if (keys %calculators == 0) {
      $runningCounter--;
      $totalFailedCounter++;
      return;
    }
    my @aliveHosts = (keys %calculators);
    my $calculator = $aliveHosts[rand @aliveHosts];
    my ($h, $p) = split ":", $calculator;
    my $res = sendTask($h, $p, $msg);
    if ($res) { 
      $srv->send($res);
      $calculators{$calculator} = time();
      $runningCounter--;
      $totalSuccessCounter++;
      $done = 1;
    } 
  }
}

#Send request to 'calculator'. If no response return 0.
sub sendTask {
  my ($host, $port, $msg) = @_;
  my $startTime = time();
  my $client = IO::Socket::INET->new(PeerPort=>$port, Proto=>"udp", PeerAddr=>"$host") or die "Couldn't connect to server\n";
  $client->send($msg);
  $client->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', $maxWaitTime, 0))
    or die "setsockopt: $!";
  if ($client->recv($msg, 1024)) {
    $client->close();
    return $msg;
  }
  $client->close();
  return 0;
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
    sleep 1;
  }
}


threads->create('checkAliveCalculators');
threads->create('detachFinishedThread');
dispatcher();

