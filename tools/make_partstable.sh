#!/bin/bash

tmp=/tmp/table$$

sort -g -k3  |egrep " .\..." >/tmp/table$$

currentac=-1
startindex=-1

exec 3<$tmp

while true
do
  lastindex=$index
  read <&3 index cost ac
  if [ "x$index" == "x" ]; then break; fi

  if [ "$1" != "" ]; then
    ac=$1
  fi

  if [ $currentac != $ac ]; then
    if [ $startindex -gt -1 ]; then
      prev[$startindex]=$lastindex
      next[$lastindex]=$startindex
    fi
    startindex=$index
    lastindex=-1
    currentac=$ac
  fi
  if [ $lastindex -gt -1 ]; then
    next[$lastindex]=$index
    prev[$index]=$lastindex
  fi
  ac[$index]=$ac
done

prev[$startindex]=$lastindex
next[$lastindex]=$startindex

n=0

echo "2DA V2.0"
echo
echo
echo "      Next   Prev"
while [ $n -lt 256 ]
do
  if [ "x"${prev[$n]} != "x" ]; then
    printf "%-3d   %-4d   %-4d\n" $n ${prev[$n]} ${next[$n]}
   else
    printf "%-3d   ****   ****\n" $n
  fi
  let n=$n+1
done
rm $tmp
