package EPrints::DataObj::LDN;

our @ISA = qw( EPrints::DataObj );

use COARNotify::Utils;
use JSON qw(decode_json encode_json);

use strict;
use Data::Dumper;
use Encode qw( encode_utf8 );
use Digest::MD5 qw(md5_hex);
use APR::UUID;

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
        { name=>"timestamp", type=>"time", required=>0 },
        { name => "uuid", type => "uuid" },
        { name => "in_reply_to", type => "id" },
        { name => "from", type => "text" },
        { name => "to", type => "id", render_single_value => "COARNotify::Utils::render_ldn_to" },
        { name => "type", type => "set", multiple=>0, options=>[
                'OfferEndorsement',
                'Reject',
                'TentativeAccept',
                'AnnounceReview',
                'AnnounceEndorsement',
                'TentativeReject',
                'Announce',
            ]       
        },
        { name => "subject", type=> "text" },
        { name => "object", type=> "text" },
        { name => "subject_id", type=> "int" }, # subject will often by a record in the repository, so useful to store this in a more retrievable way
        { name => "subject_dataset", type=> "id" },
        { name => "content", type => "longtext" },
        { name => "status", type => "set", multiple=>0, options=>[
                'unsent',
                'sent',
                'failed',
                'response_received',
            ]
        },
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

    return $data;
}

sub create_payload_and_send
{
    
    my( $self, $object, $actor, $sub_object, $type ) = @_;

    # first create the payload
    my $json = $self->_create_payload($object, $actor, $sub_object, $type);
    $self->set_value("content", $json);
    $self->commit;

    # now we have it, we can send it!
    $self->_send;
}

sub _send
{
    my( $self ) = @_;
 
    my $ldn_inbox = $self->_inbox;
 
    # send an ldn to it's to
    my $ua = new LWP::UserAgent;

    my $res = $ua->post(
        $ldn_inbox->value( "endpoint" ),
        #'https://some.endpoint',
        'Content-Type' => 'application/ld+json',
        'Content' => $self->value( "content" ) 
    );

    # we've now sent this, so at least record a timestamp
    $self->set_value( "timestamp", EPrints::Time::get_iso_timestamp );

    if( $res->is_success )
    {
        $self->set_value( "status", "sent" );
    }
    else
    {
        $self->set_value( "status", "fail" );
        $self->{session}->log( "Issue sending LDN (ID: " . $self->id . "). Error: '" . $res->status_line . "'" );
    }

    $self->commit;
}

sub _inbox
{
    my( $self ) = @_;
    
    my $session = $self->{session};

    if( !defined $self->{inbox} )
    {

      my $ldn_inbox_ds = $session->dataset( "ldn_inbox" );
      $self->{inbox} = $ldn_inbox_ds->dataobj_class->find_or_create( $session, $self->value( "to" ) );

      if( !$self->{inbox} )
      {
        $session->log( "Could not find LDN Inbox. LDN: " . $self->id ."; Target: " . $self->value( "to" ) );
        return 0;
      }
    }
    return $self->{inbox};
}

sub _create_payload
{
    my( $self, $object, $actor, $sub_object, $type ) = @_;

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
 
    if( $self->value( "type" ) eq "Announce" )
    {
        return $self->_create_relationship_payload( $session, $ldn_inbox, $object, $actor );
    }

    # assuming actor is a user but not assuming that that user will have a name value...
    my $actor_name = EPrints::Utils::tree_to_utf8( $actor->render_description );

    # we have our details, let's build our payload
    # this assumes the object is an eprint, the actor is a user and the sub_object is a document for now...
    use JSON; 
    my $payload = encode_json({
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
        "name"=> $actor_name,
        "type"=> "Person"
    },
    "object"=> {
        "type"=> [
            "Page",
            "sorg:AboutPage"
        ],
        "id"=> $object->url,
        "ietf:cite-as"=> $object->url,
        "ietf:item"=> {
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
    },
    "type"=> $type
   });
}

sub _create_relationship_payload
{
    my( $self, $session, $ldn_inbox, $object, $actor ) = @_;

    # assuming actor is a user but not assuming that that user will have a name value...
    my $actor_name = EPrints::Utils::tree_to_utf8( $actor->render_description );

    # we have our details, let's build our payload
    # this assumes the object is an eprint, the actor is a user and the sub_object is a document for now...
    use JSON; 
    my $payload = encode_json({
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
        "name"=> $actor_name,
        "type"=> "Person"
    },
    "context"=> {
        "id"=>$self->value( "object" ),
        "type"=>[
            "Page",
            "sorg:AboutPage",
        ]
    },
    "object"=> {
        "as:object"=> $self->value( "object" ),
        "as:relationship"=> "http://purl.org/vocab/frbr/core#supplement",
        "as:subject"=> $object->url,
        "id"=> "urn:uuid:" . APR::UUID->new->format(),
        "type"=> "Relationship",
    },
    "target"=> {
        "id"=> $ldn_inbox->value( "id" ),
        "inbox"=> $ldn_inbox->value( "endpoint" ),
        "type"=> $ldn_inbox->value( "type" ),
    },
    "type"=> 
        [
            "Announce",
            "coar-notify:RelationshipAction"
        ]
   });
}



# get a value from the payload/json content - may return a single value, may return a json hash 
sub get_content_value{

    my( $self, $key ) = @_;

    return undef if !$self->is_set( "content" );

    my $content = decode_json( $self->value( "content" ) );

    if( defined $content->{$key} )
    {
        return $content->{$key};
    }
    else
    {
        return undef;
    }
}

# get all LDNs that are a response to this LDN as processed by our LDN inbox handler
sub get_responses{

    my( $self ) = @_;

    return $self->dataset->search(
        filters => [
            { meta_fields => [qw( in_reply_to )], value => $self->value( "uuid" ) },
        ],
        custom_order => "-timestamp",
    );
}

sub get_latest_response{

    my( $self ) = @_;

    return $self->get_responses->item(0);
}

# get the ldn this ldn is replying to
sub get_in_reply_to_ldn{
 
    my( $self ) = @_;
 
    return $self->dataset->search(
        filters => [
            { meta_fields => [qw( uuid )], value => $self->value( "in_reply_to" ) },
        ],
    )->item(0);
}
