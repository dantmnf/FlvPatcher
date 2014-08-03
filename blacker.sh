#!/bin/bash

# Blacker v0.02 by Beining(cnbeining[at]gmail.com), original author: dant(dantmnf2 at gmail.com)

WORKDIR="/tmp/Blacker-$(uuidgen)"

usage() {
	echo "usage: $(basename $0) [-b target_bitrate] inputfile [outputfile]"
}

set_bitrate() { # $1: bitrate
	target_bitrate=${1:-1990000}
	target_bitrate=${target_bitrate/[kK]/000}
	echo "INFO:    target bitrate is ${target_bitrate}bps"
}

parse_commandline() {
	while getopts 'b:' arg
	do
		echo $arg
		case $arg in
			'b')
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
	set_bitrate $br
	outputfile=${2:-${inputfile}.upload.mp4}
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
			echo "ERROR:   not overriding"
			exit 1
		fi
	fi

	# check ffmpeg/avconv
	which ffmpeg &>/dev/null && ffmpeg=ffmpeg
	which avconv &>/dev/null && ffmpeg=avconv
	if [ -z "$ffmpeg" ];then
		echo "ERROR:   no ffmpeg or avconv found"
		exit 1
	fi

}

execute() {
	mkdir -p "$WORKDIR"
	# remux the input file to flv and measure the size
	flvsize=$($ffmpeg -v 0 -i "$inputfile" -c copy -f flv - | wc -c)
	if (( $flvsize == 0 ));then
		echo "ERROR:   cannot analyze the input file."
		echo "INFO:    please check whether ffmpeg is a recent version which can also remux"
		echo "         media files, and make sure your input file can be remuxed to FLV."
		exit 1
	fi

	# index the input file
	# according to issue#2, use ffmpeg/avconv instead of ffms2
	tcfile="$WORKDIR/tc.txt"
	$ffmpeg -v 0 -i "$inputfile" -c:v copy -an -f mkvtimestamp_v2 -- "$tcfile"
	if [ ! -e $tcfile ];then
		echo "ERROR:   cannot analyze the input file."
		echo "INFO:    please check whether your ffmpeg supports 'mkvtimestamp_v2' format"
		exit 1
	fi

	# create a black patch
	$ffmpeg -v 0 -i "$inputfile" -c copy -frames:v 3 -- "$WORKDIR/patch.mkv"
	patchsize=$($ffmpeg -v 0 -i "$WORKDIR/patch.mkv" -c copy -f flv - | wc -c)

	# modify the timecode
	blacktime1=$(echo "scale=8;((${flvsize}+${patchsize})/${target_bitrate})*8000" | bc)
	blacktime2=$(echo "$blacktime1 + 60" | bc)
	blacktime3=$(echo "$blacktime2 + 60" | bc)

	echo $blacktime1 >> $tcfile
	echo $blacktime2 >> $tcfile
	echo $blacktime3 >> $tcfile

	mkvmerge -o "$WORKDIR/upload.mkv" --timecodes "0:$tcfile" \
	'(' "$inputfile" ')' '+' '(' "$WORKDIR/patch.mkv" ')'        \
	--track-order "0:0,0:1" >/dev/null #--append-to "1:0:0:0" & >/dev/null

	$ffmpeg -v 0 -f matroska -i "$WORKDIR/upload.mkv" -c copy -f mp4 -y -- "$outputfile" 

	# clean up
	rm -rf -- $WORKDIR
}

parse_commandline $@
check
execute
