package Test::UserAgent::Transaction::Response;

use Mojo::Base -base, -strict, -signatures;
use Carp::Always;
use Data::Dumper;
use Mojo::JSON qw/encode_json to_json from_json true false/;
use Mojo::Util qw /url_unescape/;
use Mojo::File 'path';
use Encode qw /decode_utf8/;

has 'ua';    # Test::UserAgent ?
has 'req_res';

=head1 NAME

Test::UserAgent::Transaction::Respone::GoogleDrive

=head1 SYNOPSIS

    my $ua = Test::UserAgent->new(response=>Test::UserAgent::Transaction::Respone::GoogleDrive->new);
    my $gd = Mojo::GoogleDrive::Mirror->new(ua=>$ua);

=head1 DESCRIPTION

A response mocked object for Mojo::Message::Response object.

=head1 METHODS

=head2 body

    $string = $tx->res->body:

Return response body.

=cut

sub body ($self) {
    my $key = '';
    for my $method (qw/method url header payload/) {
        my $k = $self->ua->$method;
        next if !$k;
        if (!ref $k) {
            $key .= "$k¤";
        }
        elsif (ref $k eq 'HASH') {
            $key .= to_json($k) . '¤';
        }
        elsif ($k->can('to_string')) {
            $key .= $k->to_string . '¤';
        }
        else {
            die "Unknown object: " . ref $k;
        }
    }

#https://www.googleapis.com/drive/v3/files/root?fields=id%2Ckind%2Cname%2CmimeType%2Cparents%2CmodifiedTime%2Ctrashed%2CexplicitlyTrashed
# POPULER REQ_RES basert på config file.
# GJØR LOOKUP OR RETUR.

#    my $ua = $self->ua;
#    warn "No valid return found. ua: ".  ref $ua;
    my $hash_ret = {};
    my $mojourl  = Mojo::URL->new($self->ua->url);
    if (lc($self->ua->method) eq 'get') {
        if ($mojourl->host eq 'www.googleapis.com') {
            if ($mojourl->path =~ '\/drive\/v3\/files\/(\w+)') {
                if (   exists $mojourl->query->to_hash->{fields}
                    && !exists $mojourl->query->to_hash->{q}
                    && !exists $mojourl->query->to_hash->{alt}) {

                    # id%2Ckind%2Cname%2CmimeType%2Cparents%2CmodifiedTime%2Ctrashed%2CexplicitlyTrashed
                    my ($file_id, $fields) = ($1, $mojourl->query->to_hash->{fields});
                    if ($file_id eq 'root') {
                        my $root = {
                            id                => '/',
                            kind              => "drive#file",
                            name              => 'Min disk',
                            mimeType          => 'application/vnd.google-apps.folder',
                            trashed           => 0,
                            explicitlyTrashed => 0,
                            modifiedTime      => '2013-10-19T11:06:57.289Z'
                        };
                        return encode_json($root);

#https://www.googleapis.com/drive/v3/files/?q=mimeType+%3D+%27application%2Fvnd.google-apps.folder%27+and+%27t%2Fremote%2F%27+in+parents+and+name+%3D+%27t%27
                    }
                    else {
                        die "No data for GET: $file_id:   $key";
                    }
                }
                else {
                    ...;
                }
            }
            elsif ($mojourl->path eq '/drive/v3/files/') {
                if ($mojourl->query->to_hash->{q}) {
                    my $attr = url_unescape($mojourl->query->to_hash->{q});
                    my @a    = split / and /, $attr;
                    my %crit;
                    for my $x (@a) {

#warn $x;
                        if (my ($key, $type, $value) = $x =~ /^'?(.*?)'? (=|in|!=) '?(.*?)'?$/) {
                            if ($type eq 'in') {
                                $type       = $key;
                                $key        = $value;
                                $value      = $type;
                                $crit{$key} = $value;
                            }
                            elsif ($type eq '=') {
                                $crit{$key . "_not"} = url_unescape($value);
                            }
                            elsif ($type eq '!=') {
                                $crit{$key} = url_unescape($value);
                            }
                            else {
                                say STDERR "Unhandeled $type";
                                ...;
                            }
                        }
                        else {
                            say STDERR "Unknown criteria: $x";

                            ...;
                        }
                    }

                    #            die Dumper \%crit;
                    my $allfiles = path($self->ua->real_remote_root)->list_tree({dir => 1});
                    if ($crit{mimeType} && $crit{mimeType} eq 'application/vnd.google-apps.folder') {
                        $allfiles = $allfiles->grep(sub { -d "$_" });
                    }
                    if ($crit{parents}) {
                        my $re = quotemeta($crit{parents});
                        if ($crit{parents} eq '/' || $crit{parents} eq 'root') {
                            $re = quotemeta(path($self->ua->real_remote_root)->to_string) . '.';
                        }
                        $allfiles = $allfiles->grep(sub { "$_" =~ /$re/ });
                    }
                    if ($crit{name}) {

#warn join(',',$allfiles->each);
                        $allfiles = $allfiles->grep(sub { decode_utf8($_->basename) eq $crit{name} });

#warn join(',',$allfiles->each);
                    }
                    my $root = $self->ua->real_remote_root;
                    if ($root =~ /\/$/) {
                        chop($root);
                    }
                    my $root_length = length($root);
                    return to_json(
                        {files => $allfiles->map(sub { $self->_metadata(substr("$_", $root_length)) })->to_array});
                }
                else {
                    ...;
                }
            }
            elsif ($self->ua->url =~ m|https:\/\/www.googleapis.com\/drive\/v3\/files\/(.+)\?|) {
                my $id = $1 or die "No id: " . $self->ua->url;
                $id = decode_utf8(url_unescape($id));
                die "Missing local_root" if !$self->ua->local_root;
                my $file = $self->ua->real_remote_root . $id;
                if ($self->ua->url =~ /alt=media/) {    # TODO check for alt=media

                    return path($file)->slurp;
                }
                else {
                    return to_json($self->_metadata($file));
                }
            }
            else {
                die $mojourl->host . " No value for key: " . $key;
            }
        }
        else {
#https://www.googleapis.com/drive/v3/files/?fields=files%2Fid%2Cfiles%2Fkind%2Cfiles%2Fname%2Cfiles%2FmimeType%2Cfiles%2Fparents%2Cfiles%2FmodifiedTime%2Cfiles%2Ftrashed%2Cfiles%2FexplicitlyTrashed%2Cfiles%2Fmd5Checksum&q=%27%2F%27+in+parents+and+name+%3D+%27file.txt%27+and+trashed+%3D+false¤
            die "No value for key: " . $key;
        }
    }
    elsif ($self->ua->method eq 'post') {

        # https://www.googleapis.com/upload/drive/v3/files/?uploadType=multipartmultipart#ARRAY(0x5576579c3f78)
        if ($self->ua->url =~ m|https:\/\/www.googleapis.com\/upload\/drive\/v3\/files\/\?uploadType=multipart|) {

            #https://www.googleapis.com/upload/drive/v3/files/?uploadType=multipart
            #fields\=(.+)|) {
            my $fileid = $self->ua->metadata->{id};
            my $hash;
            if (!$fileid) {
                my $x    = $self->ua->metadata;
                my $json = $x->{content};
                $hash = from_json($json);

#                die Dumper $hash;
            }
            else {
                ...;
            }
            if (!$hash->{id}) {
                $hash->{id} = $hash->{parents}->[0] . '/' . $hash->{name};
            }

            #make missing path
            path($self->ua->real_remote_root)->child($hash->{parents}->[0])->make_path();

            path($self->ua->real_remote_root)->child($hash->{id})->spew($self->ua->payload->{content});
            my $metadata = $self->ua->metadata;

            # recontruct metadata if missing
            if (exists $metadata->{content}) {
                $metadata = $self->ua->get_metadata_from_file(path($self->ua->real_remote_root)->child($hash->{id}));

                #               for my $k ( keys %$meta ) {
#                    $metadata->{$k} = $meta->{$k};
#                }
#                delete $metadata->{content};
#                die Dumper $meta;

            }
            return encode_json($metadata);
        }
        if ($self->ua->url
            =~ m|https:\/\/www\.googleapis\.com\/drive\/v3\/files\/\?fields\=id\%2Ckind\%2Cname\%2CmimeType\%2Cparents\%2CmodifiedTime\%2Ctrashed\%2CexplicitlyTrashed\%2Cmd5Checksum|
        ) {
            my $header   = $self->ua->header;
            my $metadata = $self->ua->metadata;
            my $payload  = $self->ua->payload;
            if (!$metadata) {
                warn Dumper $header, $payload;
                die "Missing metadata";
            }
            my $parent = $metadata->{parents}->[0] // 'root';
            die "Missing name" . Dumper $metadata if !exists $metadata->{name} || !$metadata->{name};
            my $f = $self->ua->get_rmojofile_from_id($parent)->child($metadata->{name})->make_path;

            #my $allfiles = path($self->ua->real_remote_root)->list_tree({dir=>1});

            my $meta = $self->ua->get_metadata_from_file($f);
            return encode_json($meta);
        }
        say STDERR "UNKNOWN URL: " . $self->ua->method . ' ' . $self->ua->url;
        ...;
    }
    elsif ($self->ua->method eq 'patch') {

#https://www.googleapis.com/upload/drive/v3/files/file%C3%A6%C3%B8%C3%A5.txt?uploadType=multipart&fields=id%2Ckind%2Cname%2CmimeType%2Cparents%2CmodifiedTime%2Ctrashed%2CexplicitlyTrashed%2Cmd5Checksum
        if ($self->ua->url =~ m|https:\/\/www\.googleapis\.com\/upload\/drive\/v3\/files\/(.*)\?|) {
            my $hash;
            $hash->{id} = '/' . url_unescape($1);
            if (!$hash->{id}) {
                die;
            }
            path($self->ua->real_remote_root)->child($hash->{id})->spew($self->ua->payload);
            return encode_json($self->ua->metadata);
        }
        else {
            say STDERR "UNKNOWN URL: " . $self->ua->method . ' ' . $self->ua->url;
            ...;
        }
    }
    else {
        die "Unkown method " . $self->ua->method;

    }
}

sub _metadata ($self, $pathfile) {
    my $p      = path($pathfile);
    my $f      = path($self->ua->real_remote_root, $pathfile);
    my $return = $self->ua->get_metadata_from_file($f);

#    my $return={id=>"$pathfile"||'/',name => $p->basename||'/', parents=>[path($pathfile)->dirname->to_string||'/'],trashed=>false,explicitlyTrashed=>false, modifiedTime =>'2013-10-19T11:06:57.289Z'};
    #   if(-d "$f") {
    #       $return->{mimeType} = 'application/vnd.google-apps.folder';
    #   }
    return $return;
}

=head2 code

    $httpcode = $tx->res->code:

Return response code.

=cut


sub code ($self) {

#    for my $key(qw/config_file method url header payload/) {
#        print $key .":  ".($self->ua->$key//'__UMDEF__') . "  " if defined $self->ua->can($key);
#    }
    return 200;
}


1;
