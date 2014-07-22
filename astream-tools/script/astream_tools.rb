#!/usr/bin/env ruby
$:.push('gen-rb')

require 'thor'
require '../lib/storm_info'
require '../lib/kafka_flow'
require '../lib/elasticsearch_data'
require '../lib/astream_es_data'
require '../lib/astream_es_data_process'
class Tools < Thor
  desc "search"," search astream info"
  long_desc <<-LONGDESC
     `astream_tools.rb search` will print astream info
   \x5  parameters default value:
   \x5  --product ""
   \x5  --service ""
   \x5  --form    last 24 hours 
   \x5  --to      current time
   \x5  --timeout 1
   \x5  --pretty  false
   \x5  some examples
   \x5  1. ruby astream_tools.rb search --pretty
   \x5     print all product/service/period info in last 24 hours
   \x5  2. ruby astream_tools.rb search --pretty --product sf --service adcore 
   \x5  3. ruby astream_tools.rb search --pretty --product sf --service adcore --from 20140710123030 --to 20140711240000
  LONGDESC
  option :product,  :type => :string,  :aliases => :p,   :required => false,:banner => "argument: product name, default all"
  option :service,  :type => :string,  :aliases => :s,   :required => false,:banner => "argument: service name.,default all"
  option :period,   :type => :numeric, :aliases => :per, :required => false,:banner => "argument: period 1 or 60"
  option :from,     :type => :numeric, :aliases => :f,   :required => false,:banner => "argument: begin time, default 24h"
  option :to ,	  :type => :numeric, :aliases => :t,   :required => false, :banner => "argument: end time, default now"
  option :timeout,  :type => :numeric, :aliases => :out, :required => false, :banner => "argument: time threshold, default 1s"
  option :pretty,   :type => :boolean, :aliases => :pr,  :required => false,:banner => "display json prettily"
  def search
    @product = options[:product]
    @service = options[:service]
    #@period  = options[:period]
    @from    = options[:from]
    @to      = options[:to]
    @timeout = options[:timeout]
    @product = @product == nil ? "" : @product
    @service = @service == nil ? "" : @service
    #@period  = @period  == nil ? "" : @period
    @timeout = @timeout == nil ?  1 : @timeout
    time = Time.new
    @to      = @to == nil ? time.strftime("%Y%m%d%H%M%S") : @to
    @from    = @from == nil ? (Time.now - 24*60*60).strftime("%Y%m%d%H%M%S")  : @from
    stream = Astream_es_data_process.new 
    stream.get_es_data(@product, @service,@from,@to,@timeout)
    stream.cluster
    stream.print_all_info(options[:pretty])    
  end
end
Tools.start(ARGV)
