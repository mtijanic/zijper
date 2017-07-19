#!/usr/bin/ruby
require 'yaml'
require 'rubygems'
require_gem 'activerecord'
require 'progressbar'

$dbspecfile = ARGV.shift or fail "No database spec file"
$target = ARGV.shift or fail "No target directory"
$basefile = "cp_basic.uti"
$filemask = "cp_%d.uti"
$tagmask = "cp_%d"

trap "INT", proc {
	exit 1
}

class CraftingRecipe < ActiveRecord::Base
	set_table_name 'craft_prod'
	def cskill
		Craft::find(:first, :conditions => 
			['cskill = ?', super]
		)
	end
end

class Craft < ActiveRecord::Base
	set_table_name 'craft_crafts'
end

ActiveRecord::Base.establish_connection(YAML::load(File::new($dbspecfile, 'r')))

a = CraftingRecipe::find(
	:all
)
puts "%d recipes" % a.size

ids = {}
a.each do |recipe|
	file = $tagmask % recipe['id']
	ids[file] = recipe
	#if File::exists?(file)
	#	next
	#end
end

b = ProgressBar::new('cp', ids.size)
ids.each {|k,v|
	# copy base recipe
	if !v.cskill
		$stderr.puts "Recipe #{v['id']}/'#{v['name']}' has no valid cskill set."
		next
	end
	if !v.name
		$stderr.puts "Recipe #{v['id']} has no name set."
		next
	end
	file = k + ".uti"
	name = "(Rezept) " + v.cskill.name + ": " + v.name
	system("cp", $basefile, file)
	system("gffmodify.pl", file,
		'--variable', 'craft_recipe#int=' + v['id'].to_s,
		'-m', '/Tag=' + k,
		'-m', '/TemplateResRef=' + k,
		'-m', '/LocalizedName/4=' + name,
		'-m', '/Cost=' + v['cost'].to_s
	)

#	puts "%-16s => %s" % [k, name]
	b.inc
	# gffmodify k, '-m "/LocalizedName/4=' + name.gsub('"', '\"') + "\""
	# update description, palette, name and lvar
}
b.finish
