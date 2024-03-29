#!/usr/bin/env ruby

require 'open3'
require 'erb'
require 'optparse'

String.class_eval do
  attr_accessor :loc, :is_safe
end

class Erbwiz
  Options = Struct.new(:notation)

  IDENTIFIER = '([\w\d]+(?:\s*[\w\d]+)*)'
  LABEL = "[\\[\\(]#{IDENTIFIER}[\\]\\)]"
  DICT = '\s*({.*})?'
  MARK = '\s*(?:<(.*)>)?'

  REGEXPS = {
    global: /\A#{MARK}#{DICT}\Z/,
    label: /\A#{LABEL}*#{MARK}#{DICT}\Z/,
    field: /\A(\*?)#{IDENTIFIER}(\*?)#{MARK}#{DICT}\Z/,
    relation: /\A#{LABEL}\s*(.)--(.)\s*#{LABEL}#{MARK}#{DICT}\Z/,
    same: /\A#{LABEL}((?:\s*==\s*#{LABEL})+)#{MARK}#{DICT}\Z/
  }

  def initialize
    @_index_ = 0

    @last_label = nil

    @groups = {
      globals: {},
      tables: {},
      relations: [],
      sames: []
    }
    @groups[:globals] = {
      graph: {
        bgcolor: :white,
        fontcolor: :black,
        labelloc: :t,
        labeljust: :l,
        rankdir: :LR,
        fontsize: 14,
        # ordering: :out
      },

      node: {
        fontsize: 12,
        fontcolor: :black,
        style: :filled,
        color: '#000000',
        fillcolor: '#ffffff'
      },

      edge: {
        fontsize: 12,
        fontcolor: :black,
        labeldistance: 2.0,
        dir: :both,
        style: :solid,
        arrowtail: :none,
        arrowhead: :none
      }
    }

    @colors = {
      blue: {
        color: '#000040',
        fillcolor: '#ececfc'
      },
      green: {
        color: '#002000',
        fillcolor: '#d0e0d0'
      },
      orange: {
        color: '#804000',
        fillcolor: '#eee0a0'
      },
      red: {
        color: '#c00000',
        fillcolor: '#fcecec'
      },
      white: {
        color: '#000000',
        fillcolor: '#ffffff'
      },
      yellow: {
        color: '#606000',
        fillcolor: '#fbfbdb'
      }
    }

    @tails = {
      uml: {
        '-' => { taillabel: '' },
        '1' => { taillabel: '1' },
        '*' => { taillabel: '0..N' },
        '+' => { taillabel: '1..N' },
        '?' => { taillabel: '0..1' }
      },
      ie: {
        '-' => {},
        '1' => { arrowtail: :teetee },
        '*' => { arrowtail: :crowodot },
        '+' => { arrowtail: :crowdot },
        '?' => { arrowtail: :teeodot },
        '>' => { arrowtail: :inv },
        '<' => { arrowtail: :normal }
      }
    }

    @heads = {
      uml: {
        '-' => { headlabel: '' },
        '1' => { headlabel: '1' },
        '*' => { headlabel: '0..M' },
        '?' => { headlabel: '0..1' },
        '+' => { headlabel: '1..M' }
      },
      ie: {
        '-' => {},
        '1' => { arrowhead: :teetee },
        '*' => { arrowhead: :crowodot },
        '+' => { arrowhead: :crowdot },
        '?' => { arrowhead: :teeodot },
        '>' => { arrowhead: :normal },
        '<' => { arrowhead: :inv }
      }
    }

    @combineds = {
      '----' => {},
      '*--1' => {},
      '1--*' => {},
      '*--*' => {},
      '1--?' => {},
      '?--1' => {}
    }
  end

  def safe(string)
    string.is_safe = true
    string
  end

  def present?(value)
    !value.nil? && !value.empty?
  end

  def presence(value)
    present?(value) ? value : nil
  end

  def detect(line)
    REGEXPS.each do |key, regexp|
      regexp.match(line).tap { |match| return [key, match.to_a] if match }
    end
    fail "SYNTAX ERROR on line #{line.loc}: #{line}"
  end

  def next_index
    @_index_ += 1
  end

  def parse_mark(mark)
    mark
  end

  def parse_dict(dict)
    dict ? eval(dict) : {}
  end

  def create_table(label, dict)
    @groups[:tables][label] ||= {
      index: next_index,
      options: dict,
      fields: {}
    }
  end

  def global_found(_, _, dict)
    dict.delete(:mark)
    k = dict.delete(:key)
    (@groups[:globals][k] ||= {}).merge!(dict)
  end

  def label_found(_, _, name, dict)
    @last_label = name.to_sym
    create_table(@last_label, dict)
  end

  def field_found(line, _, pk, name, fk, dict)
    dict[:pk] = presence(pk.strip)
    dict[:fk] = presence(fk.strip)
    fail "SYNTAX ERROR on line #{line.loc}: #{line}" unless @last_label
    @groups[:tables][@last_label][:fields][name.to_sym] = dict
  end

  def relation_found(_, _, t1, n1, n2, t2, dict)
    t1 = t1.to_sym
    t2 = t2.to_sym
    create_table(t1, {})
    create_table(t2, {})
    @groups[:relations] << [t1, n1, n2, t2, dict]
  end

  def same_found(_, expr, *args)
    _dict = args.pop
    tables = expr.scan(Regexp.new(IDENTIFIER)).flatten
    tables.map! do |table|
      table.to_sym.tap { |t| create_table(t, {}) }
    end
    @groups[:sames] << tables
  end

  def tableid(label)
    l = label.to_s.gsub(/[^a-zA-Z]/, '').ljust(6, '_')[0...6]
    "entity_#{@groups[:tables][label][:index]}"
    "#{l}_#{@groups[:tables][label][:index].to_s.rjust(3, '0')}"
  end

  def format_keys(fields)
    fields.values.map { |v| v[:pk] || ' ' }.join('|')
  end

  def row_marks(v)
    [
      v[:fk] && ' (FK)',
      v[:mark] && " #{escape_value(v[:mark])}"
    ].join
  end

  def format_rownames(fields)
    fields.map { |n, v| "#{n}#{row_marks(v)}\\l" }.join('|')
  end

  def format_fields(table)
    return unless presence(table[:fields])
    keys = format_keys(table[:fields])
    rownames = format_rownames(table[:fields])
    "{{#{keys}}|{#{rownames}}}"
  end

  def mark(table)
    return unless presence(escape_value(table[:options][:mark]))
    escape_value("  #{table[:options][:mark]}")
  end

  def format_table(label)
    table = @groups[:tables][label]
    text = "#{escape_value(label)}#{mark(table)}"
    [text, format_fields(table)].compact.join('|')
  end

  def display_attr(attribute)
    attribute.is_a?(String) ? escape_attr(attribute) : attribute.to_s
  end

  def escape_value(value)
    safe(value.to_s.gsub(/[ <>]/) { |m| "\\#{m}" }.gsub("\n", '\n').gsub('"', '\\"'))
  end

  def escape_attr(attribute)
    # require "debugger"; debugger
    str_attribute = attribute.to_s
    str_attribute = escape_value(str_attribute) unless str_attribute.is_safe
    str_attribute = "\"#{str_attribute}\"" if attribute.is_a?(String)
    safe(str_attribute)
  end

  def table_attrs_hash(label)
    table = @groups[:tables][label]
    options = table[:options]
    color = @colors[options[:color]] || @colors[:yellow]
    base = {
      shape: :record,
      label: safe(format_table(label)),
      tooltip: label.to_s
    }
    opts = options.select { |key, _value| [:group].include?(key) }
    merge_all(base, color, opts)
  end

  def display_rel_mark(dict)
    { label: dict[:mark].to_s } if presence(dict[:mark])
  end

  def display_rel_taillabel(dict)
    { taillabel: " #{dict[:N1]} " } if presence(dict[:N1])
  end

  def display_rel_headlabel(dict)
    { headlabel: " #{dict[:N2]} " } if presence(dict[:N2])
  end

  def rel_attrs_hash(_t1, n1, n2, _t2, dict)
    user = merge_all(
      display_rel_mark(dict),
      display_rel_taillabel(dict),
      display_rel_headlabel(dict)
    )
    tail = @tails.fetch(@options.notation, {}).fetch(n1, {})
    head = @heads.fetch(@options.notation, {}).fetch(n2, {})
    combined = @combineds.fetch(@options.notation, {}).fetch("#{n1}--#{n2}", {})

    merge_all(tail, head, combined, user)
  end

  def merge_all(*list)
    list.compact.inject({}) { |a, e| a.merge(e) }
  end

  def table_attrs(label)
    hash_to_attrs(table_attrs_hash(label))
  end

  def rel_attrs(*args)
    hash_to_attrs(rel_attrs_hash(*args))
  end

  def hash_to_attrs(hash)
    hash.map { |key, value| "#{key}=#{display_attr(value)}" }.join(', ')
  end

  def import(lines)
    lines.each_with_index do |line, index|
      line.loc = index
    end

    lines.map! do |line|
      line.gsub!(/#.*/, '')
      line.strip!
      presence(line)
    end

    lines.compact!

    lines.each do |line|
      kind, match = detect(line)
      mark = parse_mark(match.delete_at(-2))
      match[-1] = parse_dict(match[-1])
      match[-1][:mark] ||= mark
      send("#{kind}_found", line, *match)
    end

    return self
  end

  # helpers for erb
  def globals
    @groups[:globals]
  end

  def tables
    @groups[:tables]
  end

  def relations
    @groups[:relations]
  end

  def sames
    @groups[:sames]
  end

  def dot
    ERB.new(TEMPLATE, nil, '-').result(binding)
  end

  def export(fileout, options)
    @options = options
    # Open3.capture3('dot -Tpng | open -f -a Preview', stdin_data: dot)
    ext = nil
    if fileout
      ext = fileout.split('.').last
      if ext == 'dot'
        File.open(fileout, 'w').puts(dot)
      else
        Open3.capture2("dot -T#{ext} -o #{fileout}", stdin_data: dot)
      end
    else
      puts dot
    end
  end

  def export_to(format, options=nil)
    default_notation = ENV['ERBWIZ_NOTATION'] || 'ie'
    @options ||= Erbwiz::Options.new(default_notation.to_sym)

    return dot if format == 'dot' || format == :dot

    stdout, _, _ = Open3.capture3("dot -T#{format}", stdin_data: dot)
    stdout
  end
end


def main(args)

  default_notation = ENV['ERBWIZ_NOTATION'] || 'ie'

  options = Erbwiz::Options.new(default_notation.to_sym)

  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: erbwiz [options] file_in [file_out]'

    opts.on('-n NOTATION', '--notation=NOTATION', 'Notation: [ie]/uml') do |n|
      if %w(ie uml).include? n
        options.notation = n.to_sym
      else
        exit(-1)
      end
    end

    opts.on('-h', '--help', 'Prints this help') do
      puts opts
      exit
    end
  end

  opt_parser.parse!(args)

  filein = args[0]
  fileout = args[1]

  opt_parser.parse!(%w(--help)) unless filein

  er = Erbwiz.new
  er.import(File.readlines(filein))
  er.export(fileout, options)
end

TEMPLATE = %q(
/*
 * This file was generated by [Erbwiz version 0.1.0] at [<%= Time.now %>]
 */

digraph ERD {

<%- [:graph, :node, :edge].each do |option| -%>
  <%= option %> [
  <%- globals[option].each do |key, value| -%>
    <%= key %> = <%= display_attr(value) %>
  <%- end -%>
  ]

  <%- end -%>
<%- tables.keys.each do |label| -%>
  //E [<%= label %>]
  <%= tableid(label) %> [<%=table_attrs(label)%>]

<%- end -%>

<% relations.each do |t1, n1, n2, t2, dict| %>
  //R [<%= t1 %>] <%= n1 %>--<%= n2 %> [<%= t2 %>]
  <%= "#{tableid(t1)} -> #{tableid(t2)} [#{rel_attrs(t1, n1, n2, t2, dict)}]" %>
<% end %>

<% sames.each do |tables| %>
  {rank=same; <% tables.each do |table| %><%= tableid(table) %> <% end %>}
<% end %>
}

)

main(ARGV) if __FILE__ == $0
