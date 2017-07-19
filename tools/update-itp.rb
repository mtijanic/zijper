#!/usr/bin/ruby

require 'rubygems'
require_gem 'progressbar'

$target = "test.itp";


$source = ARGV.map{|x| Dir[x]}.flatten

# read all templates

main = {}

p = ProgressBar.new("read", $source.size)
$source.each do |s|
	f = `gffprint.pl #{s}`
	f =~ /^\/TemplateResRef:\s+(.+)$/
	resref = $1
	f =~ /\/PaletteID:\s+(\d+)$/
	pid = $1.to_i
	f =~ /\/LocName\/4:\s+(.+)$/
	name = $1

	if !main[pid]
		main[pid] = {
			'ID' => pid,
			'STRREF' => 1235356,
			'List' => [],
		}
	end


	h = {
		'RESREF' => resref,
	}
	h['NAME'] = name if !name.nil?

	main[pid]['List'] << h

	p.inc
end
p.finish

p main
