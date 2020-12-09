package Test::UserAgent;
use Mojo::Base -base, -signatures;
use Data::Dumper;
use Test::UserAgent::Transaction;
use Mojo::JSON qw /to_json true false/;
use Mojo::File qw/path/;
use Mojo::Date;
use File::MMagic;
use Digest::MD5::File qw(file_md5_base64);



=head1 NAME

Test::UserAgent - Dropping mocked useragent for dropping for Mojo::UserAgent

=head1 SYNOPSIS

    my $ua = Test::UserAgent->new( config_file => 't/data/some-api.yml' );

=head1 DESCRIPTION

For unittest without accessing external apis.


=head1 ATTRIBUTES

=cut

has 'real_remote_root';
has 'config_file';
has 'method';
has 'url';
has 'header';
has 'payload';
has  'metadata';
has 'magic';


=head1 METHODS

=head2 get

=cut

sub get($self,$url,@) {
    my %params=(method=>'GET', config_file=>$self->config_file, url=>$url);
    if  (ref $url) {
        $url =$url->to_string;
    }
    shift @_;# remove self
    shift @_;# remove url
    if (@_) {
        for my $i(0 .. $#_) {
            my $v= $_[$i];
            if (ref $v eq 'HASH') {
                if ($v->{Authorization}) {
                    $v->{Authorization} = 'Bearer: X';
                }
                $params{header} = to_json($v);
            } elsif (!$v) {
                #
            } else {
                die "Unkown $i  $v  ".ref $v;
            }
        }
    }
    $self->$_($params{$_}) for keys %params;
    return Test::UserAgent::Transaction->new( ua => $self );
}

=head2 post

=cut

sub post($self,$url,@) {
    my %params=(method=>'post', config_file=>$self->config_file, url=>$url);
    if  (ref $url) {
        $url =$url->to_string;
    }
    shift @_;# remove self
    shift @_;# remove url
    my $param;
    if (@_) {
        for my $i(0 .. $#_) {
            my $v= $_[$i];
            if (ref $v eq 'HASH' && $i == 0) {
                if ($v->{Authorization}) {
                    $v->{Authorization} = 'Bearer: X';
                }
                $params{header} = $v;
            } elsif (!$v) {
                ...;
            } elsif ($v eq 'multipart') {
              $param=$v;
            } elsif (ref $v eq 'ARRAY') {
                if ($param eq 'multipart') {
                    $self->metadata($v->[0]);
                    $self->payload($v->[1]);
                    die if exists $v->[2];
                } else {
                    warn "$param  ".Dumper $v;
                    ...;
                }
            } elsif ($v eq 'json') {
                $param=$v;
            } elsif (ref $v eq 'HASH') {
                if ($param eq 'json') {
                    $self->metadata($v);
                }
                else {
                    warn "$param   ".Dumper $v;
                    ...;
                }
            }
            else {
                die "Unknown $i  $v  ".ref $v;
            }

        }
    }
    $self->$_($params{$_}) for keys %params;

    return Test::UserAgent::Transaction->new( ua => $self );
}

=head2 get_rmojofile_from_id

    my $remote_root_file = $self->ua->get_rmojofile_from_id('root');

Return Mojo::File object for remote file based on id.

=cut

sub get_rmojofile_from_id($self, $id) {
    my $return;
    if (! defined $id) {
        return;
    }
    if($id eq 'root' || $id eq '' || $id eq '/') {
        return Mojo::File->new($self->real_remote_root);
    }
    else {
        return Mojo::File->new($self->real_remote_root)->child($id);
    }
    #$return->{id} = ...;#$self->rfile->to_string;
    #$meta->parents=[ path($self->rfile)->dirname->to_string ];
    ...;
}

=head2 get_metadata_from_file

Return metadata based on Mojo::File object

=cut

sub get_metadata_from_file($self,$file) {
    my $return;
    my $pathfile = substr($file->to_string,length($self->real_remote_root));
#id%2Ckind%2Cname%2CmimeType%2Cparents%2CmodifiedTime%2Ctrashed%2CexplicitlyTrashed%2Cmd5Checksum$_
    $return->{id} = $pathfile;
    $return->{kind} = 'drive#file';
    $return->{name} = $file->basename;
    $return->{parents} = [path($pathfile)->dirname->to_string];
    $return->{trashed} = false;
    $return->{explicitlyTrashed} = false;
    if (-d "$file") {
        $return->{mimeType} = 'application/vnd.google-apps.folder';
    } else {
        # There don't seem to be great implementations of mimetype
        # detection on CPAN, so just use this one for now.

        if ( !$self->{magic} ) {
            $self->{magic} = File::MMagic->new();
        }

        $return->{mimeType} = $self->{magic}->checktype_filename("$file");
    }

    my $mdate = Mojo::Date->new->epoch($file->stat->mtime);
    $return->{modifiedTime} = "$mdate";
    $return->{md5Checksum} = file_md5_base64("$file") if $return->{mimeType} ne 'application/vnd.google-apps.folder';
    return $return;
}
=head2 AUTOLOAD

=cut

1;
