package Async::Methods;

our $VERSION = '0.000001'; # 0.0.1

$VERSION = eval $VERSION;

use strict;
use warnings;
use Carp ();
use Hash::Util qw(fieldhash);

fieldhash my %start;
fieldhash my %then;
fieldhash my %else;

package start;

sub start::_ {
  my ($self, $method, @args) = @_;
  my $f = $self->$method(@args);
  $start{$f} = $self;
  return $f;
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = our $AUTOLOAD =~ /^start::(.+)$/;
  $self->start::_($method => @args);
}

package then;

sub then::_ {
  my ($self, $method, @args) = @_;
  my $f_type = ref($self);
  my $f; $f = $self->then(
    sub { my $obj = shift; $obj->$method(@args, @_) },
    sub {
      if (my $else = $else{$f}) {
        $else->(@_)
      } else {
        $f_type->AWAIT_FAIL(@_)
      }
    },
  );
  if (my $start_obj = $start{$self}) {
    $then{$f} = $start{$f} = $start_obj;
  }
  return $f;
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = our $AUTOLOAD =~ /^then::(.+)$/;
  $self->then::_($method => @args);
}

package else;

sub else::_ {
  my ($self, $method, @args) = @_;
  Carp::croak "Can only call else on result of start:: -> then::"
    unless my $start_obj = $then{$self};
  $else{$self} = sub { $start_obj->$method(@args, @_) };
  return $self;
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = our $AUTOLOAD =~ /^else::(.+)$/;
  $self->else::_($method => @args);
}

package catch;

sub catch::_ {
  my ($self, $method, @args) = @_;
  Carp::croak "Can only call catch on start:: or start:: -> then:: object"
    unless my $start_obj = $start{$self};
  $self->catch(sub { $start_obj->$method(@args, @_) });
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = our $AUTOLOAD =~ /^catch::(.+)$/;
  $self->catch::_($method => @args);
}

package await;

sub this {
  my ($self) = @_;
  if ($self->isa('Mojo::Promise') and !$self->can('get')) {
    require Mojo::Promise::Role::Get;
    $self = $self->with_roles('+Get');
  }
  return $self->get;
}

sub await::_ {
  my ($self, $method, @args) = @_;
  my $f = $self->then::_($method, @args);
  $f->await::this;
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = our $AUTOLOAD =~ /^await::(.+)$/;
  $self->await::_($method => @args);
}

1;

=head1 NAME

Async::Methods - Helpers for async method work

=head1 SYNOPSIS

Sorry, this is not documented yet and is just a demonstration of the
relevant ideas. Please don't try and use it yet.

=head1 DESCRIPTION

=head1 AUTHOR

 mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

None yet - maybe this software is perfect! (ahahahahahahahahaha)

=head1 COPYRIGHT

Copyright (c) 2020 the Async::Methods L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.
