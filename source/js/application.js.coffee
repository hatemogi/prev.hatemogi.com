#= require_tree ./vendor
#= require_tree ./lib

setup_google_analytics = ->
  window._gaq = [['_setAccount', 'UA-8995709-3'], ['_trackPageview']]
  ga = document.createElement('script')
  ga.type = 'text/javascript'
  ga.async = true;
  ga.src = 'http://www.google-analytics.com/ga.js'
  s = document.getElementsByTagName('script')[0]
  s.parentNode.insertBefore(ga, s)

setup_facebook_js = ->
  s = 'script'
  id = 'facebook-jssdk'
  fjs = document.getElementsByTagName(s)[0]
  return if document.getElementById(id)
  js = document.createElement(s)
  js.id = id
  js.src = "//connect.facebook.net/ko_KR/all.js#xfbml=1&appId=167741896656859"
  fjs.parentNode.insertBefore(js, fjs)

setup_twitter_js = ->
  d = document
  s = "script"
  id = "twitter-wjs"
  return if d.getElementById(id)
  js = d.createElement(s)
  js.id = id
  js.src = "//platform.twitter.com/widgets.js"
  fjs = d.getElementsByTagName(s)[0]
  fjs.parentNode.insertBefore(js,fjs)

round_all_img = ->
  $("img:not(img[class])").addClass('img-rounded')

highlight_code = ->
  $('pre').has('code').each (i, e) ->
    lang = $(this).children('code')[0].className
    $(this).addClass(if lang == "no-highlight" then lang else "lang-#{lang}")
    hljs.highlightBlock(e)

# $(setup_facebook_js)
# $(setup_twitter_js)
$(round_all_img)
$(highlight_code)

unless window.location.hostname == '0.0.0.0'
  $(setup_google_analytics)

