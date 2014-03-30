#!/bin/bash

# 3xSpeed v0.01 by dant(dantmnf2 at gmail.com)





# !!!!!!! UNUSABLE !!!!!!!





WORKDIR="/tmp/3xSpeed-$(uuidgen)"

usage() {
	echo "usage: $(basename $0) [-x multiplier] inputfile [outputfile]"
}

set_multiplier() { # $1: multiplier
	multiplier=${1:-3}
	echo "INFO:    multiplier is ${multiplier}"
}

parse_commandline() {
	while getopts 'x:' arg
	do
		echo $arg
		case $arg in
			'x')
				br=$OPTARG
				shift 2
				;;
			'?')
				echo "WARNING: unknown argument: $arg" > 1
				shift
				;;
		esac
	done

	inputfile=$1
	if [ ! -e "$inputfile" ];then
		usage
		exit 1
	fi
	set_multiplier $br
	outputfile=${2:-${inputfile}.upload.flv}
}

check() {
	if [ ! -e $inputfile ];then
		echo "ERROR:   input file '${inputfile}' does not exist!!"
		exit 1
	fi
	if [ -e $outputfile ];then
		echo -n "WARNING: output file '${outputfile}' exists, override? (y/N):"
		read answer
		if (( $answer != y && $answer != Y ));then
			echo "INFO:    exiting..."
			exit 1
		fi
		if rm -d -- $outputfile;then
			echo "INFO:    overriding ${outputfile}"
		else
			echo "ERROR:   failed to override ${outputfile}"
			exit 1
		fi
	fi


}

execute() {
	mkdir -p "$WORKDIR"
	# remux the input file to flv and measure the size
	#flvsize=$(ffmpeg -v 0 -i "$inputfile" -c copy -f flv - | wc -c)
	#if (( $flvsize == 0 ));then
	#	echo "ERROR:   cannot analyze the input file."
	#	echo "INFO:    please check whether ffmpeg is a recent version which can also remux"
	#	echo "         media files, and make sure your input file can be remuxed to FLV."
	#	exit 1
	#fi

	# index the input file
	ffmsindex -c "$inputfile" "$WORKDIR/tc" >/dev/null
	tcfile="$WORKDIR/tc_track00.tc.txt"
	if [ ! -e $tcfile ];then
		echo "ERROR:   cannot analyze the input file."
		echo "INFO:    please check whether a working ffmsindex is installed on your system"
		exit 1
	fi


	# modify the timecode
	head -n 1  $tcfile > "$WORKDIR/tc.txt"
	tail -n +1 $tcfile | awk '{ print $1 * '"$multiplier"' }' >> "$WORKDIR/tc.txt"


	mkvmerge -o "$WORKDIR/upload.mkv" --timecodes "0:${WORKDIR}/tc.txt" "$inputfile" #>/dev/null 

	ffmpeg -v 0 -f matroska -i "$WORKDIR/upload.mkv" -c copy -f flv -y -- "$outputfile" 

	# clean up
	rm -rf -- $WORKDIR
}

parse_commandline $@
check
execute
