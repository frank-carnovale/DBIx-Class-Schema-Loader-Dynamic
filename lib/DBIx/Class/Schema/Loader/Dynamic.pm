package DBIx::Class::Schema::Loader::Dynamic;

use strict;
use warnings;

use base qw/DBIx::Class::Schema::Loader::DBI/;
use mro 'c3';
use Data::Dumper;

our $VERSION = '1.01';

sub new {
    my ($self, %args) = @_;
    my $class = ref $self || $self;

    $args{dump_directory} //= '/die/if/I/get/used';

    my $new = $self->next::method(%args);

    # The loader 'factory' returns a more engine-specific subclass, e.g. DBIC.SL::DBI::Pg.  So,
    # I'll have what she's having..
    {
        my $isa = $class . "::ISA";
        no strict 'refs'; @$isa = (ref $new);
    }

    eval("require $_") || die for @{$new->left_base_classes};
    bless $new, $class;
}

sub _dbic_stmt {
    my ($self, $class, $method, @args) = @_;
    printf STDERR "DBIC_STMT %s ( %s )\n", "$class->$method(@args);", Dumper(\@args) if $self->debug;
    $class->$method(@args);
}

sub _load_tables {
    my ($self, @tables) = @_;

    # Save the new tables to the tables list and compute monikers
    foreach (@tables) {
        $self->_tables->{$_->sql_name}  = $_;
        $self->monikers->{$_->sql_name} = $self->_table2moniker($_);
    }

    # "check for moniker clashes": NEED TO FACTOR OUT THIS ALGORITHM FROM ::Base.  leave it out for now.

    $self->_make_src_class($_) for @tables;
    $self->_setup_src_meta($_) for @tables;

    # Here's the "Rinse-and-Repeat" Catch-22 that leads to dbics::loader agony:
    # - 'register_class' freezes what we know about the class so far.  
    # - relationships cannot be dynamically added until classes are registered.
    # Solution: register all classes as unrelated, then build relationships, then wipe-and-reregister!

    for my $table (@tables) {
        my $moniker = $self->monikers->{$table->sql_name};
        my $class = $self->classes->{$table->sql_name};
        $self->schema->register_class($moniker=>$class);
    }

    $self->_load_relationships(\@tables);

    for my $class (sort values %{$self->classes}) {
        if (eval "require $class") {
            printf STDERR "$class customisations loaded\n" if $self->debug;
            next
        }
        my $err = $@;
        next if $err =~ /Can't locate/; # It's not a sin..
        printf STDERR "WARNING errors loading customisations for $class.. %s\n", $err;
    }

    $self->schema->source_registrations({});
    for my $table (@tables) {
        my $moniker = $self->monikers->{$table->sql_name};
        my $class = $self->classes->{$table->sql_name};
        $self->schema->register_class($moniker=>$class);
    }

    return \@tables;
}

sub _inject {
    my ($self, $class, @parents) = @_;
    return unless @parents;
    my $isa = $class . '::ISA';
    no strict 'refs';
    unshift @$isa, @parents;
}

sub _base_class_pod {}
sub _make_pod {}
sub _make_pod_heading {}
sub _pod {}
sub _pod_class_list {}
sub _pod_cut {}
sub _use {}

1;

__END__

=head1 NAME

DBIx::Class::Schema::Loader::Dynamic -- Really Dynamic Schema Generation for DBIx::Class

=head1 SYNOPSIS

    package MySchema;

    use strict;
    use warnings;

    use base 'DBIx::Class::Schema';
    use       DBIx::Class::Schema::Loader::Dynamic;

    sub connect_info { [ 'dbi:Pg:dbname="my_db, 'uid', 'pwd' ] }

    sub setup {
        my $class = shift;
        my $schema = $class->connect(@{$class->connect_info});

        DBIx::Class::Schema::Loader::Dynamic->new(
            left_base_classes => 'MySchemaDB::Row',
            naming            => 'v8',
            use_namespaces    => 0,
            schema            => $schema,
        )->load;
        return $schema;
    }
    1;


    package MySchema::Row;
    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('InflateColumn::DateTime');
    sub hello { 'everybody gets me' }

    1;

=head1 DESCRIPTION

L<Mojolicious::Plugin::StaticLog> is a L<Mojolicious> plugin which will log the http code, file name and size when rendering static files.

By default logs in debug level only.  Will respond to dynamically changed log levels and will honour "MOJO_LOG_LEVEL" if present.

=head1 REASON

L<Mojolicious> includes a static file server L<Mojolicious::Static> which does some very clever things, silently.  With this Plugin you can trace which static files your app is serving and you will also easily identify when the browser is getting a fresh version of your static resource e.g. C<Static 200 19157 /js/stuff.js> and when it's getting a zero-content "Not Modified" response e.g. C<Static 304 0 /img/searching.gif>.

=head1 METHODS

L<Mojolicious::Plugin::StaticLog> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register($app)

or

  $plugin->register($app, {level => $level}) # where $level =~ /debug|info|warn|error|fatal/

Adds an appropriate after_static hook for logging static file responses.

=head1 REPOSITORY

Open-Sourced at Github: L<https://github.com/frank-carnovale/Mojolicious-Plugin-StaticLog>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016, Frank Carnovale <frankc@cpan.org>

This program is free software, you can redistribute it and/or modify it under the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Mojo::Log>, L<Mojolicious::Static>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
