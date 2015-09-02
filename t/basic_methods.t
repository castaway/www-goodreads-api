#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Data::Dumper;

use_ok('WWW::Goodreads::API');

## Find a book:

my $api = WWW::Goodreads::API->new(
    dev_key => $ENV{DEV_KEY}
    );


my $prot_api = WWW::Goodreads::API->new(
    dev_key => $ENV{DEV_KEY},
    dev_secret => $ENV{DEV_SECRET},
    oauth_token => $ENV{OAUTH_TOKEN},
    oauth_secret => $ENV{OAUTH_SECRET},
    );
my $user_xml = $prot_api->auth_user;

diag(Dumper($user_xml));
is($user_xml->{user}{name}, 'Jess Robinson', 'Got reasonable user_xml (name is Jess)');
is($user_xml->{user}{id}, '4483033', 'Got reasonable user_xml (id is set)');

my $bookid = $prot_api->book_isbn_to_id('9781430223658');
diag($bookid);
is($bookid, '6609266', 'Got Definitive Guide to Catalyst via ISBN');

#my $books = $prot_api->books({ author => 'Sue Robinson'});
# diag(Dumper($books));

my $search_bookid = $prot_api->find_goodreads_book( title => 'The Poisonwood Bible',
                                             author => 'Barbara Kingsolver',
                                            );

my $added = $prot_api->add_to_shelf( book_id => '6609266',
                                     name => 'apitest'
                                    );
diag(Dumper($added));

my $book = $prot_api->book_show( book_id => '6609266');
diag(Dumper($book));

my $book2 = $prot_api->book_show( book_id => '1032724');
diag(Dumper($book2));

my $user_all = $prot_api->show_user(id => '4483033');
diag(Dumper($user_all));

## this needs to check that we didnt already add this same book_id/page combo!
#my $update = $prot_api->user_status( book_id => '103241',
#                                     page => 42,
#                                    );
# diag(Dumper($update));

done_testing;
