#!/usr/bin/env ruby
$:.push('gen-rb')

require 'zookeeper'
require 'json'
require 'rubygems'
require 'thrift'
require '../vendor/gen-rb/nimbus'


class Storm_info
  @@socket    = Thrift::Socket.new('10.52.126.75', 6627)
  @@transport = Thrift::FramedTransport.new(@@socket)
  @@protocol  = Thrift::BinaryProtocol.new(@@transport)
  @@client    = Nimbus::Client.new(@@protocol)
  @@transport.open
  @@cluster_info = @@client.getClusterInfo
  @@topologyAry = Array.new
  @@cluster_info.topologies.each{ |em| @@topologyAry.push(em) }
  

  def get_cluster_info()
	return @@cluster_info
  end 

  def get_topology_name()
    topologyName = Array.new
    @@topologyAry.each do |em|
      topologyName.push(em.name.to_s)
    end
    return topologyName
  end
  # name: topology name
  # return 
  def get_topology_spout(name)
    topologyInfoArray = Array.new
    executorsInfoArray = Array.new
    id = ""
    @@topologyAry.each do |em|
      if em.name.to_s == name 
         topology_info = @@client.getTopologyInfo(em.id)
	 id = em.id.to_s
         executorsInfoArray =  topology_info.executors    
      end
    end   
    topologySpoutValueSec = 0
    firstcheckFlag = true
    executorsInfoArray.each do |ex|
        if ex.component_id == "kafkaSpout"
           spout_emitted = ex.stats.emitted
           spout_emitted.each do |time,context|
             if time == "600"
                if context.empty?
                   topologySpoutValueSec = topologySpoutValueSec + 0
                end
                context.each do |item, value|
                  #puts "item: "+item+ " #{value}"
		  if item == "default"
                      firstcheckFlag ?  topologySpoutValueSec =  value :  topologySpoutValueSec += value
		      firstcheckFlag = false
                  end
                end
             end
           end
        end
      end
    
    return topologySpoutValueSec
  end
  #get topology id by name
  def get_topo_id(name)
        id = "" 
	@@cluster_info.topologies.each do |em|
           if em.name.to_s == name
           id =  em.id
 	   end
	end
     return id
  end
  #host list  code by jiqiang	
  def get_host_list(name)
     #first get topology id by name
     id = get_topo_id(name)
     if id == nil
     	puts "incorrect name, id is null "
	return nil
     end
     #second get TopologyInfo by calling client.getTopologyInfo
     topologyInfo = @@client.getTopologyInfo(id)
     executors =  Array.new
     topologyInfo.executors.each do |ea|
        executors.push(ea.host)
     end
     return executors     
  end
  #remove duplication from array
  def removeDu(list)
	noDu = Array.new
	flag = false
 	list.each do |each_|
		flag = true
		noDu.each do |du|
			if du == each_
			  flag = false
			end
		end
		if flag 
		   noDu.push(each_)
		end
	end
	return noDu
  end

  def close_topology()
    @@transport.close
  end
end
