#!/usr/bin/env ruby
# This script prints out all placeables that are flagged as
# useable.

require 'rubygems'
require 'nwn/all'

$quit = false
trap "INT", proc { $quit = true }

count = ARGV.size
curr = 0
for file in ARGV do
  curr += 1
  puts "#{file} (#{curr}/#{count}): "
  $stdout.flush

  gff = YAML.load(IO.read(file))
  
  (gff / 'Placeable List$').each {|p|
    if p / 'Useable$' == 1 && p / 'Static$' == 0
      puts "  %-32s %2x:%2x" % [ p/'Tag$', p/'X$', p/'Y$' ]
      puts "    %s" % [ p.keys.select {|k| k =~ /^On/ }.map {|k| p/(k+"$")}.join(' ') ]
    end
  }

  break if $quit
end
