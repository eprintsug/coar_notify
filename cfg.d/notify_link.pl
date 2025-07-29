$c->{plugins}{'InputForm::Component::Field::NotifyLink'}{params}{disable} = 0;

$c->add_dataset_field( "eprint", 
    {
        name => "notify_links",
        type => "url",
        virtual => 1,
        render_value => "render_notify_links",
    }
);

$c->{render_notify_links} = sub {
    my ( $session, $field, $value, $alllangs, $nolink, $object ) = @_;

    my $html = $session->make_doc_fragment();

    next unless defined($object);

    # get our outgoing ldns
    my $outgoing_ldns = COARNotify::Utils::get_notify_link_requests( $session, $object );

    # get our incoming ldns
    my $incoming_ldns = COARNotify::Utils::get_links_from_repositories( $session, $object );

    if( $outgoing_ldns->count > 0 || $incoming_ldns->count > 0 )
    {
        $html->appendChild( my $ul = $session->make_element( "ul" ) );
        $outgoing_ldns->map( sub {
            (undef, undef, my $ldn ) = @_;

            return if $ldn->value( "status" ) ne "sent";

            $ul->appendChild( my $li = $session->make_element( "li" ) );
            $li->appendChild( my $a = $session->make_element( "a", 
                target => "_blank",
                href => $ldn->value( "object" )
            ) );
            $a->appendChild( $session->make_text( $ldn->value( "object" ) ) );
        });

        $incoming_ldns->map( sub {
            (undef, undef, my $ldn ) = @_;

            $ul->appendChild( my $li = $session->make_element( "li" ) );
            $li->appendChild( my $a = $session->make_element( "a", 
                target => "_blank",
                href => $ldn->value( "subject" )
            ) );
            $a->appendChild( $session->make_text( $ldn->value( "subject" ) ) );
        });
    }
     
    return $html;
};
