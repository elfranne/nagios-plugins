#!/usr/bin/perl

# Usage : ./send_sms.pl <phone number> "<message>"
# example: ./send_sms.pl 12345678 "Test message"

#https://github.com/elfranne/nagios-plugins
#License: GPL v3
#http://securfox.wordpress.com/2009/03/30/how-to-configure-nagios-to-send-sms-to-your-mobile/

#Nagios plugin for sending sms via http://stadel.dk/
#description of the service : http://stadel.dk/?module=WYSIWYG&page=default&do=&id=77
# save to /usr/lib/nagios/plugin/send_sms.pl
# chmod +x send_sms.pl

#insert those two commands in /etc/nagios3/commands.cfg:
# define command {
# command_name notify-service-by-sms
# command_line /usr/lib/nagios/plugin/send_sms.pl $CONTACTPAGER$ "Nagios – $NOTIFICATIONTYPE$ : $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$ ($OUTPUT$)"
# }

# define command {
# command_name notify-host-by-sms
# command_line /usr/lib/nagios/plugin/send_sms.pl $CONTACTPAGER$ "Nagios – $NOTIFICATIONTYPE$ : Host $HOSTALIAS$ is $HOSTSTATE$ ($OUTPUT$)"
# }

use strict;
use warnings;
use LWP::UserAgent;

my $num_args = $#ARGV + 1;
exit 2 if ($num_args != 2);

### EDIT THOSE ###
my $user = '';
my $password = '';
##          ###

my $url = 'http://sms.stadel.dk/send.php';
my $phone_number = $ARGV[0];
$phone_number =~ s/^\+//gi if $phone_number =~ /^\+/gi;
$phone_number =~ s/^00//gi if $phone_number =~ /^00/gi;
my $message = $ARGV[1];

my @message_parts = $message =~ /(.{1,450})/g;
foreach (@message_parts) {
    $url = URI->new($url);
    $url->query_form( user => $user, pass => $password, message => $_, mobile => $phone_number, sender => 'Nagios');
    my $response = LWP::UserAgent->new->get($url);
    #print $response->content;
}
exit 0;
