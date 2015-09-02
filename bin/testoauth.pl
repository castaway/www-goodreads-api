#!/usr/bin/env perl

use strict;
use warnings;

use Net::OAuth;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new();

my $request = Net::OAuth->request("request token")->new(
    consumer_key => shift,
    consumer_secret => shift,
    request_url => 'http://www.goodreads.com/oauth/request_token',
    request_method => 'POST',
    signature_method => 'HMAC-SHA1',
    timestamp => time(),
    nonce => rand(), # join('', rand_chars(size=>16, set=>'alphanumeric')),
#    callback => 'http://printer.example.com/request_token_ready',
    );

$request->sign;
my $res = $ua->post($request->to_url);
my $token;
if($res->is_success) {
    my $response = Net::OAuth->response('request token')->from_post_body($res->content);
    print "Got Request Token ",  $response->token, "\n";
    print "Got Request Token Secret ", $response->token_secret, "\n";
    $token = $response->token;
} else {
    print "Oops, failed to get request token ";
    print $res->status_line;
}

## user auth

my $request_ua = Net::OAuth->request("user auth")->new(
    token => $token,
    callback => 'http://desert-island.me.uk/rubbish',
#    request_url => 'http://www.goodreads.com/oauth/authorize',
    );


my $ua_url = URI->new('http://www.goodreads.com/oauth/authorize');
$ua_url->query($request_ua->to_url);

print "Please visit $ua_url\n";


