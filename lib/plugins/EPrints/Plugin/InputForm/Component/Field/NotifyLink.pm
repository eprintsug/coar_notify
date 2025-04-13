package EPrints::Plugin::InputForm::Component::Field::NotifyLink;

use EPrints;
use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( 'EPrints::Plugin::InputForm::Component::Field' );

use Unicode::String qw(latin1);
use strict;

sub new
{
    my( $class, %opts ) = @_;

    my $self = $class->SUPER::new( %opts );

    $self->{name} = 'Notify Link';
    $self->{visible} = 'all';
    $self->{visdepth} = 1;

    return $self;
}



sub update_from_form
{
    my( $self, $processor ) = @_;

    my $session = $self->{session};
    my $eprint = $self->{dataobj};
    my $field = $self->{config}->{field};
    my $user = $session->current_user;

    my $ibutton = $self->get_internal_button;

    # we've submitted a new request
    if( $ibutton eq 'request' )
    {
        my @params = $session->param;

        my $url = $session->param( $self->{prefix}.'_url_input' );

        my $uri = URI->new( $url );
        my $base_url = $uri->scheme."://".$uri->host;

        # we have a url - let's make an LDN for the request
        my $ldn_ds = $session->dataset( "ldn" );
        my $ldn = EPrints::DataObj::LDN->create_from_data(
            $session,
            {
                from => $session->get_conf("base_url"),
                to => $base_url,
                type => "Announce",
                subject_id => $eprint->id,
                subject_dataset => "eprint",
                object => $url,
            },
            $ldn_ds
        );

        # now try and send it (includes finding the inbox)
        $ldn->create_payload_and_send(
            $eprint,
            $user,
        );
    }

    return;
}

sub render_content
{
    my( $self, $surround ) = @_;

    my $session = $self->{session};
    my $field = $self->{config}->{field};
    my $eprint = $self->{workflow}->{item};

    my $page = $session->make_element( 'div' );

    # show URL form
    $page->appendChild( $self->_render_url_input( $session, $eprint, $field) );

    # show existing notify graphs
    $page->appendChild( $self->_render_notify_requests( $session, $eprint, $field ) );
    
    return $page;
}


sub _render_url_input
{
    my( $self, $session, $eprint, $field ) = @_;

    my $prefix = $self->{prefix};

    my $div = $session->make_element( 'div', style=>'padding: 5px;' );

    # intro/help text
    $div->appendChild( $self->html_phrase( 'notify_link_help' ) );

    # form
    my $bar = $self->html_phrase(
        $field->get_name.'_url_input',
        input=>$session->render_noenter_input_field(
            class=>'ep_form_text',
            name=>$prefix.'_url_input',
            id=>$prefix.'_url_input',
            type=>'text',
            value=>$self->{url},
            onKeyPress=>'return EPJS_enter_click( event, \'_internal_'.$prefix.'_send_request\' )' ),
        request_button=>$session->render_button(
            name=>'_internal_'.$prefix.'_request',
            class=>'ep_form_internal_button',
            id=>'_internal_'.$prefix.'_request',
            value=>$self->phrase( 'request_button' ) ),
    );

    $div->appendChild( $bar );

    return $div;
}

sub _render_notify_requests
{
    my( $self, $session, $eprint, $field ) = @_;

    my $div = $session->make_element( 'div', class=>'ep_block notify_link_requests' );

    # get our outgoing ldns
    my $outgoing_ldns = COARNotify::Utils::get_notify_link_requests( $session, $eprint );
    if( $outgoing_ldns->count > 0 )
    {
        $div->appendChild( my $outgoing_header = $session->make_element( 'h3' ) );
        $outgoing_header->appendChild( $self->html_phrase( "outgoing_header" ) );

        $outgoing_ldns->map( sub {
            (undef, undef, my $ldn ) = @_;

            my $status = $ldn->value( "status" );

            $div->appendChild( my $ldn_div = $session->make_element( "div", class => "notify_link_ldn_request notify_link_$status" ) );
            $ldn_div->appendChild( $ldn->render_citation( "notify_link_request" ) );
        });
    }

    # this may also be a useful place to show anything that has linked to us
    my $incoming_ldns = COARNotify::Utils::get_links_from_repositories( $session, $eprint );
    if( $incoming_ldns->count > 0 )
    {        
        $div->appendChild( my $outgoing_header = $session->make_element( 'h3' ) );
        $outgoing_header->appendChild( $self->html_phrase( "incoming_header" ) );
        $incoming_ldns->map( sub {
            (undef, undef, my $ldn ) = @_;

            my $status = "sent"; # highlights these as successes, which they should be if we're storing them from incoming requests

            $div->appendChild( my $ldn_div = $session->make_element( "div", class => "notify_link_ldn_request notify_link_$status" ) );
            $ldn_div->appendChild( $ldn->render_citation( "notify_link_request" ) );
        });
    }

    return $div;
}
