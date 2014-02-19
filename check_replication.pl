#!/usr/bin/perl -w

use strict;
use warnings;
use feature qw(say);

use Data::Dump qw(pp);
use JSON::XS;
use LWP::Simple;

my $couch = $ARGV[0] or say 'You need to supply a couchDB address!' and exit 3;
my $json = get($couch . '/_active_tasks') or say 'Failed to fetch status' and exit 3;
my $status = decode_json $json or say 'Failed to decode json' and exit 3;

my $exit_status = 2;

for (@{$status}) {
    $exit_status = 0 if  ($_->{type} and $_->{type} eq 'replication');
}
exit $exit_status;