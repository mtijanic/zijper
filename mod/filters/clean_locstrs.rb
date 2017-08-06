#!/usr/bin/env nwn-dsl

# This FILTER walks all cexolocstrs and makes sure
# that there are no stray language-ids.
#
# This is obviously only useful for single-language projects.

want Gff::Struct

count = 0

self.each_by_flat_path do |label, field|
  next unless field.is_a?(Gff::Cexolocstr)
  next if field.v.size == 0

  val = field.v.dup

  # strip empty strings
  val.reject! {|k,v|
    v.strip == ""
  }

  rej_lid = ENV['NWN_LIB_CLEAN_LOCSTR_REJECT_LANGUAGES']
  val.reject! {|k,v|
    rej_lid.index(k.to_s)
  } if val.size > 1 && rej_lid && rej_lid = rej_lid.split(/\s+/)

  # Remove all duplicate values.
  val.each {|k,v|
    ppx = val.select {|kk,vv| vv == v}[0..-2]
    next if ppx == nil
    ppx.each {|kk,vv| val.delete(kk) }
  }

  compactable = val.size < 2

  unless will_output?
    unless compactable
      log "%s: need interactive." % [label]
      log "  %s" % [val.inspect]
    else
      log "%s: can fix for myself." % label
    end

  else
    str = nil
    unless compactable
      log "Cannot compact #{label}, because the contained strings are not unique."
      selection = ask "Use what string?", val
      log "Using: #{selection.inspect}"
      str = selection
    else
      str = val[val.keys.sort[0]]
    end
    if str
      field.v.clear
      field.v[0] = str
      count += 1
    end
  end
end

log "#{count} str-refs modified." if will_output?
