package COARNotify::COARNotifyHandler;

use EPrints;
use EPrints::XML;
use EPrints::Apache::AnApache;
use Switch;

use strict;

sub handler {
    my $r = shift;

    # Do we have a session?
    my $session = new EPrints::Session(2);
    if( !defined $session )
    {
        print STDERR "Could not create session object.";
        $r->status(500);
        return Apache2::Const::DONE;
    }
  
    # What's our URI
    my $uri = $r->uri;

    # is it an inbox request?
    if( $uri =~ m! /inbox$ !x )
    {
        return _inbox_handler( $session, $r );
    }
    
    if( $uri =~ m! /system_description$ !x )
    {
         return _system_description_handler( $r );     
    }


};

sub _inbox_handler
{
    
    my( $session, $r ) = @_;

    # 1) Check against allow list
    
    # 2) Check an appropriate method    
    my $method = $r->method;
    if( $method eq "GET" )
    {
        # TODO: Add in nice forbidden page
        return Apache2::Const::HTTP_METHOD_NOT_ALLOWED;
    }

    # 3) Check the Content-Type
    my $accept = $r->headers_in->{'Content-Type'};
    return Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE if $accept ne "application/ld+json";

    # 4) Get our JSON
    my $content;
    while($r->read(my $buffer, 4096)) {
        $content .= $buffer;
    }
    
    # 5) Act based on Type
    my $payload = JSON::decode_json( $content );

    # First normalise to an array
    my $type = $payload->{type};
    my @types;
    if( ref( \$type ) eq "SCALAR" )
    {
        push @types, $type;
    }
    else
    {
        @types = @{$type};
    }

    if( grep { "Reject" eq $_ } @types )
    {
        return _request_handler( $session, $r, "Reject", $payload );
    }
    elsif( grep { "TentativeReject" eq $_ } @types )
    {
        return _request_handler( $session, $r, "TentativeReject", $payload );
    }
    elsif( grep { "TentativeAccept" eq $_ } @types )
    {
        return _request_handler( $session, $r, "TentativeAccept", $payload );
    }
    elsif( ( grep { "coar-notify:ReviewAction" eq $_ } @types ) && ( grep { "Announce" eq $_ } @types ) )
    {
        return _request_handler( $session, $r, "AnnounceReview", $payload );
    }
    elsif( ( grep { "coar-notify:EndorsementAction" eq $_ } @types ) && ( grep { "Announce" eq $_ } @types ) )
    {
        return _request_handler( $session, $r, "AnnounceEndorsement", $payload );
    }
    elsif( ( grep { "coar-notify:RelationshipAction" eq $_ } @types ) && ( grep { "Announce" eq $_ } @types ) )
    {
        return _request_relationship_handler( $session, $r, "AnnounceRelationship", $payload );
    }
    else
    {
        return Apache2::Const::HTTP_UNPROCESSABLE_ENTITY; 
    }

    # Success - must respond with a 2-1 Created and the Location header set to th URL from which the notification data can be retrieved

    return Apache2::Const::DONE;
}

sub _create_ldn
{
    my( $session, $type, $payload, $subject, $object) = @_;
   
    my $ds = $session->dataset( "ldn" );
    my $ldn = $ds->create_dataobj(
        {
            uuid => $payload->{id},
            from => $payload->{origin}->{id},
            to => $payload->{target}->{id},
            type => $type,
            content => JSON::encode_json( $payload ),
            timestamp => EPrints::Time::get_iso_timestamp,            
        },
    );

    if( defined $payload->{inReplyTo} )
    {
        $ldn->set_value( "in_reply_to", $payload->{inReplyTo} );
        $ldn->commit;
    }

    if( defined $subject )
    {
        $ldn->set_value( "subject", $subject );
        $ldn->commit;    
    }

    if( defined $object )
    {
        $ldn->set_value( "object", $object );
        $ldn->commit;    
    }

    return $ldn;
}

sub _request_handler
{
    my( $session, $r, $type, $payload )  = @_;

    # Store the LDN
    my $ldn = _create_ldn( $session, $type, $payload );

    return Apache2::Const::DONE;
}

sub _system_description_handler
{
    
    my $r = shift;

    # TODO: Generate a nice JSON description
    # E.g. https://evolbiol.peercommunityin.org/coar_notify/system_description

    print STDERR "System Description handler\n";

    return Apache2::Const::DONE;
}

sub _request_relationship_handler
{
    my( $session, $r, $type, $payload )  = @_;

    # first does the payload indicate this is a relationship
    return Apache2::Const::HTTP_UNPROCESSABLE_ENTITY if $payload->{object}->{type} ne "Relationship";

    # check we have the details we need
    return Apache2::Const::HTTP_UNPROCESSABLE_ENTITY if !exists $payload->{object}->{'as:subject'};
    return Apache2::Const::HTTP_UNPROCESSABLE_ENTITY if !exists $payload->{object}->{'as:object'};

    # get the object = we expect this to be a landing page for an item in the repository
    my $object = $payload->{object}->{'as:object'};
    my $urlpath = $session->get_repository->get_conf( 'base_url' );
    if( $object =~ s! ^${urlpath}/id/eprint/(0*)([1-9][0-9]*)\b !!x )
        #|| $object =~ s! ^$urlpath/(0*)([1-9][0-9]*)\b !!x ) # option to support both formats???
    {
        my $dataobjid = $2;
        my $ds = $session->get_repository->dataset( "archive" );
        my $dataobj = $ds->dataobj( $dataobjid );
        if( $dataobj )
        {
            # this is in the live archive
            # record this ldn
            my $ldn = _create_ldn( 
                $session, 
                $type, 
                $payload, 
                $payload->{object}->{'as:subject'},
                $payload->{object}->{'as:object'},
            );

            # and send back a positive response
            return Apache2::Const::DONE;
        }
        else
        {
            # we don't appear to have this record
            return Apache2::Const::HTTP_NOT_FOUND;
        }
    }

    # we couldn't identify the object as a record in this repository
    return Apache2::Const::HTTP_UNPROCESSABLE_ENTITY;
}


1;
