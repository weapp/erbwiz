
#!/usr/bin/env ruby

require 'bundler/setup'
require 'open-uri'

class StringInquirer < String
  private

  def respond_to_missing?(method_name, include_private = false)
    method_name[-1] == '?'
  end

  def method_missing(method_name, *arguments)
    if method_name[-1] == '?'
      self == method_name[0..-2]
    else
      super
    end
  end
end

APP_ENV = StringInquirer.new(ENV['RACK_ENV'] || 'development')

Bundler.require(:default, APP_ENV)

require './erbwiz'
require 'yaml/store'

class App < Sinatra::Base
  register Sinatra::AssetPack
  assets do
    js :application, [
      '/js/ejs.js',
      '/js/erjs.js',
      '/js/er2dot.js',
      '/js/viz.js',

      '/js/fetchival.js',
      '/js/store.min.js',

      '/js/dnd_textarea.js',
      '/js/autosize.js',

      '/js/app.js'
    ]


    js_compression :yui
  end

  helpers do
    def store
      @store ||= YAML::Store.new "database.store"
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def export(content)
      if ENV['DOT']
        format = params[:format] || :svg
        content_type({'dot' => :text, 'plain' => :tex}.fetch(format, format))
        Erbwiz.new.import(content.split("\n")).export_to(format)
      else
        @graph = Erbwiz.new.import(content.split("\n")).export_to('dot')
        erb :graph
      end
    end
  end

  get '/' do
    if params['url'] && params['url'] =~ %r{^https?://}
      export(open(params['url']).read)
    elsif params['content'] && params['content'] != ""
      export(params['content'])
    else
      redirect to("/#{SecureRandom.urlsafe_base64(6)}")
    end
  end

  get '/:key' do
    `pegjs -e erjs app/js/erjs.pegjs` if APP_ENV.development?
    store.transaction do
      @content = store[params['key']]
    end
    @content = @content && JSON[@content]['content']
    erb :index
  end

  post '/save/:key' do
    body = request.body.read
    store.transaction do
      store[params[:key]] = body
    end
    p body
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
      erb :index
    end
  end
end

