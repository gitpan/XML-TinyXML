
use strict;
use Test::More qw(no_plan);
use XML::TinyXML;
BEGIN { use_ok('XML::TinyXML::Selector') };

my $txml = XML::TinyXML->new();
$txml->loadFile("./t/t.xml");

warn "Text::Iconv not available" and exit 0
    unless (eval "require Text::Iconv; 1");
my $utf8_output = $txml->dump;
$txml->setOutputEncoding("UTF-16");
my $utf16_output = $txml->dump;
my $iconv = Text::Iconv->new("UTF-8", "UTF-16");
# iconv won't change the declared document-encoding
# but we need it to be changed before comparing the 
# UTF-16 buffers
$utf8_output =~ s/utf-8/UTF-16/; 
my $converted = $iconv->convert($utf8_output);

is( $utf16_output, $converted );

$txml->setOutputEncoding("UTF-8"); # set it back to utf-8
$utf8_output = $txml->dump;
my $txml2 = XML::TinyXML->new();
$txml2->loadFile("./t/t-ucs2.xml");
my $out = $txml2->dump;
ok( $out eq $utf8_output, "import/export" );
