package Mojo::GoogleDrive::Mirror;

use Mojo::Base -base, - signatures;
use Mojo::File 'path';
#use Mojo::File::Role::Decode;
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
use Encode 'decode';
use YAML::Syck;
use Const::Fast;

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
has api_file_url => "https://www.googleapis.com/drive/v3/files/";
has api_upload_url => "https://www.googleapis.com/upload/drive/v3/files/";
has oauth          => sub { OAuth::Cmdline::GoogleDrive->new() };
has sync_direction => 'both'; # both ways clound wins if in conflict
has sync_conflict_master =>'cloud';
has ua =>sub {Mojo::UserAgent->new};
has state_file => sub {path($ENV{HOME})->child('etc')->make_path->child('googledrive.yml')->touch};
has 'debug';
has state => sub {
    my $self =shift;
    my $state = {};
    if (-f $self->state_file->to_string && ! -z $self->state_file->to_string) {
        $state = YAML::Syck::LoadFile($self->state_file->to_string );
    }
    return $state;
};
has metadata_all => sub{{}};
=head2 INTERESTING_FIELDS

Constant set to minimum meta data for a file.

=cut

const my $INTERESTING_FIELDS => 'id,kind,name,mimeType,parents,modifiedTime,trashed,explicitlyTrashed,md5Checksum,size';

#sub path {
#    return Mojo::File->with_roles('+Decode')->path(@_);
#}

my $new_from_epoch;

=head2 new

    my $gd = Mojo::GoogleDrive::Mirror->new(local_root=>$ENV{HOME} . '/gdtest');

=head2 file

    $file = $gd->file('/path/filename');

Return a new file object.

=cut

sub file($self,$pathfile) {
    my $opts ={};
    for my $key(qw/remote_root local_root api_file_url api_upload_url oauth debug/) {
        $opts->{$key} = $self->$key if ($self->can($key));
    }
    my %common = $self->get_common_hash;
    if ($pathfile eq '/') {
        $opts->{metadata} = {id=>'root'};
    }
    $opts->{$_}=$common{$_} for keys %common;
    return Mojo::GoogleDrive::Mirror::File->new(pathfile => $pathfile,%$opts);

}

=head2 is_needing_sync

Return true if in need of sync. Check if exists newer files locallly anf remote than last sync time.

=cut

sub is_needing_sync($self) {
    my $old = $self->_read_from_epoch();
    my @rfiles = $self->_get_remote_files($old);
    return 1 if @rfiles;
    my @localchange = grep {$old< $_} map { my @s = stat($_);$s[9] } grep{defined $_} path( $self->local_root )->list_tree({dont_use_nlink=>1})->each;
    return 1 if @localchange;
    return 0;
}

=head2 sync

Calculate diff with newly changed files local and remote. If both changes keep remote and overwrite local change.

=cut

