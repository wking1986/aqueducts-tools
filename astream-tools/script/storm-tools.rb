#!/usr/bin/env ruby
$:.push('gen-rb')

require 'thor'
require '../lib/storm_info'
require '../lib/kafka_flow'
require '../lib/elasticsearch_data'
require '../lib/astream_es_data'
class Tools < Thor
  desc "search topology ", "search storm topology info"
  long_desc  <<-LONGDESC
    `strom-tools.rb search topology` will print strom info
   \x5  some examples:
   \x5  1. ruby strom-tools.rb search topology --list
   \x5     list all topolog names
   \x5  2. ruby strom-tools.rb search topology --name sf  --host
   \x5     list all hosts and cpu_num for sf
  LONGDESC
  option :list, :type => :boolean, :aliases => :l, :banner => "no argument,return topology name list" 
  option :name, :type => :string, :aliases => :n, :banner => "argument:topology_name"
  option :elasticsearch, :type => :string, :aliases => :e, :banner => "argument:item,calculation,unit,num,show_frequency"
  option :kafka, :type => :boolean, :aliases => :k, :banner => "no argument,return kafka out,in bytes"
  option :storm, :type => :numeric, :aliases => :s, :banner => "show frequency,1 is best"
  option :host, :type => :boolean, :aliases => :h, :banner => "no argument, return topology host list"
  option :stream, :type => :boolean, :aliases => :m 
  def search(arg)
    if arg == "topology"
      si = Storm_info.new
      show_frequency = 0
      if options[:list] == true
        topology_name = []
        topology_name = si.get_topology_name() 
        topoNum = topology_name.length
        puts "topology number: #{topoNum}"
        topology_name.each do |to|
          puts to
        end
      elsif options[:name] != "name" and options[:name] != nil
        if options[:storm] != nil
          show_frequency = options[:storm]
          while show_frequency > 0 do 
            topology_spout = Hash.new
            topology_spout = si.get_topology_spout(options[:name])
            #topology_spout.each do |toname, value| 
            puts "spoutMessagePerSec:#{topology_spout/600}"
            #end
            sleep show_frequency
          end
        end
        if options[:kafka] == true
          topic_name = options[:name].to_s + "_topic"
          kf = Kafka_flow.new
          kafka_hosts = kf.kafkaHosts()
          kf.kafka_bytes(kafka_hosts, topic_name)
        end
        if options[:elasticsearch] != nil
          elastic_search = Array.new
          elastic_search = options[:name].split("_") + options[:elasticsearch].split(",")
          show_frequency = elastic_search[6].to_i
          ed = Elasticsearch_data.new
          while true do 
            ed.search_data(elastic_search[0], elastic_search[1], elastic_search[2], elastic_search[3], elastic_search[4], elastic_search[5]) 
            sleep show_frequency
          end
        end
        #host -h: puts host list
        if options[:host] == true
          #host_info = Hash.new
           si.list_host_info(options[:name])
        end
        # for test
        if options[:stream] == true
           stream = Astream_es_data.new 
           stream.search("14.07.01", "hao", "pc_lighttpd","","",1)
        end
      else
         puts 'ERROR:"--name/-n need topology name or you need use --name/-n "'
      end
    end
  end
end
Tools.start(ARGV)
