# Enable Linked Data Notifications Inbox
$c->{ldn_inbox} = 1;

# Registed Customer Handler - requires EPrints 3.4.2
$c->{custom_handlers}->{coar_notify}->{regex} = '^URLPATH/coar_notify/inbox';
$c->{custom_handlers}->{coar_notify}->{function} = sub
{
    my( $r ) = @_;
 
    $r->handler( 'perl-script' );
    $r->set_handlers( PerlResponseHandler => [ 'COARNotify::COARNotifyHandler' ] );
    return EPrints::Const::OK;
};