sub sync($self) {
    # Calcutale diff
    # newly changed remote
    my $from_epoch = $self->_read_from_epoch();
    my @rfiles;
    my @pathfile_deleted=();

if(1) { # turn of query remote when develop local
    @rfiles = $self->_get_remote_files(0);


    #get root
    my $url = Mojo::URL->new($self->api_file_url)->path('root')->query(fields => 'id,name');

    say $url if $self->debug;
    my $root = $self->http_request('get',$url,'');

    my $opts={};
    my %id2pathfile = ($root->{id} => '');
    $opts->{q} = '';
    $opts->{fields} = "nextPageToken,".join(',', map{"files/$_"} split(',','id,name,parents,kind') );
    $opts->{q} = q_and($opts->{q}, "trashed = false" );
    $opts->{q} = q_and($opts->{q}, "mimeType = 'application/vnd.google-apps.folder'");
    $opts->{pageSize} = 1000;
    $url = Mojo::URL->new($self->api_file_url)->query($opts);
    my $remote_folders = $self->http_request('get',$url,'');

    #build all folder structures
    my @folders = @{$remote_folders->{files}};
    my $j =0;
    while (@folders && $j<6) {
        for my $i(reverse  0 .. $#folders) {
            for my $k(keys %id2pathfile) {
                next if ! $k;
                next if ! $folders[$i];
                if (! exists $folders[$i]->{parents} || ! $folders[$i]->{parents}->[0]) {
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

    # get pathfile value
    for my $r (@rfiles) {
        $r->{modifiedTime} = Mojo::Date->new($r->{modifiedTime});
        if (! exists $r->{parents}->[0] || !$r->{parents}->[0]) {
            $r = undef;# shared with me
        } else {
            if (! exists $id2pathfile{$r->{parents}->[0]}) {
                if ($r->{name} =~ /FORE/) {
                    $r->{name}='ERROR NAME';
                }
               if ($r->{name} =~ /[\xC3\x{FFFD}\x{C3B8}\x{C2}]/) { # used by utf8
                    $r->{name} = decode('UTF-8', $r->{name}, Encode::FB_DEFAULT);
                } else {
                    $r->{name} = decode('ISO-8859-1', $r->{name});
                }
                $r = undef;# shared with me
            } else {
                $r->{pathfile} = $id2pathfile{$r->{parents}->[0]}.'/'.$r->{name};
            }
        }
    }
    @rfiles = grep{$_} @rfiles;
    {
        my $state = $self->state;
        my @old_rem_pathfiles=();
        @old_rem_pathfiles = map {decode('UTF-8', $_)} sort @{$state->{remote_pathfiles}} if exists $state->{remote_pathfiles};
        my @rem_pathfiles = sort map{$_->{pathfile}} @rfiles;

        #TODO: Find missing since last state. Mark for Removal of local copies.
        for my $orpf (@old_rem_pathfiles) {
            if (! grep {$orpf eq $_} @rem_pathfiles) {
                next if grep {$orpf eq $_} @pathfile_deleted;
                push @pathfile_deleted, $orpf;
            }
        }


        $state->{remote_pathfiles} = \@rem_pathfiles;
        $self->state($state);
    }
} #if 0
    # newly local changes
        my %lc;  # {pathfile, md5Checksum, modifiedTime}

     %lc = map { my @s = stat($_);$_=>{pathfile=>decode('UTF-8',$_),is_folder =>(-d $_), size => $s[7], modifiedTime => Mojo::Date->new->epoch($s[9]) }} grep{defined $_} path( $self->local_root )->list_tree({dont_use_nlink=>1})->each;
    my @lfiles;
     for my $k (keys %lc) {
        if (! $lc{$k}->{is_folder}) {
            $lc{$k}{md5Checksum} = md5_hex(path($k)->slurp);
            push @lfiles, $lc{$k};
        }
     }
    say "remotefiles: ".scalar @rfiles   if $self->debug;
    say "localfiles: ".scalar @lfiles    if $self->debug;
    say "\nExists local but not remote"  if $self->debug;;
    my @pathfile_download=();
    my @pathfile_upload=();
    my @allfiles = @rfiles;
    for my $l(@lfiles) {
        my $hit =0;
        my $lpf = substr($l->{pathfile},length($self->local_root));
        die Dumper $l if ! defined $lpf;
        next if grep {$lpf eq $_} @pathfile_deleted;
        for my $r(@rfiles) {
            next if ! ref $r || ! exists $r->{pathfile};
            if ($lpf eq $r->{pathfile}) {
                $hit =1;
                last;
            }
        }
        if (!$hit) {
            push @pathfile_upload,$lpf;
            say "$lpf: $hit"  if $self->debug;
        }
    }
    if(1) {
        say "\nExists remote but not local"  if $self->debug;
        for my $r(@rfiles) {
            my $hit =0;
            next if ! ref $r ||! exists $r->{pathfile};
            for my $l(@lfiles) {
                my $lpf = substr($l->{pathfile},length($self->local_root));
                next if ! $lpf;
                if ($lpf eq $r->{pathfile}) {
                    $hit =1;
                    last;
                }
            }
            if (!$hit) {
                say "$r->{pathfile}: $hit"  if $self->debug;
                push @pathfile_download,$r->{pathfile};
            }
        }
    }

    # diff resolve
    {
        my %uniqpath;
        my %rfiles_h = map { $_->{pathfile}, $_ } @rfiles;
        my $local_root_length = $self->local_root;
        my %lfiles_h = map { substr($_->{pathfile},length($local_root_length)), $_ } @lfiles;
        $uniqpath{$_}++ for keys %rfiles_h;
        $uniqpath{$_}++ for keys %lfiles_h;

        my @fallfiles;
        for my $k(keys %uniqpath) {
            if ($uniqpath{$k} == 2) {
                if ($lfiles_h{$k}->{md5Checksum} eq $rfiles_h{$k}->{md5Checksum}) {
                    next;
                }
                say 'md5 diff'. $k.' '.$lfiles_h{$k}->{md5Checksum}. ' '.$rfiles_h{$k}->{md5Checksum} if $self->debug;
                next if grep{$k eq $_} @pathfile_download,@pathfile_upload; #remove duplicates
                if ($rfiles_h{$k}->{modifiedTime}->epoch() >= $lfiles_h{$k}->{modifiedTime}->epoch()) {
                    push (@pathfile_download,$k);
                }
                elsif ($rfiles_h{$k}->{modifiedTime}->epoch() >= $from_epoch) {
                    push (@pathfile_download,$k);
                } else {
                    push (@pathfile_upload,$k);
                }

            } else {
                say "Name diff $k" if $self->debug;
                ;
            }
        }
    }
    # resolve conflicts

    say "Download: ".join(', ', @pathfile_download);
    say "Upload: ".  join(', ', @pathfile_upload);
    say "Deleted: ". join(', ', @pathfile_deleted);
    $self->file($_)->download   for (@pathfile_download);
    $self->file($_)->upload   for (@pathfile_upload);
    for my $d(@pathfile_deleted) {
        my $destiny = path($ENV{HOME},'.googledrive','conflict-removed',$d);
        say "delete $d";
        $destiny->dirname->make_path;
        path($self->local_root,$d)->move("$destiny");
    }
    $self->_end_tasks();
}

=head2 clean_remote_duplicates

Look for duplicates on remote. Remove newer duplicates. Compare parents->[0], name, md5Checcksum

Report unwanted, unnatural files.

=cut

sub clean_remote_duplicates($self) {

# get all elements but not google docs
    my @rfiles =grep { $_->{mimeType} !~ /^application\/vnd\.google-apps/}  $self->_get_remote_files(undef);

# put them in an hash with arrays.
    my %files_h = ();
    for my $f (@rfiles) {
        my $id = join('/',($f->{parents}->[0]//'__UNDEF__'),$f->{name},($f->{md5Checksum}//'__UNDEF__'));
        push @{$files_h{$id}}, $f;
    }
# delete newer versions of a file.
    for my $k(keys %files_h) {
        if (scalar @{$files_h{$k}} > 1) {
#            say $k;

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

        }
    }

    # Look for empty files
    for my $f(@rfiles) {
        die encode_json($f)if ! exists $f->{size};
        if ($f->{size} == 0) {
                    say Dumper $f;
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

    my $file = $gd->file_from_metadata({name=>'test.txt',kind=>'drive#file', mimeType =>'application/octet-stream'},pathfile => $pathfile);

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
    say $method.' '.$url.'#'. join('#', map {ref $_ ? encode_json($_):'$_'} @extra) if $self->debug;
    my $tx = $self->ua->$method($url, $main_header,@extra);
    my $code = $tx->res->code;
    if (!$code) {
        say STDERR $url;
        die "Timeout";
    }
    if ($code eq '404') {
        warn "BODY: " . $tx->res->body;
        my @err = @_;
        shift @err;
        die Dumper \@err;
    }
    die Dumper $tx->res if $code > 299;
    my $return;
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
        say "####################################################################" if $self->debug;
        $url->query({pageToken=>$return->{nextPageToken}});
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
    $opts->{q} = q_and($opts->{q}, "modifiedTime > '".Mojo::Date->new->epoch($from_md)->to_datetime."'") if $from_md;
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application/vnd.google-apps.map'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application/vnd.google-apps.folder'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.document'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.presentation'");
    $opts->{q} = q_and($opts->{q}, "mimeType != 'application\/vnd.google-apps.spreadsheet'");
    $opts->{pageSize} = 1000;

    $opts->{fields} = 'nextPageToken,' . join(',', map{"files/$_"} split(',',$INTERESTING_FIELDS) );#INTERESTING_FIELDS;
    my $url = Mojo::URL->new($self->api_file_url)->query($opts);
#    ...;# mangler dateo fra || since q => modifiedTime > '2012-06-04T12:00:00' // default time zone is UTC
    my $remote_files = $self->http_request('get',$url,'');
#    die keys %$remote_files;
    return grep {$_->{mimeType} !~/^application\/vnd.google-apps/} @{ $remote_files->{files} };
}

sub _read_from_epoch($self) {
    # read old from epoch file and store for return on end of sub

    my $old_from_epoch = 0;
    if (-f $self->state_file->to_string && ! -z $self->state_file->to_string) {
        $old_from_epoch = YAML::Syck::LoadFile($self->state_file->to_string)->{last_sync_epoch};
    }
    # read new from epoch file and store for write in _end_tasks
    $new_from_epoch = time() if ! $new_from_epoch;
    return $old_from_epoch;;
}

sub _end_tasks($self) {
    # write new_from_epoch to file 11 - 13
    my $state = $self->state;
    $state->{last_sync_epoch} = $new_from_epoch;
    YAML::Syck::DumpFile($self->state_file->to_string,$state);
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

