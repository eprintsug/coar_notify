# Enable Linked Data Notifications Inbox
$c->{ldn_inbox} = 1;

use EPrints::DataObj::LDN;
use EPrints::DataObj::LDNInbox;

# LDN Dataset
$c->{datasets}->{ldn} = {
    class => "EPrints::DataObj::LDN",
    sqlname => "ldn",
};

$c->{datasets}->{ldn_inbox} = {
	class => "EPrints::DataObj::LDNInbox",
	sqlname => "ldn_inbox",
};


# Registed Customer Handler - requires EPrints 3.4.2
$c->{custom_handlers}->{coar_notify}->{regex} = '^URLPATH/coar_notify/(inbox|system_description)';
$c->{custom_handlers}->{coar_notify}->{function} = sub
{
    my( $r ) = @_;
 
    $r->handler( 'perl-script' );
    $r->set_handlers( PerlResponseHandler => [ 'COARNotify::COARNotifyHandler' ] );
    return EPrints::Const::OK;
};

{
package EPrints::Script::Compiled;
use strict;

sub run_ldn_json
{
    my( $self, $state, $ldn ) = @_;

    my $session = $state->{session};

    $ldn = $ldn->[0];

    my $content = $ldn->value( "content" );

    my $json = JSON->new->allow_nonref;
    my $json_text = $json->decode( $content );
    my $text = $session->make_text( $json->pretty->encode( $json_text ) );

    return [ $text, "XHTML" ];
}

}
