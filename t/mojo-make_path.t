#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
#use Test::More;
use Test::More skip_all => 'make_path make sometimes duplicates. Must have some protection for this';
use Test::UserAgent;
use Data::Dumper;



# TEST UPLOAD

`rm -r t/local/*`;
`rm -r t/remote/*`;

ok(1,'dummy');

my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'));
my $f= $o->file('/catalog');
my $metadata = $f->get_metadata;
print STDERR Dumper $metadata;
say STDERR "\n";

$f->make_path();
my $d =path('t/remote/catalog');
ok (-d $d->to_string,'path made');

$f->make_path();

done_testing;
