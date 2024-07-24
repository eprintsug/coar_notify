package COARNotify::COARNotifyHandler;

use EPrints;
use EPrints::XML;
use EPrints::Apache::AnApache;

use strict;

sub handler {
    my $request = shift;

    my $session = new EPrints::Session(2);
    if( !defined $session )
    {
        print STDERR "Could not create session object.";
        $request->status(500);
        return Apache2::Const::DONE;
    }

    print STDERR "ok coar notify\n";

    return Apache2::Const::DONE;
};

1;
