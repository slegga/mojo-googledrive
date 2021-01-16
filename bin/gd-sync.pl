#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
use open ':std', ':encoding(UTF-8)';

my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"../../googledrive", remote_root=>'/');
$o->sync();