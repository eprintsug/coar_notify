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
        { name => "type", type => "set", multiple=>1, options=>[
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

    # Timestamp
    $data->{timestamp} = EPrints::Time::get_iso_timestamp();

    return $data;
}

