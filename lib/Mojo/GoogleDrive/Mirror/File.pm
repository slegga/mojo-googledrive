package Mojo::GoogleDrive::Mirror::File;
use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::File; #->with_roles(
use Mojo::File::Role::Decode;
use Mojo::URL;
use File::MMagic;
use Mojo::JSON qw /true false to_json from_json/;
use Data::Dumper;
use Mojo::Collection;
use Mojo::GoogleDrive::Mirror;
use open qw(:std :utf8);
use utf8;
use Digest::MD5 'md5_hex';
use Const::Fast;
use Encode 'encode';
use Carp qw/carp confess/;

#use Mojo::Util 'url_escape';
=head1 NAME

Mojo::GoogleDrive::Mirror::File - Google Drive file object

=head1 SYNOPSIS

    use Mojo::GoogleDrive::Mirror;
    use Mojo::GoogleDrive::Mirror::File;
    my $mgm= Mojo::GoogleDrive::Mirror->new(local_root=>$ENV{HOME}.'/googledrive');
    my $file = $mgm->file('/test/testfile.txt');
    $file->download;

=head1 DESCRIPTION

A help file for Mojo::GoogleDrive::Mirror, usually this object is not ment to be used by others.
Responsible to implement common logic for each file.

=head1 ATTRIBUTES

=over 4

=item pathfile - String containing relative path on GoogleDrive

=item metadata - Hash containing meta data from googledrive

=back

=head1 METHODS

=cut


has 'pathfile';
has 'remote_root' => '/';
has 'local_root';# => "$ENV{HOME}/googledrive/";
has 'last_message';
#has 'api_file_url' => "https://www.googleapis.com/drive/v3/files/";
#has 'api_upload_url' => "https://www.googleapis.com/upload/drive/v3/files/";
#has 'oauth';     #     => OAuth::Cmdline::GoogleDrive->new();
#has 'sync_direction';# => 'both-cloud'; # both ways clound wins if in conflict
has 'metadata' => sub{{}};
#has ua => sub { Mojo::UserAgent->new};
has mgm => sub { Mojo::GoogleDrive::Mirror->new()};
has 'debug';
=head2 INTERESTING_FIELDS

Constant set to minimum meta data for a file.

=cut

const my $INTERESTING_FIELDS => 'id,kind,name,mimeType,parents,modifiedTime,trashed,explicitlyTrashed,md5Checksum';

sub path {
    return Mojo::File->with_roles('+Decode')->new(@_);
}

=head2 lfile

    $file->lfile

Full local path to file mirrored from google drive.

=cut

sub lfile($self) {
    die "Missing local_root" if ! $self->local_root;
    return path($self->local_root)->child($self->pathfile);
}

=head2 rfile

    $fullpath = $file->rfile

Full remote file path.

=cut

sub rfile($self) {
    $self->remote_root('/') if ! $self->remote_root;
    return path($self->remote_root)->child($self->pathfile);
}

=head2 need_sync

Return empty if file is in sync, else return 1 if sync is needed.

Check if file exists both remote and local. Then get md5chechsum_hex if missing and compare.

=cut

sub need_sync($self) {
    say $self->rfile if $self->debug;
    if($self->get_metadata->{id} and -f $self->lfile) {
        if($self->get_metadata->{md5Checksum} eq md5_hex(path($self->lfile)->slurp) ) {
            return 0;
        } else {
            return 1;
        }
    } else {
        return 1
    }

    ...;
}

=head2 get_metadata

    $metadata = $file->get_metadata();

Look up cashed data, if not as google drive for an update.

=cut

