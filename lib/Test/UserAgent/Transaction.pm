package Test::UserAgent::Transaction;
use Mojo::Base -base, -signatures;
use Test::UserAgent::Transaction::Response;
=head1 NAME

Test::UserAgent::Transaction - Test object;

=head1 SYNOPSIS

    my $tx = $ua->res->body;

=head1 DESCRIPTION

Simulate Transaction object.

=head1 ATRIBUTES

=cut

has 'ua';

=head1 METHODS


=head2 res

    $tx->res

Return response object.

=cut

sub res($self) {
    shift @_;
    return Test::UserAgent::Transaction::Response->new(ua => $self->ua);
}

=head2 req

    $tx->req

Return request body.

=cut

sub req($self) {
    ...;
}
1;