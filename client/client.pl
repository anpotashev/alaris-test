#!/usr/bin/perl -w
use strict;
use IO::Socket;
use threads;
use JSON;
use threads::shared;
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

#total request
my $counter = 0;
share($counter);
#'got response' counter
my $successCounter = 0;
share($successCounter);
#'timed out' request counter
my $faildRequestCounter = 0;
share($faildRequestCounter);
#received timeout
my @successTimes = ();
share(@successTimes);

my %requests = ();
share(%requests);

#Network setting
my $connSetting = ConnSetting->new("client_net.json");
my %connProps = %{$connSetting->getProps()};

my $client = IO::Socket::INET->new(%connProps)
  or die "Couldn't connect to server\n";

#sleep random time, then send request to 'dispatcher'
sub client {
  while (1) {
    sleep rand($range);
    sendRequest();
  }
}

#listen for answers
sub getAnswers {
  my $msg;
  while($client->recv($msg, 1024, 0)) {
    updateStat($msg);
  }
}

#Send request to 'dispatcher'
sub sendRequest {
  $requests{++$counter} = time();
  my $args = {
	'id'=>$counter
	, 'a'=>rand($range)
	, 'b'=>rand($range)
	, 'c'=>rand($range)
  };
  my $jsonString = encode_json \%$args;
  $client->send($jsonString);
}

#print statistic. Update every second.
sub printStat {
  while (1) {
    my $sum = sum 0, @successTimes;
    my $min = min @successTimes;
    if (!defined $min) { $min = 0; }
    $min = $min + 0;
    my $max = max 0, @successTimes;
    my $avr = 0;
    if ($successCounter > 0) { $avr = sprintf "%.2f", $sum/$successCounter; }
    my $processing = keys %requests;
    #https://stackoverflow.com/questions/197933/whats-the-best-way-to-clear-the-screen-in-perl
    print "\033[2J";
    print "\033[0;0H";
    format = 
+-------+---------+----------+--------+---------+---------+---------+
|               count                 |           timeout           |
| total | success | prossing | failed | minimum | maximum | average |
+-------+---------+----------+--------+---------+---------+---------+
| @|||| | @|||||| | @||||||| | @||||| | @|||||| | @|||||| | @|||||| |
$counter, $successCounter, $processing, $faildRequestCounter, $min, $max, $avr
+-------+---------+----------+--------+---------+---------+---------+
.
    write; 
    sleep 1;
  }
}

#run when got response. update statistic information.
sub updateStat {
  my ($arg) = @_;
  my %v = %{decode_json($arg)};
  my $id = $v{id};
  if (defined $requests{$id}) {
    my $t = time() - $requests{$id};
    $successCounter++;
    push @successTimes, $t;
    delete $requests{$v{id}}; 
  }
}

sub deleteTimedOutTasks {
  while(1) {
    my $id;
    foreach $id (keys %requests) {
      if (time() > $requests{$id} + $maxRequestLive ) {
        delete $requests{$id};
        $faildRequestCounter++; 
      }
    }
    sleep 1;
  }
}

threads->create('getAnswers');
threads->create('printStat');
threads->create('deleteTimedOutTasks');
client();
