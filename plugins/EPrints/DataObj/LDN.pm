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
        { name => "to", type => "text" },
        { name => "type", type => "set", multiple=>0, options=>[
                'Offer',
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
    my( $class, $session, $data, $dataset ) = @_;

    $data = $class->SUPER::get_defaults( @_[1..$#_] );

    # UUID - TODO

    return $data;
}

sub send_ldn
{
    # TODO: Looks up the inbox for this LDN's "to" value
    #       Makes a POST to the given inbox using Content Type "application/ld+json"
    #       Set the timestamp on the LDN record after POST-ing
}

sub build_payload
{
    my( $class, $session, $origin ) = @_;

    # TODO: Builds a JSON payload including...
    #       @context: Defaults to "https://www.w3.org/ns/activitystreams" and "http://purl.org/coar/notify"
    #       origin: This will (always?) default to us! Need to provide type, id and inbox
    #       actor: Again this will default to us, but this time we provide a name from than an inbox
    #       id: Uuid which we should already have in the LDN object
    #       object: Convert the given dataobj into an LDN object - a function for each invidual dataobj, but almost certainly just an eprint for now. Needs a type, id and cite-as (see signposting)
    #       target: another LDN inbox - get details from our LDN inbox dataset
    #       type: the kind of LDN we're sending
}
