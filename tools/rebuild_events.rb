#!/usr/bin/ruby -w

# This script rebuilds all events for inc_events.n in case
# events are being added/removed and the -dev is too lazy
# to maintain the list for herself.

counter = {} # Hash.new(0)

while s = $stdin.gets
	next unless s =~ /^([A-Z]+)_([A-Z]+)_([A-Z]+)\s+/
	a, b, c = $1, $2, $3
	counter[b] = 0 unless counter[b]
	puts "const int %s = 1 << %d;" % [a + "_" + b + "_" + c, counter[b]]
	counter[b]  = counter[b] + 1
end
