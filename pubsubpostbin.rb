require 'rubygems'
require 'sinatra'
require 'crack'
require 'httpclient'

begin
  require 'system_timer'
  MyTimer = SystemTimer
rescue
  require 'timeout'
  MyTimer = Timeout
end

module PubSubPostBin
  class App < Sinatra::Default

    set :sessions, false
    set :run, false
    set :environment, ENV['RACK_ENV']

    configure do
      GIVEUP = 10
    end
    
    helpers do
      def atom_parse(text)
        atom = Crack::XML.parse(text)
        r = []
        if atom["feed"]["entry"].kind_of?(Array)
          atom["feed"]["entry"].each { |e| 
            r << {:id => e["id"], :title => e["title"], :published => e["published"] }
          }
        else
          e = atom["feed"]["entry"]
          r = {:id => e["id"], :title => e["title"], :published => e["published"] }
        end
        r
      end
    
      def postman(url, msg)
        msg = [msg].flatten  # convert single entry to array
        msg.each do |m|
          begin
            MyTimer.timeout(GIVEUP) do
              HTTPClient.post(url, m)
            end
          rescue Exception => e
            case e
              when Timeout::Error
                puts "Timeout: #{sub}"
              else  
                puts e.to_s
            end  
            next
          end
        end
      end
    
    end
    
    get '/' do
      erb :index
    end
    
    # Superfeedr
    get '/superfeedr/:secret/:id' do
      return params[:secret]
    end
    
    post '/superfeedr/:secret/:id' do
      msg = atom_parse(request.body.string)
      postman("http://postbin.org/#{params[:id]}", msg)
    end 
    
    
    # PubSubHubbub
    get '/:id' do
      return request['hub.challenge']
    end  
    
    post '/:id' do
      msg = atom_parse(request.body.string)
      postman("http://www.postbin.org/#{params[:id]}", msg)
    end

  end
end  
