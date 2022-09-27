package Test::oauth;
use Mojo::Base -base, -signatures;

=head1 NAME

Test::oauth - dummy for

=head1 SYNOPSIS

    use Test::oauth;

=head1 DESCRIPTION

Dropin test object so not google is contacted every time tests is runned.

=head1 METHODS

=head2 authorization_headers

Dummy

=cut

sub authorization_headers($self) {
    return ();
}
1;

=head1 AUTHOR

slegga

=cut