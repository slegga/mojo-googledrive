#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Test::oauth;
use Data::Dumper;
use utf8;
use Encode qw/encode decode/;

# TEST UPLOAD

`rm -r t/local/*`;
`rm -r t/remote/*`;
#`echo local-fileæøå >t/local/fileæøå.txt`;
`echo remote-fileæøå >t/remote/fileæøå.txt`;

my $local_root = "t/local/";
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>$local_root, remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/',local_root =>$local_root),oauth=>Test::oauth->new);
my $f = $o->file('fileæøå.txt');
my $metadata = $f->get_metadata;
print STDERR Dumper $metadata;
say STDERR "\n";

#p $metadata;
like ($metadata->{id},qr{\w},'id is set');
my $root = $o->file('/');
my @objects =  $root->list->map(sub{$_->metadata})->each;
p @objects;
is (@objects,1,'file found');

my @pathfiles = $f->path_resolve->grep(sub{$_->metadata})->map(sub{$_->metadata->{id}})->each;
is @pathfiles,2,'Number og objects';
p @pathfiles;
is_deeply (\@pathfiles,['/','/fileæøå.txt'],'resolve_path');
$f->download;
is (decode("UTF-8",path('t/local/fileæøå.txt')->slurp),'remote-fileæøå
','Content downloaded');


done_testing;
