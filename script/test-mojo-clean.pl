#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"../../googledrive/", remote_root=>'/');
$o->clean_remote_duplicates;