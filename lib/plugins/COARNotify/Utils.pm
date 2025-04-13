package COARNotify::Utils;

use LWP::UserAgent;
use JSON;
use Encode;

use strict;

# the 'to' value of an ldn contains a string that represents where the ldn is being sent to
# convert this into a more human readable phrase is one is available
sub render_ldn_to
{
    my( $session, $field, $value ) = @_;

    if( $session->get_lang->has_phrase( "ldn_to:$value", $session ) )
    {
        return $session->html_phrase( "ldn_to:$value" );
    }
    else
    {
        return $session->make_text( $value );
    }
}

# get an eprint's attempts to link to another repository
sub get_notify_link_requests
{
    my( $session, $eprint ) = @_;

    return $session->dataset( "ldn" )->search(
        filters => [
            { meta_fields => [qw( subject_dataset )], value => "eprint" },
            { meta_fields => [qw( subject_id )], value => $eprint->id },
            { meta_fields => [qw( type )], value => "Announce" },
        ],
        custom_order => "-timestamp",
    );
}

# get an eprint's confirmed links from other repository's
sub get_links_from_repositories
{
    my( $session, $eprint ) = @_;
    return $session->dataset( "ldn" )->search(
        filters => [
            { meta_fields => [qw( object )], value => $eprint->get_url, match => "EX" },
            { meta_fields => [qw( type )], value => "AnnounceRelationship" },
        ],
        custom_order => "-timestamp",
    );
}


1;
