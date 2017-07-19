#!/usr/bin/env ruby
require 'rubygems'
require_gem 'progressbar'

require 'digest/md5'

$data = {
# filename => md5sum
'target' => {},
'merge'  => {},

# files to merge(tmp storage)
'to_merge' => {},

# mv| file in target => file in merge
'to_to' => {},
}

$merge_rx = /^(.+?_)(\d+)(\.tga)$/i

target = ARGV.shift or fail "No target directory specified."
merge = ARGV.shift or fail "No merge directory specified."
final = ARGV.shift or fail "No final directory specified."

target = File::expand_path(target)
merge = File::expand_path(merge)
dir = Dir::pwd
$datafile = "#{dir}/data.%s" % [Digest::MD5.hexdigest(target + merge)]

if File::exists?($datafile)
	puts "File exists, not creating new index."
	$data = Marshal::load(File::new($datafile, "r"))
else
	Dir::chdir(merge)
	m = Dir["*.*"]
	p = ProgressBar.new("merge", m.size)
	$data['merge'] = Hash[*m.map {|x|
		p.inc
		d = IO.read(x)
		[x, Digest::MD5.hexdigest(d)]
	}.flatten]
	$data['to_merge'] = $data['merge'].dup

	puts ""

	Dir::chdir(target)
	m = Dir["*.*"]
	p = ProgressBar.new("target", m.size)
	$data['target'] = Hash[*m.map {|x|
		p.inc
		d = IO.read(x)
		[x, Digest::MD5.hexdigest(d)]
	}.flatten]
	puts ""
	puts "Saving."
	Marshal::dump($data, File::new($datafile, "w"))

end

# check dups
puts "merge:    #{$data['merge'].size}"
puts "target:   #{$data['target'].size}"

# remove all files that are md5-equal
puts "Removing all merge files that are md5-equal"
p = ProgressBar.new("copy", $data['to_to'].size)
($data['merge'].values - $data['target'].values).each do |val|
	$data['to_merge'].delete(
		$data['to_merge'].index(val)
	)
	p.inc
end
puts ""
puts "to merge: #{$data['to_merge'].size}"

puts "Renaming all merge files to fit schema"

p = ProgressBar.new("rename", $data['to_to'].size)
$data['to_merge'].sort.each do |k,v|
	if $data['target'].has_key?(k)
		raise "erp" unless k =~ $merge_rx
		base = $1
		num  = $2.to_i
		rest = $3
		num += 1
		newk = base + num.to_s + rest
		# puts " exists: #{k}"
		
		$data['to_merge'].delete(k)
		$data['to_to'][k] = newk
	else
		$data['to_to'][k] = k
	end
	p.inc		
end
puts ""

$data['to_merge'].sort.each do |k,v|
	if $data['target'].has_key?(k)
		puts "exists: #{k}"
	end
end

puts "to move:  #{$data['to_to'].size}"

puts "copying files to new directory"
p = ProgressBar.new("copy", $data['to_to'].size)
$data['to_to'].each do |k,v|
	system("cp", merge + "/" + k, final + "/" + v)
	p.inc
end
puts ""

# Marshal::dump($data, File::new($datafile, "w"))
