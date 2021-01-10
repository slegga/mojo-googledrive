package Mojo::GoogleDrive::Mirror;

use Mojo::Base -base, - signatures;
use Mojo::File 'path';
use utf8;
use open qw(:std :utf8);
use Mojo::GoogleDrive::Mirror::File;
use Mojo::UserAgent;
use Data::Dumper;
use OAuth::Cmdline::GoogleDrive;
use Mojo::JSON qw /decode_json encode_json true false/;
use Mojo::Date;
use Digest::MD5 qw /md5_hex/;
use Mojo::Util 'url_unescape';

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

=head2 INTERESTING_FIELDS

Constant set to minimum meta data for a file.

=cut

sub INTERESTING_FIELDS {
    return 'id,kind,name,mimeType,parents,modifiedTime,trashed,explicitlyTrashed,md5Checksum,size';
}


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

=head2 sync

Calculate diff with newly changed files local and remote. If both changes keep remote and overwrite local change.

=cut

sub sync($self) {
    # Calcutale diff
    # newly changed remote

    my @rfiles;
if(1) { # turn of query remote when develop local
    @rfiles = $self->_get_remote_files(undef);


    #get root
    my $url = Mojo::URL->new($self->api_file_url)->path('root')->query(fields => 'id,name');

    say $url;
    my $root = $self->http_request('get',$url,'');

    my $opts={};
    my %id2pathfile = ($root->{id} => '');
    $opts->{q} = '';
#    $opts->{fields} = join(',', map{"files/$_"} split(',','id,name,parents,kind') );
    $opts->{fields} = "nextPageToken,".join(',', map{"files/$_"} split(',','id,name,parents,kind') );
    $opts->{q} = q_and($opts->{q}, "trashed = false" );
    $opts->{q} = q_and($opts->{q}, "mimeType = 'application/vnd.google-apps.folder'");
    $opts->{pageSize} = 1000;
    $url = Mojo::URL->new($self->api_file_url)->query($opts);
    my $remote_folders = $self->http_request('get',$url,'');
#    warn join(' ', keys %$remote_folders);
#    say scalar @{ $remote_folders->{files} };

    #build all folder structures

    my @folders = @{$remote_folders->{files}};
    my $j =0;
    while (@folders && $j<6) {
        for my $i(reverse  0 .. $#folders) {
            for my $k(keys %id2pathfile) {
                next if ! $k;
                next if ! $folders[$i];
                if (! exists $folders[$i]->{parents} || ! $folders[$i]->{parents}->[0]) {
#                    say "No parent: ".encode_json($folders[$i]);
                    next;
                }
                elsif ($folders[$i]->{parents}->[0] eq $k) {
                    $id2pathfile{$folders[$i]->{id}} = $id2pathfile{$k}.'/'. $folders[$i]->{name};
                    delete $folders[$i];
                }
            }
        }
        $j++;
    }
#    die Dumper \%id2pathfile;

    # get pathfile value
    for my $f (@rfiles) {
        $f->{modifiedTime} = Mojo::Date->new($f->{modifiedTime});
        warn encode_json($f) if ! exists $f->{parents}->[0];
        $f->{pathfile} = $id2pathfile{$f->{parents}->[0]}.'/'.$f->{name};
    }
} #if 0
    # newly local changes
        my %lc;  # {pathfile, md5Checksum, modifiedTime}

     %lc = map { my @s = stat($_);$_=>{is_folder =>(-d $_), size => $s[7], modifiedTime => Mojo::Date->new->epoch($s[9]) }} grep {defined $_} path( $self->local_root )->list_tree({dont_use_nlink=>1})->each;
    my @lfiles;
     for my $k (keys %lc) {
 #       say $lc{$k}->{is_folder};
        if (! $lc{$k}->{is_folder}) {
            $lc{$k}{md5Checksum} = md5_hex($k);
            $lc{$k}{pathfile} = $k;
            push @lfiles, $lc{$k};
        }
     }
#    say Dumper \%lc;
    say "remotefiles: ".scalar @rfiles;
    say "localfiles: ".scalar @lfiles;
    say "\nExists localbut not remote";
    for my $l(@lfiles) {
        my $hit =0;
        my $lpf = substr($l->{pathfile},length($self->local_root));
        for my $r(@rfiles) {

            if ($lpf eq $r->{pathfile}) {
                $hit =1;
                last;
            }
        }
        say "$lpf: $hit" if !$hit;
    }

    say "\nExists remote but not local";
    for my $r(@rfiles) {
        my $hit =0;
        for my $l(@lfiles) {
            my $lpf = substr($l->{pathfile},length($self->local_root));

            if ($lpf eq $r->{pathfile}) {
                $hit =1;
                last;
            }
        }
        say "$r->{pathfile}: $hit" if !$hit;
    }
;

    # resolve conflicts

    # diff resolve
}

