use Mojo::Base -strict;

use Test::Most;

my $testdir;
BEGIN {
    use File::Basename 'dirname';
    $testdir = dirname(__FILE__);
    $ENV{EXAMPLEDB} = "$testdir/example.db";
}
use lib $testdir;

use_ok('ExampleDB', "can use ExampleDB");

my $schema;
lives_ok { $schema = ExampleDB->setup } "can setup ExampleDB" ;

my @sources = $schema->sources;
ok @sources == 3, "3 result-source definitions loaded";

my $sources = join('-', sort @sources);
ok $sources eq 'Artist-Cd-Track', "result sources are Artist, Cd, Track";

my $rs = $schema->resultset('Artist');
my $artist0 = $rs->search({}, {order_by=>'name',rows=>1})->first;
ok $artist0->name eq 'Eminem', "first artist by name is 'Eminem'";

my $TITLE = 'The Marshall Mathers LP';
my $cd = $artist0->cds({}, {order_by=>'title'})->first;
ok $cd->title eq $TITLE, "first cd by title of first artist by name is '$TITLE'";

done_testing();

