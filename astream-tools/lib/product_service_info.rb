#!/usr/bin/env ruby
$:.push("gen-rb")

# 对于一个特定的product service period 组合，该类的实例记录了详细信息
#a particular product_service_period combination
class Product_service_info                                                                            
  def initialize(pro, ser, per, total, ave_res, ave_ser, delay_pv, ave_delay, max, min, ave_ser_per)
    @product = pro  
    @service = ser
    @period  = per  # 1 or 60 
    @total_pv = total  #总PV
    @ave_response_time = ave_res  #平均响应时间
    @ave_search_period = ave_ser  #查询时间区间平均值
    @delay_pv_per = delay_pv      #查询时间大于timeout的pv百分比
    @delay_pv_num = 0             #查询时间大于timeout的pv总数
    @ave_delay_pv_response_time = ave_delay   #查询时间大于timeout的pv平均响应时间
    @max_delay_response_time = max            #最大超时时间
    @min_delay_response_time = min            #最小超时时间
    @ave_delay_search_period = ave_ser_per    #超时查询，平均时间区间
  end
  #calculate result调用该函数计算最后结果
  def calResult
    @delay_pv_num = @delay_pv_per
    if @delay_pv_num !=nil && @delay_pv_num != 0
      @ave_delay_search_period /=@delay_pv_num
      @ave_delay_pv_response_time /= @delay_pv_num.to_f
	else
      @ave_delay_search_period = 0
	  @ave_delay_pv_response_time = 0
	  @max_delay_response_time = 0
	  @min_delay_response_time = 0
	end
    if @total_pv !=nil && @total_pv != 0
      @ave_response_time /= @total_pv
      @ave_search_period /= @total_pv
      @delay_pv_per /= @total_pv.to_f
	else
	  @ave_response_time = 0
	  @ave_search_period = 0
	  @delay_pv_per = 0
	end
    #formatAllNum
  end
  # 统一将Float保留4位小数
  def formatAllNum
    @ave_response_time = formatOneNum(@ave_response_time)
    @ave_search_period = formatOneNum(@ave_search_period)
    @delay_pv_per      = formatOneNum(@delay_pv_per)
    @ave_delay_pv_response_time = formatOneNum(@ave_delay_pv_response_time)
    @ave_delay_search_period    = formatOneNum(@ave_delay_search_period)
  end
  #4 decimal places 0.0001
  def formatOneNum(num)
    if num.class == Float
      num = num.to_s
      if num.length < 5
        return num 
      end
      flag = num.index(".")
      return  num[0..flag+4]
    else 
      return num 
    end
  end
  attr_accessor:product,:service,:period,:total_pv,:ave_response_time
  attr_accessor:ave_search_period,:delay_pv_num,:ave_delay_pv_response_time                                                             
  attr_accessor:max_delay_response_time,:min_delay_response_time,:ave_delay_search_period,:delay_pv_per
  def to_s 
    return "total_pv: #{@total_pv},ave_response_time: #{@ave_response_time},ave_search_period: #{@ave_search_period},"+
           "delay_pv_num: #{@delay_pv_num} ,delay_pv_per: #{@delay_pv_per},ave_delay_pv_response_time: #{@ave_delay_pv_response_time},"+
           "max_delay_response_time: #{@max_delay_response_time},min_delay_response_time: #{@min_delay_response_time},"+
           "ave_delay_search_period: #{@ave_delay_search_period}"
  end
end

