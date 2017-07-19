#!/usr/bin/env ruby


file = ARGV.shift or fail "No 2da file specified."
fields = ARGV
fields.size > 0 or fail "No fields specified."


rows = []
headers = []
IO::readlines(file).each {|l|
	case l.strip
	when /^2DA V2\.0/, ""
		next
	when /^\S+[a-z]+\S+/i
		headers = l.split(/\s+/).map{|x| x.strip.downcase}.reject{|x| x == ""}
	when /^(\d+)\s/
		line = l.split(/\s+/).map{|x| x.strip }.reject{|x|x == ""}
		rows << line.flatten
	else
		$stderr.puts "Unparseable line: #{l}"
	end
}
# p headers

res = []
hd = []
fields.each do |f|
	f = f.downcase
	fail "No such colname: #{f}" if !headers.index(f)
	hd << f
end
fields = hd
res<< hd

rows.each do |row|
	res << [[row[0]] + 
		fields.map {|f| row[headers.index(f) + 1] }
	].flatten
end
$stderr.puts( ( [["id"] + res[0]].flatten.join("\t")))
res[1..-1].each do |line|
	puts line.join("\t")
end
