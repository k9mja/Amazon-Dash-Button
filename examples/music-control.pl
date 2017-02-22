#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Amazon::Dash::Button ();

use constant MPC => q{/usr/bin/mpc};

die
  "You should run this script as root. Please run:\nsudo $0 [en0|eth0|wlan0]\n"
  if $>;

my $device = $ARGV[0] || q{wlan0};

my @all_hosts = qw{
    salon.pi.eboxr.com
    mezza.pi.eboxr.com
    bed.pi.eboxr.com
    127.0.0.1
};

my $CURRENT_HOST = q{127.0.0.1};

# $CURRENT_HOST = q{salon.pi.eboxr.com};
# my $x = q{NAS/QNap/Tidals/Focus/Tidal Focus/05 Threnody.mp3};
# _move_song_to_trash( $x );
# exit;

Amazon::Dash::Button->new( dev => $device, )->add(
    name    => 'KY',
    mac     => '34:d2:70:9f:bf:04',
    onClick => sub {
        my $self = shift;
        print "clicked ! from the KY button\n";
        $CURRENT_HOST = q{127.0.0.1};
        start_stop_bedroom();
    },
    _fork_for_onClick => 0,    # fast enough do not need to fork there
  )->add(
    name    => 'Trojan',
    mac     => '68:54:fd:b5:2d:a0',
    onClick => sub {
        my $self = shift;
        print "clicked ! from the Trojan button\n";
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        $CURRENT_HOST = q{127.0.0.1};
        if ( $hour > 6 && $hour <= 20 ) {
            start_or_clean_and_next_song();
        } else {
            go_to_bed();    
        }
    },
  )->add(
    name    => 'ON Kitchen',
    mac     => '50:f5:da:2a:62:4f',
    onClick => sub {
        my $self = shift;
        $CURRENT_HOST = q{salon.pi.eboxr.com};
        print "clicked ! from the Kitchen button\n";
        start_or_clean_and_next_song();
    },
)->listen;

sub start_or_clean_and_next_song {
    # start the music if nothing is playing it
    my $host = which_host_is_playing();
    if ( !$host ) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        my %opts = ( dir => 'NAS/QNap/random', volume => 35 );
        if ( $wday == 0 || $wday == 6 ) {
            # during the weekend use mezza
            $CURRENT_HOST = q{mezza.pi.eboxr.com};
            delete $opts{volume}; # do not move the volume on snapcast
        }
        # music is not playing let's start it using the default CURRENT_HOST
        
        return start( %opts );
    }
    $CURRENT_HOST = $host; # not a big deal this is done in a forked process
    # # mpc -h salon.pi.eboxr.com --format \"[%file%]\"
    my @out = split "\n", mpc( '--format', q{"[%file%]"} ) // '';
    my $listening_file = $out[0];
    mpc( 'next' ); # play the next song
    # now we can move the previous song to another folder
    _move_song_to_trash($listening_file);

    return;
}

sub _move_song_to_trash {
    my $f = shift or return;
    return unless length $f;
    $f =~ s{^NAS/QNap}{/multimedia/Music};

    if ( $f =~ qr{"} ) {
        warn "File '$f' contains some double quotes... skipping";
        next;
    }

    print qx{ssh -t sab\@sab.eboxr.com 'echo "Moving file..."; echo "$f" >> /multimedia/tmp/Music/trash.log; mv "$f" /multimedia/tmp/Music/'};
    # do the md5sum only if it s in random directory
    # if not found check the files... (with same size ?) then md5
    return;
}

sub go_to_bed {

    return mpc('stop') if is_mpc_playing();

    my @decrease = (

        # volume , time in minute
        [ 10, 2 ],
        [ 9,  2 ],
        [ 8,  5 ],
        [ 7,  5 ],
        [ 6,  20 ],
        [ 5,  10 ],
        [ 4,  2 ],
    );

    mpc('stop');
    mpc('clear');

    #mpc('add', 'NAS/QNap/random' );
    mpc( 'add', 'NAS/QNap/Musique\ Classique' );
    mpc('shuffle');
    volume( $decrease[0]->[0] );    # set the volume at the beginning
    tlog("start play...");
    mpc('play');

    foreach my $rule (@decrease) {
        my ( $volume, $time ) = @$rule;
        tlog("volume at $volume for $time minutes");
        volume($volume);
        sleep( 60 * $time );
    }

    mpc('stop');

    return;
}

sub start_stop_bedroom {    
    # if localhost is playing stop it
    return mpc('stop') if is_mpc_playing();

    # if the multiroom is playing do nothing
    my $host = which_host_is_playing();
    return if $host && $host eq 'mezza.pi.eboxr.com';

    # else then just start some music for the bathroom
    start( dir => 'NAS/QNap/Compilations', volume => 65 );

    return;
}

sub start {
    my ( %opts ) = @_;
    
    my $folder = $opts{dir} // 'NAS/QNap/random';

    mpc( 'stop' );
    mpc( 'clear' );
    mpc( 'add', $folder );
    mpc( 'shuffle' );
    volume($opts{volume}) if defined $opts{volume} && $opts{volume} =~ qr{^[0-9]$};
    mpc( 'play' );

    return;
}

sub is_mpc_playing {
    my @args = @_;

    my $cmd = join ' ', MPC, @args;
    my $out = qx{$cmd 2>&1};
    return 0 if $? != 0;
    return $out && $out =~ qr{^\[playing\]}mi ? 1 : 0;
}

sub which_host_is_playing {
    foreach my $h ( @all_hosts ) {
        return $h if is_mpc_playing( '-h', $h );
    }
    return;
}

sub mpc {
    my @args = @_;

    if ( length $CURRENT_HOST && $CURRENT_HOST ne '127.0.0.1' && ! grep { $_ eq '-h' } @args ) {
        unshift @args, '-h', $CURRENT_HOST;
    }

    my $cmd = join " ", MPC, @args;
    return qx{$cmd 2>&1};
}

sub volume {
    my $v = shift;
    tlog("set volume to $v");
    return mpc( 'volume', $v );
}

sub tlog {    # dummy helper to print timed log
    print STDERR join( ' ', @_, "\n" );
    return;
}
