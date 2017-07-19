#!/usr/bin/env ruby
# This script fixes all door scripts in a git.yml template. Do not
# call it with anything else as a parameter.
#
require 'rubygems'
require 'nwn/gff'
require 'nwn/yaml'
require 'yaml'

$quit = false
trap "INT", proc { $quit = true }

scripts = {
  'OnClick' => 'door_click',
  'OnClosed' => 'door_closed',
  'OnDamaged' => 'door_damaged',
  'OnDisarm' => 'door_disarm',
  'OnDeath' => 'door_death',
  'OnFailToOpen' => 'door_failtoopen',
  'OnHeartbeat' => '',
  'OnMeleeAttacked' => 'door_attacked',
  'OnLock' => 'door_lock',
  'OnOpen' => 'door_open',
  'OnSpellCastAt' => 'door_spellcast',
  'OnTrapTriggered' => 'door_traptrig',
  'OnUnlock' => 'door_unlock',
  'OnUserDefined' => '',
}

count = ARGV.size
curr = 0
for file in ARGV do
  curr += 1
  print "#{file} (#{curr}/#{count}): "
  $stdout.flush
  changed = false

  gff = YAML.load(IO.read(file))

  print "(#{gff['Door List'].value.size}) "
  $stdout.flush
  gff['Door List'].value.each {|door|
    scripts.each {|n,desired_value|
      v = door[n].value
      if v != '' && v != desired_value && (n == 'OnDeath' && v != 'x2_door_death')
        print " #{n}=#{v} "
        $stdout.flush
      else
        if v != desired_value
          changed = true
          door[n] = NWN::Gff::Element.new(n, :resref, desired_value)
        end
      end
    }
    if door['LocName'].value.size > 0
      print " LocName! "
      $stdout.flush
      changed = true
      door['LocName'].value.languages.clear # = NWN::Gff::Element.new('LocName', :cexolocstr, {})
    end
  }

  if changed
    File.open(file, "w") {|f| f.write YAML.dump(gff) }
    print" w"
  end
  puts ""
  break if $quit
end
