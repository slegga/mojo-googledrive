#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Test::oauth;
use Data::Dumper;

# TEST UPLOAD

path('t/local')->make_path;
path('t/remote')->make_path;
`rm -r t/local/*`;
`rm -r t/remote/*`;
`echo local-file >t/local/file.txt`;
`echo remote-file >t/remote/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/', local_root => 't/local'), oauth=>Test::oauth->new);
my $f= $o->file('file.txt');
$f->download;
is (path('t/local/file.txt')->slurp,'remote-file
','Content uploaded');


done_testing;
