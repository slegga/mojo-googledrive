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
`mkdir t/local/ukjent`;
`echo local-file >t/local/ukjent/file.txt`;
#`echo remote-file >t/remote/file.txt`;


my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"t/local/", remote_root=>'/', ua=>Test::UserAgent->new(real_remote_root=>'t/remote/'));
my $f= $o->file('ukjent/file.txt');
is($f->lfile->to_string,'t/local/ukjent/file.txt','Local remote dir');
is($f->rfile->to_string,'/ukjent/file.txt','Right remote dir');

my $metadata = $f->get_metadata;
print STDERR Dumper $metadata;
say STDERR "\n";



#p $metadata;
ok (! exists $metadata->{id},'id is NOT set');

my @pathfiles = $f->path_resolve->map(sub{defined $_ && $_->metadata ?$_->metadata->{id} : undef })->each;
is @pathfiles,3,'Number og objects';
p @pathfiles;
is_deeply (\@pathfiles,['/',undef,undef],'resolve_path');
$f->upload;
is (path('t/remote/ukjent/file.txt')->slurp,'local-file
','Content uploaded');


done_testing;
