#!/bin/bash
###############################################################################
#   rpmrebuild.sh 
#
#    Copyright (C) 2002 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id$
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
###############################################################################
VERSION="$Id$"
###############################################################################
function Echo
{
	echo -e "$@" 1>&2
}
###############################################################################
function Error
{
	Echo "$0: ERROR: $@"
}
###############################################################################

function Warning
{
	Echo "$0: WARNING: $@"
}
###############################################################################

function AskYesNo
{
	local Ans
	echo -en "$@ ? (y/N) " 1>&2
	read Ans
	case "x$Ans" in
		x[yY]*) return 0;;
		*)      return 1;;
	esac || return 1 # should not happened
	return 1 # should not happend
}

###############################################################################
function Interrog
{
	local QF=$1
	rpm --query --i18ndomains /dev/null $package_flag --queryformat "${QF}" ${PAQUET}
}
###############################################################################
function SpecChange
{
	# rpmlib dependencies are insert during rpm building
	# gpg key can not be provided
	# let us remove it.
	sed                                                     \
		-e 's/\(^Requires:[[:space:]]*rpmlib(.*\)/#\1/' \
	    	-e 's/\(^Provides:[[:space:]]*gpg(.*\)/#\1/'    \
	|| return
	return 0
}
###############################################################################
# build general tags
function SpecFile
{
	(
		set -e
		echo '# rpmrebuild autogenerated specfile'
		if [ "X$autorequire" = "Xno" ]; then
			echo 'AutoReq: no'
			echo '%undefine __find_requires'
			echo '%define rpmrebuild_use_requires 1'
		else
			echo 'AutoReq: yes'
			echo '#undefine __find_requires'
			echo '%define rpmrebuild_use_requires 0'
		fi
		if [ "X$autoprovide" = "Xno" ]; then
			echo 'AutoProv: no'
			echo '%undefine __find_provides'
			echo '%define rpmrebuild_use_provides 1'
		else
			echo 'AutoProv: yes'
			echo '#undefine __find_provides'
			echo '%define rpmrebuild_use_provides 0'
		fi
		HOME=$MY_LIB_DIR rpm --query --i18ndomains /dev/null $package_flag --spec_spec ${PAQUET}
	) | SpecChange || return
	return 0
}
###############################################################################
function ChangeSpecFile
{
	# first sed is to pervent all macros from expanding (by doubling each %)
	# then rollback on tag line
	HOME=$MY_LIB_DIR rpm --query $package_flag --spec_change ${PAQUET} | \
	sed                                           \
		-e 's/%/%%/g'                         \
		-e 's/^%%description/%description/'   \
		-e 's/^%%pre/%pre/'                   \
		-e 's/^%%post/%post/'                 \
		-e 's/^%%preun/%preun/'               \
		-e 's/^%%postun/%postun/'             \
		-e 's/^%%trigger/%trigger/'           \
		-e 's/^%%files/%files/'               \
		-e 's/^%%changelog/%changelog/'       \
		-e 's/^%%verifyscript/%verifyscript/' \
	|| return
	return 0
}
###############################################################################
# build the list of files in package
function FilesSpecFile
{
	rm -f $FILES_IN || return
	HOME=$MY_LIB_DIR rpm --query $package_flag --spec_files ${PAQUET} > $FILES_IN || return
	echo "%files" || return
	/bin/bash $MY_LIB_DIR/rpmrebuild_files.sh < $FILES_IN || return
	return 0
}


###############################################################################
function SpecGen
{
	if [ -n "$new_release" ]; then
		echo "%define new_release $new_release";
	else
		:
	fi       &&
	if [ "x$BUILDROOT" = "x/" ]; then
		:
	else
		echo "BuildRoot: $BUILDROOT"
	fi       &&
	SpecFile &&
	FilesSpecFile &&
	ChangeSpecFile || return
	return 0
}
###############################################################################
function SpecGeneration
{
	# fabrication fichier spec
	# build spec file

	if [ "X$need_change_spec" = "Xyes" ]; then
		SpecGen > ${FIC_SPEC}.1       || return
	else
		case "x$specfile" in
			x-)
				SpecGen || return	
			;;

			x)
				SpecGen > ${FIC_SPEC} || return
			;;

			*)
				rm -f     $specfile || return
				SpecGen > $specfile || return
			;;
		esac
	fi
	return 0
}

