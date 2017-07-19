#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Gff.pm -- Gff object module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Gff.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Gff.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 14:06 Jul 20 2004 kivinen
#	  Last Modification : 03:34 Aug  9 2007 kivinen
#	  Last check in     : $Date: 2007/08/15 12:56:50 $
#	  Revision number   : $Revision: 1.20 $
#	  State             : $State: Exp $
#	  Version	    : 1.765
#	  Edit time	    : 376 min
#
#	  Description       : Gff object module
#
#	  $Log: Gff.pm,v $
#	  Revision 1.20  2007/08/15 12:56:50  kivinen
#	  	Added check that types are defined before comparing them.
#
#	  Revision 1.19  2007/06/08 00:25:34  kivinen
#	  	Added support for converting languages names to codes. Fixed
#	  	documentation.
#
#	  Revision 1.18  2007/05/23 22:20:30  kivinen
#	  	No changes.
#
#	  Revision 1.17  2007/05/23 20:04:40  kivinen
#	  	Added support for finding items based on the type.
#
#	  Revision 1.16  2007/05/17 22:04:03  kivinen
#	  	Added print_code feature.
#
#	  Revision 1.15  2006/11/23 17:55:48  kivinen
#	  	Added del to encoded characters.
#
#	  Revision 1.14  2006/11/23 17:54:01  kivinen
#	  	Print special characters with % encoding.
#
#	  Revision 1.13  2006/11/01 19:20:13  kivinen
#	  	Added encode function.
#
#	  Revision 1.12  2006/10/24 21:11:28  kivinen
#	  	Added manual.
#
#	  Revision 1.11  2005/10/27 17:03:38  kivinen
#	  	Changed so that get_or_set can also return full structures.
#	  	Added support for extracting the text from tlk file, if
#	  	tlk object is given to print.
#
#	  Revision 1.10  2005/10/25 10:54:34  kivinen
#	  	Changed to print string_ref.
#
#	  Revision 1.9  2005/10/11 15:08:59  kivinen
#	  	Changed the diffing routine to return more usefull outputs.
#
#	  Revision 1.8  2005/07/06 11:04:55  kivinen
#	  	Added copy_to_top.
#
#	  Revision 1.7  2005/02/05 14:31:12  kivinen
#	  	Fixed get_or_set so it will not create hash tables when
#	  	reading values. Added support for deleting the variable table
#	  	if it ever comes empty. Added support fof skip_matching_label
#	  	and skip_matching_value in print (used to skip empty values
#	  	etc). Fixed find_level so it will correctly set the parent
#	  	gffs to only have Gff hashes (no arrays). Added diff to get
#	  	full list of differences.
#
#	  Revision 1.6  2004/12/05 16:46:51  kivinen
#	  	Fixed variable handling so it will remove the old variable
#	  	before adding new variable. Fixed returning of variable to
#	  	return last variable also.
#
#	  Revision 1.5  2004/11/21 14:22:25  kivinen
#	  	Allow get_or_set to take path to the item to get or set, so it
#	  	can be used to change or read values deeper in the tree.
#
#	  Revision 1.4  2004/09/20 11:43:06  kivinen
#	  	Added proper value to the proc when calling it. Removed extra
#	  	j++ from array loop.
#
#	  Revision 1.3  2004/08/25 15:21:38  kivinen
#	  	Changed to use UNIVERSAL::isa.
#
#	  Revision 1.2  2004/08/25 14:32:58  kivinen
#	  	Changed to use UNIVERSAL::isa instead of ref.
#
#	  Revision 1.1  2004/08/15 12:34:04  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Gff;
use strict;
use Carp;

######################################################################
# Set gff

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    if (!ref($_[0])) {
	my(%temp);
	bless \%temp, $class;
	return \%temp;
    } 
    bless $_[0], $class;
    return $_[0];
}

######################################################################
# $value = $self->get_or_set($field)
# $value = $self->get_or_set($field, $value);
#
# Get or set field

