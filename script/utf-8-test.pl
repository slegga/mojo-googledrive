#!/usr/bin/env perl
use Mojo::Base -strict;
use Encode qw /decode/;
if (!@ARGV) {
    die "Please add arguments to script for decode";
}
say "plain";
say join(" ",  @ARGV);
say "decode UTF8";
say join(" ", map{decode('UTF-8',$_)} @ARGV);
say "double decode UTF8";
say join(" ", map{decode('UTF-8',decode('UTF-8',$_))} @ARGV);
