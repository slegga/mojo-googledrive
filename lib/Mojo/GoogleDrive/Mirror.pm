package Mojo::GoogleDrive::Mirror;

use Mojo::Base -base, - signatures;
use Mojo::File 'path';
use utf8;
use open qw(:std :utf8);
use Mojo::GoogleDrive::Mirror::File;
use Mojo::UserAgent;
use Data::Dumper;
use OAuth::Cmdline::GoogleDrive;
use Mojo::JSON qw /decode_json encode_json/;
=head1 NAME

Mojo::GoogleDrive::Mirror

=head1 SYNOPSIS

    my $gd = Mojo::GoogleDrive::Mirror->new(local_root => $ENV{HOME}.'/googledrive');
    my $file = $gd->file('/test/testfile.txt');
    $file->download;
    $gd->sync('delta');

=head1 DESCRIPTION

Container for config and credentials.
Basically a producer of Mojo::GoogleDrive::Mirror::File

~/.google-drive.yml

=head1 ATTRIBUTES

=over 4

=item remote_root - string

=item local_root - string

=item api_file_url - string

=item oauth - object

=item sync_direction - string - currently support only "both"

=item ua - object Mojo::UserAgent - ment to mock google.

=back

=head1 METHODS

=cut

has remote_root => '/';
has 'local_root';
has  api_file_url => "https://www.googleapis.com/drive/v3/files/";
has  api_upload_url => "https://www.googleapis.com/upload/drive/v3/files/";
has  oauth          => sub { OAuth::Cmdline::GoogleDrive->new() };
has sync_direction => 'both'; # both ways clound wins if in conflict
has sync_conflict_master =>'cloud';
has ua =>sub {Mojo::UserAgent->new};

=head2 new

    my $gd = Mojo::GoogleDrive::Mirror->new(local_root=>$ENV{HOME} . '/gdtest');

=head2 file

    $file = $gd->file('/path/filename');

Return a new file object.

=cut

sub file {
    my $self = shift;
    my $pathfile = shift //die;
    my $opts ={};
    for my $key(qw/remote_root local_root api_file_url api_upload_url oauth/) {
        $opts->{$key} = $self->$key if ($self->can($key));
    }
    my %common = $self->get_common_hash;
    if ($pathfile eq '/') {
        $opts->{metadata} = {id=>'root'};
    }
    $opts->{$_}=$common{$_} for keys %common;
    return Mojo::GoogleDrive::Mirror::File->new(pathfile => $pathfile,%$opts);

}

=head2 get_common_hash

A semi internal method to secure that new generated file object as the minimum of attributes.

=cut

sub get_common_hash($self) {
    my %return;
    for my $key (qw/remote_root local_root api_file_url api_upload_url oauth sync_direction ua/) {
        $return{$key} = $self->$key;
    }
    $return{mgm}=$self;
    return %return;
}

=head2 file_from_metadata

    my $file = $gd->file_from_metadata({name=>'test.txt',kind=>'drive#file', mimeType =>'application/octet-stream'});

Creates a new fileobject based on metadata.

=cut

sub file_from_metadata ($self,$metadata,%opts) {
    my %common = $self->get_common_hash;
    my %options;
    %options= %opts;
    $options{$_} = $common{$_} for keys %common;
    die Dumper $self if ! $options{oauth};
    my $return = Mojo::GoogleDrive::Mirror::File->new(metadata=>$metadata, %options);
    return $return;
}

=head2 http_request

    $metadata = $file->http_request(method,url,payload)

Do a request and return a hash converted from returned json.

=cut

sub http_request($self, $method,$url,$header='',@) {


    die Dumper $self if ! $self->{oauth};
    my $main_header ={};
    $main_header = $header if $header;
    my %tmp_header = $self->{oauth}->authorization_headers();
    $main_header->{$_} = $tmp_header{$_} for keys %tmp_header;
#    say $main_header;
    my @extra = @_;
    splice @extra,0,4;
    say $url. join('#', map {ref $_ ? encode_json($_):'$_'} @extra);#, $main_header;
    my $tx = $self->ua->$method($url, $main_header,@extra);
    my $code = $tx->res->code;
    if (!$code) {
        say $url;
        die "Timeout";
    }
    if ($code eq '404') {
        die "@_     " . $tx->res->body;
    }
    die Dumper $tx->res if $code > 299;
    my $return =  decode_json($tx->res->body);

    return $return
}

1;
