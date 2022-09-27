#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Test::oauth;
use Data::Dumper;
use Carp::Always;
use Mojo::Base -strict;

# TEST UPLOAD

# DATA-119 Duplicate directories. /Diverse and /natasha/Diverse will have files duplicated since the file parent name is equal.

`rm -r t/local/*`;
`rm -r t/remote/*`;
mkdir('t/local/test');
mkdir('t/local/dir2');
mkdir('t/local/dir2/test');
`echo local-file-test >t/local/test/file1.txt`;
`echo local-file-dir2-test >t/local/dir2/test/file2.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'),debug=>1,oauth=>Test::oauth->new);
my $f= $o->file('/test/file1.txt');
my $metadata = $f->get_metadata;
print STDERR Dumper $metadata;
say STDERR "\n";

#p $metadata;
ok (!exists $metadata->{id},'id is not set since not exists on remote');

my $root = $o->file('/');
my @objects =  $root->list->map(sub{$_->metadata})->each;
p @objects;
is (@objects,0,'no remote file found');

my @pathfiles = $f->path_resolve->map(sub{$_->metadata->{id}})->each;
#is @pathfiles,3,'Number og objects';
#p @pathfiles;
is_deeply (\@pathfiles,['/',undef,undef],'resolve_path');
$f->upload;

my $f2 = $o->file('/dir2/test/file2.txt');
$f2->upload;

my @remote_tree = map{$_->to_string} path('t/remote')->list_tree->each;
is_deeply(\@remote_tree,[qw"t/remote/dir2/test/file2.txt t/remote/test/file1.txt "],'Remote tree ok');

`echo local-file-dir2-test-2 >t/local/dir2/test/file2.txt`;
$f2->upload;

@remote_tree = map{$_->to_string} path('t/remote')->list_tree->each;
is_deeply(\@remote_tree,[qw"t/remote/dir2/test/file2.txt t/remote/test/file1.txt "],'Remote tree ok');

done_testing;
