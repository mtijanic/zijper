#!/usr/bin/env ruby
# This script prints out all placeables that are flagged as
# useable.

require 'rubygems'
require 'nwn/gff'
require 'nwn/yaml'
require 'nwn/twoda'
require 'yaml'

if __cache_location = ENV['NWN2DAHOME']
  require 'nwn/helpers'
  NWN::TwoDA::Cache.setup __cache_location
  NWN::Gff::Helpers._ip_cache_setup
else
  fail "Environment variable `NWN2DAHOME' is not available"
end

module NWN::Gff::Helpers
def self.item_property_to_s p # name, subtype, cost, costvalue, p1, p1value, chanceappear = 100
  name, subtype, cost, costv, p1, p1v = p['PropertyName'].value,
    p['Subtype'].value, p['CostTable'].value, p['CostValue'].value,
    p['Param1'].value, p['Param1Value'].value

  {
    :name => @properties.by_row(name, 'Label'),
    :subtype => @subtype == 0 || @subtypes[name].nil? ? nil : @subtypes[name].by_col(1)[subtype],
    :cost => @costtables[@prop_id_to_costtable[name].to_i].by_col('Label')[costv],
    :p1 => p1 == 255 ? nil : @paramtables[@prop_id_to_param1[name].to_i].by_col('Label')[p1v],
  }
end
end

$quit = false
trap "INT", proc { $quit = true }

count = ARGV.size
curr = 0
for file in ARGV do
  curr += 1
  puts "#{file} (#{curr}/#{count}): "
  $stdout.flush

  gff = YAML.load(IO.read(file))

  puts "%-30s | %-15s | %-15s | %-15s" % %w{Name Subtype CostV Param1V}
  puts "-" * (30+15*3)
  gff['PropertiesList'].value.each {|prop|
    puts "%-30s | %-15s | %-15s | %-15s" % [*NWN::Gff::Helpers.item_property_to_s(prop).values]
  }
  puts "---"

  break if $quit
end
