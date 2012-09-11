require 'sinatra'
require './voicebox'

root_dir = File.dirname(__FILE__)

set :environment, :production
set :root,  root_dir
set :app_file, File.join(root_dir, 'voicebox.rb')
disable :run

run Sinatra::Application
