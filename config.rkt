#lang racket

;;; Leave this line alone. It's just saying to provide everything
;;; defined in this file to the rest of the program.
(provide (all-defined-out))

;;; Now on to the configuration! Aren't we excited?!
;;; I am, but I'm a fairly borning person.
;;; Don't judge me.

(define user-name
  ;; This is where you put in your name to TRUELY CUSTOMIZE THE EXPERIENCE!!!!!
  ;; Go nuts.
  "Wesley")

(define media-directory
  ;; Where you're keeping all your videos and movie backups.
  ;; I just dump all mine into ~/Videos so I can find them easier.
  ;; Set this to whatever path you use.
  "/home/wesley/Videos")

(define chunk-size
  ;; Because video output can be pretty big, choosing a good chunk
  ;; size can save a lot of frustration.  This system isn't designed
  ;; to run on heavy hardware, so it's only really just a megabyte per
  ;; page we'll be writing out by default. This gives more space for
  ;; the video cache, and LAN latency shouldn't be horrible enough that
  ;; a measly 1MB per page will cause issues. If you're on a slow/busy
  ;; LAN, maybe a bigger page is what you need. If you're doing this
  ;; on an embeddable, like an Arduino or RPi, you might want to use a
  ;; smaller page.
  1048576)

(define movie-player-path
  ;; This should be the full-path to the movie player that you want to
  ;; use. Since Grindhouse lets you interrupt movies with other movies
  ;; and only lets you watch one at a time (on the TV for now, but
  ;; streaming is planned for later), it needs to actually find and
  ;; run the video player directly instead of relying on a shell
  ;; process to handle it.
  "/usr/bin/vlc")

(define movie-player-args
  ;; This should contain a list of arguments you want to pass your
  ;; movie player whenever a movie is played.  Keep this list as
  ;; general as possible since Grindhouse will try to use them with
  ;; every video you've got!
  '("--fullscreen"))
