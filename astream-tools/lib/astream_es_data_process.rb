#!/usr/bin/env ruby
$:.push("gen-rb")

require 'rest-client' 
require 'jsonify'
require "../vendor/gen-rb/product_service_info"

#该类会调用Astream_es_data的search方法获取相关数据
#../script 下面的a-stream-tools.rb中会根据命令行参数调用 该类的get_es_data函数
class Astream_es_data_process
  # get_es_data函数接受参数，根据输入的product/service 查询从from到to的相关信息
  # 该函数处理了from/to跨越两天的情况，但是没有考虑两天以上的情况
  # @param [string: product]:  product name
  # @param [string: service]:  service name
  # @param [string:from]: starttime 
  # @param [sting:to]: endtime
  # @param [numeric:timeout]: response timeout threshold
  def get_es_data( product, service, from, to, timeout)
    @all_P_S_info = Hash.new  
    @product = product    
    @service = service
    @from = from
    @to = to
    @timeout = timeout
    @es_data = Astream_es_data.new 
    # time format
    # _index : chart_stats-14.07.09  
    # in_time and agent time format : 140709...
    @from_yy_mm_dd, @from_yymmdd = turnToYYMMDD(from)   
    @to_yy_mm_dd,@to_yymmdd = turnToYYMMDD(to)
    #same day 
    if @from_yymmdd == @to_yymmdd
      # @res_nor : array contationing hash 
      # response: 200
      @res_nor = @es_data.search(@from_yy_mm_dd.to_s,product,service,from,to,true)  
      #response : 非200 ,including 404 
      @res_abnor = @es_data.search(@from_yy_mm_dd.to_s,product,service,from,to,false)
    else
      #search from/to not in same day
      tempTo = "20#{@to_yymmdd}000000"
      @res_nor = @es_data.search(@from_yy_mm_dd.to_s,product,service,from,tempTo,true)  
      @res_abnor = @es_data.search(@from_yy_mm_dd.to_s,"","",from,tempTo,false)
      @res_nor_p2 = @es_data.search(@from_yy_mm_dd.to_s,product,service,tempTo,to,true)
      @res_abnor_p2 = @es_data.search(@from_yy_mm_dd.to_s,"","",tempTo,to,false)      
    end 
    @all_products = getAllProducts
    @all_services = getAllServices(@all_products)
    @count_period_60 = 0
    @count_period_1 = 0
  end
  # get all products and service 
  # 该函数用于获取所有的product，并返回包含所有products的数组
  # @return [array:all_products] 
  def getAllProducts
    @url = "http://api.aqueducts.baidu.com/v1/products/"
    all_products = Array.new
    res = RestClient.get @url
    res = JSON.parse(res)
    res.each do |each_p|
      all_products.push(each_p["name"])
    end  
    return all_products  
  end
  # getAllService 根据传入的products列表，获取所有的服务，并返回数组
  # @param [array: all_products]: all products list
  # @return [array:all_services]: return all services 
  def getAllServices(all_products)
    all_services = Array.new
    all_products.each do |each_|
      res = RestClient.get "#{@url}#{each_}/services"
      res = JSON.parse(res)
      res.each do |each_p|
        all_services.push(each_p["name"])
      end
    end
    return all_services
  end 
  # print all info 
  # print_all_info 打印所有需要查询的信息
  # 首先打印错误的信息
  # 然后按照product_service_period 输出信息
  # @param[boolean:pretty]: true means print json prettily  
  def print_all_info(pretty)
    @pretty = pretty
    #first print all abnormal request
    bad_sec = @res_abnor_p2 == nil ? 0 : @res_abnor_p2.length
    bad_res_num = @res_abnor.length + bad_sec
    size = @all_P_S_info.size
    json = Jsonify::Builder.new( :format => :pretty)
    json.bad_request_number bad_res_num
    json.produt_service_period_numver size
    puts json.compile!
    #for each product/service print corressponding info
    i = 1 
    @all_P_S_info.each do |key,value|
      process_one_PS(key,value,i)
      i += 1    
    end
  end
  # print info 
  # @param [string:key]: unique key- product_service_period 
  # @param [string:value]: detail info corresponding to key
  # @param [string:integer] : counter
  def process_one_PS(key,value,i)
    value.calResult
    if @pretty == nil || @pretty == false
      json = Jsonify::Builder.new 
    else 
      json = Jsonify::Builder.new( :format => :pretty)  
    end
    json.key do
      json.id  i
      json.key key
      json.product value.product
      json.service value.service 
      json.period  value.period
    end
    json.details do
      json.total_pv value.total_pv
      json.ave_response_time value.ave_response_time
      json.ave_search_period value.ave_search_period
      json.delay_info do
        json.delay_pv_per value.delay_pv_per 
        json.delay_pv_num value.delay_pv_num 
        json.ave_delay_pv_response_time value.ave_delay_pv_response_time
        json.max_delay_response_time value.max_delay_response_time
        json.min_delay_response_time value.min_delay_response_time
        json.ave_delay_search_period value.ave_delay_search_period
      end
    end
    puts json.compile!
  end
  # classfy all doc
  # cluster 遍历es的直接查询结果，将这些结果按照product/service/period 分类，product_service_period作为hash的key
  # Product_service_info类的实例作为value
  def cluster
    if @res_nor != nil 
      @res_nor.each do |each_map|
      process_one_source(each_map)  
      end
    end
    if @res_nor_p2 != nil
      @res_nor_p2.each do |each_map|
        process_one_source(each_map)
      end    
    end
  end
  # process one _source
  # 对一个es查询结果数组中的元素处理
  # @param [json: each_map]: one piece info containing request, responce, responce_time..
  def process_one_source(each_map)
    request = each_map._source.request
    response_time = each_map._source.response_time.to_f
    product,service,searchRange,period = get_P_S_searchRange_period_fromRequest(request)   
    # check if product and service in @all_product and @all_services
    if is_product_service_valid(product,service) == false
      return nil
    end
    # key
    key = "#{product}_#{service}_#{period}"
    if @all_P_S_info.has_key? (key)
      value = @all_P_S_info[key]
      value.total_pv += 1
      value.ave_response_time += response_time.to_f
      value.ave_search_period += searchRange
      if response_time.to_f > @timeout.to_f
        value.delay_pv_per += 1 
        value.ave_delay_pv_response_time += response_time.to_f
        max = value.max_delay_response_time
        value.max_delay_response_time = max > response_time ? max : response_time
        min = value.min_delay_response_time
        value.min_delay_response_time = min < response_time ? min : response_time
        value.ave_delay_search_period += searchRange
      end
      @all_P_S_info[key] = value
    else #no such key
      if response_time.to_f > @timeout.to_f
        value = Product_service_info.new(product,service, period,1,response_time,searchRange,1,response_time,response_time,response_time,searchRange)
      else
        value = Product_service_info.new(product, service, period, 1,response_time,searchRange, 0, 0, @timeout,100000,0)  
      end    
      @all_P_S_info[key]=value
    end
  end
  # check if product and service in @all_products and @all_services
  # 检查 product 和service是否是合法的
  # @param [string: product] : product name
  # @param [string:service] : service name
  # @return [boolean]
  def is_product_service_valid(product,service)
    p_flag = false
    s_flag = false     
    @all_products.each do |each_p|
      if each_p == product
        p_flag = true
        break
      end  
    end
    @all_services.each do |each_s|
      if each_s == service
        s_flag = true
        break
      end 
    end
    return (p_flag && s_flag)
  end
  # get product/service/searchRange form _source.request or _source.message
  # 从request信息中提取product service period range等信息
  # return [string:product,string:service, string: range,integer:period]
  def get_P_S_searchRange_period_fromRequest(req)
    all_item = req.split("&")
    product =  getInfoFromArray(all_item,"product")
    service =  getInfoFromArray(all_item,"service")
    #from = 
    #to = 
    period =  getInfoFromArray(all_item,"period")
    period = period == nil ? 1 : period
    #period = period.to_i
    range = 0
    return [product,service,range.to_f,period]
  end
  def getInfoFromArray(array,item)
    array.each do |each_|
      flag = each_.index(item)
      if flag != nil && flag >= 0 
        re = each_.split("=")
        return re[1]
      end  
    end
    return nil
  end
  # turn 20140608000000 (form/to) to yymmdd, in order to test if form and to in same day
  # 将输入的form/to 提出出 yymmdd，用来检测from和to是否是同一天的
  def turnToYYMMDD(from_to_time)
    time_s =  from_to_time.to_s
    if time_s.length == 14
      yy = time_s[2..3]
      mm = time_s[4..5]
      dd = time_s[6..7]
      return ["#{yy}.#{mm}.#{dd}","#{yy}#{mm}#{dd}"] 
    end
  end
end
