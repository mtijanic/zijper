# Splits an array uniformly over count threads,
# running the given block for each one,
# passing the sub-array as the only argument.
def threadify(a, count = 2, &block)
	per_thread = a.size / count
	thra = []
	for i in 0..count do
			base = i * per_thread
			thra[i] = a[base, per_thread]
	end
	thra.reject! {|f| f.size == 0}

	threads = []

	thra.each do |tha|
		threads << Thread.new {
			begin
				yield(tha)
			rescue Exception => e
				$stderr.puts "Thread failed with exception #{e}"
				$stderr.puts(e.backtrace.join("\n"))

			end
		}
	end
	threads
end