=head2 clean_remote_duplicates

Look for duplicates on remote. Remove newer duplicates. Compare parents->[0], name, md5Checcksum

Report unwanted, unnatural files.

=cut

sub clean_remote_duplicates($self) {

# get all elements but not google docs
    my @rfiles = $self->_get_remote_files(undef);

# put them in an hash with arrays.
    my %files_h = ();
    for my $f (@rfiles) {
        my $id = join('/',$f->{parents}->[0],$f->{name},$f->{md5Checksum});
        push @{$files_h{$id}}, $f;
    }
# delete newer versions of a file.
    for my $k(keys %files_h) {
        if (scalar @{$files_h{$k}} > 1) {
            say $k;

            # get min date
            my $min='ZZ';
            for my $dup(@{$files_h{$k}}) {
                if ($min gt $dup->{modifiedTime}) {
                    $min = $dup;
                }
            }
            return if $min eq 'ZZ';
            # delete all newer versions
            my $deleted_count=0;
            for my $dup(@{$files_h{$k}}) {
                if ($min ne $dup->{modifiedTime}) {
                    say $k;
                    my $res = $self->http_request('delete',$self->api_file_url . $dup->{id});
                    die Dumper $res if $res;

                }
                $deleted_count++;
            }
            say "#        Deleted count ".$deleted_count;

            #            die Dumper $files_h{$k};
        }
    }

    # Look for empty files
    for my $f(@rfiles) {
        die if ! exists $f->{size};
        if ($f->{size} == 0) {
                    say Dumper $f;;
                    my $res = $self->http_request('delete',$self->api_file_url . $f->{id});
                    die Dumper $res if $res;
        }
    }

    # report orphan files

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
    if (! $options{oauth}) {
        warn Dumper $self;
        die 'oauth';
    }
    my $return = Mojo::GoogleDrive::Mirror::File->new(metadata=>$metadata, %options);
    return $return;
}

=head2 http_request

    $metadata = $file->http_request(method,url,payload)

Do a request and return a hash converted from returned json.

=cut

sub http_request($self, $method,$url,$header='',@) {


    if (! $self->oauth) {
        warn Dumper $self;
        die "No oauth";
    }
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
#    die Dumper $tx->res->body;
    my $return;
#    return if $method eq 'patch';
    my $body;
    $body = $tx->res->body;
    if ($url =~/alt\=media/) {
        $return = $body;
    } elsif (! defined $body || length($body) ==0 ) {
        return undef;
    } else {
        $return = decode_json($body);
    }
    say scalar @{$return->{files}} if ref $return && exists $return->{files};
    if (ref $return eq 'HASH' && exists $return->{nextPageToken}) {
        my %real_return = %$return;
        say "####################################################################";
        $url->query({pageToken=>$return->{nextPageToken}});
        #$url .= "$url".''
#        $url = "$url".'&pageToken='.$return->{nextPageToken}.'QQQ%3D%3D';
        $body = $self->http_request($method,$url,$header,@extra);
        $return = $body;
        #merge next page in result;
        for my $x(keys %real_return) {
            if (ref $real_return{$x} eq 'ARRAY') {
                push @{ $real_return{$x}}, @{ $return->{$x}};
            } elsif($x eq 'nextPageToken') {
                # ignore
            } else {
                say $x;
                ...;
            }
        }
        $return = \%real_return;
    }
    return $return;
}

# PRIVATE METHODS

# _get_remote_files
#  Return all files changed after given $from_md
# Called by sync and clean_remote_duplicates

sub _get_remote_files($self,$from_md) {

    my $opts;
    $opts->{q} = '';
    $opts->{q} = q_and($opts->{q}, "trashed = false" );
    $opts->{q} = q_and($opts->{q}, "modifiedTime > '$from_md'") if $from_md;
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application/vnd.google-apps.folder'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.document'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.presentation'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.spreadsheet'");
    $opts->{pageSize} = 1000;

    $opts->{fields} = 'nextPageToken,' . join(',', map{"files/$_"} split(',',INTERESTING_FIELDS) );#INTERESTING_FIELDS;
    my $url = Mojo::URL->new($self->api_file_url)->query($opts);
#    ...;# mangler dateo fra || since q => modifiedTime > '2012-06-04T12:00:00' // default time zone is UTC
    my $remote_files = $self->http_request('get',$url,'');
#    die keys %$remote_files;
    return @{ $remote_files->{files} };
}

# NON SELF UTILITY SUBS

=head2 q_and

    $q = q_and($q,"name = 'filename.txt'");

=cut

sub q_and($old,$add) {
    my $return=$old;
    $return .=' and ' if $return;
    $return .= $add;
    return $return;
}

1;
