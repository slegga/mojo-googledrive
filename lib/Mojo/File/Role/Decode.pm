package Mojo::File::Role::Decode;
use Mojo::Base -role;
use Encode 'decode';
use open ':std','utf8';

requires 'to_string';

=head1 NAME

Mojo::File::Role::Decode

=head1 DESCRIPTION

Role which give to_plaintext where a decode('UTF-8', $self->to_string is done.

=head1 SYNOPSIS

    use Mojo::File;
    use Mojo::File::Role::Decode;
    my $filename = Mojo::File->new('file.txt')->with_roles('+Decode')->to_plaintext;

=head1 ENVIRONMENT

=over 4

=item LC_ALL - Use this variable to extract what encoding the filesystem has.

=back

=head1 METHODS

=head2 to_plaintext

Same as to_string but decode the filename from filesystem.

=cut

sub to_plaintext {
  my $self = shift;
  my $encoding;
  if( $ENV{LC_ALL}) {
    $encoding= $ENV{LC_ALL};
    $encoding =~ s/^.*\.//;
  }
  $encoding = 'UTF-8' if ! $encoding;
  return decode($encoding, $self->to_string);#, Encode::FB_CROAK);
}

1;