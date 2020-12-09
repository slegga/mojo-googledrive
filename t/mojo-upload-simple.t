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
`echo remote-file >t/remote/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'));
my $f= $o->file('file.txt');
my $metadata = $f->get_metadata;
print STDERR Dumper $metadata;
say STDERR "\n";



#p $metadata;
like ($metadata->{id},qr{\w},'id is set');

my $root = $o->file('/');
my @objects =  $root->list->map(sub{$_->metadata})->each;
p @objects;
is (@objects,1,'file found');

my @pathfiles = $f->path_resolve->map(sub{$_->metadata->{id}})->each;
is @pathfiles,2,'Number og objects';
p @pathfiles;
is_deeply (\@pathfiles,['/','/file.txt'],'resolve_path');
$f->upload;
is (path('t/remote/file.txt')->slurp,'local-file
','Content uploaded');


done_testing;
