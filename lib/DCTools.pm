package DCTools;

use strict;
use warnings;
use utf8;
use LWP::Simple;
use XML::Simple;
use Data::Dumper;

our $lastfm_api_key = "";
our $recent_tracks_url = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&api_key=".$lastfm_api_key."&user=";

sub new
{
    my $pack = shift;

    my $self = bless
    {
    }, $pack;


    return $self;
}

sub random_string
{
    my ($self, $length) = @_;

    my @chars = ('a'..'z','A'..'Z','0'..'9','_');
    my $string = "";

    foreach (1..$length)
    {
	$string .= $chars[rand @chars];
    }

    return $string;
}

sub now_playing
{
    my ($self, $user) = @_;
    return '' unless $user;

    my $response = get($recent_tracks_url.$user);
    return '' unless $response;

    my $rt = XMLin($response, ForceArray => 1);

    if ($rt && $rt->{recenttracks})
    {
	foreach my $track (@{$rt->{recenttracks}->[0]->{track}})
	{
	    if ($track->{nowplaying} && $track->{nowplaying} eq 'true')
	    {
		return $track->{artist}->[0]->{content}." – ".$track->{name}[0];
	    }
	}
    }

    return '';
}

1;
