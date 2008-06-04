=head1 NAME

XML::TinyXML - Little and efficient Perl module to manage xml data. 

=head1 SYNOPSIS

  use XML::TinyXML;

  # first create an XML Context
  $xml = XML::TinyXML->new();
    
  $node = XML::TinyXML::Node->new("nodelabel", "somevalue");
  # or maybe 
  $attrs = { attr1 => v1, attr2 => v2 };
  $node = XML::TinyXML::Node->new("nodelabel", "somevalue", $attrs);

  $xml->addRootNode($node);

  # or you could want to create the XML Context 
  # specifying the root node directly at creation time
  $xml = XML::TinyXML->new($node);

  # or maybe 
  $xml = XML::TinyXML->new("rootnode", "somevalue", { attr1 => v1, attr2 => v2 });

  # or we can just create an empty root node:
  $xml = XML::TinyXML->new("rootnode");

  # and then obtain a reference using the getNode() method
  $node = $xml->getNode("/rootnode");

  # the leading '/' is optional ... since all paths will be absolute and 
  # first element is assumed to be always a root node
  $node = $xml->getNode("rootnode");

  # see XML::TinyXML::Node documentation for further details on possible
  # operations on a node reference

  ########                                            #########
  ########## hashref2xml and xml2hashref facilities ###########
  ########                                            #########
  
  # An useful facility is loading/dumping of hashrefs from/to xml
  # for ex:
  $hashref = { some => 'thing', someother => 'thing' };
  my $xml = XML::TinyXML->new($hashref, 'mystruct');

  # or to load on an existing XML::TinyXML object
  $xml->loadHash($hashref, 'mystruct');

  # we can also create and dump to string all at once :
  my $xmlstring = XML::TinyXML->new($hashref, 'mystruct')->dump;

  # to reload the hashref back
  my $hashref = $xml->toHash;

=head1 DESCRIPTION

Since in some environments it could be desirable to avoid installing 
Expat, XmlParser and blahblahblah , needed by most XML-related perl modules,.
my main scope was to obtain a fast xml library usable from perl
(so with a powerful interface) but without the need to install 
a lot of other modules (or even C libraries) to have it working.
Once I discovered XS I started porting a very little and efficent
xml library I wrote in C some years ago.

The interesting part of porting it in perl is that now it's really easy
to improve the interface and I was almost always pissed off of installing 
more than 10 modules to have a simple xml implementation.

=over

=cut

package XML::TinyXML;

use 5.008008;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

use XML::TinyXML::Node;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use XML::TinyXML ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	XML_BADARGS
	XML_GENERIC_ERR
	XML_LINKLIST_ERR
	XML_MEMORY_ERR
	XML_NOERR
	XML_OPEN_FILE_ERR
	XML_PARSER_GENERIC_ERR
        XML_NODETYPE_SIMPLE
        XML_NODETYPE_COMMENT
        XML_NODETYPE_CDATA
	XXmlAddAttribute
	XmlAddChildNode
	XmlAddRootNode
	XmlCountAttributes
	XmlCountBranches
	XmlCountChildren
	XmlCreateContext
	XmlCreateNode
	XmlDestroyContext
	XmlDestroyNode
	XmlDump
	XmlDumpBranch
	XmlGetBranch
	XmlGetChildNode
	XmlGetChildNodeByName
	XmlGetNode
	XmlGetNodeValue
	XmlParseBuffer
	XmlParseFile
	XmlRemoveBranch
	XmlRemoveNode
	XmlSave
	XmlSetNodeValue
	XmlSubstBranch
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&XML::TinyXML::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('XML::TinyXML', $VERSION);

# Preloaded methods go here.

=item * new ($arg, $param, $attrs, $doctype)

=cut
sub new {
    my ($class, $arg, $param, $attrs, $doctype) = @_;
    my $self = {} ;
    bless($self, $class);

    $self->{_ctx} = XmlCreateContext();
    if($arg) {
        if(UNIVERSAL::isa($arg, "XML::TinyXML::Node")) {
            XmlAddRootNode($self->{_ctx}, $arg->{_node});
        } elsif(UNIVERSAL::isa($arg, "XmlNodePtr")) {
            XmlAddRootNode($self->{_ctx}, $arg);
        } elsif(ref($arg) eq "HASH") {
            $self->loadHash($arg, $param);
        } elsif(defined($arg) && (!ref($arg) || ref($arg) eq "SCALAR")) {
            $self->addRootNode($arg, $param, $attrs);
        }
    }
    return $self;
}

=item * addNodeAttribute ($node, $key, $value)

=cut
sub addNodeAttribute {
    my ($self, $node, $key, $value) = @_;
    return undef unless($node && UNIVERSAL::isa("XML::TinyXML::Node", $node));
    return $node->addAttributes($key => $value);
}

=item * removeNodeAttribute ($node, $index)

=cut
sub removeNodeAttribute {
    # TODO
}

=item * addRootNode ($name, $val, $attrs)

=cut
sub addRootNode {
    my ($self, $name, $val, $attrs) = @_;

    $val = "" unless(defined($val));

    my $node = XML::TinyXML::Node->new($name, $val);

    return undef unless($node);

    if($attrs && ref($attrs) eq "HASH") {
        $node->addAttributes(%$attrs)
    }

    return XmlAddRootNode($self->{_ctx}, $node->{_node});
}

=item * dump ()

Returns a stringified version of the XML structure represented internally

=cut
sub dump {
    my $self = shift;
    return XmlDump($self->{_ctx});
}

