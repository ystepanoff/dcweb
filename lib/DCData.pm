package DCData;

use strict;
use warnings;
use DBI;
use JSON;
use utf8;

sub new
{
    my $pack = shift;

    my $self = bless
    {
        login		=> '', # DB login
        password	=> '', # DB password
        db_name		=> 'chat',
        dhhd		=> '',
        json		=> ''
    }, $pack;

    $self->{json} = JSON->new->allow_nonref;

    return $self;
}

sub disconnect
{
    my $self = shift;
    $self->{dbhd}->disconnect || return 0;
    return 1;
}

sub encode_string
{
    my $string = shift;
    return '' unless $string;

    $string =~ s/'/''/g;
    $string =~ s/\\/\\\\/g;

    return $string;
}

sub decode_string
{
    my $string = shift;
    return '' unless $string;

    $string =~ s/''/'/g;
    $string =~ s/\\\\/\\/g;

    utf8::decode($string);

    return $string;
}

sub add_message
{
    my ($self, $time, $user, $message, $status) = @_;
    return 0 unless $time;
    return 0 unless $message;

    $user = encode_string($user);
    $message = encode_string($message);

    #print $message."\n";

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    $self->{dbhd}->do("INSERT INTO messages (time,nick,message,status) VALUES ('$time','$user','$message','$status');");
}

sub get_last_messages
{
    my ($self, $k) = @_;
    return '[]' unless $k;

    $k = 10000 if $k > 10000;

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    my $sth = $self->{dbhd}->prepare("SELECT * FROM (SELECT * FROM messages ORDER BY id DESC LIMIT $k) AS T1 ORDER BY id ASC;");
    $sth->execute;

    my @messages;

    while (my $message = $sth->fetchrow_hashref)
    {
        $message->{nick} = decode_string($message->{nick});
        $message->{message} = decode_string($message->{message});
        push(@messages, $message);
    }

    $sth->finish;

    return \@messages;
}

sub get_messages_from_id
{
    my ($self, $id) = @_;
    return '[]' unless $id;

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    my $sth = $self->{dbhd}->prepare("SELECT id FROM messages ORDER BY id DESC LIMIT 1;");
    $sth->execute;

    my $last_id = $sth->fetchrow_array;
    return '[]' if ($last_id - $id > 1000);
    $sth->finish;

    $sth = $self->{dbhd}->prepare("SELECT * FROM messages WHERE id>?;");
    $sth->execute($id);

    my @messages;

    while (my $message = $sth->fetchrow_hashref)
    {
        $message->{nick} = decode_string($message->{nick});
        $message->{message} = decode_string($message->{message});
        push(@messages, $message);
    }

    $sth->finish;

    return \@messages;
}

sub clear_logins
{
    my ($self, $login) = @_;
    return unless $login;

    $self->{dbdh} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    $self->{dbhd}->do("DELETE FROM logins WHERE nick='".encode_string($login)."';");
}

sub set_user_cookie
{
    my ($self, $login, $cookie) = @_;
    return unless $login;
    return unless $cookie;

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    $self->{dbhd}->do("INSERT INTO logins (nick, cookie) VALUES ('".encode_string($login)."', '".$cookie."');");
}

sub reset_user_cookie
{
    my ($self, $cookie) = @_;
    return unless $cookie;

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    $self->{dbhd}->do("DELETE FROM logins WHERE cookie='".$cookie."';");
}

sub get_nick
{
    my ($self, $cookie) = @_;
    return '' unless $cookie;

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    my $sth = $self->{dbhd}->prepare("SELECT nick FROM logins WHERE cookie='".$cookie."';");
    $sth->execute;

    if (my $nick = $sth->fetchrow_array)
    {
        return decode_string($nick);
    }

    return '';
}

sub set_lastfm_account
{
    my ($self, $nick, $lastfm) = @_;
    return unless $nick;
    return unless $lastfm;

    $nick = encode_string($nick);
    $lastfm = encode_string($lastfm);

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    my $sth = $self->{dbhd}->prepare("SELECT lastfm_account FROM lastfm WHERE nick='".$nick."';");
    $sth->execute;

    my $cnt = $sth->rows;
    $sth->finish;

    if ($cnt == 0)
    {
        $self->{dbhd}->do("INSERT INTO lastfm (nick, lastfm_account) values ('".$nick."', '".$lastfm."')");
    } else
    {
        $self->{dbhd}->do("UPDATE lastfm SET lastfm_account='".$lastfm."' WHERE nick='".$nick."';");
    }
}

sub get_lastfm_account
{
    my ($self, $nick) = @_;
    return '' unless $nick;

    $nick = encode_string($nick);

    $self->{dbhd} ||= DBI->connect("DBI:mysql:".$self->{db_name}, $self->{login}, $self->{password});
    $self->{dbhd}->{mysql_auto_reconnect} = 1;

    my $sth = $self->{dbhd}->prepare("SELECT lastfm_account FROM lastfm WHERE nick='".$nick."';");
    $sth->execute;

    if (my $lastfm = $sth->fetchrow_array)
    {
        return $lastfm;
    }

    $sth->finish;
    return '';
}

1;
