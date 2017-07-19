#!/usr/bin/ruby -w
$: << File::dirname(__FILE__)
require 'rubygems'
require 'progressbar'
require 'threadify'
$updatecmd = 'gffmodify.pl -m /PaletteID=%d %s'
$threads = 4

files = ARGV

puts "%d entities to work on" % files.size

# Dir => id
$cache = {}


puts "Filling strref cache"
files.each do |f|
	file = File::expand_path(f)
	path = File::dirname(file)

	next if $cache[path]

	if File::directory?(file)
		fail "Cannot specify directories. Use shell globbing to do that."
	end

	if !File::exists?(path + "/.strref")
		fail "No .strref found in #{path}"
	end

	id, strref = IO::read(path + "/.strref").split("\n", 2).map{|x| x.to_i}

	$cache[path] = id
end
puts "Cache filled."

Thread.abort_on_exception = true

p = ProgressBar::new("total", files.size)

threadify(files, $threads) {|aa|
	puts "Thread has #{aa.size} items"
	aa.each {|f|
		file = File::expand_path(f)
		path = File::dirname(file)
		id = $cache[path]

		puts($updatecmd % [id, file])
		unless system($updatecmd % [id, file])
			puts "oops: #{$?}"
			fail "Failed updating #{f}."
		end
		#puts "Thread executed."
		p.inc
	}
}
p.finish

puts "\nAll done."
#p all
