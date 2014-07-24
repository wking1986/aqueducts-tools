#!/usr/bin/env ruby

require 'erb'    


class KPI_HTML
  include ERB::Util  
  attr_accessor :pro_kpi,:pro_pv,:pro_delayPv,:ser_kpi,:ser_pv, :ser_delayPv
  # initialize info
  # @param [Aqueducts_KPI_info:kpi_info]  
  def initialize(kpi_info)
    @time_from,@time_to =kpi_info.get_time_info
    @pro_kpi,@pro_pv,@pro_delayPv,@ser_kpi,@ser_pv,@ser_delayPv = kpi_info.get_kpi_info
    @pro_avi,@pro_yes_num,@pro_no_num,@ser_avi,@ser_yes_num,@ser_no_num = kpi_info.get_avi_info
    @kpi_template = File.read("../lib/table_kpi_avi.html.erb")    
  end
  def render()
    # read the erb template 
    return ERB.new(@kpi_template).result(binding)
  end
  def mailsend(sender,receiver,subject,html)
    message = "To:#{receiver}\nFrom:#{sender}\nSubject:#{subject}\nContent-type:text/html\n#{html}"
    fd = File.open("./mail.html","w")
    fd.puts message
    fd.close
    cmd = "/usr/lib/sendmail -t <mail.html 2> /dev/null"
    if  system(cmd) == true
      return true
    end
  end
  # send eamil 
  def send()
    html = render
    sender = "aqueducts@baidu.com"
    receiver = "jiqiang@baidu.com"
    subject  = "[Aqueducts KPI]"
    begin
      mailsend(sender,receiver,subject,html)
    rescue
      mailsend(sender,receiver,"error","this is a test, sorry!")
    end
  end
end
