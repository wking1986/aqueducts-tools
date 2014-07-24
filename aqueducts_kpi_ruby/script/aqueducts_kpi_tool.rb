#!usr/bin/env ruby

require '../lib/aqueducts_kpi'
require 'rubygems'
require 'thor'


class Tools < Thor 
  desc "search_kpi [option]...[argument]...","search aqueducts kpi info"
  long_desc <<-LONGDESC
    `aqudects_kpi_tool.rb search_kpi` will print out messages about kpi corresponing to arguments.   
     \x5 You can optionally specify some parameter, which will print out a message as well 
     \x5 --one     default false 
     \x5 --product default []
     \x5 --service default []
     \x5 --oneday  default nil 
     \x5 --from    default yesterday current time 
     \x5 --to      default current time
     \x5 --email   default false
     \x5 --show    default false, show process detail 
     \x5 default: kpi will exclude those new p/s
     \x5 if --one is set, --product and --service must be set togethor
     \x5    eg.  --one -p sf,im  -s adcore,nova 
     \x5 if --oneday is set, --from and --to should not be set 
     \x5 some examples:
     \x5 1. ruby aqueducts_kpi_tool.rb search_kpi
     \x5    default search time is yesterday
     \x5    default p/s is dirty data   
     \x5 2. ruby aqueducts_kpi_tool.rb search_kpi --oneday 2014-07-10 -p sf,sf -s adcore,vega --email
     \x5    search and email  kpi info in 2014-07-10, excepting product sf's services adcore vega 
     \x5 3. ruby aqueducts_kpi_tool.rb search_kpi --from -5 
     \x5    search kpi info in last 5 hours 
     \x5 4. ruby aqueducts_kpi_tool.rb search_kpi --from 2014-07-11 --to 2014-07-13
     \x5    search kpi from 2014-07-10 00:00:00 to 2014-07-13 24:00:00
     \x5 5. ruby aqueducts_kpi_tool.rb search_kpi --oneday 2014-07-17 --show
     \x5    searh kpi in 2014-07-17 and show search process info
     \x5 6. ruby aqueducts_kpi_tool.rb search_kpi --one -p sf -s adcore --oneday 2014-07-10
     \x5    search sf/adcore's kpi in 2014-07-10
     \x5 7. ruby aqueducts_kpi_tool.rb search_kpi --one --from -24 -p sf,sf,im  -s adcore,vega,asp --show
     \x5    search sf/adcore, sf/vega, im/asp kpi info one by one 
  LONGDESC
  option :one,     :type => :boolean, :aliases => :on,:banner  => "no argument: search kpi for a partular product/service"
  option :product, :type => :string,  :aliases => :p, :banner => "argument: product list,eg sf,im,..."
  option :service, :type => :string,  :aliases => :s, :banner => "argument: service list,eg adcore,..."
  #option :only,    :type => :boolean,  :aliases => :on, :banner => "no argument :default exclude "
  option :oneday,  :type => :string,   :aliases => :o,:banner => "argument: search kpi for a partular day,eg 2014-07-15"
  option :from,    :type => :string,  :aliases => :f, :banner => "argument: start time:eg 2014-07-10 or -2(hours from current time) or '2014-07-10 20:20:30' "
  option :to,      :type => :string , :aliases => :t, :banner => "argument: fromat same as --from"
  option :email,   :type => :boolean,  :aliases => :e,:banner => "no argument: default false"
  option :show,    :type => :boolean,  :aliases => :sh, :banner => "no argument: show details"
  def search_kpi
    @product = options[:product]
    @service = options[:service]
    @one    = options[:one]
    @email   = options[:email]
    @from    = options[:from]
    @to      = options[:to]
    @oneday  = options[:oneday]
    @show    = options[:show]
    if @oneday != nil && @from !=nil 
      puts "--oneday and --from --to cannot be set togather"
      return false
    end
    if @oneday != nil 
      @from = @oneday
      @to   = @oneday
    end
    @kpi_info = Aqueducts_KPI_info.new
    @from,@to = @kpi_info.from_to_time_format(@from,@to)
    @time,@time_list = @kpi_info.get_time_list(@from,@to)
    #puts "time:\n #@time","time_list\n #@time_list"#,"time_list_dis:\n#@time_list_dis"
    #return nil
    @product_service_map = @kpi_info.get_product_service_map(@product,@service)
    if @show != nil && @show == true
      @kpi_info.set_show_detail
      #puts @product_service_map
    end
    if @product_service_map == nil 
      return false
    end
    if @one == true 
      if @product == nil 
        puts "when --one is set  --product cannot be empty"
        return false
      else 
        @product = @product.split(",")
        @service = @service.split(",")
        if @product.size != @service.size 
          puts "--product sf,im,.. --service adcore,nova.. must have the same size"
          return false
        end
        @kpi_info.get_one_product_service_kpi(@product,@service,@from,@to)
      end
    else
      @kpi_info.get_product_service_kpi_from_to(@product_service_map,@time,@time_list)
      if @email != nil && @email == true
        @kpi_info.sendemail
      end
    end
  end
end
Tools.start(ARGV)




