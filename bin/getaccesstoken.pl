#!/usr/bin/env perl

use strict;
use warnings;

use Net::OAuth;
use LWP::UserAgent;
my $ua = LWP::UserAgent->new();

my ($token, $token_secret, $key, $secret) = @ARGV;

my $response = Net::OAuth->response("user auth")->from_hash({
    authorize => 1,
    oauth_token => $token,
    });

my $request = Net::OAuth->request("access token")->new(
    consumer_key => $key,
    consumer_secret => $secret,
    token => $response->token,
    token_secret => $token_secret,
    request_url => 'http://www.goodreads.com/oauth/access_token',
    request_method => 'GET',
    signature_method => 'HMAC-SHA1',
    timestamp => time(),
    nonce => rand(), # join('', rand_chars(size=>16, set=>'alphanumeric')),
    );

$request->sign;

print "Getting: ", $request->to_url, "\n";

my $res = $ua->get($request->to_url);
my $a_token;
if($res->is_success) {
    my $response = Net::OAuth->response('access token')->from_post_body($res->content);
    print "Got Access Token ",  $response->token, "\n";
    print "Got Access Token Secret ", $response->token_secret, "\n";
    $a_token = $response->token;
} else {
    print "Oops, failed to get request token ";
    print $res->status_line;
}

# perl testoauth.pl - consumer key/secret from https://www.goodreads.com/api/keys
# outputs Request Token / Request Token Secret, pass those together with Consumer Key / Secret to this script


