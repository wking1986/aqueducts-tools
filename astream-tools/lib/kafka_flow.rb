#!/usr/bin/env ruby

require 'zookeeper'
require 'json'
require 'rubygems'

class Kafka_flow
  @@port = "8888"
  @@jarPath = "/home/work/nfs/jmxcmd.jar"
  @@kafkaOp = "kafka.server"
  @@type = "BrokerTopicMetrics"
  @@objectOut = "BytesOutPerSec"
  @@objectIn = "BytesOutPerSec"
  @@zkhost = "10.36.4.185"
  @@zkport = 2181
  
  def kafkaHosts()
    brokers = Array.new
    zk = Zookeeper.new("#{@@zkhost}:#{@@zkport}")
    zk.get_children(:path => "/brokers/ids")[:children].each do |ids|
      broker_meta = zk.get(:path => "/brokers/ids/#{ids}")[:data]
      broker_meta_in_json = JSON.parse(broker_meta)
      brokers.push(broker_meta_in_json["host"])
    end
    zk.close
    return brokers
  end
  def kafkaStatus(object, hosts, topicname)
    kafkaMsgCountSum = 0 
      hosts.each do |host|
      kafkaCmdValue = `java -jar #{@@jarPath} - #{host}:#{@@port} '"#{@@kafkaOp}":name="#{topicname}-#{object}",type="#{@@type}"' Count 2>&1`
      #by jiqiang test
      #puts  "kafkaCmdValue: -- "+kafkaCmdValue
      kafkaMsgCount = kafkaCmdValue.split(": ").last.to_i
      kafkaMsgCountSum = kafkaMsgCountSum + kafkaMsgCount.to_i
    end
    time = Time.new
    return kafkaMsgCountSum,time 
  end 
  
  def kafka_bytes(hosts, topic)
    kafkaBytesOutfirst, timefirst = kafkaStatus(@@objectOut, hosts, topic)
    kafkaBytesOutlater, timelater = kafkaStatus(@@objectOut, hosts, topic)
    #by jiqiang test
    #puts "kafkaBytesOutfirst: #{kafkaBytesOutfirst}   kafkaBytesOutlater:  #{kafkaBytesOutlater}"	
    puts "kafkaBytesOutPerSec: #{topic}: #{(kafkaBytesOutlater - kafkaBytesOutfirst) / (timelater - timefirst)}"
    kafkaBytesInfirst, timefirst = kafkaStatus(@@objectIn, hosts, topic)
    kafkaBytesInlater, timelater = kafkaStatus(@@objectIn, hosts, topic)
    #puts "kafkaBytesInfirst: #{kafkaBytesInfirst}   kafkaBytesInlater:  #{kafkaBytesInlater}"	
    puts "kafkaBytesInPerSec:  #{topic}: #{(kafkaBytesInlater - kafkaBytesInfirst) / (timelater - timefirst)}"
  end
end
