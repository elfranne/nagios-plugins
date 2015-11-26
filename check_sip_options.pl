#!/usr/bin/perl

## Script stolen from https://github.com/nguttman/Nagios-Checks/
## Script written by Noah Guttman and Copyright (C) 2014 Noah Guttman. This script is released and distributed under the terms of the GNU General Public License
## 26 nov 2015 : Changed the user agent string.


#Libraries to use
use warnings;
use strict;
use Getopt::Std;
use Time::HiRes qw(gettimeofday usleep);
use IO::Socket;
use threads;
use threads::shared;
use String::Random;

use vars qw($opt_h $opt_H $opt_P $opt_t $opt_r $opt_d $opt_R $opt_M $opt_s $opt_I $opt_c);

$opt_R ='';
my $baseport;

my @output;
my @line;
my $val;

my $gah :shared;
$gah ="";
my $testerrortotal=0;
my $response_timeout=0;

my $elapsed=1000;
my $debug_output="";
my $exitcode=3;
my $icmp_responsed :shared;
$icmp_responsed = 0;
my $timeout=1000000;
my $retries=4;
my $errors=0;
my $maxfailures =3;
my $localIP;
my $localPort;
my $timer =0;

my $ReturnMin=10000000;
my $ReturnMax=0;
my $ReturnTotal=0;
my $testoktotal=0;
my $ReturnAvg=0;

my $sock;
my $recvthread;
my $optionPacket='';

my $randomstring = new String::Random;

##init();

# Get the options
if ($#ARGV le 0) {
	$opt_h=1;
} else {
	getopts('hdsH:P:t:r:R:M:I:c:');
}


## Display Help
if ($opt_h){
	print "::SIP Options Check Instructions::\n\n";
	print " -h,		Display this help information\n";
	print " -H,		Hostname or IP to check\n";
        print " -P,		Port to check\n";
        print "                  The default is 5060\n";
	print " -s,             Accept any SIP message as valid response\n";
	print " -I,             Attempt to bind to the IP when sending the Options packet\n";
	print "                  If this IP is not present on the server the test will fail with an error \n";
	print " -M,             Custom message to report on failure\n";
	print " -R,             Restart command to use (for use with event handlers)\n";
        print " -t,             Timeout (ms) for each communication attempt.\n";
        print "                  The default is 1000\n";
        print " -r,             Number of OPTIONS packets to send.\n";
        print "                  The default is 4\n";
        print " -c,             Number of bad responses to trigger a critical\n";
        print "                  The default is 3\n";
        print " -d,             Turn on debug mode - prints out packet(s) recived.\n";
        print "Script written by Noah Guttman and Copyright (C) 2014 Noah Guttman.\n";
        print "This script is released and distributed under the terms of the GNU\n";
        print "General Public License.     >>>>    http://www.gnu.org/licenses/\n";
        print "";
        print "This program is free software: you can redistribute it and/or modify\n";
        print "it under the terms of the GNU General Public License as published by\n";
        print "the Free Software Foundation.\n\n";
        print "This program is distributed in the hope that it will be useful,\n";
        print "but WITHOUT ANY WARRANTY; without even the implied warranty of\n";
        print "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n";
        print "GNU General Public License for more details.\n";
        print ">>>>    http://www.gnu.org/licenses/\n";
        exit 0; 
}




##Set custom output if any set

if ($opt_P){
        $baseport=$opt_P;
}else{
        $baseport=5060;
}
if ($opt_t){
        $timeout=$opt_t*1000;
}
if ($opt_r){
        $retries=$opt_r;
}
if ($opt_c){
	$maxfailures = $opt_c;
}



