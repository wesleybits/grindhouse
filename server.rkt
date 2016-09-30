#lang racket

(require web-server/servlet-env
         web-server/servlet
         net/http-client
         racket/splicing
         racklog
         json
         "config.rkt")

(provide start refresh-db)

(define (response/xexpr5 xexpr
                         #:code [code 200]
                         #:message [message #"Okay"]
                         #:seconds [seconds (current-seconds)]
                         #:mime-type [mime-type TEXT/HTML-MIME-TYPE]
                         #:headers [headers '()]
                         #:cookies [cookies '()])
  (response/xexpr xexpr
                  #:preamble #"<!DOCTYPE html>"
                  #:code code
                  #:message message
                  #:seconds seconds
                  #:mime-type mime-type
                  #:headers headers
                  #:cookies cookies))

;;; Utilities that help build the pages and model

(define (in-char-range first-char last-char)
  (if (char>=? first-char last-char)
      (list last-char)
      (cons first-char
            (in-char-range ((compose integer->char add1 char->integer)
                            first-char)
                           last-char))))

(define root (current-directory))

(define (strip-extension p)
  (path-replace-extension p ""))

(define (rx-extract-name str)
  (regexp-match #px"^(.*)\\..{3,4}$"
                str))

(define (rx-clean str)
  (regexp-replace* #px"[_\"':]+" str " "))

(define path->video-name (compose string-trim
                                  rx-clean
                                  second
                                  rx-extract-name
                                  path->string
                                  last
                                  explode-path))

(define ((is? . regexps) str)
  (ormap (λ (pat) (regexp-match? pat str))
         regexps))

(define/match (path->mime-type name)
  [((? (is? #px"[.]webm$") _))
   "video/webm"]
  [((? (is? #px"[.]mkv$") _))
   "video/x-matroska"]
  [((? (is? #px"[.]ogg$" #px"[.]ogv$")))
   "video/ogg"]
  [((? (is?  #px"[.]mp4") _))
   "video/mp4"]
  [((? (is? #px"[.]avi$") _))
   "video/avi"]
  [((? (is?  #px"[.]wmv$") _))
   "video/x-ms-wmv"]
  [((? (is? #px"[.]wm$") _))
   "video/x-ms-wm"]
  [(_) #f])

;;; Model code! Using Racklog to drive a small in-memory DB

(define %video %empty-rel)

(define %video-starts-with
  (%rel (char name path mime)
   [('number name path mime)
    (%and (%video name path mime)
          (%is #t (regexp-match? #px"^\\d" name)))]
   [('symbol name path mime)
    (%and (%video name path mime)
          (%is #t (regexp-match? #px"^[^0-9a-zA-Z]" name)))]
   [(char name path mime)
    (%and (%video name path mime)
          (%is #t (char? char))
          (%is #t (char-ci=? char (string-ref name 0))))]))

(define (%count thing)
  (if (not thing) 0
      (add1 (%count (%more)))))

(define (num-videos-starts-with char)
  (%count (%which () (%video-starts-with char (_) (_) (_)))))

(define (video-exists? path)
  (%which () (%video (_) path (_))))

(define (refresh-db)
  (define %new-video-cache %empty-rel)

  (define (add-video! path)
    (%assert! %new-video-cache () ([(path->video-name path) path (path->mime-type path)])))

  (for ([file (in-directory media-directory)]
        #:when (and (not (regexp-match? #px"/\\." file)) ; no private files
                    (path->mime-type file)))
    (add-video! file))

  (set! %video %new-video-cache))

;;; Process control! This lets us play exactly one movie at a time on the TV!

(splicing-let ([film-name #f]
               [controller #f]
               [job #f])

  (define (exec/stop-film)
    (when film-name (controller 'kill))
    (when job (thread-wait job)))

  (define (exec/play-film film)
    (exec/stop-film)

    (match-define (list-no-order (cons 'name name)
                                 (cons 'path path)
                                 _ ...)
      film)

    (set! film-name name)

    (match-define (list sub-sdtin sub-stdout pid sub-stderr control)
      ((compose (curry apply process* movie-player-path)
                (curry append movie-player-args)
                list)
       path))

    (set! controller control)
    (set! job
          (thread
           (λ ()
             (control 'wait)
             (set! controller #f)
             (set! film-name #f)
             (set! job #f)))))

  (define (currently-playing-movie) film-name))

;;; Web code ahead! HTML templates and page renderers fer yah.

(define (headers)
  `((meta ([name "viewport"]
           [content "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"]))
    ;; gets BOOTSTRAP CSS
    (link ([rel "stylesheet"]
           [href "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"]
           [integrity "sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u"]
           [crossorigin "anonymous"]))
    ;; gets custom overrides so everything looks _PERFECT_
    (link ([rel "stylesheet"]
           [href "/public/custom.css"]))
    ;; gets JQuery 3.x
    (script ([src "https://code.jquery.com/jquery-3.1.1.min.js"]
             [type "text/javascript"]))))

(define (top-bar [mesg #f] [tagline #f])
  `(div ([id "top"]
         [tabindex "-1"])
        (div ([class "container"])
             (h1 ,(or mesg (~a user-name "'s Grindhouse")))
             (p ,(or (and (currently-playing-movie)
                          (~a "Now showing: " (currently-playing-movie)))
                     tagline
                     "The Gridhouse private movies server and stuff")))))

(define ((play-film film) req)
  (exec/play-film film)
  ((show-film-details film) (redirect/get)))

(define ((show-film-details film) req)
  (match-define (list-no-order (cons 'name name)
                               (cons 'path path)
                               (cons 'mime mime))
                film)

  (define q-name (regexp-replace* #px"\\s+" name "+"))
  (define omdb-host "www.omdbapi.com")
  (define omdb-uri (format "/?t=~a&y=&plot=short&r=json" q-name))
  (define-values (omdb/status omdb/headers omdb/input)
    (http-sendrecv omdb-host omdb-uri))

  (define omdb/response (delay (read-json omdb/input)))
  (define success?
    (and (regexp-match? #px"200" omdb/status)
         (equal? "True" (hash-ref  (force omdb/response) 'Response #f))))

  (define (format-field field [alt #f])
    `(div ([class "row"]
           [style "margin-top:10px;border-top:thin solid grey;"])
          (div ([class "col-md-2"]) (b ,(or alt (symbol->string field))))
          (div ([class "col-md-8"]) (p ,(hash-ref (force omdb/response) field "Unprovided/Unknown")))))

  (define (response-generator embed/url)
    (response/xexpr5
     `(html ([lang "en"])
            (head (title ,user-name "'s Grindhouse - " ,name)
                  ,@(headers))
            (body ,(top-bar name)
                  (div ([class "container"])
                       ,@(if success?
                             (list (format-field 'Year)
                                   (format-field 'Rated)
                                   (format-field 'Genre)
                                   (format-field 'Director)
                                   (format-field 'Actors)
                                   (format-field 'Plot "Synopsys")
                                   (format-field 'imdbRating "IMDB Rating"))
                             `((div ([class "col-md-offset-2 col-md-8"])
                                    (p "It doesn't seem that IMDB knows about this film. Try renaming the
                                       file to better represent the film's name if this isn't the result
                                       you were looking for."))))

                       (div ([class "col-md-offset-2 col-md-8"])
                            (a ([href ,(~a "/" (find-relative-path media-directory path))]
                                [class "btn btn-default btn-lg"])
                               "Watch Here Now")
                            (a ([href ,(embed/url (play-film film))]
                                [class "btn btn-default btn-lg"])
                               "Watch On TV")
                            (p "Click "
                               (a ([href ,(embed/url start)]) "here")
                               " to return to your regularly scheduled programming.")))))))

  (send/suspend/dispatch response-generator))

(define (not-found req)
  (define (response-generator embed/url)
    (response/xexpr5
     #:code 404
     #:message #"Not Found"
     `(html ([lang "en"])
            (head ,@(headers)
                  (title "Oops, Something's Missing!"))
            (body ,(top-bar "Wait! What?" "Sh*t, where did I put that?")
                  (div ([class "col-md-offset-2 col-md-8"])
                       (p "Oh jeeze, the thing for that you wanted located at somplace isn't anywhere to be found!")
                       (p "This is OK. Don't panic, maybe.")
                       (p "First try going back to the home page and force a refresh of the videos that Grindhouse is aware of.
                        If that doesn't work, try restarting the server. If " (i "that") " doesn't work, you're gonna have
                        to see if your files are really where you think they are, so check " (code "config.rkt") " to see if
                        it contains all the right stuff and it's configured correctly.")
                       (p "At best this is a temporary madness.")
                       (p "At worst... well, let's not think about that. It can get pretty bad.")
                       (p "Click "
                          (a ([href ,(embed/url start)]) "here")
                          " to return to your regularly scheduled programming."))))))

  (send/suspend/dispatch response-generator))

(define (force-refresh req)
  (refresh-db)

  (define (response-generator embed/url)
    (response/xexpr5
     `(html ([lang "en"])
            (head (title "Refresh Forced")
                  ,@(headers))
            (body ,(top-bar "So Refreshing!")
                  (div ([class "container"])
                       (div ([class "col-md-offset-2 col-md-8"])
                            (h1 "Ok")
                            (p "It's done now.")
                            (p "Click "
                               (a ([href ,(embed/url start)]) "here")
                               " to return to your regularly scheduled programming.")))))))

  (send/suspend/dispatch response-generator))

(define (start req)
  (define/match (fill-films film embed/url)
    [((list-no-order (cons 'name name) _ ...) embed/url)
     (cons `(div ([class "film-listing"])
                 (a ([href ,(embed/url (show-film-details film))])
                    ,name))
           (fill-films (%more) embed/url))]
    [(_ _) '()])

  (define (response-generator embed/url)
    (response/xexpr5
     `(html ([lang "en"])
            (head (title ,user-name "'s Grindhouse - Movie Listing")
                  ,@(headers)
                  ;; gets the movie sidenav js file
                  (script ([src "/public/main.js"]
                           [type "text/javascript"])))
            (body ,(top-bar)
                  (div ([class "container"])
                       (div ([class "row"])
                            (div ([class "col-md-9 col-sm-9 col-xs-9"]
                                  [role "main"])
                                 (h1 (i "Your") " Movies")

                                 ,(if (%which () (%video-starts-with 'symbol (_) (_) (_)))
                                      `(div (h2 ([id "symbol-movies"]) "$#*!")
                                            ,@(fill-films (%which (name path mime) (%video-starts-with 'symbol name path mime))
                                                          embed/url))
                                      "")

                                 ,(if (%which () (%video-starts-with 'number (_) (_) (_)))
                                      `(div (h2 ([id "number-movies"]) "0-9")
                                            ,@(fill-films (%which (name path mime) (%video-starts-with 'number name path mime))
                                                          embed/url))
                                      "")

                                 ,@(for/list ([char (in-char-range #\A #\Z)])
                                     (if (%which () (%video-starts-with char (_) (_) (_)))
                                         `(div (h2 ([id ,(~a "movies-" char)]) ,(~a char))
                                               ,@(fill-films (%which (name path mime) (%video-starts-with char name path mime))
                                                             embed/url))
                                         "")))

                            (div ([class "col-md-3 col-sm-3 hidden-xs"]
                                  [id "movie-sidenav"])
                                 (nav ([class "movie-sidebar"])
                                      (ul ([class "nav"])
                                          (li (a ([href "#top"]) "Top"))
                                          (li (a ([href ,(embed/url force-refresh)]) "Force Refresh"))
                                          ,(let ([vids (num-videos-starts-with 'symbol)])
                                                (if (zero? vids)
                                                    `(li (a "$#*!"))
                                                    `(li (a ([href "#symbol-movies"])
                                                            ,(~a "$#*! (" vids " movies)")))))
                                          ,(let ([vids (num-videos-starts-with 'number)])
                                                (if (zero? vids)
                                                    `(li (a "0-9"))
                                                    `(li (a ([href "#number-movies"])
                                                            ,(~a "0-9 (" vids " movies)")))))
                                          ,@(for/list ([char (in-char-range #\A #\Z)])
                                              (let ([vids (num-videos-starts-with char)])
                                                (if (zero? vids)
                                                    `(li (a ,(~a char)))
                                                    `(li (a ([href ,(~a "#movies-" char)])
                                                            ,(~a char
                                                                 " ("
                                                                 vids
                                                                 (if (= 1 vids)
                                                                     " movie)"
                                                                     " movies)"))))))))))))))))
  (send/suspend/dispatch response-generator))

;;; Startup code!
(refresh-db)

(define port
  (if (getenv "PORT")
      (string->number (getenv "PORT"))
      8080))

(serve/servlet start
               #:servlet-path "/"
               #:servlet-regexp #px"^/$"
               #:listen-ip #f
               #:port port
               #:command-line? #t
               #:extra-files-paths (list (build-path root)
                                         (build-path media-directory)))
