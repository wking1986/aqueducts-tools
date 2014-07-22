require 'rest-client'

req = "v1/events?product=sf&service=adcore&item=response_time&calculation=average&from=-1m&to=now&period=60"



puts req.length
puts req.index("product")
puts req.index("service")

puts req[req.index("product")+"product".length+1.. req.index("&service")-1]
puts req[req.index("service")+"service".length+1.. req.index("&item")-1]

def getStringPart(req,flag1)
  flag2 = req.index("&",req.index(flag1))-1
  return req[req.index(flag1)+flag1.length+1..flag2]
end

puts getStringPart(req,"service")
puts "--------------"
#puts req[req.index("&period")+"&period".length+1..req.length-1]

#from = getStringPart(req,"&from","&to")
#range = - from[0..from.length-2].to_i
#puts range

class SA
  def initialize
   @ji = 11122 
   @qiang = 110
  end
  attr_accessor:qiang,:ji
end

sa = SA.new
#sa.qiang = 10

puts sa.qiang
puts sa.ji

puts "qiang"
#sa.@qiang = 2

#puts sa.@qiang
#

f = 1.00987655
g = format("%.2f",f)
puts g

t = Time.new
puts t.year
puts t.month
puts  t.strftime("%Y%m%d%H%M%S")
puts  (Time.now - 24*60*60).strftime("%Y%m%d%H%M%S")

