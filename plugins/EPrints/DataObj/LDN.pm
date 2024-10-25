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
    
    my( $self, $object, $actor, $sub_object ) = @_;

    # first create the payload
    my $json = $self->_create_payload($object, $actor, $sub_object);
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
        #$ldn_inbox->value( "endpoint" ),
        'https://some.endpoint',
        'Content-Type' => 'application/ld+json',
        'Content' => encode_json $self->value( "content" ) 
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
    
    # assuming actor is a user but not assuming that that user will have a name value...
    my $actor_name = EPrints::Utils::tree_to_utf8( $actor->render_description );

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
        "name"=> $actor_name,
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


