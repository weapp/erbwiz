now = Date.now or -> (new Date).getTime()

debounce = (func, wait, immediate) ->
  timeout = undefined
  args = undefined
  context = undefined
  timestamp = undefined
  result = undefined

  later = ->
    last = now() - timestamp
    if last < wait and last >= 0
      timeout = setTimeout(later, wait - last)
    else
      timeout = null
      if !immediate
        result = func.apply(context, args)
        if !timeout
          context = args = null
    return

  ->
    context = this
    args = arguments
    timestamp = now()
    callNow = immediate and !timeout
    if !timeout
      timeout = setTimeout(later, wait)
    if callNow
      result = func.apply(context, args)
      context = args = null
    result

$ = (selector, container) ->
  (container or document).querySelector selector

document_id = ->
  $('#key').value

isSaved = ->
  store.get("erbwiz:v1:#{document_id()}:saved") == 'true'

setSaved = (value) ->
  store.set("erbwiz:v1:#{document_id()}:saved", '' + value)

setLabelSaved = (value) ->
  if value == 'transfer'
    $('#saved').innerHTML = '<i class="glyphicon glyphicon-transfer"></i>'
  else if value == 'saved'
    $('#saved').innerHTML = '<i class="glyphicon glyphicon-floppy-saved green"></i>'
  else if value == 'error'
    $('#saved').innerHTML = '<i class="glyphicon glyphicon-floppy-remove red"></i>'

refresher = (textarea, graph, tmpl) ->
  (saved)->
    lastWatched()
    try
      dot = er2dot(textarea.value, tmpl)
      # console.log(dot[1])
      graph.innerHTML = Viz(dot[1], 'svg')
      setSaved saved == true
    catch e
      console.error e
      setSaved true
      setLabelSaved('error')

autoSave = (textarea) ->
  ->
    if !isSaved()
      store.set "erbwiz:v1:#{document_id()}:content", textarea.value

      payload = ->
        id: document_id()
        content: textarea.value

      compare = (a, b) ->
        JSON.stringify(a) == JSON.stringify(b)

      fetchival("/save/#{document_id()}").post(payload())
      .then(
        (data) -> compare(data, payload()) and setLabelSaved('saved'),
        (data) -> setLabelSaved('error')
      )

      setSaved true

@download = ->
  graph = $('#graph')

  canvas = document.createElement('canvas')
  canvas.width  = graph.offsetWidth
  canvas.height = graph.clientHeight

  img = new Image
  img.src = 'data:image/svg+xml,' + graph.innerHTML

  img.onload = ->
    canvas.getContext('2d').drawImage img, 0, 0
    a = document.createElement('a')
    a.download = "#{document_id()}.png"
    a.href = canvas.toDataURL('image/png')
    a.click()
    return

  return


@downloadud = ->
  svg = $("svg")
  canvas = document.createElement('canvas')
  context = canvas.getContext('2d')

  canvas.setAttribute("width", svg.offsetWidth);
  canvas.setAttribute("height", svg.clientHeight);

  img = new Image
  img.src = 'data:image/svg+xml,' + svg.innerHTML
  console.log(img)
  img.onload = ->
    console.log("................")
    context.drawImage img, 0, 0
    a = document.createElement('a')
    a.download = 'fallback.png'
    a.href = canvas.toDataURL('image/png')
    a.click()
  return

lastWatched = ->
  selector = (prev, current) ->
    if current.startsWith('erbwiz:') and current.endsWith(':saved')
      page = current.split(":")[2]
      if page != ""
        prev += "<li><a href=\"/#{page}\">#{page}</a></li>"
    prev

  keys = Object.keys(store.getAll()).reduce(selector, "")


  $('#last-watched').innerHTML = "<ul>#{keys}</ul>"

document.addEventListener 'DOMContentLoaded', ->
  lastWatched()
  setLabelSaved('saved')
  textarea = $('#content')
  graph = $('#graph')
  template = $('#graph-template').innerHTML
  refresh = debounce(refresher(textarea, graph, template), 500)
  content = store.get("erbwiz:v1:#{document_id()}:content")
  if content
    textarea.value = content
  refresh(true)

  textarea.addEventListener 'input', refresh
  textarea.addEventListener 'input', -> setLabelSaved('transfer')

  setInterval autoSave(textarea), 3000

  dnd_textarea textarea, refresh
  autosize($('textarea'))