###############################################################################
function SpecEdit
{
	[ $# -ne 1 -o "x$1" = "x" ] && {
		Echo "Usage: $0 SpecEdit <file>"
		return 1
	}
	# -e option : edit the spec file
	local File=$1
	${VISUAL:-${EDITOR:-vi}} $File
	AskYesNo "$WantContinue" || {
		Aborted="yes"
		Echo "Aborted."
	        return 1
	}
	return 0
}
###############################################################################

function VerifyPackage
{
	# verification des changements
	# check for package change
	rpm --verify --nodeps ${PAQUET} # Don't return here, st=1 - verify fail 
	return 0
}

function QuestionsToUser
{
	[ "X$batch"     = "Xyes" ] && return 0 ## batch mode, continue
	[ "X$spec_only" = "Xyes" ] && return 0 ## spec only mode, no questions

	AskYesNo "$WantContinue" || return
	AskYesNo "Do you want to change release number" && {
		old_release=$(Interrog '%{RELEASE}')
		echo -n "Enter the new release (old: $old_release): "
		read new_release
	}
	return 0
}

function IsPackageInstalled
{
	# test if package exists
	local output
	output="$(rpm --query ${PAQUET} 2>&1 | grep -v 'is not installed')" # Don't return here - use output
	set -- $output
	case $# in
		0)
			# No package found
			Error "no package '${PAQUET}' in rpm database"
			return 1
		;;

		1)
			: # Ok, do nothing
		;;

		*)
			Error "too much packages match '${PAQUET}':\n$output"
			return 1
		;;
	esac || return
	return 0
}

