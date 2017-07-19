#!/usr/bin/env ruby
#
# Give a summary of all file types and ranges (nwn-specific tool)


$rx = /^(.+?_)(\d+)(\..+)$/

target = (ARGV || [Dir::pwd]).flatten


all = target.map {|x|
	if !File::directory?(x)
		fail "No such file or directory."
	end
	Dir[File::expand_path(x + "/*.*")]
}.flatten

$base = Hash.new
all.each {|x|
	if x =~ $rx
		base, num, ext = $1, $2.to_i, $3
		$base[base + ext] = [] if !$base[base+ext]
		$base[base + ext] << num
	else
		$base[x] = [] if !$base[x]
		$base[x] << ["NP"]
	end
}
$base.sort.each {|k,v|
	puts "%s:\n\t%d min\t%d max\t%d total" % [k, v.sort[0], v.sort[-1], v.size]
}
