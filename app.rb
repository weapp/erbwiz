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
    format = params[:format] || :svg
    content_type({'dot' => :text, 'plain' => :tex}.fetch(format, format))
    Erbwiz.new.import(content.split("\n")).export_to(format)
  end
end

get '/' do
  if request.params['content']
    %( #{request} )
  elsif request.params['url'] && request.params['url'] =~ %r{^http://}
    export(open(request.params['url']))
  else
    ERB.new(INDEX, nil, '-').result(binding)
  end
end

post '/' do
  begin
    if params['url'] && params['url'] =~ %r{^http://}
      export(open(request.params['url']))
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

