#!/bin/sh
###############################################################################
#   ld_rpm.sh 
#
#    Copyright (C) 2002 by Eric Gerbier
#    Bug reports to:  gerbier@users.sourceforge.net
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

# shell pour refabriquer un fichier rpm a partir de la base rpm
# version 0.3 du 10/07/2002

#####################################################

interrogation() {
rpm -q --queryformat "$1" ${PAQUET}
}

#####################################################

ecrire_info() {
comment=$1
query=$2

output=`interrogation "$query"`
if [ "$output" != "(none)" ]
then
	echo -e "$comment $output" >> ${FIC_SPEC}
fi
}

#####################################################

# test argument
if [ $# -ne 1 ]
then
	echo "syntaxe $0 package"
	exit 1 
fi

# test existence package
export PAQUET=$1
output=`rpm -q ${PAQUET}`
if [ -z "$output" ]
then
	# pas de package ${PAQUET}
	exit 1
else
	NAME=`interrogation '%{NAME}\n'`
	VERSION=`interrogation '%{VERSION}\n'`
	RELEASE=`interrogation '%{RELEASE}\n'`

	NOM_COMPLET=${NAME}-${VERSION}-${RELEASE}
	NOM_VERSION=${NAME}-${VERSION}
fi

# fabrication fichier tar contenant les fichiers du paquet
REPER=/tmp/${NOM_VERSION}
if [ -a $REPER ]
then
	echo "$REPER existe"
	exit 1
fi
mkdir $REPER
rpm -ql  ${PAQUET} | cpio -pd  $REPER > /dev/null 2>&1
cd /tmp/
tar cvzf /usr/src/redhat/SOURCES/${NOM_COMPLET}.tgz  ${NOM_VERSION} >/dev/null
cd -
rm -rf  ${REPER} > /dev/null 2>&1

# fabrication fichier spec
FIC_SPEC=/usr/src/redhat/SPECS/${NOM_COMPLET}.spec

if [ -a ${FIC_SPEC} ]
then
	echo "fichier ${FIC_SPEC} existe"
	rm -f ${FIC_SPEC}
fi

ecrire_info "Summary: " '%{SUMMARY}\n'
echo "Name: ${NAME}"  >> ${FIC_SPEC}
echo "Version: ${VERSION}" >> ${FIC_SPEC}
echo "Release: ${RELEASE}" >> ${FIC_SPEC}

echo "Source: ${NOM_COMPLET}.tgz " >> ${FIC_SPEC}
ecrire_info "URL: " '%{URL}\n'
ecrire_info "Patch: " '%{PATCH}\n'

ecrire_info "Copyright: " '%{COPYRIGHT}\n'
ecrire_info "Group: "  '%{GROUP}\n'
ecrire_info "Packager: " '%{PACKAGER}\n'

ecrire_info "Distribution: " '%{DISTRIBUTION}\n'
ecrire_info "Vendor: " '%{VENDOR}\n'

ecrire_info "%description\n" '%{DESCRIPTION}\n'

cat << END >>  ${FIC_SPEC}
%prep
%setup
%build
%install
%clean
rm -rf \$RPM_BUILD_ROOT

END

rpm -q --scripts ${PAQUET} | awk -F: '/postinstall/ {printf ("%post \n%s\n", $2); getline}
/postuninstall/ {printf ("%postun \n%s\n", $2); getline}
/preinstall/ {printf ("%pre \n%s\n", $2);getline }
/preuninstall/ {printf ("%preun \n%s\n", $2);getline }
{ print $0} ' >> ${FIC_SPEC}

cat << END2 >>  ${FIC_SPEC}
%files
%defattr(-, root, root)
END2

# petite subtilite : les repertoires ne doivent pas 
# aparaitre directement, sinon probleme de doublons
liste=`rpm -ql ${PAQUET}`
for file in $liste
do
	if [ -d $file ]
	then
		echo "%dir $file" >> ${FIC_SPEC}
	else
		echo "$file" >> ${FIC_SPEC}
	fi
done

output=`rpm -q --changelog  ${PAQUET}`
if [ $output != "(none)" ]
then
	echo "%changelog" >> ${FIC_SPEC}
	echo $output >> ${FIC_SPEC}
fi

# reconstruction fichier rpm
rpm -bb -vv  ${FIC_SPEC}

ls -ltr /usr/src/redhat/RPMS/i386
