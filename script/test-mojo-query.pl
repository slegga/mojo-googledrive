#!/usr/bin/env perl
use lib 'lib';
use Mojo::Base -strict;
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
use Data::Printer;
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"../../googledrive", remote_root=>'/');
p $o->file($ARGV[0])->get_metadata(1);