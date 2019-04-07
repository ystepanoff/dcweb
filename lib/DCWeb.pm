package DCWeb;

use Mojo::Base 'Mojolicious';
use DCData;
use DCMain;
use DCTools;
use CGI;
use HTML::Entities;

use utf8;

$DCWeb::title = "dc++ chat web client";

my %handlers;

sub startup
{
    my $self = shift;
    my $db = new DCData;
    my $tools = new DCTools;

    $self->secret('dcpp_web_client_2.0');
    $self->helper(db => sub { return $db });

    $self->renderer->encoding('utf-8');
    $self->types->type(json => 'application/json; charset=utf-8');

    my $r = $self->routes;

    $r->any('/css' => sub
    {
	my $self = shift;
	$self->res->headers->content_type('text/css; charset=utf-8');
	$self->res->content->asset(Mojo::Asset::File->new(path => "static/chat.css"));
	$self->rendered(200);
    });

    $r->any('/js' => sub
    {
	my $self = shift;
	$self->res->headers->content_type('text/javascript; charset=utf-8');
	$self->res->content->asset(Mojo::Asset::File->new(path => "static/chat.js"));
	$self->rendered(200);
    });

    $r->any('/messages' => sub
    {
	my $self = shift;
	my $cnt = $self->param("cnt");

	$cnt = 40 if !$cnt;
	$cnt = int($cnt);

	$self->render_json($db->get_last_messages($cnt));
    });

    $r->any('/from_id' => sub
    {
	my $self = shift;
	my $id = int($self->param("id"));
	$self->render_json($db->get_messages_from_id($id));
    });

    $r->post('/send' => sub
    {
	my $self = shift;
	my $cookie = $self->param("hash");
	my $message = $self->param("message");

	if ($handlers{$cookie} && $message)
	{
	    utf8::decode($message);
	    $message = HTML::Entities::encode_entities_numeric($message, '^\n\x20-\x7e\x{410}-\x{44f}\x{401}\x{451}\x{2014}\x{ab}\x{bb}');

	    if ($message =~ /\.set_lastfm/)
	    {
		$message =~ s/^\s+//;
		$message =~ s/\s+$//;
		my @tokens = split(/ /, $message);

		if ($tokens[0] eq '.set_lastfm' && $#tokens >= 1)
		{
		    $db->set_lastfm_account($db->get_nick($cookie), $tokens[1]);
		} else
		{
		    $handlers{$cookie}->send($message);
		}
	    } elsif ($message =~ /\.np/)
	    {
		$message =~ s/^\s+//;
		$message =~ s/\s+$//;

		if ($message eq '.np')
		{
		    my $lastfm = $db->get_lastfm_account($db->get_nick($cookie));
		    chomp $lastfm;

		    if ($lastfm)
		    {
			my $nowplaying = $tools->now_playing($lastfm);
			#utf8::encode($nowplaying);

			if ($nowplaying)
			{
			    utf8::decode($nowplaying);
			    $nowplaying = HTML::Entities::encode_entities_numeric($nowplaying, '^\n\x20-\x7e\x{410}-\x{44f}\x{401}\x{451}\x{2013}\x{2014}\x{ab}\x{bb}');
			    $handlers{$cookie}->send("+me is listening to ".$nowplaying);
			}
		    }
		} else
		{
		    $handlers{$cookie}->send($message);
		}
	    } else
	    {
		$handlers{$cookie}->send($message);
	    }
	}

	$self->render(template => 'send');
    });

    $r->any('/dc' => sub
    {
	my $self = shift;
	my $cookie = $self->cookie('dcpp_web');
	my $nick = $db->get_nick($cookie);

	if ($nick)
	{
	    $self->stash(user => $nick);
	    $self->stash(hash => $cookie);
	    $self->render(template => 'index_user');
	} else
	{
	    $self->render(template => 'index_common');
	}
    });

    $r->any('/login' => sub
    {
	my $self = shift;
	my $login = $self->param("login");
	my $password = $self->param("password");

	my $cookie = $tools->random_string(32);
	$handlers{$cookie} = DCMain->new(nick => $login, password => $password);

	if ($handlers{$cookie}->connect)
	{
            $db->clear_logins($login);
	    $db->set_user_cookie($login, $cookie);
	    $self->cookie('dcpp_web' => $cookie);

	    $self->stash(result => ':)');
	} else
	{
	    $self->stash(result => ':(');
    	}

	$self->render(template => 'login_result');
    });

    $r->any('/logout' => sub
    {
	my $self = shift;
	my $cookie = $self->cookie('dcpp_web');

	if ($handlers{$cookie})
	{
	    $handlers{$cookie}->disconnect();
	    delete $handlers{$cookie};
	}

	$db->reset_user_cookie($cookie);

	$self->redirect_to("/dc");
    });

    $r->any('/preloader' => sub
    {
	my $self = shift;
	$self->res->headers->content_type('image/gif');
	$self->res->content->asset(Mojo::Asset::File->new(path => "static/preloader.gif"));
	$self->rendered(200);
    });

    $r->any('/404' => sub
    {
	my $self = shift;
	$self->res->headers->content_type('image/jpeg');
	$self->res->content->asset(Mojo::Asset::File->new(path => "static/404.jpg"));
	$self->rendered(200);
    });

    $r->any('/(*)' => sub
    {
	my $self = shift;
	$self->render_not_found();
    });
}

1;
