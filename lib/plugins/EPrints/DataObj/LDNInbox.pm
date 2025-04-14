package EPrints::DataObj::LDNInbox;

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
        { name =>"ldninboxid", type=>"counter", required=>1, import=>0, show_in_html=>0, can_clone=>0, sql_counter=>"ldninboxid" },
        { name => "id", type => "text" },  # e.g. pci_evolbiol
        { name => "endpoint", type => "url" },
        { name => "last_accessed", type=>"time", required=>0, },
        { name => "type", type => "text" },
    );
}

sub get_dataset_id { "ldn_inbox" }

sub get_url { shift->uri }

sub get_defaults
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = $class->SUPER::get_defaults( @_[1..$#_] );

	return $data;
}


sub find_or_create
{
    my( $class, $session, $id ) = @_;

    my $inbox = $class->search_by_id($session, $id);
    if( !$inbox )
    {    
        # get the url from our config if we have it... but it may just be a url we want to keep and doesn't correspond with a config mapping
        my $url;
        my $url_from_conf = $class->get_service_url($session, $id);
        if( $url_from_conf )
        {
            $url = $url_from_conf;
        }
        else
        {
            $url = $id;
        }

        my $inbox_url = $class->discover_inbox($session, $url);
        if($inbox_url)
        {
	        $inbox = $class->create_from_data(
                $session,
                {
                    id => $id,
	                endpoint => $inbox_url,
	                #last_accessed => undef, 
	                type => "Service"
                },
                $session->dataset( $class->get_dataset_id )
            );
        }
        else
        {
            $session->log( "LDN Inbox data object was not found and could not be created because the service url does not return a valid inbox endpoint. Service url: ($url)" );
	        return 0;
        }
    }
    else
    {
    }
    return $inbox;
}

sub discover_inbox
{

  my( $class, $session, $url ) = @_;
  use HTTP::Link::Parser ':standard';
  use LWP::UserAgent;

  my $ua = LWP::UserAgent->new;
  my $response = $ua->head($url);

  # Parse link headers into an RDF::Trine::Model.
  my $model = parse_links_into_model($response);

  # Find data about <http://example.com/foo>.
  my $iterator = $model->get_statements(
    RDF::Trine::Node::Resource->new($url),
    undef,
    undef);

  while (my $statement = $iterator->next)
  {
     return $statement->object->uri if $statement->predicate->uri eq "http://www.w3.org/ns/ldp#inbox"
  }
  return 0;
}

sub get_service_url
{
    my( $class, $session, $id ) = @_;
    
    if( defined $session->get_conf("ldn_inboxes") )
    {
        while( my( $key, $inbox ) = each %{$session->get_conf("ldn_inboxes")} )
        {
            return $inbox->{$id} if($inbox->{$id});
        }
    }
}

sub search_by_id
{
    my( $class, $session, $id ) = @_;

    return $session->dataset( $class->get_dataset_id )->search(
        filters => [{
            meta_fields => [qw( id )],
            value => $id,
            match => "EX",
        }],
        custom_order => "-ldninboxid",
    )->item(0);
}

1;
