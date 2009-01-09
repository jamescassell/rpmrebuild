# Initial spec file created by autospec ver. 0.6 with rpm 2.5 compatibility
Summary: A tool to build rpm file from rpm database
Summary(fr): Un outil pour construire un package depuis une base rpm
# The Summary: line should be expanded to about here -----^
Name: rpmrebuild
License: GPL
Group: Development/Tools
BuildRoot: %{_topdir}/installroots/%{name}-%{version}-%{release}
Source: rpmrebuild.tar.gz
# Following are optional fields
Url: http://rpmrebuild.sourceforge.net
Packager: Eric Gerbier <gerbier@users.sourceforge.net>
#Distribution: Red Hat Contrib-Net
BuildArchitectures: noarch
Requires: bash
Requires: cpio
# mkdir ...
Requires: fileutils
Requires: sed
# sort
Requires: textutils
Requires: rpm >= 4.0, /usr/bin/rpmbuild
Release: %{release}

%description
rpmrebuild allow to build an rpm file from an installed rpm, or from
another rpm file, with or without changes (batch or interactive).
It can be extended by a plugin system.
A typical use is to easy repackage a software after some configuration's
change.

%description -l fr
rpmbuild permet de fabriquer un package rpm � partir d'un 
package install� ou d'un fichier rpm, avec ou sans modifications 
(interactives ou batch).
Un syst�me de plugin permet d'�tendre ses fonctionnalit�s.
Une utilisation typique est la fabrication d'un package suite � des modifications
de configuration.

%prep
%setup -c rpmrebuild

%build
make

%install
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf "$RPM_BUILD_ROOT"
make DESTDIR="$RPM_BUILD_ROOT" install

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf "$RPM_BUILD_ROOT"

%files -f rpmrebuild.files