function CreateProcessing
{
	[ $# -ne 1 -o "x$1" = "x" ] && {
		Echo "$0: CreateProcessing <operation>"
		return 1
	}

	local operation=$1
	local SPEC_IN SPEC_OUT
	local Output="$RPMREBUILD_PROCESSING"
	local cmd
	case "X$operation" in
		Xinit)
			# This variable should not be local
			spec_index=1
		;;

		Xfini)
			if [ "X$need_change_spec" = "Xyes" ]; then
				SPEC_IN="$FIC_SPEC.$spec_index"
				case "x$specfile" in
					x) # No spec-only flag
						cmd="cp -f $SPEC_IN $FIC_SPEC"
					;;

					x-) # Spec-only flag, specfile is stdout
						cmd="cat $SPEC_IN"
					;;

					*) # Spec-only flag, not specfile not stdout
						cmd="cp -f $SPEC_IN $specfile"
					;;
				esac || return
				cat <<-CMD_FINI >> $Output || return
				# fini
				   $cmd || return
				CMD_FINI
			else
				:
			fi
		;;

		Xedit)
			need_change_spec="yes"
			SPEC_IN="$FIC_SPEC.$spec_index"
			spec_index=$[spec_index + 1]
			SPEC_OUT="$FIC_SPEC.$spec_index"
			cat <<-CMD_EDIT >> $Output || return
			# edit
			   cp -f $SPEC_IN $SPEC_OUT || return
			   SpecEdit $SPEC_OUT       || return

			CMD_EDIT
		;;

		Xall)
			modify="yes"
			need_change_spec="yes"
			SPEC_IN="$FIC_SPEC.$spec_index"
			spec_index=$[spec_index + 1]
			SPEC_OUT="$FIC_SPEC.$spec_index"
			cat <<-CMD_ALL >> $Output || return
			# all
			(
			   PATH="$MY_PLUGIN_DIR/all:\$PATH"       &&
			   RPM_BUILD_ROOT="$BUILDROOT"            &&
			   SPEC_IN="$SPEC_IN"                     &&
			   SPEC_OUT="$SPEC_OUT"                   &&
			   export RPM_BUILD_ROOT SPEC_IN SPEC_OUT &&
			   $OPTARG;
			) || return

			CMD_ALL
		;;

		Xfiles)
			modify="yes"
			cat <<-CMD_FILES >> $Output || return
			# files
			(
			   PATH="$MY_PLUGIN_DIR/files:\$PATH" &&
			   RPM_BUILD_ROOT="$BUILDROOT"        &&
			   export RPM_BUILD_ROOT              && 
			   $OPTARG; 
			) || return
			
			CMD_FILES
		;;

		Xspec)
			need_change_spec="yes"
			SPEC_IN="$FIC_SPEC.$spec_index"
			spec_index=$[spec_index + 1]
			SPEC_OUT="$FIC_SPEC.$spec_index"
			cat <<-CMD_SPEC >> $Output || return
			# spec
			( 
			   PATH="$MY_PLUGIN_DIR/spec:\$PATH" &&
			   $OPTARG; 
			) < $SPEC_IN > $SPEC_OUT || return
			
			CMD_SPEC
			
		;;

		*)
			Echo "$0: CreateProcessing: unknown operation '$operation'"
			return 1
		;;
	esac || return
	return 0
}
###############################################################################
function RpmUnpack
{
	[ "x$BUILDROOT" = "x/" ] && {
	   Error "Internal '$BUILDROOT' can not be '/'." 
           return 1
	}
	local CPIO_TEMP=$RPMREBUILD_TMPDIR/${PAQUET_NAME}.cpio
	rm -f $CPIO_TEMP                                    || return
	rpm2cpio ${PAQUET} > $CPIO_TEMP                     || return
	rm    --force --recursive $BUILDROOT                || return
	mkdir --parent            $BUILDROOT                || return
	(cd $BUILDROOT && cpio --quiet -idmu ) < $CPIO_TEMP || return
	rm -f $CPIO_TEMP                                    || return
	# Process ghost files
	/bin/bash $MY_LIB_DIR/rpmrebuild_ghost.sh $BUILDROOT < $FILES_IN || return
	return 0
}
###############################################################################
function CreateBuildRoot
{
        if [ "x$package_flag" = "x" ]; then
		if [ "X$modify" = "Xyes" ]; then
			/bin/bash $MY_LIB_DIR/rpmrebuild_buildroot.sh $BUILDROOT < $FILES_IN || return
		else
			: # Do nothing
		fi
	else
        	RpmUnpack || return
	fi 
	return 0
}
###############################################################################

function RpmBuild
{
	# reconstruction fichier rpm : le src.rpm est inutile
	# build rpm file, the src.rpm is not usefull to do
	# for rpm 4.1 : use rpmbuild
	local BUILDCMD=rpm
	[ -x /usr/bin/rpmbuild ] && BUILDCMD=rpmbuild
	eval $BUILDCMD $rpm_defines -bb $rpm_verbose $additional ${FIC_SPEC} || {
   		Error "package '${PAQUET}' build failed"
   		return 1
	}
	
	return 0
}

###############################################################################
function RpmFileName
{
	QF_RPMFILENAME=$(eval rpm $rpm_defines --eval %_rpmfilename) || return
	RPMFILENAME=$(eval rpm $rpm_defines --specfile --query --queryformat "${QF_RPMFILENAME}" ${FIC_SPEC}) || return
	# workarount for redhat 6.x
	arch=$(eval rpm $rpm_defines --specfile --query --queryformat "%{ARCH}"  ${FIC_SPEC})
	if [ $arch = "(none)" ]
	then
		arch=$(eval rpm $rpm_defines --query $package_flag --queryformat "%{ARCH}" ${PAQUET})
		RPMFILENAME=$(echo $RPMFILENAME | sed "s/(none)/$arch/g")
	fi

	[ -n "$RPMFILENAME" ] || return
	RPMFILENAME="${rpmdir}/${RPMFILENAME}"
	return 0
}