sub get_metadata($self,$full = 0) {
    my $metadata;
    $metadata = $self->metadata if ( ref $self->metadata);
    if (! ref $metadata || ! keys %$metadata || ! $metadata->{kind}) {
        $metadata = $self->mgm->metadata_all->{$self->rfile->to_plaintext};
    }
    my @pathobj;
    if (! ref $metadata || ! keys %$metadata) {

        @pathobj = $self->path_resolve($full)->map(sub{$_->metadata})->each;
        $metadata = $pathobj[$#pathobj] if @pathobj;# kunne vært get_metadata
    }
    if ((! $metadata || ! keys %$metadata) && -f path($self->lfile)->to_string) {
        # populate name from local_file
        # try to lookup remote parents
        # fill kind,mimeType,parents,trashed,modifiedTime,explicitlyTrashed
        $metadata={
            kind=>'drive#file',
#            trashed=>false,
#            explicitlyTrashed=>false,
        };
        $metadata->{mimeType}=$self->file_mime_type if -e $self->pathfile;
        $metadata->{name} = path($self->rfile)->basename;
        #$metadata->{name} = decode('UTF-8',path($self->rfile)->basename);
        if (exists $pathobj[$#pathobj -1]) {
            $metadata->{parents} = [$pathobj[$#pathobj -1]->{id}];
        }
        $metadata->{modifiedTime} = (stat( $self->{pathfile}))[9]; #convert to google timeformat
        say scalar @pathobj." $#pathobj"  if $self->debug;
        say $self->rfile  if $self->debug;
        say Dumper $metadata  if $self->debug;
    }
    return $metadata;
}

=head2 upload

    my $meta = $file->upload;

Uploads the file to google drive.

=cut

sub upload {
    #POST https://www.googleapis.com/upload/drive/v3/files
    # https://mojolicious.io/blog/2017/12/11/day-11-useragent-content-generators/
    my $self = shift;
    my $main_header = {$self->{oauth}->authorization_headers()};
    my $local_file_content = $self->lfile->slurp;
    my $byte_size;
    {
            use bytes;
            $byte_size = length($local_file_content);
    }
    my $metadata = $self->get_metadata;
    my $mcontent={name=>encode('UTF-8',$metadata->{name})};

    my $http_method = 'post';
    if (exists $metadata->{id} && $metadata->{id}) {
        say Dumper $metadata if $self->debug;
        my $fileid = $metadata->{id} ;      # this line because of tests :-(
        $fileid =~ s/^\///;                 # this line because of tests :-(
        $mcontent->{id} = $metadata->{id} ;
        $http_method = 'patch';
        my $urlstring = Mojo::URL->new($self->mgm->api_upload_url)->path($fileid)->query(uploadType=>'multipart',fields=> $INTERESTING_FIELDS)->to_string;
        say $urlstring if $self->debug;
        my $meta = $self->mgm->http_request($http_method, $urlstring, $main_header,$local_file_content);

        if ($meta) {
            say Dumper $meta  if $self->debug;
        }
        return $self;
    }
    $main_header ->{'Content-Type'} = 'multipart/related';
    $mcontent->{parents} = $metadata->{parents} if exists $metadata->{parents} && $metadata->{parents};

    # create missing folders if not exists
    if (exists $mcontent->{parents}->[0] && ! defined $mcontent->{parents}->[0]) {
        my $path_string = path($self->pathfile)->dirname->to_string;
        my $rpath = $self->{mgm}->file($path_string);
        $rpath->make_path;
        $mcontent->{parents}->[0] = $rpath->metadata->{id};
        my $x = $rpath->metadata;
        if (! $x->{id}) {
            say STDERR Dumper $x ;
            die '$x->{id} is missing';
        }
    } elsif (exists $mcontent->{parents}->[0]) {
        # root
#        ...;
    } else {
        die "Should never come here";
    }

    my $metapart = {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length'=>$byte_size, content => to_json($mcontent),};

    my $urlstring = Mojo::URL->new($self->mgm->api_upload_url)->query(uploadType=>'multipart',fields=> $INTERESTING_FIELDS)->to_string;
    say $urlstring if $self->debug;
    my $meta = $self->mgm->http_request($http_method, $urlstring, $main_header ,   multipart => [
    $metapart,
    {
      'Content-Type' => $self->file_mime_type,
      content => $local_file_content,
    }
  ] );
    my $md = $self->metadata;
    $md->{$_} = $meta->{$_} for (keys %$meta);
    $self->metadata($md);
    my $ma = $self->mgm->metadata_all;
    $ma->{$self->rfile->to_string} = $md;
    $self->mgm->metadata_all($ma);
    return $self;
}

=head2 file_mime_type

    my $mime_type = $file->file_mime_type;

Return mime type for the local file.

=cut

sub file_mime_type($self) {
   # my ( $self ) = @_;

    # There don't seem to be great implementations of mimetype
    # detection on CPAN, so just use this one for now.

    if ( !$self->{magic} ) {
        $self->{magic} = File::MMagic->new();
    }
    my $file = $self->lfile;
    my $filetype = $self->{magic}->checktype_filename("$file");
    die "$filetype  $file" if $filetype =~/x-sys/;
    return $filetype;
}

=head2 path_resolve

    $collectonoffiles = $file->path_resolve;

Get File objects for each element in path include. First element is root and last is the actual file.


=cut

sub path_resolve($self,$full=0) {
    my @parts = grep { $_ ne '' } @{ $self->rfile->to_array };

    my @return;

    # get root
    my $parent_id='root';
    my $id;
    my $root_meta;
    if(exists $self->mgm->metadata_all->{'/'}) {
        $root_meta = $self->mgm->metadata_all->{'/'};
    }
    if (!$root_meta->{id}) {
        my $fields = ($full ? '*' : $INTERESTING_FIELDS);
        my $url = Mojo::URL->new($self->mgm->api_file_url)->path($parent_id)->query(fields=> $fields );
        say $url  if $self->debug;
        $root_meta = $self->mgm->http_request('get',$url,'');
        my $ma=$self->mgm->metadata_all;
        $ma->{'/'} = $root_meta;
        $self->mgm->metadata_all($ma);
    }
    die "Can not find root" if !$root_meta;
    push @return, $root_meta;
    $parent_id = $root_meta->{id};
    my $tmppath=path('/');
    my $old_part='/';
    my $i = -1;
  PART: for my $part (@parts) {
        $i++;
        my $dir;
        next if ! $part;
        if (exists $self->mgm->metadata_all->{$tmppath->to_plaintext}) {
            $dir = $self->mgm->file_from_metadata($self->mgm->metadata_all->{$tmppath->to_plaintext});
        }

        if (! $dir) {
            $dir = $self->{mgm}->file_from_metadata({id => $parent_id, name => $old_part},pathfile => $tmppath->to_string);
        }
        $tmppath = $tmppath->child($part);
        my %param=(name=>$part);
        if ($i<$#parts) {
            $param{dir_only}=1;
        }
        $param{full}=$full;
        my @children = $dir->list(%param)->each;

        $old_part=$part;
        if (! @children) {
            push @return,undef;
            # return Mojo::Collection->new(@return) ;
        } else {
#        die Dumper $children;# if ! ref $children eq 'ARRAY';
die if !$part;
            for my $child (@children) {
                say Dumper $child->metadata if ! $child->metadata->{name} && $self->debug;
                say "Found child ", $child->metadata->{name} if $ENV{MOJO_DEBUG};
                if ( $child->metadata->{name} eq $part ) {
                    $parent_id = $child->metadata->{id};
                    push @return,$child->metadata;
                    next PART;
                }
            }
        }

    }
    #die Dumper \@return;
    my @return2;
    my $pathfile='';
    for my $r (@return) {
#        next if ! keys %$r;
        if ( exists $r->{name}) {
            $pathfile .= $r->{name};
        } else {
            $pathfile=undef;
        }
        push  @return2, $self->{mgm}->file_from_metadata( $r, pathfile=>$pathfile );
        $pathfile .= '/';
    }
    return Mojo::Collection->new(@return2);
}

=head2 list

    print $_->metadata->{name} for $file->list;

Return Mojo::Collection of files if object is a directory. Else return empty.

=cut

sub list($self, %options) {
    my $folder_id;
    my @return;
    my $meta = $self->get_metadata;
    $folder_id = $meta->{id} if exists $meta->{id};
    if (! $folder_id && $self->rfile->to_string) {
        $folder_id = $self->mgm->metadata_all->{$self->rfile->to_string}->{parents}->[0] if exists $self->mgm->metadata_all->{$self->rfile->to_plaintext};
    }
    if ($self->pathfile && ! $folder_id) {
        say STDERR "Did not found:  ".$self->rfile->to_plaintext;
        ...;
        return;
    }
    my    $opts= \%options;
    $opts->{q} = '' ;
    if ($options{dir_only}) {
        $opts->{q} = q_and($opts->{q},"mimeType = 'application/vnd.google-apps.folder'");
    }

    $opts->{q} = q_and($opts->{q},"'$folder_id' in parents");

    if ($options{name}) {
        $opts->{q} = q_and($opts->{q},"name = '$options{name}'");
    }

    $opts->{q} = q_and($opts->{q},"trashed = false");
    my $fields = $INTERESTING_FIELDS;
    if($options{full}) {
       $fields = '*';
    }
    delete $options{full};

  #  $opts->{fields} = join(',', map{"files/$_"} split(',',$fields) );
    $opts->{fields} = "nextPageToken,files($fields)";#INTERESTING_FIELDS;
    my @children = ();
    delete $opts->{dir_only};
    delete $opts->{name};

    my $url = Mojo::URL->new($self->mgm->api_file_url)->query($opts);

    my $data = $self->mgm->http_request('get',$url,'');

    my @objects =  map {$self->{mgm}->file_from_metadata($_)} @{ $data->{files} };
    if ($data->{nextPageToken}) {
        die Dumper $data;
    }
    return Mojo::Collection->new(@objects);
}

=head2 make_path

    $file->make_path

Make remote path if not exists.

=cut

sub make_path($self) {
    # pathfile to array
    my @pathparts = @{ path($self->rfile)->to_array}; #new path
    # path_resolve
    my @pathobjs = $self->path_resolve->each; #old path from remote
#    shift @pathparts;
    if (@pathparts != @pathobjs) {
        say STDERR "Uneven parts:". $#pathparts.'  '.$#pathobjs;
        say STDERR  '->rfile:  '.join(',',map{$_//'__UNDEF__'}  @pathparts);
        say STDERR  "->path_resolve: ".join(',',map{$_//'__UNDEF__'}  map{$_->pathfile()} @pathobjs );
    }
    my $main_header = {$self->{oauth}->authorization_headers()};
    my $parent='root';
    for my $i(0 .. $#pathparts) {
        if (exists  $pathobjs[$i]->{id} && $pathobjs[$i]->{id}) {
            $parent = $pathobjs[$i]->{id};
            next ;
        }
        next if ! $pathparts[$i];
#        die Dumper $pathobjs[$i], \@pathparts,$i if ! $pathobjs[$i];
        my$mcontent = { name => $pathparts[$i],mimeType=> 'application/vnd.google-apps.folder',parents=>[$parent] };
        # make dir
    say STDERR "Make dir: ". Dumper $mcontent;;
        my $metapart = {'Content-Type' => 'application/json; charset=UTF-8', content => to_json($mcontent),};
        my $urlstring = Mojo::URL->new($self->mgm->api_file_url)->query(fields=> $INTERESTING_FIELDS)->to_string;
        say $urlstring  if $self->debug;
    die "Temporary problem with duplicates. Check for duplicates, and if not exists create at drive.google.com this folder: ".join('/',@pathparts);
        my $meta = $self->mgm->http_request('post',$urlstring, $main_header ,
        json=>$mcontent);
        $pathobjs[$i] =$self->mgm->file_from_metadata($meta);
        {
            my $ma = $self->mgm->metadata_all;
            $ma->{$self->rfile->to_plaintext} = $meta;
            $self->mgm->metadata_all($ma);
        }
        $parent = $meta->{id};
        $self->metadata($meta); # the last item will have the meta data
    }
    return $self;
}

=head2 download

    my $mgm = Mojo::GoogleDrive::Mirror->new(local_root=>$ENV{HOME});
    my $f = $mgm->file('/remotefile.txt');
    $f->download;

=cut

sub download($self) {
    my $meta =  $self->get_metadata;
    if (exists $meta->{id}) {
        my $id = $meta->{id};
        my $urlstring = Mojo::URL->new($self->mgm->api_file_url.$id)->query(alt => 'media')->to_string;
        my $content = $self->mgm->http_request('get',$urlstring);  #      GET https://www.googleapis.com/drive/v3/files/fileId
        if ( $content ) {
            $self->lfile->dirname->make_path;
            $self->lfile->spurt( $content );
            return $self;
        }
    } elsif ($self->{pathfile}) {
        ...;
    } else {
        ...;
    }
    return ;
}


=head2 remove

Delete file locally and remote;

=cut

sub remove($self) {
    my $message='';
    die "Missing patfile" if !$self->pathfile;
    $self->last_message('');
    if ( -f $self->lfile->to_string ) {
        $self->lfile->remove;
        $message .= 'Removed local file: '.$self->lfile->to_string;
    }
    my $meta = $self->get_metadata;
    if (! $meta->{id}) {
        $meta = $self->path_resolve->last->get_metadata;
    }
    if ($meta->{id}) {
        my $res = $self->mgm->http_request('delete',$self->mgm->api_file_url . $meta->{id});
        die $res if $res; #empty if success
        $message .= 'Removed remote file: '.$self->rfile->to_string;
        my $delete_file = $self->mgm->file($self->delete_archive)->lfile;
        my $delete_content = $delete_file->slurp;
        $self->mgm->file($self->delete_archive)->lfile->to_string.';'. $self->pathfile;
    } else {
        $message .= 'Remote file not found '. $self->rfile->to_string;
    }
    return $self->last_message($message);
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
