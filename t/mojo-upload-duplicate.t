#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File 'path';
use Test::More;
use Test::UserAgent;
use Data::Dumper;
use Carp::Always;
use Mojo::Base -strict;

# TEST UPLOAD

`rm -r t/local/*`;
`rm -r t/remote/*`;
mkdir('t/local/dir1');
mkdir('t/local/dir2');
`echo local-file-dir1 >t/local/dir1/file.txt`;
`echo local-file-dir2 >t/local/dir2/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'),debug=>1);
my $f= $o->file('/dir1/file.txt');
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
is (path('t/remote/dir1/file.txt')->slurp,'local-file-dir1
','Content uploaded dir1');



diag ' upload file 2';
my $f2= $o->file('/dir2/file.txt');
$f2->upload;
$metadata = $f2->get_metadata;
say Dumper $metadata;
delete $metadata->{modifiedTime};
is_deeply($f2->get_metadata,{
          'id' => 'dir2/file.txt',
          'name' => 'file.txt',
          'explicitlyTrashed' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
          'trashed' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
          'md5Checksum' => 'HvGIssvIdVHYXYFrMvqIow',
          'kind' => 'drive#file',
          'parents' => ['dir2'],
          'mimeType' => 'text/plain',
},'Metadata ok');

is (path('t/remote/dir2/file.txt')->slurp,'local-file-dir2
','Content uploaded dir2');


done_testing;
