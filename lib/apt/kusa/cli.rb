require 'thor'
require 'yaml'
require 'zlib'
require 'pixela'
require 'apt/history'

module Apt::Kusa
  class CLI < Thor
    class_option :config, type: :string, default: File.join(Dir.home, ".apt-kusa")

    option :all, type: :boolean, default: false
    desc "summary", "Summarize history.log"
    def summary
      summary = parse_and_summarize
      summary.each do |k, v|
        puts "#{k} #{v.to_a.map{|a| a.join(":")}.join(" ")}"
      end
    end

    option :all,   type: :boolean, default: false
    option :graph, type: :string,  required: true
    option :create,type: :boolean, default: false
    desc "post", "Post to pixe.la"
    def post
      config = load_config

      unless username = ENV["PIXELA_USER_NAME"] || config['username']
        puts "Please set your username."
        exit
      end
      unless token = ENV["PIXELA_USER_TOKEN"] || config['token']
        puts "Please set your API token"
        exit
      end

      summary = parse_and_summarize

      client = Pixela::Client.new(username: username, token: token)
      graph = client.graph(options[:graph])
      if options[:create]
        graph.create(name:"Count of package install/upgrade", unit:"commit", type:"int", color:"shibafu")
      end

      summary.each do |date, count|
        q = count.to_a.select{|h| [:install,:upgrade].include?(h[0])}.inject(0) {|s,h| s+=h[1]}
        graph.pixel(Date.parse(date)).update(quantity: q)
      end
    end

    desc "version", "Show version"
    def version
      puts Apt::Kusa::VERSION
    end

    no_commands do
      def load_config(path=options[:config])
        YAML.load_file(path)
      end

      def parse_and_summarize
        summarize(parse(Apt::History::FILEPATH, options[:all]))
      end

      def parse(path, all)
        result = []

        filelist = if all
                     Dir.glob("#{path}*")
                   else
                     [path]
                   end
        filelist.each do |path|
          reader = if File.extname(path) == ".gz"
                    Zlib::GzipReader.open(path)
                  else
                    File.open(path)
                  end
          result.concat(Apt::History.parse(reader))
        end

        result
      end

      def summarize(logs)
        summary = Hash.new {|h,k| h[k] = {install:0, reinstall:0, upgrade:0, remove:0, purge:0}}
        logs.each do |log|
          next unless log.action
          date = log.end_date || log.start_date
          summary[date.strftime("%Y%m%d")][log.action] += log.package.count
        end
        summary
      end
    end
  end
end
