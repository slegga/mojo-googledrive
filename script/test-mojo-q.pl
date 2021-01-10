#!/usr/bin/env perl
use lib 'lib';
use Mojo::Base -strict;
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
use Data::Printer;
use Mojo::URL;
use Mojo::Util 'url_escape';

my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"../../googledrive", remote_root=>'/');
my $url = Mojo::URL->new($o->api_file_url);
my $q = '';
$q= Mojo::GoogleDrive::Mirror::q_and($q,"name = '$ARGV[0]'");
$url->query(q=>$q,fields=>'*');
p $o->http_request('get',$url->to_string);