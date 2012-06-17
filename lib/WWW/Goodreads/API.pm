package WWW::Goodreads::API;

use strict;
use warnings;

use v5.10;

## Minimal moose compat:
use Moo;
use URI;
use URI::QueryParam;
use LWP::Simple 'get', '$ua';
use XML::Simple ;
use Data::Dumper;
use Business::ISBN;

## for signed requests
use Net::OAuth;

our $VERSION = '0.001';

=head1 NAME

WWW::Goodreads::API - Interact with the goodreads.com api

=head1 SYNOPSIS

    my $api = WWW::Goodreads::API->new(
      dev_key => $mydevkey,
      dev_secret => $mydevsecret,
      oauth_token => $myoauthtoken,
      oauth_secret => $myoauthsecret,
    );

    my $user_data = $api->call_method('auth_user');

    my $user_books = $api->call_method('review.list', { page => 1 } );

=head1 DESCRIPTION

This is a thinnish wrapper over the goodreads.com api (see
L<http://goodreads.com/api>. It retrieves XML content for the various
API methods, some of which require authentication, and returns the
result passed through XML::Simple.

Note that the API documentation is incorrect in places, especially the
protected methods. This module is a result of some experimentation.

To use this module you will need to sign up for a goodreads developer
key, then jump through some OAuth hoops to get your OAuth access
token. Once fetched this token can be stored and re-used.

=head1 ATTRIBUTES

The developer key and secret are provided by the goodreads.com
website, go here to get one:
L<http://www.goodreads.com/api/keys>. Note also the terms of use while
you are there.

=head2 dev_key

=head2 dev_secret

The oauth token and secret are obtained by logging in with the goodreads api, see L<http://www.goodreads.com/api/documentation#oauth>.

=head2 oauth_token

=head2 oauth_secret

=cut

# goodreads api key/secret
has dev_key => (isa => sub { $_[0] =~ /^\w+$/ }, is => 'rw', required => 0);
has dev_secret => (isa => sub { $_[0] =~ /^\w+$/ }, is => 'rw', required => 0);

# oauth access/secret
has oauth_token => (isa => sub { $_[0] =~ /^\w+$/ }, is => 'rw', required => 0);
has oauth_secret => (isa => sub { $_[0] =~ /^\w+$/ }, is => 'rw', required => 0);

=head1 API METHODS

So far the following methods have been tested/configured:

=over

=item auth_user

=item user.show

=item book.show

=item shelves.list

=item author.books

=item owned_books.list

=item review.list

=back

=cut

my %api_methods = (
    auth_user => { 
        api => 'api/auth_user', 
        http_method => 'GET', 
        protected => 1,
        content_in => 'xml',
    },
    'user.show' => { 
        api => 'user/show',
        http_method => 'GET', 
        protected => 1,
        content_in => 'xml',
    },
    'book.show' => { 
        api => 'book/show',
        http_method => 'GET', 
        protected => 0,
        content_in => 'xml',
    },
    'shelves.list' => {
        api => 'shelf/list.xml',
        http_method => 'GET',
        protected => 0,
        content_in => 'xml',
    },
    'author.books' => {
        api => 'author/list.xml',
        http_method => 'GET',
        protected => 0,
        content_in => 'xml',
    },
    'owned_books.list' => {
        api => 'owned_books/user',
        http_method => 'GET',
        protected => 1,
        content_in => 'xml',
    },
    'review.list' => {
        api => 'review/list',
        http_method => 'GET',
        protected => 1,
        content_in => 'xml',
        default_params => {
#            v => 2,
            format => 'xml',
        },
     },
);

=head1 METHODS

=head2 call_method

=head3 Arguments: $method_name, $params_hashref, $protected_flag, $http_method

=head3 Returns: XML::Simple-parsed perl data structure

Call an api method. If passed an api method name from the list above,
will use internal settings to determine whether it is a protected
method, and which default parameters to send to it. If the method name
is not recognised, will just try to call it anyway.

  $api->call_method('book.show', { id => $mybookid });

  $api->call_method('book/show', { id => $mybookid }, 0, 'GET');

=cut

## TODO: Track calls and ensure that each is not called more than once
## per secord.
sub call_method {
    my ($self, $method, $params, $protected, $http_method) = @_;
    ## The api page names methods with foo.bar, the uri is actually foo/bar
    ## but some method names end in .xml.
    ##$method =~ s!\.!\/!g;

    my $content_in = 'plain';
    if(exists $api_methods{$method}) {
        $protected = $api_methods{$method}{protected};
        $http_method = $api_methods{$method}{http_method};
        $content_in = $api_methods{$method}{content_in};

        $params = { %{$api_methods{$method}{default_params} || {}}, %$params };
        $method = $api_methods{$method}{api} if(exists $api_methods{$method}{api});
    }

    # FIXME: merge normal/protected more elegantly.
    my $response;
    my $goodreads_api_url = URI->new("http://www.goodreads.com");

    if($protected) {
        $response = $self->_call_protected_method($method, $params, $http_method);
    } else {

        $goodreads_api_url->query_form_hash($params)
          if ($params);


#    $goodreads_api_url->query_param(oauth_access_token => $self->oauth_key)
#        if $self->oauth_key;
#    $goodreads_api_url->query_param(oauth_access_token_secret => $self->oauth_secret)
#        if($self->oauth_secret);

        $goodreads_api_url->query_param(key => $self->dev_key) 
          if ($self->dev_key);
    
        ## Method will often consist of multiple path segments.
        $goodreads_api_url->path($method);

        print STDERR "Fetching: $goodreads_api_url\n";

        $response = $ua->get($goodreads_api_url);
    }

    if (!$response->is_success)
    {
        if ($response->content =~ m/<html>/ or 
            $response->content =~ m/not authorized/i
            #$response->content =~ m!<error>book not found</error>!
           )
        {
            # This is probably the website's general 404 response -- we mistyped the API name.
            for my $subresponse ($response->redirects, $response)
            {
                my $subrequest = $subresponse->request;
                print $subrequest->as_string("\n"), "\n--->\n";
                print $subresponse->as_string("\n"), "\n---\n\n";
            }
            die "Failed API call " . $response->status_line . " from url $goodreads_api_url\n";
        }
        
        # This is the specific API deciding that we failed.  Make it produce something that can be nicely handled by an eval {}.
        die $response->content;
        
    }

    my $content = $response->content;

    if ($content_in eq 'xml') {
        $content = XMLin($content, SuppressEmpty => '');
    }

    return $content;
}

sub _call_protected_method {
    my ($self, $method, $params, $http_method) = @_;

    $http_method ||= 'GET';
    $http_method = uc $http_method;

    my $gr_url = URI->new('http://www.goodreads.com');
    $gr_url->path($method);
    if(exists $params->{id}) {
        $gr_url->path("$method/$params->{id}.xml");
    }
    $gr_url->query_form_hash($params)
        if ($params);

#    print STDERR "Calling: $gr_url\n";

    my $oauth_request = Net::OAuth->request('protected resource')->new(
        consumer_key => $self->dev_key,
        consumer_secret => $self->dev_secret,
        request_url => $gr_url->as_string,
        request_method => $http_method,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => rand(),
        token => $self->oauth_token,
        token_secret => $self->oauth_secret,
        extra_params => $params,
       );

    $oauth_request->sign;
#     print STDERR "Calling: ", $oauth_request->request_url, "\n";

    my $response;
    if ($http_method eq 'GET') {
        print STDERR "Fetching ".$oauth_request->request_url." (protected GET)\n";
        $response = $ua->get($oauth_request->request_url, #to_url 
                            Authorization => $oauth_request->to_authorization_header );
    } else {
        print STDERR "Fetching ".$oauth_request->request_url." (protected POST)\n";
        $response = $ua->post($oauth_request->request_url,
                              $params,
                              Authorization => $oauth_request->to_authorization_header );
    }


    return $response;
}


#####

sub books {
    my ($api, $params) = @_;

    my $method = 'search/index.xml';

    print Dumper($params);
    print "books($api, ".join(' // ', %$params)."\n";

    my $results = {};

    $results = $api->call_method($method, {
        'q' => (($params->{title}||'') . '   ' . ($params->{author}||'')),
    });


    # my $author = delete $params->{author};
    # if($author) {
    #     $results = $self->call_method($method, { 
    #         'search[field]' => 'author', 
    #         'q' => $author,
    #                                      });
    # } else {
    #     $results = $self->call_method($method, { 
    #         'q' => $params->{title},
    #                                      });
    # }

    my $xml = XMLin($results, 
                    ForceArray => ['work'],
                    KeyAttr => [],
        );
#    print Dumper($xml);
    my $works = $xml->{search}{results}{work};

    #print "Found: ", Dumper($works);
    my @books = grep { $_->{best_book}{title} =~ /\Q$params->{title}\E/i
                       and $_->{best_book}{author}{name} =~ /\Q$params->{author}\E/ } @$works;
    #print "Filtered: ", Dumper(\@books);

    return \@books;
    
}

=item book_isbn_to_id

  my $bookid = $api->book_isbn_to_id($isbn);

L<http://www.goodreads.com/api#book.isbn_to_id>

=cut

sub book_isbn_to_id {
    my ($api, $isbn) = @_;
    # as_isbn10: Finds 4/6.
    # as_isbn13: Finds 4/6.
    print "book_isbn_to_id($isbn)\n";
    $isbn = Business::ISBN->new($isbn)->as_isbn13->as_string([]);
    my $res;
    eval {
        $res = $api->call_method('book/isbn_to_id', {isbn => $isbn});
    };
    if ($@ =~ m/No book with that ISBN/) {
        return undef;
    } elsif ($@) {
        # Rethrow
        die;
    }
    return $res;
}

=head1 user_status

  $api->user_status(%params);

L<http://www.goodreads.com/api#user_status.create>

=cut

sub user_status {
    my ($api, %params) = @_;

    # FIXME: this should be more flexable about which params the user wants to enter.
    $api->call_method('user_status.xml', 
                      {
                          'user_status[book_id]' => $params{book_id},
                          'user_status[page]' => $params{page}
                      }, 1, 'POST');
}

=head2 show_user

  $api->show_user(id => 42);
  $api->show_user(username => 'yourmother');

L<http://www.goodreads.com/api#user.show>

=cut

sub show_user {
    my ($api, %params) = @_;

    return $api->call_method('user.show',
                             { id => $params{id}, }
        );
#    my $xml = $api->call_method('user/show/' . ($params{id}||$params{username}) . '.xml', {}, 1); 

#    return XMLin($xml);
}

sub get_updates {
    my ($api, %params) = @_;

    my $user_data = $api->show_user(%params);
    my $updates = $user_data->{user}{updates}{update};

    my $book_pages = {};
    for my $update (@$updates) {
        #print Dumper($update);
        # This also includes "review", and presumably some other junk for things like friends.
        # (Review seems to be an update with no page, including adding it to a shelf.)
        next unless $update->{type} eq 'userstatus';

        # FIXME: Make it less fragile to make sure that we only count the most recent update on a given book ... or the one with the highest page number?
        # Current behavior relies on goodreads giving the most recent one at the top.
        $book_pages->{$update->{object}{user_status}{book}{id}{content}} ||= $update->{object}{user_status}{page}{content};
    }

    return $book_pages;
}

=head1 add_to_shelf

 $api->add_to_shelf(book_id => 27, name => 'bobthebuilder');

L<http://www.goodreads.com/api#shelves.add_to_shelf>

=cut

sub add_to_shelf {
    my ($api, %params) = @_;

    $api->call_method('shelf/add_to_shelf.xml',
                      {
                          book_id => $params{book_id},
                          name => $params{name},
                      }, 1, 'POST');
}

=head1 auth_user

Fetch data about the currently logged in user, most basic protected method.

L<http://www.goodreads.com/api#auth.user>

=cut

sub auth_user {
    my ($api) = @_;

    $api->call_method('auth_user');
}

=head1 book_show

Show current data about a particular book

L<http://www.goodreads.com/api#book.show>

=cut

sub book_show {
    my ($api, %params) = @_;

    my $book = $api->call_method('book/show/' . $params{book_id} . '.xml', {}, 1);
    return XMLin($book);
}

sub get_book_page {
    my ($api, %params) = @_;

    my $book = $api->book_show(%params);

    if(exists $book->{book}{my_review}) {
        return $book->{book}{my_review}{user_statuses}{user_status}{page}{content};
    } 

    return 0;
}

sub find_goodreads_book {
    my ($api, %params) = @_;
    ## find it by isbn, or resort to searching on title/author

    my $bookid;
    if(defined $params{isbn}) {
        $bookid = $api->book_isbn_to_id($params{isbn});
    }
    if(!$bookid) {
        my $books = $api->books({ 
            author => $params{author},
            title => $params{title},
        });
#        print Dumper($books);
        if(@$books ==1) {
            $bookid = $books->[0]{best_book}{id}{content};
        }
    }

    return $bookid;
}

'done coding';