#Check that the thread is responding
for (my $i=0; $i < $retries; $i++){
	if ($opt_I){
                $sock = IO::Socket::INET->new(
                Proto    => 'udp',
                PeerPort => $baseport,
                PeerAddr => $opt_H,
		LocalAddr => $opt_I,
                ) or die "Could not create socket: $!\n";
	}else{
	        $sock = IO::Socket::INET->new(
	        Proto    => 'udp',
	        PeerPort => $baseport,
	        PeerAddr => $opt_H,
	        ) or die "Could not create socket: $!\n";
	}
	$recvthread = threads->new( \&recive_rtpproxy_request);
	usleep(10000);
	$localIP = $sock->sockhost;
	$localPort = $sock->sockport;

	$optionPacket = "OPTIONS sip:test\@$opt_H SIP/2.0\r\nVia: SIP/2.0/UDP $localIP:$localPort;branch=z9hG4bK." .$randomstring->randpattern("cCncnCCcnCncnCcncC") .";rport;alias\r\nFrom: sip:nagios\@$localIP:$localPort;tag=" .$randomstring->randpattern("cCncnCc") ."\r\nTo: sip:test\@$opt_H\r\nCall-ID: " .$randomstring->randpattern("cCncnCCcnCncnCcncC") ."\@$localIP\r\nCSeq: 1 OPTIONS\r\nContact: sip:nagios\@$localIP:$localPort\r\nContent-Length: 0\r\nMax-Forwards: 70\r\nUser-Agent: Nagios sip options check.\r\nAccept: text/plain\r\n";
	if ($opt_d){
		$debug_output = $debug_output."\n------------------------------\nOPTIONS PACKET:$optionPacket\n------------------------------\n";
	}

        my $starttime = gettimeofday;
	$sock->send("$optionPacket") or die "Send error: $!\n";

	#reset timer
	$timer =0;
	while (($timer <= $timeout ) && ($gah !~ /SIP\/2.0 \d\d\d/i)){
		usleep(1000);
		$timer = $timer + 2000;
	}
	#reset timer
	$timer =0;

        $elapsed = (gettimeofday - $starttime)*1000;

	#reject bad time data
        if ($elapsed < 0){
                $elapsed='';
        }

	if ($opt_d){
                $debug_output = $debug_output."\n------------------------------\nRESPONSE PACKET:$gah\n------------------------------\n";
        }

	if ($gah =~ /SIP\/2.0 200/i){
		$recvthread->join();
		if ($ReturnMin > $elapsed){
			$ReturnMin = $elapsed;
		}
		if ($ReturnMax <$elapsed){
			$ReturnMax = $elapsed;
		}
		$ReturnTotal = $ReturnTotal + $elapsed;
		$testoktotal++;
		$ReturnAvg = ($ReturnTotal / $testoktotal);
		if ($opt_d){
			$debug_output = $debug_output."Stats so far : ReturnMin=$ReturnMin"."ms;; ReturnAvg=$ReturnAvg"."ms;; ReturnMax=$ReturnMax"."ms;;ICMP=$icmp_responsed;; Errors=$errors;; Timeouts=$response_timeout;;\n";
		}
	}elsif (($gah =~ /SIP\/2.0/i) && ($opt_s)){
                $recvthread->join();
                if ($ReturnMin > $elapsed){
                        $ReturnMin = $elapsed;
                }
                if ($ReturnMax <$elapsed){
                        $ReturnMax = $elapsed;
                }
                $ReturnTotal = $ReturnTotal + $elapsed;
                $testoktotal++;
                $ReturnAvg = ($ReturnTotal / $testoktotal);
                if ($opt_d){
			$debug_output = $debug_output."Stats so far : ReturnMin=$ReturnMin"."ms;; ReturnAvg=$ReturnAvg"."ms;; ReturnMax=$ReturnMax"."ms;;ICMP=$icmp_responsed;; Errors=$errors;; Timeouts=$response_timeout;;\n";
                }
	}elsif ($icmp_responsed >$testerrortotal){
		$recvthread->join();
		$testerrortotal++
	}elsif ($gah =~ /./){
                $errors++;
		$recvthread->join();
		$testerrortotal++
	}else{
		$recvthread->detach;
		$response_timeout++;
		$testerrortotal++;
	}
	$sock->close;
	$gah='';
	usleep (5000);
}
if ($testerrortotal == 0){
	print ("$opt_R $opt_H $opt_P OK: SIP Component has responded in an average of $ReturnAvg ms.");
	$exitcode = 0;
	if ($opt_d){
        	print ("$debug_output");
        }
	print ("|ReturnMin=$ReturnMin"."ms;; ReturnAvg=$ReturnAvg"."ms;; ReturnMax=$ReturnMax"."ms;; ICMP=$icmp_responsed;; Errors=$errors;; Timeouts=$response_timeout;;\n");
	exit ($exitcode);
}elsif ($testerrortotal < $maxfailures){
        print ("$opt_R $opt_H $opt_P Warning: SIP Component has responded with $testerrortotal errors and in an average of $ReturnAvg ms.");
        $exitcode = 1;
	if ($opt_M){
        	print ("$opt_M");
	}
        if ($opt_d){
                print ("$debug_output");
        }
        print ("|ReturnMin=$ReturnMin"."ms;; ReturnAvg=$ReturnAvg"."ms;; ReturnMax=$ReturnMax"."ms;; ICMP=$icmp_responsed;; Errors=$errors;; Timeouts=$response_timeout;;\n");
        exit ($exitcode);
}
#Catch all for all other cases
print ("$opt_R $opt_H $opt_P CRITICAL: SIP Component has not responded correctly after $testerrortotal attempts.");
$exitcode = 2;
if ($opt_M){
	print ("$opt_M");
}
if ($opt_d){
	print ("$debug_output");
}
print ("|ICMP=$icmp_responsed;; Errors=$errors;; Timeouts=$response_timeout;;\n");
exit ($exitcode);


sub recive_rtpproxy_request{
		$sock->recv($gah,128) or $icmp_responsed++;
		$sock->close;
}

