$(function() {
    var $nav = $("#movie-sidenav")
    var navHeight = $nav.outerHeight()
    var origin = $nav.offset().top
    var y = 0
    var buffer = 0

    function resetMenuPos () {
        var lastY = y
        y  = $(window).scrollTop()

        var dy = y - lastY
        var $win = $(window)
        $nav = $("#movie-sidenav")

        function floatNavBottom() {
            var top = $nav.offset().top - buffer
            var bottom = $nav.offset().top + navHeight
            var winBottom = y + $win.height()

            if ($win.height() > navHeight && y > top)
                $nav.css('margin-top', (y + buffer) - origin)
            else if ($win.height() < navHeight && (winBottom + buffer) > bottom)
                $nav.css('margin-top', $win.height() - navHeight + y - buffer - origin)
        }

        function floatNavTop() {
            if (y < origin)
                $nav.css('margin-top', 0)
            else if (y < $nav.offset().top + buffer)
                $nav.css('margin-top', (y + buffer) - origin)
        }

        if (dy < 0) floatNavTop()
        else if (dy > 0) floatNavBottom()
    }
    resetMenuPos()
    $(window).scroll(resetMenuPos)
})
