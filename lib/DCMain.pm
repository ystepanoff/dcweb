package DCMain;

use strict;
use warnings;
use IO::Socket;
use Text::Iconv;

$DCMain::version = "2.0.0";

sub new
{
    my $pack = shift;

    my %args;
    while ($#_ > 0) { $_ = shift; $args{$_} = shift; }

    my $self = bless
    {
        version			=> $DCMain::version,
        host			=> "",
        port			=> 411,
        nick			=> '',
       	pass			=> '',
       	description		=> "DCWeb",
       	tags			=> "",
       	connection		=> 100,
       	icon			=> 16,
       	email			=> "",
       	share			=> 0,
       	maxlen			=> 65536,
       	time_lag		=> 600,
       	hub_enc			=> "windows-1251",
       	shell_enc		=> "UTF-8",
       	convhs			=> '',
       	convsh			=> '',

       	parity			=> 0,
       	socket			=> ''
    }, $pack;

    $args{host} =~ s/\$/&#36;/g; $args{host} =~ s/\|/&#124;/g;
    $args{nick} =~ s/\$/&#36;/g; $args{nick} =~ s/\|/&#124;/g;
    $args{password} =~ s/\$/&#36;/g; $args{password} =~ s/\|/&#124;/g;

    $self->{host} = $args{host} if $args{host};
    $self->{nick} = $args{nick} if $args{nick};
    $self->{pass} = $args{password} if $args{password};

    $self->{convhs} = Text::Iconv->new($self->{hub_enc}, $self->{shell_enc});
    $self->{convsh} = Text::Iconv->new($self->{shell_enc}, $self->{hub_enc});

    return $self;
}

sub time_lag
{
    my $self = shift;
    return $self->{time_lag};
}

sub lock2key($)
{
    my @lock = split(//, shift);
    my @key = ();

    map {$_ = ord} @lock;
    push(@key, $lock[0]^5);

    for (my $i = 1; $i < @lock; $i++)
    {
        push(@key, ($lock[$i]^$lock[$i - 1]));
    }

    for (my $i = 0; $i < @key; $i++)
    {
        $key[$i] = ((($key[$i] << 4) & 240) | (($key[$i] >> 4) & 15)) & 0xff;
    }

    $key[0] ^= $key[@key - 1];

    foreach (@key)
    {
        $_ = ($_ == 0 || $_ == 5 || $_ == 36 || $_ == 96 || $_ == 124 || $_ == 126) ? sprintf('/%%DCN%03i%%/', $_) : chr;
    }

    return join('', @key);
}

sub connect
{
    my $self = shift;

    $self->{socket} = new IO::Socket::INET(PeerAddr => $self->{host},
					                       PeerPort => $self->{port},
					                       Proto    => 'tcp',
					                       Type     => SOCK_STREAM) || die $!;

    my ($data, $lock);

    $self->{socket}->recv($data, $self->{maxlen});
    $data =~ m/Pk=(.+?)\|/; $lock = $1;

    my $supports = "";

    if ($lock eq "PtokaX")
    {
        ($lock) = $data =~ m/EXTENDEDPROTOCOL(.+?)\s/;
        $supports = "\$Supports UserCommand NoGetINFO NoHello UserIP2 TTHSearch ZPipe0 |";
    }

    my $key = lock2key($lock);

    $self->{socket}->send($supports."\$Key ".$key."|\$ValidateNick ".$self->{convsh}->convert($self->{nick})."|");
    $self->{socket}->recv($data, $self->{maxlen});

    if ($data !~ /(\$Hello|\$GetPass)/)
    {
        $self->{socket}->recv($data, $self->{maxlen});
    }

    # Another try

    if ($data !~ /(\$Hello|\$GetPass)/)
    {
        $self->{socket}->recv($data, $self->{maxlen});
    }

    # And one more time

    if ($data !~ /(\$Hello|\$GetPass)/)
    {
        $self->{socket}->recv($data, $self->{maxlen});
    }

    if ($data =~ m/\$GetPass\|/)
    {
        $self->{socket}->send("\$MyPass ".$self->{pass}."|");
        $self->{socket}->recv($data, $self->{maxlen});

        if ($data =~ m/^\$BadPass/)
        {
            return 0;
        }
    }

    if ($data !~ m/\$Hello (.+?)\|/)
    {
        return 0;
    }

    $self->{socket}->send("\$Version ".$self->{version}."|\$MyINFO \$ALL ".
                $self->{convsh}->convert($self->{nick})." ".
                $self->{description}.$self->{tags}."\$ \$".
                $self->{connection}.chr($self->{icon})."\$".
                $self->{email}."\$".$self->{share}."\$|");

    return 1;
}

sub disconnect
{
    my $self = shift;
    $self->{socket}->close();
}

sub receive
{
    my $self = shift;

    my $data;
    $self->{socket}->recv($data, $self->{maxlen});

    return unless $data;

    $data = $self->{convhs}->convert($data);

    my ($to, $from, $message, $status);

    if ($data =~ m/(^|\|)((\*.+?|<.+?>) .*?)\|/s)
    {
        $data = $2;

        if ($data =~ m/<(.+?)>\s(.+)/s)
        {
            return ("", $1, $2, 0);
        } elsif ($data =~ m/\*\*\s(.+)/s)
        {
            return ("", "", $1, 1);
        }
    } elsif ($data =~ m/^\$To: (\S+) From: (\S+) \$<(.+?)> (.*?)\|/s)
    {
        return ($1, $2, $4, 2);
    }

    return 0;
}

sub send
{
    my ($self, $message) = @_;
    return unless $message;

    $message = $self->{convsh}->convert($message);
    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $message .= " " if $self->{parity} == 1;
    $self->{parity} = ($self->{parity} + 1) % 2;

    $self->{socket}->send("<".$self->{convsh}->convert($self->{nick})."> ".$message."|");
}

sub send_noparity
{
    my ($self, $message) = @_;
    return unless $message;

    $message = $self->{convsh}->convert($message);
    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $self->{socket}->send("<".$self->{convsh}->convert($self->{nick})."> ".$message."|");
}

sub send_asis
{
    my ($self, $message) = @_;
    return unless $message;

    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $message .= " " if $self->{parity} == 1;
    $self->{parity} = ($self->{parity} + 1) % 2;

    $self->{socket}->send("<".$self->{convsh}->convert($self->{nick})."> ".$message."|");
}

sub send_asis_noparity
{
    my ($self, $message) = @_;
    return unless $message;

    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $self->{socket}->send("<".$self->{convsh}->convert($self->{nick})."> ".$message."|");
}

sub send_pm
{
    my ($self, $user, $message) = @_;
    return unless $user;
    return unless $message;

    $message = $self->{convsh}->convert($message);
    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $self->{socket}->send("\$To: ".$self->{convsh}->convert($user).
                        " From: ".$self->{convsh}->convert($self->{nick}).
                        " \$<".$self->{convsh}->convert($self->{nick}).
                        "> ".$message."|");
}

sub send_pm_asis
{
    my ($self, $user, $message) = @_;
    return unless $user;
    return unless $message;

    $message =~ s/\$/&#36;/g; $message =~ s/\|/&#124;/g;

    $self->{socket}->send("\$To: ".$self->{convsh}->convert($user).
                        " From: ".$self->{convsh}->convert($self->{nick}).
                        " \$<".$self->{convsh}->convert($self->{nick}).
                        "> ".$message."|");
}

1;
