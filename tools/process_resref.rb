#!/usr/bin/ruby -w

$source = ARGV.shift or fail "No source specified."
$target = ARGV.shift or fail "No target specified."

f = File.new($source, "rb")
i = Marshal.load(f)
f.close

#  $i[resref] = {
#    :resref => resref,
#    :tag => tag, 
#    :name => name,
#    
#    :addcost => addcost.to_i,
#    :plot => plot.to_i,
#    :stolen => stolen.to_i,
#    :palette => palette.to_i,
#    :baseitem => baseitem.to_i,
#    :stacksize => stacksize.to_i,
#    :cursed => cursed.to_i
#  }

i.delete(nil)

i = i.sort.map{|n| n[1]}

i.map!{|n|n[:resref].strip!; n}

f = File.new($target, "w")

f.puts("# Source: #{$source}")
f.puts("# Date generated: " + Time.now.to_s)
f.puts("")
f.puts("# %-18s# %-32s %s" % ["ResRef", "Tag", "Name(4)"])
f.puts("")
i.each do |hash|
  f.puts("%-20s %-32s %s" %  [ hash[:resref], hash[:tag], hash[:name] ] )
end

f.close