sub get_or_set {
    my $self = shift;
    my $field = shift;
    my $create = 0;

    if (@_) {
	$create = 1;
    }

    if ($field =~ /^([^\/]*)\/(.*)$/) {
	my($dir, $rest, $num, $newgff, %newhash);
	$dir = $1;
	$rest = $2;
	if ($dir eq '') {
	    # top
	    return get_or_set($self, $rest, @_);
	}
	if ($dir =~ /^(.*)\[(\d+)\]$/) {
	    # array
	    $dir = $1;
	    $num = $2;
	    if (!defined($$self{$dir})) {
		my(@newarray);
		return undef if (!$create);
		# No array there, create one
		$$self{$dir} = \@newarray;
	    }
	    if (!defined($$self{$dir}[$num])) {
		return undef if (!$create);
		$newgff = Gff->new(\%newhash);
		$$self{$dir}[$num] = $newgff;
	    }
	    return get_or_set($$self{$dir}[$num], $rest, @_);
	}
	if (!defined($$self{$dir})) {
	    return undef if (!$create);
	    $newgff = Gff->new(\%newhash);
	    $$self{$dir} = $newgff;
	}
	return get_or_set($$self{$dir}, $rest, @_);
    }
    if (@_) {
	$$self{$field} = $_[0];
	if ($field =~ /^(.*)\. ____type$/) {
	    # Check that the item exists where the type is referencing to
	    if (!defined($$self{$1})) {
		# Not, create it
		if ($_[0] == 12 || $_[0] == 14) {
		    my(%newhash);
		    $$self{$1} = \%newhash;
		} elsif ($_[0] == 15) {
		    my(@newarray);
		    $$self{$1} = \@newarray;
		}
	    }
	}
	shift;
	confess "too many arguments" if (@_);
    }
    if ($field eq '') {
	return Gff->new($self);
    }
    if (ref($$self{$field}) eq 'ARRAY') {
	return $$self{$field};
    } elsif (ref($$self{$field})) {
	return Gff->new($$self{$field});
    } else {
	return $$self{$field};
    }
}
    
######################################################################
# $file_type = $self->file_type()
# $file_type = $self->file_type($file_type);
#
# Get or set file type

sub file_type {
    my $self = shift;
    confess "file_type can only be called on top level gff"
	if (defined($$self{''}) && $$self{''} ne '');
    return $self->get_or_set(' ____file_type', @_);
}

######################################################################
# $file_version = $self->file_version()
# $file_version = $self->file_version($file_version);
#
# Get or set file version

sub file_version {
    my $self = shift;
    confess "file_version can only be called on top level gff"
	if (defined($$self{''}) && $$self{''} ne '');
    return $self->get_or_set(' ____file_version', @_);
}

######################################################################
# $new_top_gff = $gff->copy_to_top($file_type, $file_version);
#
# Takes a copy of the gff so that new returned gff is on the top level
# i.e. suitable for GffWrite. They do share the lower level structures. 

sub copy_to_top {
    my $self = shift;
    my(%gff, $gff);
    %gff = %{$self};
    $gff{''} = '';
    $gff = Gff->new(\%gff);
    if (@_) {
	$gff->file_type(shift);
	if (@_) {
	    $gff->file_version(shift);
	}
    }
    return $gff;    
}


######################################################################
# (@keys) = $self->struct_keys();
# 
# Get list of keys

sub struct_keys {
    my $self = shift;
    my(@keys, $i);
    
    foreach $i (keys %{$self}) {
	next if ($i =~ /____((struct_|file_|)type|file_version)$/);
	next if ($i eq '');
	push(@keys, $i);
    }
    return @keys;
}

######################################################################
# $gff_or_value = $self->value($field)
# $gff_or_value = $self->value($field, $value);
# $gff_or_value = $self->value($field, $value, $type);
#
# Get or set value

sub value {
    my $self = shift;
    my $field = shift;
    if (@_) {
	my($value) = shift;
	my($type) = shift;

	if (defined($type)) {
	    $self->get_or_set($field . ". ____type", $type);
	}
	return $self->get_or_set($field, $value);
    }
    return $self->get_or_set($field);
}

######################################################################
# $type = $self->type()
# $type = $self->type($type);
#
# Get or set type

sub type {
    my $self = shift;
    my $field = shift;
    return $self->get_or_set($field . ". ____type", @_);
}

######################################################################
# Language codes

%Gff::code2language = ( 0 => 'English',
			1 => 'French',
			2 => 'German',
			3 => 'Italian',
			4 => 'Spanish',
			5 => 'Polish',
			6 => 'Russian',
			128 => 'Korean',
			129 => 'ChineseTraditional',
			130 => 'ChineseSimplified',
			131 => 'Japanise' );

map {
    $Gff::language2code{lc($Gff::code2language{$_})} = $_;
} keys(%Gff::code2language);

######################################################################
# $code = language($lang, $gender);
# $code = language($lang);
# 
# Return language code for given language
# if gender is missing Male is assumed.
# $lang can be name of the language or the number directly

