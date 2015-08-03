@dnd_textarea = (textarea, cb) ->

  handleFileSelect = (evt) ->
    evt.stopPropagation()
    evt.preventDefault()
    file = evt.dataTransfer.files[0]
    reader = new FileReader

    # If we use onloadend, we need to check the readyState.
    reader.onloadend = (evt) ->
      if evt.target.readyState == FileReader.DONE # DONE == 2
        textarea.value = evt.target.result
        cb textarea.value

    reader.readAsBinaryString file

  handleDragOver = (evt) ->
    evt.stopPropagation()
    evt.preventDefault()
    evt.dataTransfer.dropEffect = 'copy'
    # Explicitly show this is a copy.

  # Setup the dnd listeners.
  textarea.addEventListener 'dragover', handleDragOver, false
  textarea.addEventListener 'drop', handleFileSelect, false
