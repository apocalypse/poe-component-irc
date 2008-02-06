package POE::Component::IRC::Plugin::BotTraffic;

use strict;
use warnings;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Filter::IRCD;
use POE::Filter::CTCP;
use vars qw($VERSION);

$VERSION = '5.54';

sub new {
  return bless { PrivEvent => 'irc_bot_msg', PubEvent => 'irc_bot_public', ActEvent => 'irc_bot_action', @_[1..$#_] }, $_[0];
}

sub PCI_register {
  my ($self,$irc) = splice @_, 0, 2;

  $self->{filter} = POE::Filter::IRCD->new();
  $self->{ctcp} = POE::Filter::CTCP->new();
  $irc->plugin_register( $self, 'USER', qw(privmsg) );
  return 1;
}

sub PCI_unregister {
  return 1;
}

sub U_privmsg {
  my ($self,$irc) = splice @_, 0, 2;
  my $output = ${ $_[0] };

  my ($lines) = $self->{filter}->get([ $output ]);

  foreach my $line ( @{ $lines } ) {
    my $text = $line->{params}->[1];
    if ($text =~ /^\001/) {
      my $ctcp_event = shift( @{ $self->{ctcp}->get( [':' . $irc->nick_name() . ' ' . $line->{raw_line}] ) } );
      next if $ctcp_event->{name} ne 'ctcp_action';
      my $event = $self->{ActEvent};
      $irc->_send_event( $event => @{ $ctcp_event->{args} }[1..2] );
    }
    else {
      foreach my $recipient ( split(/,/,$line->{params}->[0]) ) {
        my $event = $self->{PrivEvent};
        $event = $self->{PubEvent} if ( $recipient =~ /^(\x23|\x26|\x2B)/ );
        $irc->_send_event( $event => [ $recipient ] => $text );
      }
    }
  }
  return PCI_EAT_NONE;
}

1;

__END__

=head1 NAME

POE::Component::IRC::Plugin::BotTraffic - A PoCo-IRC plugin that generates 'irc_bot_public', 'irc_bot_msg', and 'irc_bot_action' events whenever your bot sends privmsgs.

=head1 SYNOPSIS

  use POE::Component::IRC::Plugin::BotTraffic;

  $irc->plugin_add( 'BotTraffic', POE::Component::IRC::Plugin::BotTraffic->new() );

  sub irc_bot_public {
    my ($kernel,$heap) = @_[KERNEL,HEAP];
    my ($channel) = $_[ARG0]->[0];
    my ($what) = $_[ARG1];

    print "I said '$what' on channel $channel\n";
  }

=head1 DESCRIPTION

POE::Component::IRC::Plugin::BotTraffic is a L<POE::Component::IRC|POE::Component::IRC> plugin. It watches for when your bot sends privmsgs to the server. If your bot sends a privmsg to a channel ( ie. the recipient is prefixed with '#', '&' or '+' ) it generates an 'irc_bot_public' event, otherwise it will generate an 'irc_bot_msg' event.

These events are useful for logging what your bot says.

=head1 METHODS

=over

=item new

No arguments required. Returns a plugin object suitable for feeding to L<POE::Component::IRC|POE::Component::IRC>'s plugin_add() method.

=back

=head1 OUTPUT

These are the events generated by the plugin. Both events have ARG0 set to an arrayref of recipients and ARG1 the text that was sent.

=over

=item irc_bot_public

ARG0 will be an arrayref of recipients. ARG1 will be the text sent.

=item irc_bot_msg

ARG0 will be an arrayref of recipients. ARG1 will be the text sent.

=item irc_bot_action

ARG0 will be an arrayref of recipients. ARG1 will be the text sent.

=back

=head1 AUTHOR

Chris 'BinGOs' Williams [chris@bingosnet.co.uk]

=head1 SEE ALSO

L<POE::Component::IRC>
