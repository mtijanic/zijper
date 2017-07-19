#!/usr/bin/ruby


source = ARGV.shift or fail "No source specified."
target = ARGV.shift or fail "No target specified."

if !File::exists?(source)
	fail "Source does not exist."
end

if source !~ /(.+)\.([^\.]+)$/
	fail "No extension"
end

path = File::dirname(source)
base = File::basename(source)
ext = $2

fail "Source and target have the same base. No point." if base == File::basename(target)

field = "/" + case ext
	when "uti", "utc", "utp"
		"TemplateResRef"
	else
		fail "Unsupported extension: #{ext}"
end


inrepo = `svn info '#{source}' | grep Revision`.strip  != ""

fail "system(gffmodify.pl) failed" if
	!system("gffmodify.pl",
		"-m", "#{field}=#{target.downcase}",
		"-m", "/Tag=#{target}",
	source)


if inrepo
	fail "system(svn mv) failed" if 
		!system("svn", "mv", "--force", "--non-interactive", source, target)
else
	system("mv", "-v", "--", source, target + "." + ext)
end
