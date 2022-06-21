#!/usr/bin/perl

#
#   Author: <wexe1@protonmail.com>
#   License: MIT
#

use strict;
use warnings;
use threads;
use Net::Ping;
use Net::Netmask;

package LiveHostPinger;

sub new {
    my $class = shift;
    my $subnet = shift;

    my $self = {
        _netmask => safe_new Net::Netmask($subnet)
    };

    return undef unless $self->{_netmask};

    return bless $self, $class;
}

sub pingHost {
    my $host = shift;

    my $ping = new Net::Ping('icmp');
    my $reachable = $ping->ping($host, 2);
    $ping->close();

    return $reachable ? ($host) : ();
}

sub scan {
    my $self = shift;

    my @threads = ();

    for my $ip ($self->{_netmask}->enumerate) {
        push @threads, threads->create(\&pingHost, $ip);
    }

    my @alive = ();
    for my $thr (@threads) {
        push @alive, $thr->join();
    }

    return @alive;
}

package main;

die "Run this as root\n" unless $> == 0;

die "\$ perl $0 <IP/CIDR>\n" unless @ARGV;

my $range = shift;

# regex from: https://www.regextutorial.org/regex-for-numbers-and-ranges.php
unless ($range =~ /^([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.
([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.
([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.
([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\/(\d\d)$/x && $5 < 33) {
    die "Acceptable format: IP/CIDR, example:\n\$ perl $0 192.168.8.0/24\n";
}

my $pinger = new LiveHostPinger($range) or die "Cannot create pinger\n";

print "Scanning...\n\n";
print join("\n", map{$_ .= ' is alive!'}$pinger->scan()), "\n";
