#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use OAuth::Cmdline::GoogleDrive;
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"testlive", remote_root=>'/test/');
#my $metadata = $o->file('testfil.txt')->upload->metadata;
#my $metadata = $o->file('testæøå.txt')->upload->metadata;
my $metadata = $o->file('ukjent/ukjent1.txt')->upload->metadata;
p $metadata;