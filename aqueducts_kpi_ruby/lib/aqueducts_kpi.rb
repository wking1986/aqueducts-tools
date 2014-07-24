#!/usr/bin/env ruby

require 'rubygems'
require 'mongo'
require 'date'
require '../gen/email'
include Mongo

class Aqueducts_KPI_info
  def initialize
    #connect to mongo
    @mongo_client = MongoReplicaSetClient.new(["10.65.43.129:27017","10.92.33.26:27017","10.40.42.41:27017"])
    #use aqueducts_kpi collection
    @db = @mongo_client.db("aqueducts_kpi")
  end
  # get normalPv and delayPv for products except products in products_not_in 
  # arguments:
  # @param [db]: MongoDB database instance
  # @param [string:collection_name]: name of collections, eg. count_kpi | count_usable | search_kpi | search_usable
  # @param [Array: product_not_in]: those products you don't want search
  # @param [string:from]: starttime for searching, eg. 2014-07-10 12:23:23
  # @param [string:to]: endtime 2014-07-12 12:30:35
  # @return [Array]:return array containing hash like {id=>"sf",normalPv=>200,delayPv => 500} 
  def get_normalPv_delayPv_by_collection_name(db,collection_name,product_not_in,from,to)
    collection = db.collection(collection_name)
    selector = [{"$match" => {"product" => {"$nin" => product_not_in},
                              "date_time" => {"$gte" => from,"$lt" => to }}},
                {"$group" => {"_id" => "$product" ,# $product
                              "normalPv" => {"$sum" => "$normalPv"}, 
                              "delayPv" => { "$sum" => "$delayPv" }}}] 
    show_info("function_name: get_normalPv_delayPv_by_collection_name")
    show_info("selector:\n#{selector}")
    aggr_result = collection.aggregate(selector, {"allowDiskUse" => true})
    show_info("result:\n#{aggr_result.join("\n")}")
    return aggr_result
  end
  # when one is true/false,get a product info that exclude/include services in service_not, from "from" to "to" time
  # @param [db]
  # @param [string: collection_name]
  # @param [string:product]: name of the product
  # @param [Array: service_not]: array contains services
  # @param [string:from]: starttime
  # @param [string:to]: endtime
  # @param [boolean:one]: true include services in service_not, false $nin
  # @return[Array]:return array containing hash 
  def get_a_product_no_service_normalPv_delayPv(db,collection_name,product,service_not,from,to,one)
    collection = db.collection(collection_name)
    in_or_not = one == true ? "$in":"$nin"
    selector = [{"$match" => {"product" => product,
                             "service" => { in_or_not => service_not},
                              "date_time" => {"$gte" => from, "$lt" => to }}},
                {"$group" => {"_id" => "$product" ,
                              "normalPv" => {"$sum" => "$normalPv"},
                              "delayPv" => { "$sum" => "$delayPv" }}}]
    show_info "function_name: get_a_product_no_service_normalPv_delayPv"
    show_info "selector:\n#{selector}"
    aggr_result = collection.aggregate(selector, {"allowDiskUse" => true})
    show_info "result:\n#{aggr_result.join("\n")}"
    show_info "\n"
    return aggr_result
  end
  # search collection to get availability 
  # @param [db]
  # @param [string:collection_name]: collection name
  # @param [string:from]: starttime
  # @param [string:to]:endtime
  # @return [float,integer,integer]: return kpi,yes_num,no_num
  def get_availability_by_collection_name(db,collection_name,from,to)
    collection = db.collection(collection_name)
    selector = [{"$match" =>{"date_time" =>  {"$gte" => from,"$lt" => to } }} , 
                {"$group" => {"_id" => "$status","num" => {"$sum" => 1 }}}]
    aggr_result = collection.aggregate(selector,{"allowDiskUse" => true })
    show_info "function_name: get_availability_by_collection_name"
    show_info "selector:\n#{selector}"
    show_info "result:\n#{aggr_result.join("\n")}"
    show_info "\n"  
    size =  aggr_result.size 
    availability = 0
    yes_num = 0
    no_num = 0
    aggr_result.each do |each_|
      status = each_["_id"]
      if status == "YES"
        yes_num = each_["num"]
      elsif status == "NO"
        no_num = each_["num"]
      end
    end
    sum = yes_num + no_num
    if sum == 0 
      return 0.0, yes_num, no_num
    end
    return format("%.1f",yes_num/(sum*1.0)*100).to_f,yes_num,no_num
  end
  
  # devide a request into two parts, one is to search info for products those contains all their services
  # the other is to search info for products which not includu all services,
  # combine the two request result together
  # @param [db]
  # @param [string:collection_name]: name of collection
  # @param [hash[string,array]：product_service_map[product_name,service_list]]: key:product value:service_list
  # @param [string:from]
  # @prarm [string:to]
  # @return[float,integer,integer,integer]:return kpi,totalPv,normalPv,delay_pv
  def get_kpi_by_collection_name(db,collection_name,product_service_map,from,to)
    normal_delay_array = Array.new
    if product_service_map == nil || product_service_map.keys.size == 0
      normal_delay_array = get_normalPv_delayPv_by_collection_name(db,collection_name,[],from,to)
    else
      normal_delay_array = get_normalPv_delayPv_by_collection_name(db,collection_name,product_service_map.keys,from,to)
      product_service_map.each do|key,value|
        temp = get_a_product_no_service_normalPv_delayPv(db,collection_name,key,value,from,to,false)[0]
        if temp != nil
          normal_delay_array.push(temp) 
        end 
      end
    end
    show_info("all_details :\n#{normal_delay_array.join("\n")}")
    return cal_kpi(normal_delay_array)
  end
  # combine info together to get last result
  # @param [Array:normal_delay_array]: array contains hash like {id=> "sf", normalPv => 123, delayPv => 124 }
  # @return [float,integer,integer,integer]:return kpi,totalPv,normalPv,delay_pv
  def cal_kpi(normal_delay_array)
    normalPv_total = 0
    delayPv_total = 0
    if  normal_delay_array != nil
      normal_delay_array.each do |each_|
         #puts "normal:delay: #{each_["normalPv"]}  #{each_["delayPv"]}"
         normalPv_total += each_["normalPv"]
         delayPv_total += each_["delayPv"]
      end
      return  (normalPv_total/(delayPv_total+normalPv_total*1.0)*100),normalPv_total+delayPv_total,normalPv_total,delayPv_total
    end
  end
  # print kpi info
  # @param [string/array:time_in]: searching time range 
  def print time_in
    puts time_in
    puts "KPI:"
    puts "\tprocess :\t #{per(@pro_kpi)}\t #{common @pro_pv}\t #{common @pro_delayPv}"
    puts "\tsearch  :\t #{per @ser_kpi}\t #{common @ser_pv}\t #{common @ser_delayPv}"
    puts "Availability"
    puts "\tprocess :\t #{per @pro_avi}\t #{common @pro_yes_num}\t #{common @pro_no_num}"
    puts "\tsearch  :\t #{per @ser_avi}\t #{common @ser_yes_num}\t #{common @ser_no_num}" 
  end
  # retrun all info for erb,to fill email
  def get_time_info()
    return @from_format,@to_format
  end
  def get_kpi_info()
    return per(@pro_kpi),common(@pro_pv),common(@pro_delayPv),per(@ser_kpi),common(@ser_pv),common(@ser_delayPv)
  end
  def get_avi_info()
    return @pro_avi.to_s+"%",common(@pro_yes_num),common(@pro_no_num),@ser_avi.to_s+"%",common(@ser_yes_num),common(@ser_no_num)
  end
  # sendemail 
  def sendemail
    mail = KPI_HTML.new(self)
    mail.send 
  end
  # format kpi 
  # @param [float:x]: kpi
  # @return [string]: formatted kpi
  def per(x)
    return x.to_s[0..8]+"%"
  end
  # format big pv number, eg. 123120997 => 123,120,997
  # @param [integer:x]: big integer
  # @return [string] : formatted big number
  def common(x)
    str = x.to_s.reverse
    str.gsub!(/([0-9]{3})/,"\\1,")
    return  str.gsub(/,$/,"").reverse
  end
  # add dirty product/service into product_service_map, and remove duplication
  # @param [hash[string,array]]
  # @param [array:pro2]: product list
  # @param [array:ser2]: service list
  # @param [hash[string,array]]
  def concat_pro_ser(product_service_map,pro2,ser2)
    temp_map = product_service_map
    all = Array.new
    size = pro2.size
    0.upto(size-1){ |i| 
      p = pro2[i]
      s = ser2[i]
      if temp_map.has_key?(p)
        temparray = temp_map[p]
      else
        temparray = Array.new
      end
      temparray.push(ser2[i])
      temp_map[p]=temparray.uniq
    }
    #puts "\n"
    show_info("exclude_p/s:\n#{temp_map}")
    return temp_map
  end
  # get product/services that is new corresponding to "yesterday"
  # @param [string:time]: 2014-07-10 
  # @return [array,array:new_p,new_s]: return two arrays contains new product/services
  def new_and_old_service(time)
    yesterday = Date.parse(time)-1
    collection_name = "count_kpi"
    time_product_service = get_all_product_service_by_time(@db,collection_name,time)
    yest_product_service = get_all_product_service_by_time(@db,collection_name,yesterday.to_s)
    new_p = Array.new
    new_s = Array.new
    time_product_service.each do|each_|    
      if yest_product_service.include?(each_) == false
        temp = each_.split(" ")
        new_p.push(temp[0])
        new_s.push(temp[1])
      end
    end
    return new_p,new_s
  end
  # get all product/service in "time"
  # @param [db]
  # @param [string:collection_name]
  # @param [string:time]: eg.2014-07-10
  # @return [Array:array]: return all product/services in "time"
  def get_all_product_service_by_time(db,collection,time)
    collection = db.collection(collection)
    selector = [{"$match" => {"check_time" => time}},
                {"$group" => {"_id" => {"product" =>"$product" ,"service"=>"$service"}}}]
    aggr_result = collection.aggregate(selector, {"allowDiskUse" => true})
    arry = Array.new
    aggr_result.each do |each_|
      temp = each_["_id"]
      arry.push("#{temp["product"]} #{temp["service"]}")
    end
    return arry
  end
  # get and print particular product/services combination's kpi info one by one
  # @param [array:products]: array contains products list
  # @param [array:services]: services list
  # @param [string:from]: starttime
  # @param [string:to]: endtime
  def get_one_product_service_kpi(products,services,from,to)
    size = products.size
    0.upto(size -1) do |i|
      res =   get_a_product_no_service_normalPv_delayPv(@db,"count_kpi",products[i],[services[i]],from,to,true)[0]
      normalPv = res["normalPv"]
      delayPv = res["delayPv"]
      totalPv = normalPv + delayPv
      kpi = normalPv/(totalPv*1.0)*100
      puts "Product/service: #{products[i]}/#{services[i]}"
      puts "KPI: #{per(kpi)}\t PageView: #{common(totalPv)}\t normalPv: #{common(normalPv)}\t delayPv: #{common(delayPv)}" 
    end
  end
  # invoke in aqueducts_kpi_tool 
  # get and print all kpi info
  # this function will invoke other functions to get and print kpi
  # @param [hash[string,array]]:  service_map[product_name,service_list]]: key:product value:service_list_not_in: array
  # @param [array:time]: "YYYY-MM-DD" list. eg. ["2014-10-11","2014-10-12"]
  # @param [array:time_lsit]: "YYYY-MM-DD HH-mm-ss" list. 
  def get_product_service_kpi_from_to(product_service_map,time,time_list)
    @pro_normalPv_list = Array.new
    @pro_delayPv_list  = Array.new
    size = time.size
    0.upto(size-1) do |i|
      new_p,new_s = new_and_old_service(time[i]) 
      product_service_map = concat_pro_ser(product_service_map,new_p,new_s)
      pro_kpi,pro_pv,pro_normalPv,pro_delayPv = get_kpi_by_collection_name(@db,"count_kpi",product_service_map,time_list[i],time_list[i+1])
      @pro_normalPv_list.push(pro_normalPv)
      @pro_delayPv_list.push(pro_delayPv)
    end
    pro_size = @pro_normalPv_list.size
    @pro_pv = 0
    @pro_delayPv = 0
    0.upto(pro_size-1) {|i|@pro_pv += @pro_normalPv_list[i]+@pro_delayPv_list[i]; @pro_delayPv+=@pro_delayPv_list[i]}            
    @pro_kpi = (@pro_pv-@pro_delayPv)/(@pro_pv*1.0)*100
    last = time_list.size-1
    @ser_kpi,@ser_pv,@ser_normalPv,@ser_delayPv = get_kpi_by_collection_name(@db,"search_kpi",nil,time_list[0],time_list[last])
    @pro_avi,@pro_yes_num,@pro_no_num = get_availability_by_collection_name(@db,"count_usable",time_list[0],time_list[last])
    @ser_avi,@ser_yes_num,@ser_no_num =  get_availability_by_collection_name(@db,"search_usable",time_list[0],time_list[last])
    puts "Starttime: #{time_list[0]}\t Endtime: #{time_list[last]}\t timegap: #{time_list.size-1} "
    print nil
  end
  # change "from" and "to" into corresponding format, "YYYY-MM-DD HH-mm-ss"
  # @param [string:from]: from  maybe nil, 2014-07-10 , -5 or 2014-07-10 12:30:35
  # @param [string:to]: to mabye nil , 2014-07-10 or 2014-07-10 12:30:35
  # @return [string,string] : return formatted time
  def from_to_time_format(from,to)
    @to_format = to
    @from_format = from
    if from == nil &&  to  == nil
      from  = (Time.new-24*60*60).to_s.split(" ")[0]
      to    = from + " 24:00:00"
      from  = from + " 00:00:00"
      @from_format = from
      @to_format = to
      return from,to
    end
    if to == nil || to == ""
      to = timeformat_change(Time.new)
      @to_format = to
    end
    if from.to_s.size < 5
      from_format = (Time.new + from.to_i*60*60)
      @from_format = timeformat_change(from_format)
    else
      if from.size < 12
        from = from.split("-")
        from = Time.new(from[0].to_i,from[1].to_i,from[2].to_i) 
        @from_format = timeformat_change(from)
      end
    end
    if to.size < 12
      @to_format = to+" 24:00:00"
    end
    show_info("from_time: #{@from_format}\t to_time #{@to_format}")
    return @from_format,@to_format
  end
  # 2014-07-16 12:30:35 00.00  into   2014-07-10 12:30:35
  def timeformat_change(time)
    from_format = time.to_s.split(" ")
    from_format = "#{from_format[0]} #{from_format[1]}"
    return from_format
  end
  # get "form" to "to" date list
  # @param [string:from]: 2014-07-10 12:30:25
  # @param [string:to]:
  # @return [Array:time,Array:time_list]
  def get_time_list(from,to)
    time_list = Array.new
    time_list.push(from)
    temp_from = from.split(" ")[0]
    temp_to   = to.split(" ")[0]
    date_from = Date.parse temp_from
    date_to   = Date.parse temp_to
    if date_to < date_from
      puts "from is starttime,to is endtime"
      return nil
    end
    time = Array.new
    date_from.upto( date_to){ |i| time.push(i.to_s); time_list.push("#{i} 24:00:00")}
    time_list[time_list.size-1] = to
    return time,time_list
  end
  # combine product and service into a hash[string,array]
  # key: product name, value: product's services
  # @param [array:product]: products list
  # @param [array:service]: services lsit
  def get_product_service_map(product,service) 
    if product == nil && service == nil 
      return Hash.new
    end
    productArr = product.split(",")
    if service == nil
      serviceArr = []
    else 
      serviceArr = service.split(",")
    end
    size = productArr.size
    ps_hash = Hash.new
    if serviceArr.size !=0 && serviceArr.size != productArr.size
      puts "--product --service wrong argument"
      return nil
    end
    if serviceArr.size == productArr.size
      0.upto(size-1) do |i|
        p = productArr[i]
        if ps_hash.has_key?(p)
          temparray = ps_hash[p]
        else
          temparray = Array.new
        end
        temparray.push(serviceArr[i])
        ps_hash[p]=temparray.uniq
      end
    else
      # serviceArr.size == 0
      0.upto(size-1) do |i|
        p = productArr[i]
        ps_hash[p]=[]
      end
    end
    return ps_hash
  end
  # set if show detail info
  def set_show_detail
    @show_detail = true
  end
  def show_info(info)
    if @show_detail != nil && @show_detail == true
      puts info
    end
  end
  #------test code-----
  def test2(collection_name,from,to)
    collection =@db.collection(collection_name)
    selector = [{"$match" =>{"@timestamp" =>  {"$gt" => from,"$lt"=>to } }} ,
                {"$group" => {"_id" => "$status","num" => {"$sum" => 1 }}}]
    aggr_result = collection.aggregate(selector,{"allowDiskUse" => true })
    size =  aggr_result.size
    availability = 0
    yes_num = 0
    no_num = 0
    aggr_result.each do |each_|
      status = each_["_id"]
      if status == "YES"
        yes_num = each_["num"]
      elsif status == "NO"
        no_num = each_["num"]
      end
    end
    sum = yes_num + no_num
    if sum == 0
      return 0.0, yes_num, no_num
    end
    return format("%.1f",yes_num/(sum*1.0)*100).to_f,yes_num,no_num
  end 
end
