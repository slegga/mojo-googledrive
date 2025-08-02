#!/usr/bin/env perl
use lib 'lib';
use Mojo::Base -strict;
use Data::Printer;
use Mojo::File qw/path curfile/;
use OAuth::Cmdline::GoogleDrive;
use Data::Dumper;
my $curlib;
use utf8;
BEGIN {
    $curlib = curfile->dirname->dirname->child('lib')->to_string;
};
use lib $curlib;
use Mojo::GoogleDrive::Mirror;


# REMOVE FILE FROM REMOTE

die "Must have have a file as an argument" if ! $ARGV[0];
die "Must have have a file as an argument" if ! $ARGV[0];


my $o = Mojo::GoogleDrive::Mirror->new(remote_root=>'/');
my $metadata = $o->file($ARGV[0])->remove;
print $metadata->last_message ."\n";
