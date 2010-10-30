require 'rubygems'
require 'bundler'

Bundler.require

require 'sinatra'
 
set :environment, :production
set :run, false

require 'marley'
run Sinatra::Application