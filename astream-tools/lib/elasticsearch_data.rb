#!/usr/bin/env ruby

require 'elasticsearch'
require 'jbuilder'
require 'hashie'

class Elasticsearch_data
  def search_data(product, service, item, calculation, unit, num)
    @product = product
    @service = service
    @item = item
    @calculation = calculation
    @unit = unit
    @from = (Time.now.to_i-15-num.to_i)*1000
    @to = Time.now.to_i*1000
    @size = 100000
    #@calculation = "page_view"
    
    @terms = { :item => @item, :calculation => @calculation, :unit => @unit }
    @query = Jbuilder.encode do |json|
               json.from 0
               json.size @size
               json.query do
                 json.bool do
                   json.must do
                     json.array! @terms do |key,value|
                       json.term do
                         json.set! key,value
                       end
                     end
                   end
                 end
               end
               json.filter do
                 json.range do
                   json.event_time do
                     json.gte @from
                     json.lte @to
                   end
                 end
               end
             end
    p @query
    @client = Elasticsearch::Client.new log: false, url:'http://10.57.7.78:8200/'
    @date = Time.at(Time.now.to_i).strftime(format='%F')
    @index = "aqueducts_#{@product}_#{@date}"
    @response = @client.indices.get_settings index: "#{@index}"
    @indexx = @response.select { |k,v| k }.keys.join(',')
    @response = @client.search index: @index, type: @service, body: @query
    puts @response
    @mash = Hashie::Mash.new @response
    @array = @mash.hits.hits.map { |s| [Time.at(s._source.event_time.to_i/1000), s._source.value.to_i] }.sort { |x, y| x[0] <=> y[0] }
    @array.each {|value| puts value.to_s}
  end
end


