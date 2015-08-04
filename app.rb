
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

  end

  helpers do
    def store
      @store ||= YAML::Store.new "database.store"
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def default_content
      @default_content = <<EOF
# Tables
[User] { color: :blue }
*id
blog_id* <nullable>
name

[Blog] { color: :orange }
*id
user_id*
title
logo <url>

[Post]
*id
blog_id*
title
body

# Relations
[User] 1--? [Blog]
[Blog] 1--* [Post]
[Post] +--* [Tag]
[Post] 1--* [Comment]
[User] 1--* [Comment]
[User] *--* [User] <friendship>

# Extras
[Post] == [Comment]
EOF
    end
  end



  get '/:key?' do
    # `pegjs -e erjs ./erjs.pegjs ./app/js/erjs.js` if APP_ENV.development?
    if params['url'] && params['url'] =~ %r{^https?://}
      @content = open(params['url']).read
    elsif params['content'] && params['content'] != ""
      @content = params['content']
    elsif params['key']
      store.transaction { @content = store[params['key']] }
      @content = @content && JSON[@content]['content']
    else
      redirect to("/#{SecureRandom.urlsafe_base64(6)}")
    end
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
        @content = open(params['url']).read
      elsif params[:file]
        @content = params[:file][:tempfile].read
      elsif params['content'] && params['content'] != ""
        @content = params['content']
      elsif env['CONTENT_TYPE'] == 'application/erbwiz'
        @content = request.body.read
      else
        raise "content not found"
      end
      erb :index
    rescue => error
      content_type :html
      puts error
      puts error.backtrace
      error_message = "<pre>#{h error}</pre>"
      erb :index
    end
  end
end

