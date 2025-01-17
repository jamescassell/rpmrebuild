#!/usr/bin/env sh
# this script test rpmrebuild on all installed packages
# it must be started as root
# internal use for developpers
# $Id$

function bench {
	# rpm -qa can return packages as gpg-pubkey-4ebfc273-48b5dbf3.src
	list=$( rpm -qa | sed 's/\.src$//' | sort )
	max=$( echo "$list" | wc -l )

	seen=0
	notok=0
	bad=0
	pbmagic=0
	pbdep=0
	pbarch=0
	pbnotdir=0
	list_bad=''

	for pac in $list
	do
		let seen="$seen + 1"
		echo -n "$seen/$max $pac "
		output=$( nice rpmrebuild -b -k  -y no -c yes -d $tmpdir $pac  2>&1 )
		irep=$?
		if [ $irep -eq 0 ]
		then
			echo "ok"
		else

			# parse output to remove false problems
			# dependencies problem ...
			# and only keep real rpmrebuild errors
			# todo : pubkey ?
			let notok="$notok + 1"

			depend=$( echo "$output" | grep "Failed dependencies" )
			changelog=$( echo "$output" | grep "changelog not in descending chronological order" )
			cpio=$( echo "$output" | grep "cpio: Bad magic" )
			arch=$( echo "$output" | grep "Arch dependent binaries" )
			notdir=$( echo "$output" | grep "Not a directory" )
			if [ -n "$depend" ]
			then
				echo "NOTOK (Failed dependencies)"
				echo "  $output"
				let pbdep="$pbdep + 1"
			elif [ -n "$changelog" ]
			then
				echo "NOTOK (changelog not in descending chronological order)"
				echo "  $output"
			elif [ -n "$cpio" ]
			then
				echo "NOTOK (cpio: Bad magic)"
				echo "  $output"
				let pbmagic="$pbmagic + 1"
			elif [ -n "$arch" ]
			then
				echo "NOTOK (Arch dependent binaries)"
				echo "  $output"
				let pbarch="$pbarch + 1"
			elif [ -n "$notdir" ]
			then
				echo "NOTOK (Not a directory)"
				echo "  $output"
				let pbnotdir="$pbnotdir + 1"
			else
				echo "KO"
				echo "  $output"
				let bad="$bad + 1"
				list_bad="$list_bad $pac"
			fi
		fi
		#rm -f ${pac}.spec
		# remove new rpm files to avoid file system full
		rm -f $tmpdir/i386/* $tmpdir/i586/* $tmpdir/i686/* $tmpdir/noarch/* $tmpdir/x86_64/* 2> /dev/null
	done

	# clean temporary directories
	rm -rf $tmpdir 2> /dev/null

	echo "-------------------------------------------------------"
	echo "$notok failed build on $seen packages"
	echo "$bad bad build : $list_bad"
	echo "  pb cpio : $pbmagic"
	echo "  pb dep  : $pbdep"
	echo "  pb arch : $pbarch"
	echo "  pb dir  : $pnotdir"
	echo "full log on $LOG"
	echo "-------------------------------------------------------"
}

############################################################
# main
############################################################

tmpdir=/tmp/rpmrebuild

if [ -d $tmpdir ]
then
	echo "remove old repository $tmpdir"
	mkdir -p $tmpdir
fi

LOG=rpmrebuild_bench.log
if [ -f $LOG ]
then
	mv $LOG $LOG.old
fi

# to have standardize error messages
export LC_ALL=POSIX

bench 2>&1 | tee $LOG
