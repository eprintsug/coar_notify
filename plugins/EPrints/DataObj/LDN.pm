package EPrints::DataObj::LDN;

our @ISA = qw( EPrints::DataObj );

use JSON qw(decode_json encode_json);

use strict;
use Data::Dumper;
use Encode qw( encode_utf8 );
use Digest::MD5 qw(md5_hex);

# The new method can simply return the constructor of the super class (Dataset)
sub new
{ 
    return shift->SUPER::new( @_ );
}

sub get_system_field_info
{
    my( $class ) = @_;

    return
    (
        { name=>"ldnid", type=>"counter", required=>1, import=>0, show_in_html=>0, can_clone=>0, sql_counter=>"ldnid" },
        { name=>"timestamp", type=>"time", required=>0, },
        { name => "uuid", type => "uuid" },
        { name => "from", type => "text" },
        { name => "to", type => "id" },
        { name => "type", type => "set", multiple=>0, options=>[
                'OfferEndorsement',
                'Reject',
                'TentativeAccept',
                'AnnounceReview',
                'AnnounceEndorsement',
            ]       
        },
        { name => "content", type => "longtext" },
    );
}

# This method is required to just return the dataset_id.
sub get_dataset_id
{
    my ($self) = @_;
    return "ldn";
}

sub get_defaults
{
    my( $self, $session, $data, $dataset ) = @_;

    $data = $self->SUPER::get_defaults( @_[1..$#_] );

    # UUID - TODO

    return $data;
}

sub send_ldn
{

    my( $self, $session ) = @_;

    my $ds = $session->dataset( "ldn" );

    # TODO: Looks up the inbox for this LDN's "to" value
    #       Makes a POST to the given inbox using Content Type "application/ld+json"
    #       Set the timestamp on the LDN record after POST-ing
}

sub build_payload
{
    my( $self, $session, $origin ) = @_;

    # TODO: Builds a JSON payload including...
    #       @context: Defaults to "https://www.w3.org/ns/activitystreams" and "http://purl.org/coar/notify"
    #       origin: This will (always?) default to us! Need to provide type, id and inbox
    #       actor: Again this will default to us, but this time we provide a name from than an inbox
    #       id: Uuid which we should already have in the LDN object
    #       object: Convert the given dataobj into an LDN object - a function for each invidual dataobj, but almost certainly just an eprint for now. Needs a type, id and cite-as (see signposting)
    #       target: another LDN inbox - get details from our LDN inbox dataset
    #       type: the kind of LDN we're sending
}

sub create_payload_and_send
{
    
    my( $self, $object, $actor, $sub_object ) = @_;

    my $json = $self->_create_payload($object, $actor, $sub_object);

    print STDERR "JSON : $json\n";
    $ldn->set_value("content", $json);
    $ldn->commit;

    $ldn->_send;
}

sub _send
{
   my( $self ) = @_;
 
   my $ldn_inbox = $self->_inbox;
   # send an ldn to it's to
   my $ua = new LWP::UserAgent;
 
   #   my $req = new HTTP::Request('POST', $ldn_inbox->value("endpoint"));
   my $req = new HTTP::Request('POST', 'https://somewhere.else');
 
   my $response = $ua->request($req);
   #TODO this in body of request
   #$self->value("content")

   
}

sub _inbox
{
    my( $self ) = @_;

    if( !defined $self->{inbox} )
    {
      my $ldn_inbox_ds = $session->dataset( "ldn_inbox" );
      $self->{inbox} = $ldn_inbox_ds->dataobj_class->find_or_create( $session, $self->value( "to" ) );

      if( !$self->{inbox} )
      {
        $session->log( "Could not find LDN Inbox. LDN: " . $self->id ."; Target: " . $self->value( "to" ) );
        return 0;
      }
      $self->{inbox} = $ldn_inbox;

    }

    return $self->{inbox};
}

sub _create_payload
{
    my( $self, $object, $actor, $sub_object ) = @_;

    print STDERR "self: $self\n";
    print STDERR "object: $object\n";
    print STDERR "actor: $actor\n";
    print STDERR "sub_object: $sub_object\n";

    my $session = $self->{session};

    # before we can build the payload we need some basic details
    # first, who are we sending to
    if( !$self->is_set( "to" ) )
    {
        $session->log( "Cannot build payload with no target ID set (LDN: ". $self->id );
        return 0;
    }

    # is this "to" value a valid LDN Inbox that we know or can discover
    my $ldn_inbox = $self->_inbox;

    # we have our details, let's build our payload
    # this assumes the object is an eprint, the actor is a user and the sub_object is a document for now...
    use JSON; 
    return encode_json({
		   '@context'=> [
        "https://www.w3.org/ns/activitystreams",
        "https://purl.org/coar/notify"
    ],
    "origin"=> {
        "type"=> [
            "Service"
        ],
        "id"=> $session->get_conf("base_url"),
        "inbox"=> $session->get_conf("base_url")."/coar_notify/inbox",
    },
    "id"=> $self->get_value("uuid"),
    "actor"=> {
        "id"=> "mailto:".$actor->get_value("email"),
        "name"=> EPrints::Utils::make_name_string($actor->get_value("name")), #assumes actor is a user
        "type"=> "Person"
    },
    "object"=> {
        "type"=> [
            "Page",
            "sorg:WebPage"
        ],
        "id"=> $object->url,
        "ietf:cite-as"=> $object->url,
        "url"=> {
            "id"=> $sub_object->url,
            "mediaType"=> $sub_object->get_value("mime_type"),
            "type"=> [
                "Article",
                "sorg:ScholarlyArticle"
            ]
        }
    },
    "target"=> {
        "id"=> $ldn_inbox->value( "id" ),
        "inbox"=> $ldn_inbox->value( "endpoint" ),
        "type"=> $ldn_inbox->value( "type" )
    }
   });
}


