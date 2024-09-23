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
    elsif( grep { "TentativeAccept" eq $_ } @types )
    {
        return _request_handler( $session, $r, "TentativeAccept", $payload );
    }
    elsif( grep { "coar-notify:ReviewAction" eq $_ } @types && grep { "Announce" eq $_ } @types)
    {
        return _request_handler( $session, $r, "AnnounceReview", $payload );
    }
    elsif( grep { "coar-notify:EndorsementAction" eq $_ } @types && grep { "Announce" eq $_ } @types)
    {
        return _request_handler( $session, $r, "AnnounceEndorsement", $payload );
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
    my( $session, $type, $payload ) = @_;
   
    my $ds = $session->dataset( "ldn" );
   
    my $ldn = EPrints::DataObj::LDN->create_from_data(
        $session,
        {
            uuid => $payload->{id},
            from => $payload->{origin}->{id},
            to => $payload->{target}->{id},
            type => $type,
            content => JSON::encode_json( $payload ),
        },
        $ds
    );

    return $ldn;
}

sub _request_handler
{
    my( $session, $r, $type, $payload )  = @_;

    print STDERR "handle $type\n";
    use Data::Dumper;
    print STDERR Dumper( $payload );

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



1;
