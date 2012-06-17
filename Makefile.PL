use strict;
use warnings FATAL => 'all';
use 5.008001;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'WWW::Goodreads::API',
  VERSION_FROM => 'lib/WWW/Goodreads/API.pm',
  ## Prereqs reflect which versions this module was developed with, not necessarily the minimum requirements
  PREREQ_PM => {
    'Moo' => '0.009012',
    'URI' => '1.58',
    'LWP::Simple' => '6.00',
    'XML::Simple' => '2.18',
    'Business::ISBN' => '2.05',
    'Net::OAuth' => '0.27',
  },
);
