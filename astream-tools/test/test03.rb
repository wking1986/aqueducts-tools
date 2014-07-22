
require 'jsonify'


  @person = Struct.new(:first_name,:last_name).new('George','Burdell')

  Link = Struct.new(:type, :url)

  @links = [
    Link.new('self', 'http://example.com/people/123'),
    Link.new('school', 'http://gatech.edu')
  ]

 #Build this information as JSON
 # require 'jsonify'
 json = Jsonify::Builder.new(:format => :pretty)

 json.qiang "ji"
 # Representation of the person
 json.alumnus do
   json.fname @person.first_name
   json.lname @person.last_name
 end

     # Relevant links
  json.links(@links) do |link|
    json.rel link.type
    json.href link.url
  end

         # Evaluate the result to a string
 puts  json.compile!
