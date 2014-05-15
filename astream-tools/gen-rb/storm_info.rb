#!/usr/bin/env ruby
$:.push('gen-rb')

require 'zookeeper'
require 'json'
require 'rubygems'
require 'thrift'
require './nimbus'

class Storm_info
  @@socket    = Thrift::Socket.new('10.52.126.75', 6627)
  @@transport = Thrift::FramedTransport.new(@@socket)
  @@protocol  = Thrift::BinaryProtocol.new(@@transport)
  @@client    = Nimbus::Client.new(@@protocol)
  @@transport.open
  @@cluster_info = @@client.getClusterInfo
  @@topologyAry = Array.new
  @@cluster_info.topologies.each{ |em| @@topologyAry.push(em) }
 
  def get_topology_name()
    topologyName = Array.new
    @@topologyAry.each do |em|
      topologyName.push(em.name.to_s)
    end
    return topologyName
  end
  def get_topology_spout(name)
    topologyInfoMap = Hash.new
    executorsInfoMap = Hash.new
    @@topologyAry.each do |em|
      if em.name.to_s == name 
         topology_info = @@client.getTopologyInfo(em.id)
         topologyInfoMap[em.id] = topology_info
         executorsInfoMap[em.id] =  topology_info.executors    
      end
    end   
    topologySpoutValueSecMap = Hash.new
    executorsInfoMap.each do |toname, exary|
      exary.each do |ex|
        if ex.component_id == "kafkaSpout"
           spout_emitted = ex.stats.emitted
           spout_emitted.each do |time,context|
             if time == "600"
                if context.empty?
                   topologySpoutValueSecMap[toname] = topologySpoutValueSecMap[toname].to_f + 0
                end
                context.each do |item, value|
                  if item == "default"
                     if topologySpoutValueSecMap.has_key?(toname)
                        topologySpoutValueSecMap[toname] = topologySpoutValueSecMap[toname] + value
                     else
                        topologySpoutValueSecMap[toname] = value
                     end
                  end
                end
             end
           end
        end
      end
    end
    return topologySpoutValueSecMap
  end
  def close_topology()
    @@transport.close
  end
end
