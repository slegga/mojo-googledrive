#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
#my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"testlive", remote_root=>'/');
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"testlive", remote_root=>'/test');

my $metadata = $o->file('testfil.txt')->path_resolve->to_array;
p $metadata;