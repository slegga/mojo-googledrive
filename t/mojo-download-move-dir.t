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
`mkdir t/remote/dir`;
`mkdir t/remote/newdir`;
`echo remote-file >t/remote/dir/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/', local_root => 't/local'), oauth=>Test::oauth->new);
$o->sync;
is (path('t/local/dir/file.txt')->slurp,'remote-file
','Content uploaded');

# move dir
`mv t/remote/dir t/remote/newdir/.`;
$o->sync;
is (path('t/local/newdir/dir/file.txt')->slurp,'remote-file
','Content uploaded');
ok (! -f path('t/local/dir/file.txt'),'Moved file is gone');



done_testing;
