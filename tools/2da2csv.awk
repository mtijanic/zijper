#!/usr/bin/gawk -f

{
  line = gensub("\\x0d","","g",$0);
  line = gensub("(\"[[:alnum:][:blank:][:punct:]_]+\"|[[:alnum:]_[:punct:]]+)","\"&\"","g",line);
  line = gensub("\"[[:blank:]]+\"",":","g",line);
  line = gensub("(^[[:blank:]]*\"|\"[[:blank:]]*$)","","g",line);
  print line;
}
