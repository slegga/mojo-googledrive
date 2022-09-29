#!/usr/bin/perl

###########################################
# google-drive-init
# Mike Schilli, 2014 (m@perlmeister.com)
# got from Net::Google:Drive::Simple
# Modified by slegga
###########################################

=head1 NAME

google-drive-init.pl

=encoding UTF-8

=head1 SYNOPSIS

On MAC

mojo-googledrive git:(main) ✗ PERL_LWP_SSL_CA_FILE=/opt/homebrew/share/ca-certificates/cacert.pem script/google-drive-init.pl

=head1 DESCRIPTION

Generate token from google. Needs client_id and client_secrect can reuse a copy of ~/.google-drive.yml

=cut

use Mojo::Base -strict;
use 5.26.0;;
use Data::Dumper;
# abort earlier if requires deps are missing
use LWP::Protocol::https;
use YAML::Syck;
use OAuth::Cmdline::GoogleDrive;
use OAuth::Cmdline::Mojo;

my $client_id = q[XXXXXXXX.apps.googleusercontent.com];
my $client_secret = q[YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY];
my $gfile = "$ENV{HOME}/.google-drive.yml";

# To refresh from copy of data from another computer.
if( -e $gfile ) {
    my $data = LoadFile($gfile);
    say Dumper $data;
    $client_id = $data->{client_id};
    $client_secret = $data->{client_secret};
    say `cp $gfile /tmp -v`;
#    die;

}
my $oauth = OAuth::Cmdline::GoogleDrive->new(
    client_id     => $client_id,
    client_secret => $client_secret,
    login_uri     => "https://accounts.google.com/o/oauth2/auth",
    token_uri     => "https://accounts.google.com/o/oauth2/token",
    scope         => "https://www.googleapis.com/auth/drive",
    access_type   => "offline",
);

my $app = OAuth::Cmdline::Mojo->new(
    oauth => $oauth,
);

$app->start( 'daemon', '-l', $oauth->local_uri );