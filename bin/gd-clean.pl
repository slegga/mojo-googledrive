#!/usr/bin/env perl
use lib 'lib';
use Mojo::Base -strict;
use Mojo::GoogleDrive::Mirror;
use Data::Printer;
use Mojo::File qw/path curfile/;
use OAuth::Cmdline::GoogleDrive;
use Data::Dumper;

# REMOVE EMPTY FOLDERS

my $gd_root = curfile->dirname->dirname->dirname->dirname->child('googledrive');
my %dirswithfiles=();
my $level = @{ $gd_root->to_array };
for my $dir (sort {length("$b") <=> length("$a")} $gd_root->list_tree({dir=>1})->each) {
    if (-f "$dir") {
        my $path = $dir->dirname->to_array;
        my $pathstr='';
        shift @$path for 1 .. $level;
        for my $part(@$path) {
           $pathstr.= '/' . $part;
            $dirswithfiles{"$gd_root" . $pathstr}++;
        }
        next;
    }
    elsif ($dirswithfiles{"$dir"}) {
        next;
    }
    say "delete $dir";
    rmdir "$dir"; #delete directory
}

# CLEAN FILES

my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"../../googledrive/", remote_root=>'/');
$o->clean_remote_duplicates;