sub language {
    my($lang, $gender) = @_;
    my($key, $value);

    $gender = 0 if (!defined($gender));
    $gender = 0 if ($gender =~ /^\s*male\s*$/i);
    $gender = 1 if ($gender =~ /^\s*female\s*$/i);
    if ($gender != 0 && $gender != 1) {
	carp "Invalid gender given to Gff::language: $gender";
	$gender = 0;
    }

    if ($lang =~ /^\s*\d+\s*$/) {
	return $lang * 2 + $gender;
    }
    $key = $lang;
    $key =~ s/\s+//g;
    $value = $Gff::language2code{lc($key)};
    if (defined($value)) {
	return $value * 2 + $gender;
    }
    carp "Unknown language given to Gff::language: $lang";
    return 0;
}

######################################################################
# Variables support

%Gff::type2typeID = ( '1' => '1',
		      '2' => '2',
		      '3' => '3',
		      '4' => '4',
		      '5' => '5',
		      'int' => '1',
		      'float' => '2',
		      'string' => '3',
		      'object' => '4',
		      'location' => '5');

%Gff::typeID2GffType = ( '1' => 5,
			 '2' => 8,
			 '3' => 10,
			 '4' => 4,
			 '5' => 14);		  

######################################################################
# $self->variable($name, $value, $type)
# $self->variable($name, $value)
# $gff_of_value = $self->variable($name);
# 
# If value is undef, then remove the value.
# If type is not given, then default to the int, if the the value is consist
# only integers, float if it consists of \d.\d, and string otherwise.
#
# To get the variable value use $self->variable($name)->varvalue
# To get the variable type use $self->variable($name)->vartype
# To get the variable name use $self->variable($name)->varname

