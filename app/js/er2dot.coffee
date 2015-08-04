if !@ejs? and require?
  ejs = require "ejs"
  render = ejs.render
else
  render = @ejs.render

repeat = (str, count) ->
  'use strict'
  str = '' + str
  count = Math.floor(+count)
  if str.length == 0 or count == 0
    return ''
  rpt = ''
  loop
    if (count & 1) == 1
      rpt += str
    count >>>= 1
    if count == 0
      break
    str += str
  rpt

ljust = (str, width, padding) ->
  padding = padding or ' '
  padding = padding.substr(0, 1)
  if str.length < width
    str + repeat(padding, width - (str.length))
  else
    str

rjust = (str, width, padding) ->
  padding = padding or ' '
  padding = padding.substr(0, 1)
  if str.length < width
    repeat(padding, width - (str.length)) + str
  else
    str

center = (str, width, padding) ->
  padding = padding or ' '
  padding = padding.substr(0, 1)
  if str.length < width
    len = width - (@length)
    remain = if len % 2 == 0 then '' else padding
    pads = padding.repeat(parseInt(len / 2))
    pads + str + pads + remain
  else
    str

pop = (obj, key) ->
  tap obj[key], -> delete obj[key]

color = (tree, key) -> tree.config.color[key]

tail = (tree, key) -> tree.config.tail[key]

head = (tree, key) -> tree.config.head[key]

defaultRecord = (key, fields, options)->
  flds = ''
  if fields.length > 0
    pk = (field)-> if field.pk then '*' else ' '
    annotate = (field)->
      (if field.fk then ' (FK)' else '') + marks(field.options.mark)
    flds += "|{{#{fields.map((field)->"#{pk(field)}").join('|')}}"
    flds += "|{#{fields.map((field)->"#{field.text}#{annotate(field)}\\l").join('|')}}}"
  {
    shape: 'record'
    label: '"' + escape(key) + marks(options.mark) + flds + '"'
    tooltip: '"' + key + '"'
    color: '"#606000"'
    fillcolor: '"#fbfbdb"'
  }


makeIndex = (key, index) ->
  short_tablename = ljust(key.substring(0,6), 6, '_').replace(/[^a-zA-Z0-9]/g, '_')
  str_index = rjust("" + index, 3, '0')
  "#{short_tablename}_#{str_index}"

  # sprintf("#{key.substring(0,6)}_%d_", index)

makeTables = (tree) ->
  tap tree, ->
    tables = {}
    tree['TABLE'].forEach (table) ->
      key = table.header.label
      tables[key] = tables[key] or table

    tree["REL"].forEach (rel) ->
      key = rel.node1
      tables[key] = tables[key] or {header: { label: key, options: {} }, fields: [] }
      key = rel.node2
      tables[key] = tables[key] or {header: { label: key, options: {} }, fields: [] }

    tableIndex = 0
    for key, table of tables
      tableIndex += 1
      table.index = makeIndex(key, tableIndex)

    tree['TABLE'] = tables

# escape_attr = (attribute) ->
#     # require "debugger"; debugger
#     str_attribute = attribute.to_s
#     str_attribute = escape_value(str_attribute) unless str_attribute.is_safe
#     str_attribute = "\"#{str_attribute}\"" if attribute.is_a?(String)
#     safe(str_attribute)

# display_attr = (attribute) ->
#   attribute.is_a?(String) ? escape_attr(attribute) : attribute.to_s
display_attr = (attribute) ->
  "\"#{attribute}\""
  attribute

escape_attr = (attribute) ->
  "\"#{attribute}\""

makeAttributes = (attributes...) ->
  ret = []
  for key, value of merge(attributes...)
    ret.push "#{key}=#{display_attr(value)}"
  ret.join(', ')

marks = (str) ->
  t = ->
    if str
      if str[0] == '"' and str[str.length - 1] == '"'
        str = str.substring(1, str.length-1)
      str = ' ' + str
    else
      str = ''

  escape(t())

escape = (str) ->
  str.replace(/(\s|\<|\>)/g, (r)-> "\\#{r}" )

makeAttributesGlobal = (attributes...) ->
  tap {}, (ret)->
    for key, value of merge(attributes...)
      ret[key] = display_attr(value)

makeRelAttributes = (attributes...) ->
  attributes = merge(attributes...)
  if attributes.mark
    attributes.label = escape_attr(attributes.mark)
    delete attributes.mark
  makeAttributes(attributes)

