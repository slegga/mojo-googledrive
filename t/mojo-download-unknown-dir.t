#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Data::Dumper;

# TEST UPLOAD

`rm -r t/local/*`;
`rm -r t/remote/*`;
`echo local-file >t/local/file.txt`;
`mkdir t/remote/unknown`;
`echo remote-file >t/remote/unknown/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/', local_root => 't/local'));
my $f= $o->file('/unknown/file.txt');
$f->download;
is (path('t/local/unknown/file.txt')->slurp,'remote-file
','Content downloaded');


done_testing;
