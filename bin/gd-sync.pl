#! /usr/bin/env perl
use Mojo::Base -signatures,-strict;
use Mojo::File 'curfile';
use open ':std', ':encoding(UTF-8)';
my $curlib;
BEGIN {
    $curlib = curfile->dirname->dirname->child('lib')->to_string;
};
use lib $curlib;
use Mojo::GoogleDrive::Mirror;

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

# simple_argv
# Return a hash structure based on ARGV

sub simple_argv {
    my @script_args = @_;
    my $return;
    my $index = -1;
    for my $i(0 .. $#script_args) {
        last if ($script_args[$i] =~ /^\--/);
        $index = $i;
        push @{$return->{commands}}, $script_args[$i];
    }
    $index++;
    if ($index <= $#script_args) {
        my $key;
        for my $i ($index .. $#script_args) {
            if ($script_args[$i] =~ /^\--/) {
                if ($key && ! exists $return->{$key}) {
                    $return->{$key} = 1;
                }
                $key = $script_args[$i];
                $key =~ s/^\-\-//;
            } else {
                if (! exists $return->{$key}) {
                    $return->{$key} = $script_args[$i];
                } else {
                    if (! ref $return->{$key} ) {
                        my $first = $return->{$key};
                        my @values = ($first, $script_args[$i]);
                        $return->{$key} = \@values;
                    } else {
                        push @{$return->{$key}},$script_args[$i];
                    }
                }
            }
        }

        # Fix gd-sync.pl --debug
        $return->{$key}=1 if ! exists $return->{$key};
    }
    return $return;
}


# MAIN

my $config = simple_argv(@ARGV);
my $o = Mojo::GoogleDrive::Mirror->new(local_root=>"$ENV{HOME}/googledrive", remote_root=>'/', %$config);
#say $o->is_needing_sync() ? 'Need sync now' : 'No need for sync';
if ($o->is_needing_sync()) {
    $o->sync();
} elsif ($config->{force}) {
    $o->sync();
}