=item * loadFile ($path)

Load the xml structure from a file

=cut
sub loadFile {
    my ($self, $path) = @_;
    return XmlParseFile($self->{_ctx}, $path);
}

=item * loadHash ($hash, $root)

Load the xml structure from an hashref (AKA: convert an hashref to an xml document)

=cut
sub loadHash {
    my ($self, $hash, $root) = @_;
    $root = "txml"
        unless($root);

    my $cur = undef;
    if(ref($root) && UNIVERSAL::isa("XML::TinyXML::Node", $root)) {
        XmlAddRootNode($self->{_ctx}, $root->{_node});
        $cur = $root;
    } else {
        $self->addRootNode($root);
        $cur = $self->getNode($root);
    }
    return $cur->loadHash($hash);
}

=item * toHAsh ()

Dump the xml structure represented internally in the form of an hashref

=cut
sub toHash {
    my ($self) = shift;
    # only first branch will be parsed ... This means that if multiple root 
    # nodes are present, only the first one will be parsed and translated 
    # into an hashred
    my $node = $self->getRootNode(1);
    return $node->toHash;
}

=item * loadBuffer ($buf)

Load the xml structure from a preloaded memory buffer

=cut
sub loadBuffer {
    my ($self, $buf) = @_;
    return XmlParseBuffer($self->{_ctx}, $buf);
}

=item * getNode ($path)

Get a node at a specific path.

$path must be of the form: '/rootnode/child1/child2/leafnod'
and the leading '/' is optional (since all paths will be interpreted
as absolute)

Returns an XML::TinyXML::Node object

=cut
sub getNode {
    my ($self, $path) = @_;
    return XML::TinyXML::Node->new(XmlGetNode($self->{_ctx}, $path));
}

=item * getChildNode ($node, $index)

Get the child of $node at index $index.

Returns an XML::TinyXML::Node object

=cut
sub getChildNode {
    my ($self, $node, $index) = @_;
    return XML::TinyXML::Node->new(XmlGetChildNode($node, $index));
}

=item * removeNode ($path)

Remove the node at specific $path , if present.
See getNode() documentation for some notes on the $path format.

Returns XML_NOERR (0) if success, error code otherwise.

See Exportable constants for a list of possible error codes

=cut
sub removeNode {
    my ($self, $path) = @_;
    return XmlRemoveNode($self->{_ctx}, $path);
}

=item * getBranch ($index)

alias for getRootNode

=cut
sub getBranch {
    my ($self, $index) = @_;
    return XML::TinyXML::Node->new(XmlGetBranch($self->{_ctx}, $index));
}

=item * getRootNode ($index) 

Get the root node at $index.

Returns an XML::TinyXML::Node object if present, undef otherwise

=cut
sub getRootNode {
    my ($self, $index) = @_;
    return $self->getBranch($index);
}

=item * removeBranch ($index)

Remove the rootnode (and all his children) at $index.

=cut
sub removeBranch {
    my ($self, $index) = @_;
    return XmlRemoveBranch($self->{_ctx}, $index);
}

=item * getChildNodeByName ($node, $name)

Get the child of $node with name == $name.

Returns an XML::TinyXML::Node object if there is such a child, undef otherwise

=cut
sub getChildNodeByName {
    my ($self, $node, $name) = @_;
    if($node) {
        return XML::TinyXML::Node->new(XmlGetChildNodeByName($node, $name));
    } else {
        my $count = XmlCountBranches($self->{_ctx});
        for (my $i = 0 ; $i < $count; $i++ ){
            my $res = XmlGetChildNodeByName(XmlGetBranch($self->{_ctx}, $i), $name);
            return XML::TinyXML::Node->new($res) if($res) 

        }
    }
    return undef;
}

=item * save ($path)

Save the xml document represented internally into $path.

Returns XML_NOERR if success, a specific error code otherwise

=cut
sub save {
    my ($self, $path) = @_;
    return XmlSave($self->{_ctx}, $path);
}

sub DESTROY {
    my $self = shift;
    XmlDestroyContext($self->{_ctx})
        if($self->{_ctx});
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
=back

=head2 EXPORT

None by default.

=head2 Exportable constants

  XML_BADARGS
  XML_GENERIC_ERR
  XML_LINKLIST_ERR
  XML_MEMORY_ERR
  XML_NOERR
  XML_OPEN_FILE_ERR
  XML_PARSER_GENERIC_ERR
  XML_UPDATE_ERR
  XML_NODETYPE_SIMPLE
  XML_NODETYPE_COMMENT
  XML_NODETYPE_CDATA

=head2 Exportable functions

  TXml *XmlCreateContext()
  void XmlDestroyContext(TXml *xml)
  int XmlAddAttribute(XmlNode *node, char *name, char *val)
  int XmlAddRootNode(TXml *xml, XmlNode *node)
  unsigned long XmlCountBranches(TXml *xml)
  XmlNode *XmlGetChildNode(XmlNode *node, unsigned long index)
  XmlNode *XmlGetNode(TXml *xml,  char *path)
  int XmlParseBuffer(TXml *xml, char *buf)
  int XmlRemoveBranch(TXml *xml, unsigned long index)
  int XmlSave(TXml *xml, char *path)
  char *XmlDump(TXml *xml)

=head1 SEE ALSO

  XML::TinyXML::Node

You should also see libtinyxml documentation (mostly txml.h, redistributed with this module)

=head1 AUTHOR

xant, E<lt>xant@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by xant

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
