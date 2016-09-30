# Grindhouse

PRIVATE video access "web" app. Mostly because Dad wanted something
like this and didn't know to ask for it. Just run it on some kind of
unused computer you've got lying around while it's plugged into a TV.

I know the fuzz might come a-knocking about this thing, so I'll just
point out that in no way is Grindhouse is even designed to run on the
Internet at large. If you do it, or try to do it, it's your own damn
fault if it sets fires or gets you into trouble.

YMMV quite severely. If you've got fixes, workarounds or general
advice to make this thing serve correctly to common devices, then
pulls/issues are welcome.

What isn't are feature requests, oddly enough. Grindhouse is
considered feature-complete since it's intended scope is very limited
to begin with. Only future pushes will ensure that it continues to run
on the latest Racket distos, or fixes weirdness with other
browsers/phones/tablets outside of what I have within reach of my
desk.

## Features:

It plays movies, hopefully full-screen, on a TV. No special hardware
required outside of an old junker computer you were too lazy to throw
away with HDMI or composite outputs.

Also it'll serve the movie files themselves, just in case you can't,
or can't be bothered to, go to the TV to watch the thing.

If you're like me, and enjoy having non-distributed backups of DVDs
and Bluerays that you **purchased legally**, then Grindhouse will page
out to the OMDB to get some stats on your film based on the filename
of your backup.

Maybe a future feature would eventually be caching and customization
of a video's info... if I get around to it.

## Quick-ish Start:

First, find a computer lying around that nobody uses any more. You
don't need anything beefy, just enough to run some modern Linux distro
that ships with a GUI and some kind of multi-monitor support.

Second, set it up! Here are some things to do in no particular order:

- Install Racket, VLC (or any media player that works with all your
  private videos) and some kind of text editor. I am assuming that you
  installed some kind of Debian knockoff:
  ```shell
  $ sudo apt-get install racket vlc gedit
  ```

- Plug it into your TV via some kind of HDMI output that's all the
  rage these days. If your computer is too old to have one, then just
  connect it to a **REALLY BIG** monitor and plug in some awesome
  speakers. Now mirror the two displays, that is if the TV/humongous
  monitor isn't the only display on this system.

- Mess around with `config.rkt`. This is a source file that has some
  nice options to help you customize some of the things that Grindhouse
  will try to do.

  - `user-name` should be your name, not mine.

  - `media-directory` should point to where you like to keep your
    private video collection.

  - `movie-player-path` should be the absolute path to your favorite
    movie player.

  - `movie-player-args` are arguments that are passed to the movie
    player when a video is played. At least have what you would use to
    play the video in fullscreen here.  If you edited
    `movie-player-path`, you might want to edit this too.

- Futz with your router. Go into your router settings for it's DHCP
  service and reserve a static IP for your Gindhouse box. Name it
  something memorable, like "Grindhouse". Also write down the IP
  address you gave it.

Third, Fire it up:
```shell
$ sudo PORT=80 racket server.rkt
```

Fouth: Profit!

Grab your phone or tablet, open a browser and point it to
`http://Grindhouse` and you'll see your viewing options.

If that didn't work, then just `http://x.x.x.x`, where `x.x.x.x` is
the IP address that you gave your Grindhouse server. If you had to use
an IP address to get there, you should bookmark it.

## Problems you might have:

#### DHCP settings didn't seem to take

Reboot both your Grindhouse box and the router. Make sure that the
Grindhouse server is started. Also double-check your router's DHCP
settings to see that you've indeed allocated a static IP for your
Grindhouse box and _you know what it is_.

#### Videos don't play on the TV

Check to see that you've got the right settings in `config.rkt`. Make
sure that `movie-player-path` is an absolute path to your video player
and not just the command name used to fire it up.

Also make sure that the video player that you're using can actually
open the thing.

#### Grindhouse can't find my movies!

Check to see that `media-directory` is an absolute path to where you
keep your videos. Understand that Grindhouse will _ignore_ hidden
files and directories (anything that starts with '.'), so your
_really_ private videos remain that way.

#### Grindhouse won't play the movie on my phone

Probably because your phone doesn't have the right app/codec for it?
Try going to your TV and watching it there.

#### Grindhouse only works when I'm at home!

Yeah. It was desinged to do that. Why are you trying to watch a TV
that you're not even near?

#### It's ugly

And I'm highly color-sensitive. I'm also not an artist. If you want to
fix it yourself and got the time to dig around in uncooked CSS, then
feel free to mess with `public/custom.css` to your heart's content.
Make a pull request with your styles and I'll merge it in if it's hawt
enough.

Grindhouse uses Bootstrap's CSS framework for it's mobile-friendly
styles. I feel _very_ strongly about this and it's not going to
change.

## Biblio

The projects _used_ in Grindhouse:

[Racket](http://www.racket-lang.org) is what implements the thing.

[OMDB](http://omdbapi.com) is where your film's info comes from.

[Bootstrap](http://getbootstrap.com) is the super-easy styling
framework that makes this look good on your phone.
