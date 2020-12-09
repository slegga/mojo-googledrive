#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Data::Dumper;
use utf8;
use Encode qw/encode decode/;

# TEST UPLOAD

`rm -r t/local/*`;
`rm -r t/remote/*`;
`echo local-fileæøå >t/local/fileæøå.txt`;
`echo remote-fileæøå >t/remote/fileæøå.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'));
my $f= $o->file('fileæøå.txt');
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
is_deeply (\@pathfiles,['/','/fileæøå.txt'],'resolve_path');
$f->upload;
is (decode("UTF-8",path('t/remote/fileæøå.txt')->slurp),'local-fileæøå
','Content uploaded');


done_testing;
