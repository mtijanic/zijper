#!/usr/bin/env ruby
# This script fixes all scripts in a are.yml template. Do not
# call it with anything else as a parameter.

require 'rubygems'
require 'nwn/gff'
require 'nwn/yaml'
require 'yaml'

$quit = false
trap "INT", proc { $quit = true }

scripts = {
  'OnExit' => '_area_leave',
  'OnHeartbeat' => '_area_hb',
  'OnUserDefined' => '_area_udef',
}

tilesets = {
}

count = ARGV.size
curr = 0
for file in ARGV do
  curr += 1
  print "#{file} (#{curr}/#{count}): "
  $stdout.flush
  changed = false

  gff = YAML.load(IO.read(file))
  print "(#{gff['Tileset'].value}) "
  scripts.each {|n,desired_value|
    v = gff[n].value
    if v != '' && v != desired_value
      print " #{n}=#{v} "
      $stdout.flush
    else
      if v != desired_value
        changed = true
        gff[n] = NWN::Gff::Element.new(n, :resref, desired_value)
      end
    end
  }

  oev = gff['OnEnter'].value
  if oev == '' || oev !~ /^sr_enter/
    print " OnEnter=#{oev}"
  end

  if changed
    File.open(file, "w") {|f| f.write YAML.dump(gff) }
    print" w"
  end
  puts ""
#  tilesets[gff['Tileset'].value] ||= []
#  tilesets[gff['Tileset'].value] << gff['OnEnter'].value
#  tilesets[gff['Tileset'].value].uniq!
  break if $quit
end

#y tilesets