makeRelations = (tree) ->
  tap tree, ->
    tree.templateVars.relations = []
    for rel in tree.REL
      tree.templateVars.relations.push
        node1: tree.TABLE[rel.node1]
        node2: tree.TABLE[rel.node2]
        rel: rel.rel
        attributes: makeRelAttributes(
          tail(tree, rel.rel[0]),
          head(tree, rel.rel[rel.rel.length-1]),
          rel.options)

makeSame = (tree) ->
  tap tree, ->
    tree.templateVars.sames = []
    for same in tree.SAME
      tables = []
      for table in same.tables
        tables.push tree.TABLE[table]
      tree.templateVars.sames.push tables

tap = (o, fn) -> fn(o); o

merge = (objs...) ->
  tap {}, (res) -> res[attr] = obj[attr] for attr of obj for obj in objs

deepMerge = (objs...) ->
  tap {}, (res) ->
    for obj in objs
      for attr of obj
        acc = res
        keys = attr.split(".")
        while keys.length > 1
          next_key = keys.shift()
          if acc[next_key] then acc = acc[next_key] else acc = acc[next_key] = {}
        acc[keys.shift()] = obj[attr]

makeNodes = (tree) ->
  tap tree, ->
    nodes = []
    for key, table of tree.TABLE
      options = table.header.options
      fields = table.fields
      nodes.push
        label: key,
        index: table.index,
        attributes: makeAttributes(
          defaultRecord(key, fields, options),
          color(tree, pop(options, 'color'))
          options)

    tree['templateVars']['nodes'] = nodes


defaultConfig = (tree) ->
  tap tree, ->
    tree.config =
      color:
        blue:
          color: '"#000040"',
          fillcolor: '"#ececfc"'
        green:
          color: '"#002000"',
          fillcolor: '"#d0e0d0"'
        orange:
          color: '"#804000"',
          fillcolor: '"#eee0a0"'
        red:
          color: '"#c00000"',
          fillcolor: '"#fcecec"'
        white:
          color: '"#000000"',
          fillcolor: '"#ffffff"'
        yellow:
          color: '"#606000"',
          fillcolor: '"#fbfbdb"'
      tail:
        '-' : {},
        '1' : { arrowtail: 'teetee' },
        '*' : { arrowtail: 'crowodot' },
        '+' : { arrowtail: 'crowdot' },
        '?' : { arrowtail: 'teeodot' },
        '>' : { arrowtail: 'inv' },
        '<' : { arrowtail: 'normal' }
      head:
        '-' : {},
        '1' : { arrowhead: 'teetee' },
        '*' : { arrowhead: 'crowodot' },
        '+' : { arrowhead: 'crowdot' },
        '?' : { arrowhead: 'teeodot' },
        '>' : { arrowhead: 'normal' },
        '<' : { arrowhead: 'inv' }
      global:
        bgcolor: "white"
        fontcolor: "black"
        labelloc: "t"
        labeljust: "l"
        rankdir: "LR"
        fontsize: 14
        # label: "Payments\ +\ Permissions"
      node:
        fontsize: 12
        fontcolor: "black"
        style: "filled"
        color: '"#000000"'
        fillcolor: '"#ffffff"'
      edge:
        fontsize: 12
        fontcolor: "black"
        labeldistance: 2.0
        dir: "both"
        style: "solid"
        arrowtail: "none"
        arrowhead: "none"
    tree.config = deepMerge(tree.config, tree.CONFIG)
    tree.config.global.label = tree.config.title if tree.config.title

makeGlobal = (tree) ->
  tap tree, ->
    tree['templateVars']['global'] =
      graph: makeAttributesGlobal tree.config.global
      node: makeAttributesGlobal tree.config.node
      edge: makeAttributesGlobal tree.config.edge

makeTemplateVars = (tree) ->
  tap tree, -> tree['templateVars'] = {}

@er2dot = (er, tmpl, parser) ->
  parser = parser or erjs
  parsed = parser.parse(er)
  makeTemplateVars parsed
  defaultConfig parsed
  makeTables parsed
  makeNodes parsed
  makeGlobal parsed
  makeRelations parsed
  makeSame parsed
  templateVars = parsed.templateVars
  [templateVars, render(tmpl, templateVars)]

