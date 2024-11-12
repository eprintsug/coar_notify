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

1;
