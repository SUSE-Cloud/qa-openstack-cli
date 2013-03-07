#!/bin/bash

source config

function printlog() {
	echo "$1" | while read line ; do
		echo "$line" | grep -q "^++" && continue
		echo "  $line"
	done
	echo
}

function runtest() {
	dotcount=`echo "45 - ${#1}" | bc`
	dots=`seq -s "." $dotcount | sed 's/[0-9]//g'`
	echo -ne "\e[1mRunning\e[00m $1 $dots "
	testlog="`./tests/$1 2>&1`"
	res=$?

	if [ "$res" == "0" ] ; then
		echo -e "\e[1;32mOK\e[00m"
		if [ "$DEBUG" == "1" ] ; then
			printlog "$testlog"
		fi
	elif [ "$res" == "1" ] ; then
		echo -e "\e[1;31mFAIL\e[00m"
		printlog "$testlog"
		return 1
	elif [ "$res" == "2" ] ; then
		echo -e "\e[1;35mERROR\e[00m"
		printlog "$testlog"
		return 1
	elif [ "$res" == "3" ] ; then
		echo -e "\e[1;33mSKIPPED\e[00m"
		if [ "$DEBUG" == "1" ] ; then
			printlog "$testlog"
		fi
	else
		echo -e "\e[1;34mWTF?\e[00m"
		printlog "$testlog"
		return 1
	fi
	return 0
}


ls ./tests | while read testname ; do
	if [ "$1" == "cleanup" ] ; then
		echo "$testname" | grep -v "nocleanup" | grep -q "cleanup" || continue
	elif [ "$1" == "nocleanup" ] ; then
		echo "$testname" | grep -q "cleanup" && continue
	fi
	runtest "$testname"
done
