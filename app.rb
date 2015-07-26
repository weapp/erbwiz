#!/usr/bin/env ruby

require 'bundler/setup'
require 'open-uri'

APP_ENV = (ENV['APP_ENV'] || 'development').to_sym

Bundler.require(:default, APP_ENV)

require './erbwiz'

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end

  def export(content)
    if ENV['DOT']
      format = params[:format] || :svg
      content_type({'dot' => :text, 'plain' => :tex}.fetch(format, format))
      Erbwiz.new.import(content.split("\n")).export_to(format)
    else
      graph = Erbwiz.new.import(content.split("\n")).export_to('dot')
      ERB.new(GRAPH, nil, '-').result(binding)
    end
  end
end

get '/' do
  if params['url'] && params['url'] =~ %r{^https?://}
    export(open(params['url']).read)
  elsif params['content'] && params['content'] != ""
    export(params['content'])
  else
    ERB.new(INDEX, nil, '-').result(binding)
  end
end

post '/' do
  begin
    if params['url'] && params['url'] =~ %r{^https?://}
      export(open(params['url']).read)
    elsif params[:file]
      export(params[:file][:tempfile].read)
    elsif params['content'] && params['content'] != ""
      export(params['content'])
    elsif env['CONTENT_TYPE'] == 'application/erbwiz'
      export(request.body.read)
    else
      raise "content not found"
    end
  rescue => error
    content_type :html
    puts error
    puts error.backtrace
    error_message = "<pre>#{h error}</pre>"
    ERB.new(INDEX, nil, '-').result(binding)
  end
end


INDEX = %(
<html>
  <head>
    <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" rel="stylesheet">
    <style>
      .mono{font-family:Menlo,Monaco,Consolas,"Courier New",monospace}
    </style>
  </head>
  <body>
    <div class="container">
      <%= error_message if defined? error_message %>
      <h1>E<span style="color:#DC143C">rb</span><span style="color:#483D8B">wiz</span></h1>

      <form method="post" enctype="multipart/form-data" class="form-horizontal">
        <% if ENV['DOT'] %>
          <div class="form-group">
            <label for="url" class="col-sm-2 control-label">Format</label>
            <div class="col-sm-10">
              <select class="form-control" name="format">
                <option>svg</option>
                <option>pdf</option>
                <option>png</option>
                <option>jpeg</option>
                <option>eps</option>
                <option>gif</option>
                <option>dot</option>
                <option>plain</option>
              </select>
            </div>
          </div>
        <% end %>

        <div class="form-group">
          <label for="url" class="col-sm-2 control-label">Url</label>
          <div class="col-sm-10">
            <input name="url" value="<%= params[:url] %>" class="form-control" id="url" placeholder="http://">
          </div>
        </div>

        <div class="form-group">
          <label for="file" class="col-sm-2 control-label">File</label>
          <div class="col-sm-10">
            <input type="file" name="file" id="file">
          </div>
        </div>

        <div class="form-group">
          <label for="content" class="col-sm-2 control-label">Content</label>
          <div class="col-sm-10">
          <textarea name="content" rows="20" class="form-control mono"><%= params[:content] %></textarea>
          </div>
        </div>

        <div class="form-group">
          <div class="col-sm-offset-2 col-sm-10">
            <input type="submit" class="btn btn-default" />
          </div>
        </div>
      </form>

    </div>
  </body>
</html>
)

GRAPH = %(
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Graph</title>
  </head>
  <body>
    <script type="text/vnd.graphviz" id="graph">
      <%= graph %>
    </script>

    <input type="button" onclick="download();" value="download"><br>

    <div id="output" style="display:inline-block"></div>

    <div style="display:none">
      <canvas id="canvas">
    </div>

    <script src="//mdaines.github.io/viz.js/viz.js"></script>

    <script>
      var byId = document.getElementById.bind(document);
      var svg_data = Viz(byId("graph").innerHTML, "svg");

      byId("output").innerHTML = svg_data;

      byId("canvas").setAttribute("width", byId("output").offsetWidth);
      byId("canvas").setAttribute("height", byId("output").clientHeight);

      function download(){
        var canvas = document.querySelector("canvas"),
            context = canvas.getContext("2d");

        var img = new Image();
        img.src = "data:image/svg+xml," + svg_data;
        img.onload = function() {
          context.drawImage(img, 0, 0);
          var a = document.createElement("a");
          a.download = "fallback.png";
          a.href = canvas.toDataURL("image/png");
          a.click();
        }
      };

    </script>
  </body>
</html>
)
