require 'rubygems'
require 'sinatra'
require 'harvest'
require 'erb'
require 'rack/cache'
require 'sequel'
require 'sinatra/sequel'

set :database, ENV['DATABASE_URL'] || "postgres://test:test@localhost/reports"

configure :production do
  use Rack::Auth::Basic do |username, password|
    [username, password] == ['test', 'test']
  end
end

get '/' do
  @log = Log.order(:id).last
  erb :index
end

def populate_logs
  @harvest = Harvest(:email      => "test",
                     :password   => "test",
                     :sub_domain => "opensourcery",
                     :ssl => false)
  @projects = @harvest.projects.find(:all)
  @total_remaining = 0
  @harvest.projects.find(:all).each do |project|    
    if project.budget and project.billable?
      entries = project.entries(:from => Time.now - 100.years, :to => Time.now)
      total = entries.sum(&:hours)
      if project.budget_by == 'project_cost'
        project_in_hours = project.budget / 135
      else
        project_in_hours = project.budget
      end
      remaining = (project.budget - total)
      remaining = 0 if remaining < 0
      @total_remaining += remaining if project.active?
    end
  end
  @weeks_left = ((@total_remaining / 130) * 10).round / 10.0
  Log.create(:total_remaining => @total_remaining, :weeks_left => @weeks_left)
end

class Log < Sequel::Model
  plugin :timestamps
end

migration "create teh foos table" do
  database.create_table :logs do
    primary_key :id
    timestamp   :created_at
    decimal     :total_remaining
    decimal     :weeks_left
  end
end