###############################################################################
function InstallationTest
{
	# installation test
	# force is necessary to avoid the message : already installed
	rpm -U --test --force ${RPMFILENAME} || {
		Error "Testinstall for package '${PAQUET}' failed"
		return 1
	}
	return 0
}

function Processing
{
	# Have we something to do ?
	[ "X$need_change_spec" = "Xyes" -o "X$modify" = "Xyes" ] || return 0
	local Aborted="no"
	local MsgFail="package '$PAQUET' modification failed."

	source $RPMREBUILD_PROCESSING && return 0
	[ "X$Aborted" = "Xyes" ] || Error "$MsgFail"
	return 1 
}
##############################################################
# Main Part                                                  #
##############################################################
# shell pour refabriquer un fichier rpm a partir de la base rpm
# a shell to build an rpm file from the rpm database

function Main
{
	WantContinue="Do you want to continue"

	#RPMREBUILD_TMPDIR=${RPMREBUILD_TMPDIR:-~/.tmp/rpmrebuild.$$}
	RPMREBUILD_TMPDIR=${RPMREBUILD_TMPDIR:-~/.tmp/rpmrebuild}
	export RPMREBUILD_TMPDIR

	FIC_SPEC=$RPMREBUILD_TMPDIR/spec
	FILES_IN=$RPMREBUILD_TMPDIR/files.in
	# I need it here just in case user specify 
	# plugins for fs modification 
	# (--change-files/--change-all)
	BUILDROOT=$RPMREBUILD_TMPDIR/root

	D=`dirname $0` || return
	source $D/rpmrebuild_parser.src || return
	MY_LIB_DIR="$D"
	MY_PLUGIN_DIR=${MY_LIB_DIR}/plugins

	# suite a des probleme de dates incorrectes
	# to solve problems of bad date
	export LC_TIME=POSIX

	RPMREBUILD_PROCESSING=$RPMREBUILD_TMPDIR/processing

	rm -rf   $RPMREBUILD_TMPDIR || return
	mkdir -p $RPMREBUILD_TMPDIR || return
	CommandLineParsing "$@" || return
	[ "x$NEED_EXIT" = "x" ] || return $NEED_EXIT

	if [ "x" = "x$package_flag" ]; then
   		[ "X$modify" = "Xyes" ] || BUILDROOT="/"
   		IsPackageInstalled || return
   		if [ "X$verify" = "Xyes" ]; then
      			out=$(VerifyPackage) || return
      			if [ -n "$out" ]; then
		 		Warning "some files have been modified:\n$out"
		 		QuestionsToUser || return
      			fi
   		else # NoVerify
			:
   		fi
	else
		:
		# When rebuilding package from .rpm file it's just native
		# to use perm/owner/group from the package.
		# But because it anyway default and if one has a reason
		# to change it, one can. I am not force it here anymore.
		#keep_perm="no"  # Be sure use perm, owner, group from the pkg query.
	fi

	if [ "X$spec_only" = "Xyes" ]; then
		BUILDROOT="/"
		SpecGeneration   || return
		Processing       || return
	else
		SpecGeneration   || return
		CreateBuildRoot  || return
		Processing       || return
		RpmBuild         || return
		RpmFileName      || return
		echo "result: ${RPMFILENAME}"
		InstallationTest || return
	fi
	return 0
}

Main "$@"
st=$?	# save status
#rm -rf $RPMREBUILD_TMPDIR
exit $st

#####################################
# BUILDROOT note.
# My original idea was for recreating package from another rpm file
# (not installed) use 'rpm -bb --define "buildroot foo"', but
# It does not work:
#  when i not specify buildroot in the spec file default value is "/"
#  I can build this package, but can't override buildroot from the
#  command line.
#
# when i specify buildroot: / in the spec file i got parser error.
#
# So, for recreating installed packages I need specfile WITHOUT
# buildroot
# For recreating package from another rpm I have to put buildroot in the
# specfile
#########################################
