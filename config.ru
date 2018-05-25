require 'bundler/setup'
require_relative 'torrent'

Bundler.require(:default)

run Sinatra::Application
