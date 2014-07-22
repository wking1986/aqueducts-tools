
require 'json'
require 'rest-client'

url = "http://api.aqueducts.baidu.com/v1/products/"
response = RestClient.get url
puts response 
ret = JSON.parse(response)

ret.each do |json|
  name = json["name"]
  puts name
  http ="#{url}#{name}/services"
  res = RestClient.get http
  res = JSON.parse(res)
  puts res
end


