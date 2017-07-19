#!/usr/bin/ruby -w
$: << File::dirname(__FILE__)
require 'threadify'
require 'rubygems'
require_gem 'progressbar'

$target = ARGV.shift or fail "No target specified."
$source = ARGV.size == 0 ? nil : ARGV or fail "No source specified."

$threads = 8

$ih = {}

def save
	f = File.new($target, "wb")
	Marshal.dump($ih, f)
	f.close
	puts "written: #{$ih.size}"

	f = File.new($target, "rb")
	i = Marshal.load(f)
	f.close
	puts "verified loading: #{i.size}"
end

trap "SIGINT", proc {save; exit}
trap "SIGTERM", proc {save; exit}

items = $source
puts "source size = #{items.size}"
p = ProgressBar.new("read", items.size)

threadify(items, $threads) {|tit|
	tit.each do |n|
		d = `gffprint.pl #{n}`
		d =~ %r{^/(?:Template)?ResRef:\s+([a-z0-9_]+)$}mi
		resref = $1 
		d =~ %r{^/Tag:\s+([^/]+)$}mi
		tag = $1 
		d =~ %r{^/(?:Localized|First)?Name/4:\s+(.+)$}
		name = $1
		name += " " + $1 if d =~ %r{^/LastName/4:\s+(.+)$}
		d =~ %r{^/AddCost:\s+(\d+)$}
		addcost = $1.to_i #same as || 0

		d =~ %r{^/Plot:\s+(\d+)$}
		plot = $1.to_i
		
		d =~ %r{^/Stolen:\s+(\d+)$}
		stolen = $1.to_i
		d =~ %r{^/PaletteID:\s+(\d+)$}
		palette = $1.to_i
		d =~ %r{^/BaseItem:\s+(\d+)$}
		baseitem = $1.to_i 

		d =~ %r{^/StackSize:\s+(\d+)$}
		stacksize = $1.to_i

		d =~ %r{^/Cursed:\s+(\d+)$}
		cursed = $1.to_i

		if name == ""
			puts "Skipping #{resref}"
			next
		end

		$ih[resref] = {
			:resref => resref,
			:tag => tag, 
			:name => name,

			:addcost => addcost.to_i,
			:plot => plot.to_i,
			:stolen => stolen.to_i,
			:palette => palette.to_i,
			:baseitem => baseitem.to_i,
			:stacksize => stacksize.to_i,
			:cursed => cursed.to_i
		}

		# puts resref
		p.inc
	end
}.each {|t| t.join }

p.finish

save
exit