sub variable {
    my($self) = shift;
    my($name) = shift;
    my($vars, $i);

    $vars = $$self{VarTable};

    if (@_) {
	my($value) = shift;
	my($type) = shift;
	my($item);

	confess "too many arguments" if (@_);
	# Remove old value
	if (defined($vars)) {
	    for($i = $#$vars; $i >= 0 ; $i--) {
		if ($$vars[$i]{Name} eq $name) {
		    splice(@{$vars}, $i, 1);
		}
	    }
	}
	if (!defined($value)) {
	    # Already removed, check if the variable table is now empty
	    if (defined($vars) && $#$vars == -1) {
		# Yes, remove it completely
		delete $$self{VarTable};
	    }
	    return undef;
	}
	if (!defined($type)) {
	    if ($value =~ /^\d+$/) {
		$type = 1;
	    } elsif ($value =~ /^(\d+\.\d*|\.\d+)$/) {
		$type = 2;
	    } else {
		$type = 3;
	    }
	} else {
	    my($vartype);

	    $vartype = $Gff::type2typeID{$type};
	    confess "Invalid type $type given to variable"
		unless defined($vartype);
	    $type = $vartype;
	}
	$item = {'' => ($$self{''} . '/VarTable[' . ($#$vars + 1) . "]"),
		 ' ____struct_type' => 0,
		 'Name' => $name,
		 'Name. ____type' => 10,
		 'Type' => $type,
		 'Type. ____type' => 4,
		 'Value' => $value,
		 'Value. ____type' => $Gff::typeID2GffType{$type}};
	$$self{'VarTable. ____type'} = 15;
	bless $item, ref($self);
	push(@{$$self{VarTable}}, $item);
	return $item;
    }

    return undef if (!defined($vars));
    for($i = 0; $i <= $#$vars; $i++) {
	if ($$vars[$i]{Name} eq $name) {
	    return Gff->new($$vars[$i]);
	}
    }
    return undef;
}


######################################################################
# Get varname

sub varname {
    my $self = shift;
    my $field = shift;
    return $self->get_or_set('Name');
}

######################################################################
# Get varvalue

sub varvalue {
    my $self = shift;
    my $field = shift;
    return $self->get_or_set('Value');
}

######################################################################
# Get vartype

sub vartype {
    my $self = shift;
    my $field = shift;
    return $self->get_or_set('Type');
}

######################################################################
# print($self, %options);
#
# Options can have:
# prefix	= prefix to be added before each line
# print_types	= whether to print types and other information too
# print_code	= print the structure out as a perl code
# no_labels	= whether to ignore the labels
# separator	= string to separating label and value. Default ":\t"
# skip_matching_label = Skip labels matching given regexp
# skip_matching_value = Skip values matching given regexp
# dialog        = Tlk structure to be used to map string_refs to text. 

sub print {
    my $self = shift;
    my(%options) = @_;

    if ($options{print_code}) {
	print("  my(\$gff) = Gff->new();\n");
    }
    $self->print_level("/", \%options);
}

######################################################################
# $self->print_level($levelstr, \%options);

sub print_level {
    my($self, $levelstr, $options) = @_;
    my($i);

    foreach $i (sort keys %{$self}) {
	if (!defined($$options{print_types}) ||
	    !$$options{print_types}) {
	    if ($i =~ /____((struct_|file_|)type|file_version)$/) {
		if ($$options{print_code}) {
		    if ($i eq ' ____file_type') {
			printf("  \$gff->file_type('%s');\n", $$self{$i});
		    } elsif ($i eq ' ____file_version') {
			printf("  \$gff->file_version('%s');\n", $$self{$i});
		    } elsif ($i eq ' ____struct_type') {
			printf("  \$gff->value('%s', '%s');\n",
			       $levelstr . $i, $$self{$i});
		    }
		}
		next;
	    }
	    next if ($i eq '');
	}
	if (UNIVERSAL::isa($$self{$i}, 'ARRAY')) {
	    my($item, $j, $array);
	    $j = 0;
	    $array = $$self{$i};
	    foreach $item (@{$array}) {
		Gff->new($item)->
		    print_level($levelstr . $i . "[" . $j . "]/", $options);
		$j++;
	    }
	    if ($$options{print_code}) {
		printf("  \$gff->value('%s. ____type', '%s');\n",
		       $levelstr . $i, $$self{$i . '. ____type'});
	    }
	} elsif (UNIVERSAL::isa($$self{$i}, 'HASH')) {
	    Gff->new($$self{$i})->
		print_level($levelstr . $i . "/", $options);
	    if ($$options{print_code}) {
		printf("  \$gff->value('%s. ____type', '%s');\n",
		       $levelstr . $i, $$self{$i . '. ____type'});
	    }
	} else {
	    my($txt);
	    if ($$options{print_code}) {
		$txt = $$self{$i};
		$txt =~ s/([\000-\037\177-\377%])/"%" . unpack("H2", $1)/ge;
		if ($i =~ /____string_ref$/ ||
		    !defined($$self{$i . '. ____type'})) {
		    printf("  \$gff->value('%s', '%s');\n",
			   $levelstr . $i, $txt);
		} else {
		    printf("  \$gff->value('%s', '%s', %d);\n",
			   $levelstr . $i, $txt, $$self{$i . '. ____type'});
		}
		next;
	    }
	    next if (defined($$options{skip_matching_label}) &&
		     $levelstr . $i =~ $$options{skip_matching_label});
	    next if (defined($$options{skip_matching_value}) &&
		     $$self{$i} =~ $$options{skip_matching_value});
	    print($$options{prefix}) if (defined($$options{prefix}));
	    print($levelstr, $i,
		  defined($$options{separator}) ? $$options{separator} : ":\t")
		if (!defined($$options{no_labels}) || !$$options{no_labels});
	    $txt = $$self{$i};
	    $txt =~ s/([\000-\037\177-\377%])/"%" . unpack("H2", $1)/ge;
	    print($txt, "\n");
	    if ($i =~ /____string_ref$/ && defined($$options{dialog})) {
		my($str) = $$options{dialog}->string($$self{$i});
		next if (!defined($str));
		print($$options{prefix}) if (defined($$options{prefix}));
		print($levelstr, $i . ".text",
		      defined($$options{separator}) ?
		      $$options{separator} : ":\t")
		    if (!defined($$options{no_labels}) ||
			!$$options{no_labels});
		print($str, "\n");
	    }
	}
    }
}

######################################################################
# @@result = encode($self, %options);
#
# Result is array of arrays each having 2 items, first is the key,
# second is the value
#
# Options can have:
# types		= whether to include type and other information too
# skip_matching_label = Skip labels matching given regexp
# skip_matching_value = Skip values matching given regexp

sub encode {
    my $self = shift;
    my(%options) = @_;
    
    return $self->encode_level("/", \%options);
}

######################################################################
# $self->encode_level($levelstr, \%options);

sub encode_level {
    my($self, $levelstr, $options) = @_;
    my($i, @ret);

    foreach $i (sort keys %{$self}) {
	if (!defined($$options{types}) || !$$options{types}) {
	    next if ($i =~ /____((struct_|file_|)type|file_version)$/);
	    next if ($i eq '');
	}
	if (UNIVERSAL::isa($$self{$i}, 'ARRAY')) {
	    my($item, $j, $array);
	    $j = 0;
	    $array = $$self{$i};
	    foreach $item (@{$array}) {
		push(@ret, Gff->new($item)->
		     encode_level($levelstr . $i . "[" . $j . "]/", $options));
		$j++;
	    }
	} elsif (UNIVERSAL::isa($$self{$i}, 'HASH')) {
	    push(@ret, Gff->new($$self{$i})->
		 encode_level($levelstr . $i . "/", $options));
	} else {
	    my(@pair);
	    next if (defined($$options{skip_matching_label}) &&
		     $levelstr . $i =~ $$options{skip_matching_label});
	    next if (defined($$options{skip_matching_value}) &&
		     $$self{$i} =~ $$options{skip_matching_value});
	    $pair[0] = $levelstr . $i;
	    $pair[1] = $$self{$i};
	    push(@ret, \@pair);
	}
    }
    return @ret;
}

######################################################################
# $self->find(%options);
#
# find_label	=> regexp
#		Find lables having value matching regexp, if not set
#		then do not check labels. This is matched against
#		the full label name.
# find_field	=> regexp
#		Find fields having value matching regexp, if not set
#		then do not check fields. This is only checked
#		against scalar values.
#
#		If both find_label and find_field is set, then both
#		are checked, and proc is only called if both match.
#
# find_type	=> hash table of values
#		Find fields having type defined in the hash table. 
#
# proc => 	proc($gff, $full_label, $label, $value, \@parent_gffs);
#		Perl procedure to call if field is found. The $gff is parent
#		node of the field. 

sub find {
    my($self, %options) = @_;
    $self->find_level("/", \%options, $self);
}

######################################################################
# $self->find_level($levelstr, \%options, @parents);

sub find_level {
    my($self, $levelstr, $options, @parents) = @_;
    my($i, $label, $value, $type);

    if (defined($$options{'find_label'})) {
	if ($levelstr =~ /$$options{'find_label'}/) {
	    &{$$options{'proc'}}($self, $levelstr, $label,
				 $self, \@parents);
	}
    }
    
    foreach $i (keys %{$self}) {
	next if ($i =~ /____((struct_|file_|)type|file_version)$/);
	next if ($i eq '');
	$label = 1;
	$value = 1;
	$type = 1;
	if (defined($$options{'find_label'})) {
	    if (($levelstr . $i) !~ /$$options{'find_label'}/) {
		$label = 0;
	    }
	}
	if (defined($$options{'find_value'})) {
	    if (ref($$self{$i}) ||
		$$self{$i} !~ /$$options{'find_value'}/) {
		$value = 0;
	    }
	}
	if (defined($$options{'find_type'})) {
	    if (!defined($$self{$i . ". ____type"}) ||
		!defined($$options{'find_type'}{$$self{$i . ". ____type"}})) {
		$type = 0;
	    }
	}

	if ($label && $value && $type) {
	    &{$$options{'proc'}}($self, $levelstr . $i, $i,
				 ref($$self{$i}) ? Gff->new($$self{$i}) :
				 $$self{$i}, \@parents);
	}

	if (UNIVERSAL::isa($$self{$i}, 'ARRAY')) {
	    my($item, $j, $array);
	    $j = 0;
	    $array = $$self{$i};
	    for($j = 0; $j <= $#{$array}; $j++) {
		$item = $$array[$j];
		Gff->new($item)->
		    find_level($levelstr . $i . "[" . $j . "]/", $options,
			       @parents, Gff->new($item));
	    }
	} elsif (UNIVERSAL::isa($$self{$i}, 'HASH')) {
	    Gff->new($$self{$i})->
		find_level($levelstr . $i . "/", $options,
			   @parents, Gff->new($$self{$i}));
	}
    }
}

######################################################################
# $difference = match($gff1, $gff2, ...);
# $difference = $gff1->match($gff2, ...);
#
# Return string telling where the gff differ, or undef if they match
# Only return first difference

sub match {
    my($self) = shift;
    my($i, @ret);

    foreach $i (@_) {
	@ret = match_gff($self, $i, 1);
	return $ret[0] if ($#ret != -1);
    }
    return undef;
}

######################################################################
# $difference = diff($gff1, $gff2, ...);
# $difference = $gff1->diff($gff2, ...);
#
# Return string telling where the gff differ, or undef if they match

sub diff {
    my($self) = shift;
    my($i, @ret);

    foreach $i (@_) {
	push(@ret, match_gff($self, $i, 0));
    }
    return @ret;
}

######################################################################
# $difference = match_gff($gff1, $gff2, $onlyfirst);

sub match_gff {
    my($gff1, $gff2, $onlyfirst) = @_;
    my(@keys1, @keys2, $i, $j, %keys);
    my($value1, $value2, @ret);

    @keys1 = $gff1->struct_keys();
    @keys2 = $gff2->struct_keys();

    @ret = ();
    if ($#keys1 != $#keys2) {
	push(@ret,
	     "Number of keys at level $$gff1{''} differ, $#keys1 vs $#keys2");
	return @ret if ($onlyfirst);
    }
    @keys1 = sort(@keys1);
    @keys2 = sort(@keys2);

    foreach $i (@keys2) {
	$keys{$i} = 1;
    }
    
    for($i = 0; $i <= $#keys1; $i++) {
	if (!defined($keys{$keys1[$i]})) {
	    push(@ret, "Key $keys1[$i] missing from second gff at level $$gff1{''}");
	    return @ret if ($onlyfirst);
	}
	delete $keys{$keys1[$i]}; 
   }
    foreach $i (keys %keys) {
	push(@ret, "First gff has extra key $i at level $$gff1{''}");
	delete $keys{$i};
    }

#    foreach $i (@keys1) {
#	$keys{$i} = 1;
#    }
#    
#    for($i = 0; $i <= $#keys2; $i++) {
#	if (!defined($keys{$keys2[$i]})) {
#	    push(@ret, "Key $keys2[$i] missing from second gff at level $$gff1{''}");
#	    return @ret if ($onlyfirst);
#	}
#	delete $keys{$keys2[$i]};
#    }
#
#    foreach $i (keys %keys) {
#	push(@ret, "Second gff has extra key $i at level $$gff1{''}");
#	delete $keys{$i};
#    }

    foreach $i (@keys2) {
	$keys{$i} = 1;
    }
    
    foreach $i (@keys1) {
	next if (!defined($keys{$i}));
	if (defined($gff1->type($i)) && defined($gff2->type($i)) &&
	    $gff1->type($i) != $gff2->type($i)) {
	    push(@ret, "Type of the $$gff1{''}/$i differ, " .
		 "$gff1->type($i) vs $gff2->type($i)");
	    return @ret if ($onlyfirst);
	}
	$value1 = $gff1->value($i);
	$value2 = $gff2->value($i);
	if (UNIVERSAL::isa($value1, 'ARRAY') &&
	    UNIVERSAL::isa($value2, 'ARRAY')) {
	    if ($#$value1 != $#$value2) {
		push(@ret, "Number of items in array $$gff1{''}/$i differ, " .
		     "$#$value1 vs $#$value2");
		return @ret if ($onlyfirst);
	    }
	    for($j = 0; $j <= $#$value1; $j++) {
		push(@ret, match_gff(Gff->new($$value1[$j]),
				     Gff->new($$value2[$j]), $onlyfirst));
		return @ret if ($onlyfirst && $#ret != -1);
	    }
	} elsif (UNIVERSAL::isa($value1, 'ARRAY') ||
		 UNIVERSAL::isa($value2, 'ARRAY')) {
	    push(@ret,
		 "One of the types $$gff1{''}/$i is ARRAY, but other is not");
	    return @ret if ($onlyfirst);
	} elsif (ref($value1)) {
	    if ($gff1->type($i) == 12) {
		my(@hash1keys, @hash2keys);

		@hash1keys = keys %{$value1};
		@hash2keys = keys %{$value2};

		if ($#hash1keys != $#hash2keys) {
		    push(@ret, "Number of items in localized string array " .
			 "$$gff1{''}/$i differ, $#hash1keys vs $#hash2keys");
		    return @ret if ($onlyfirst);
		}
		foreach $j (@hash1keys) {
		    if (!defined($$value2{$j})) {
			push(@ret,
			     "Localized string array $$gff1{''}/$i differ, " .
			     "key $j missing");
			return @ret if ($onlyfirst);
		    } else {
			if ($$value1{$j} ne $$value2{$j}) {
			    push(@ret,
				 "Localized string array $$gff1{''}/$i/$j " .
				 "differ, $$value1{$j} vs $$value2{$j}");
			    return @ret if ($onlyfirst);
			}
		    }
		}
	    } else {
		push(@ret, match_gff(Gff->new($value1), Gff->new($value2),
				     $onlyfirst));
		return @ret if ($onlyfirst && $#ret != -1);
	    }
	} else {
	    if ($value1 ne $value2) {
		push(@ret,
		     "Values of $$gff1{''}/$i differ, $value1 vs $value2");
		return @ret if ($onlyfirst);
	    }
	}
    }
    return @ret;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

Gff - Perl Module to modify Gff datastructures in memory

=head1 ABSTRACT

This module includes functions to read, and modify gff objects. The
objects are represented as hash table having other hash tables, arrays
or values inside of it. The basic use is like multilevel hash tables:
$$gff{'key'}[0]{'Text'}{0}.

=head1 DESCRIPTION

You first need either to greate new B<Gff> with B<Gff::new> or read
gff structure from disk using B<GffRead::read>. Then you can modify
the gff structure in memory with functions defined here (or simply
reading values from hash table or assigning new values to them). When
you are done you can write gff back to disk using B<GffWrite::write>.

=head1 B<Gff::new>

B<Gff::new> is used to bless any other hash to be B<Gff> hash or just
to return new empty B<Gff> hash.

=over 4

=head2 USAGE

\%gff = Gff->new();

\%gff = Gff->new(\%hash);

=back

=head1 B<Gff::get_or_set>

B<Gff::get_or_set> is used either get old value of the field, or to
set new value for the field. The field can be given as a path through
the gff structure.

=over 4

=head2 USAGE

$value = $gff->get_or_set($field);

$value = $gff->get_or_set($field, $value);

The $field can be in the path format, meaning it can have structure
names separated by slashes, and array names followed by index of the
item in brackets. I.e. format like "/Creature
List[0]/ClassList[0]/MemorizedList8[1]/SpellMetaMagic" or
"/AreaProperties/MusicDelay". The returned value will be blessed as
B<Gff> structure if it is structure or array. Normally you do not use
this low level function, but those upper level functions like
B<Gff::value>.

=back

=head1 B<Gff::file_type>

B<Gff::file_type> is used either to set or get file type. This
function can only be called on the top level gff structure.

=over 4

=head2 USAGE

$file_type = $gff->file_type();

$file_type = $gff->file_type($file_type);

=back

=head1 B<Gff::file_version>

B<Gff::file_version> is used either to set or get file version number.
This function can only be called on the top level gff structure.

=over 4

=head2 USAGE

$file_version = $gff->file_version();

$file_version = $gff->file_version($file_version);

=back

=head1 B<Gff::copy_to_top>

B<Gff::copy_to_top> can be used to take a copy of the gff so that the
new returned B<Gff> structure is on the top level, i.e. suitable for
B<GffWrite::write>. The returned B<Gff> and the old B<Gff> do share
the lower level data structures, so modifying them will modify both of
them.

=over 4

=head2 USAGE

$new_top_gff = $gff->copy_to_top($file_type, $file_version);

=back

=head1 B<Gff::struct_keys>

B<Gff::struct_keys> returns a list of keys on the given structure level. 

=over 4

=head2 USAGE

@keys = $gff->struct_keys();

=back

=head1 B<Gff::value>

B<Gff::value> is used either get old value of the field, or to set new
value for the field. The field can be given as a path through the gff
structure. This can also be used to set the type of the field. 

=over 4

=head2 USAGE

$gff_or_value = $gff->value($field);

$gff_or_value = $gff->value($field, $value);

$gff_or_value = $gff->value($field, $value, $type);

The $field can be in the path format, meaning it can have structure
names separated by slashes, and array names followed by index of the
item in brackets. I.e. format like "/Creature
List[0]/ClassList[0]/MemorizedList8[1]/SpellMetaMagic" or
"/AreaProperties/MusicDelay". The returned value will be blessed as
B<Gff> structure if it is structure or array. Normally you do not use
this low level function, but those upper level functions like
B<Gff::value>. If $type is given then it must be a number matching the
nwn type numbers.

=back

=head1 B<Gff::type>

B<Gff::type> returns or sets the type of the field. 

=over 4

=head2 USAGE

$type = $gff->type();

$type = $gff->type($type);

The $type is nwn internal type number.

=back

=head1 B<Gff::language>

B<Gff::language> converts language id or name and optional gender to
language code to be used as index in the localized strings.

=over 4

=head2 USAGE

$code = $Gff::language($lang, $gender);

$code = $Gff::language($lang);

The $code is number, and $lang is either language number or name
('English', 'French' etc). $gender is either number 0 (= male), or 1
(= female) or string 'Male', or 'Female'. All strings are case
insensetive.

=back

=head1 B<Gff::variable>

B<Gff::variable> is used mostly to set local variables on the
structures. It can also be used to fetch the internal gff structure of
the variable so the name, value and type can be fetched from there.
Those values match the GetLocalString/GetLocalInt etc and
SetLocalString/SetLocalInt functions of the nwn-script.

=over 4

=head2 USAGE

$gff = $gff->variable($name);

$gff = $gff->variable($name, $value);

$gff = $gff->variable($name, $value, $type);

If value is given but undef, then variable is removed. If no type is
given then the type is guessed based by the value. If value consists
only numbers, then it is assumed to be integers, if value matches
\d.\d regexp then it is assumed to be float, and string otherwise. If
the type is given it can either be numeric variable type code
(different than gff type codes), or 'int', 'float', 'string',
'object', or 'location'. In case 'object' and 'location' then the
internal format of the value must be properly formatted for that type.
This always return the internal gff structure of the variable.

To get the variable value, type or name use
$gff->variable($name)->varvalue, $gff->variable($name)->vartype, and
$gff->variable($name)->varname.

=back

=head1 B<Gff::varname>

B<Gff::varname> is used to get the name of the variable.

=over 4

=head2 USAGE

$name = $gff->varname();

=back

=head1 B<Gff::varvalue>

B<Gff::varvalue> is used to get the value of the variable.

=over 4

=head2 USAGE

$value = $gff->varvalue();

=back

=head1 B<Gff::vartype>

B<Gff::vartype> is used to get the type of the variable.

=over 4

=head2 USAGE

$name = $gff->vartype();

=back

=head1 B<Gff::print>

B<Gff::print> is used to print the B<Gff> structure to the stdout. 

=over 4

=head2 USAGE

$gff->print(%options);

=head2 OPTIONS

Following options can be given to the B<Gff::print>.

=over 4

=item B<prefix> => I<prefix>

Prefix to be added before each line.

=item B<print_types> => I<boolean>

Whether to print types and other information too.

=item B<print_code> => I<boolean>

Whether to print structure as perl code.

=item B<no_labels> => I<boolean>

Whether to print labels.

=item B<separator> => I<string>

String to separating label and value. Default value is ":\t".

=item B<skip_matching_label> => I<regexp>

Skip labels matching given regexp.

=item B<skip_matching_value> => I<regexp>

Skip values matching given regexp.

=item B<dialog> => I<Tlk::dialog>

Tlk object returned by TlkRead::read. If this is given then
string_refs are also converted to strings.

=back

=back

=head1 B<Gff::encode>

B<Gff::encode> is used to encode the B<Gff> structure as array of
arrays, i.e it is array of all entries in the gff (as flat array), and
each array entry has two items, first is the key and second is the
value.

=over 4

=head2 USAGE

@@result = $gff->encode(%options);

=head2 OPTIONS

Following options can be given to the B<Gff::encode>.

=over 4

=item B<types> => I<boolean>

Whether to include type and other information too.

=item B<skip_matching_label> => I<regexp>

Skip labels matching given regexp.

=item B<skip_matching_value> => I<regexp>

Skip values matching given regexp.

=back

=back

=head1 B<Gff::find>

B<Gff::find> is used to find parts of the B<Gff> structure and call
given function for each instance of those structures matching.

=over 4

=head2 USAGE

$gff->find(%options);

=head2 OPTIONS

Following options can be given to the B<Gff::find>.

=over 4

=item B<find_label> => I<regexp>

Find lables having value matching regexp, if not set then do not check
labels. This is matched against the full label name, i.e. full path
included, including array indexes.

If multiple of find_label, find_field and find_type are set, then all
of them are checked, and proc is only called if all match.

=item B<find_field> => I<regexp>

Find fields having value matching regexp, if not set then do not check
fields. This is only checked against scalar values.

If multiple of find_label, find_field and find_type are set, then all
of them are checked, and proc is only called if all match.

=item B<find_type> => I<hash>

Find fields having type defined in the hash table, if not set then do
not check types. This is only checked against scalar values.

If multiple of find_label, find_field and find_type are set, then all
of them are checked, and proc is only called if all match.

=item B<proc> => I<proc($gff, $full_label, $label, $value, \@parent_gffs);>

Perl procedure to call if field is found. The $gff is parent node of
the field. $full_label is the full label including all array indexes
and so on, the $label is the field label, and $value is the value. The
\@parent_gffs is a list of parent gffs, starting from the top and
going towards the structure found.

=back

=back

=head1 B<Gff::match>

B<Gff::match> is used to match two or more B<Gff> structures, and
return first difference between them. In case structures match undef
is returned. If more than two structures are given, then all other
structures are matched against the first one.

=over 4

=head2 USAGE

$difference = match($gff1, $gff2, ...);

$difference = $gff1->match($gff2, ...);

=back

=head1 B<Gff::diff>

B<Gff::diff> is used to get difference two or more B<Gff> structures,
and return all differences between them. In case structures match
undef is returned. If more than two structures are given, then all
other structures are matched against the first one, and an array of
strings is returned, one for each structure after first one.

=over 4

=head2 USAGE

$difference = diff($gff1, $gff2, ...);

$difference = $gff1->diff($gff2, ...);

=back

=head1 SEE ALSO

gffprint(1), gffmodify(1), GffRead(3), and GffWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do automated things for the cerea persistent world. 

=cut
