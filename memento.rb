#!/usr/bin/env ruby
require 'rubygems'
require 'pp'
require 'grit'
require 'yaml'
require 'directory_watcher'
require 'twitter'
require 'yahoo-weather'
include Grit


class Memento
  def initialize(&block)
    @files = []
    @message = String.new
    @config = nil
    @repo = nil
    @block = block
    start
  end
  
  def start
		begin
		  @config = YAML::load_file("memento.yaml")
		rescue SystemCallError => e
			puts "Configuration file #{file} not found!\n"
			exit 1
		end
		begin 
	    @repo = Repo.new @config[:repo][:path]
    rescue SystemCallError => e
    	puts "Not a git repository here!\n"
    	exit 1
    end
    dw = DirectoryWatcher.new @config[:repo][:path], :glob => @config[:watcher][:path], :pre_load => true
    dw.interval = @config[:watcher][:interval]
    dw.stable = @config[:watcher][:stable]
    dw.add_observer {|*args| args.each {|event| 
    	if event.type==:modified
    		puts "#{event.path} has modified!" if @config[:verbose] 
    		@files << event.path
    	end

    	if event.type==:stable and @files.include?(event.path)
    		puts "#{event.path} is stable" if @config[:verbose] 
    		@repo.add event.path
    		@files.delete event.path
    		commit
    	end
    }}
    dw.start
    key = gets
    dw.stop
    #forzar un commit mediante una tecla?
	end
	
	def commit
	  puts `git pull origin master`
	  @message = Time.now.strftime("Commited on %d/%m/%Y at %I:%M%p\n")
	  weather
	  twitter
	  #@repo.commit_all(@message)
	  #reemplazar esto!!! investigar pq no funciona con grit <-> github
	  File.open(".message.tmp", "w") {|file| file.puts @message}
	  puts `git commit -a --file=.message.tmp`
	  File.delete(".message.tmp")
	  @message = String.new
	  puts `git push origin master`
	end
	
	def twitter
	  begin
	    httpauth = Twitter::HTTPAuth.new(@config[:twitter][:id], @config[:twitter][:password])
	  rescue SystemCallError => e
	    puts "Twitter account error!\n"
	    exit 1
    end
    client = Twitter::Base.new(httpauth)
	  tweets = client.friends_timeline(:count => @config[:twitter][:count])
	  @message += "Tweets:\n"
	  @message += "=======\n"
	  tweets.each do |tweet|
	    #@message += "\t"+ tweet[:text] + "at" + tweet[:created_at] + "por" + tweet[:user][:screen_name] + "<img src=\"#{tweet[:user][:profile_image_url]}\" />\n"
	    @message += "\t\t- #{tweet[:text]} - #{Time.parse(tweet[:created_at]).strftime("Tweet on %d/%m/%Y at %I:%M%p")} by #{tweet[:user][:screen_name]}\n"
    end
  end
	
	def weather
	  client = YahooWeather::Client.new
	  response = client.lookup_location(@config[:weather][:location],@config[:weather][:units])
    @message += "Tiempo en #{@config[:weather][:city]}\n"
    @message += "======================\n"
    @message += "\tTemperatura: #{response.condition.temp}ºC\n"
    @message += "\t#{response.condition.text}\n"
    @message += "\tHumedad: #{response.atmosphere.humidity}%\n"
	end
	
end


Memento.new do; end
