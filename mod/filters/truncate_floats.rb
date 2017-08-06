#!/usr/bin/env nwn-dsl

# This truncates position floats to a sane width, thus avoiding
# miniscule floating point differences in version control diffs.

PRECISION = 4
PIBEARINGFIX = 3.1416

count = 0

self.each_by_flat_path do |label, field|
	next unless field.is_a?(Gff::Field)
	next unless field.field_type == :float
  next unless field.l == "Bearing" || field.l == "Facing" ||
    field.l =~ /Orientation$/ || field.l =~ /^(Point)?[XZY]$/ ||
    field.l =~ /Position$/

	field.field_value =
		("%.#{PRECISION}f" % field.field_value).to_f

  field.field_value = PIBEARINGFIX if field.field_value == - PIBEARINGFIX

	count += 1
end

log "#{count} floats truncated."
