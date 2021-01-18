#!/usr/bin/env perl
use lib 'lib';
use Mojo::GoogleDrive::Mirror;
use open ':std', ':encoding(UTF-8)';

=head1 NAME

gd-sync

=head1 SYNOPSIS

    gd-sync.pl dryrun

=head1 DESCRIPTION

Syncronize local katalog with your google drive. Like dropbox.

    gd-sync.pl <COMMAND>

=head1 SETUP

See README.md

=head1 COMMANDS

With no command do a normal sync with remote google drive disk.

=over 4

=item dryrun - Only print changes. Turn on verbose mode if implemented.

=item silence - Not implemented

=item verbose - Not implemented

=back

=cut

my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"$ENV{HOME}/googledrive", remote_root=>'/');
$o->sync(@ARGV);