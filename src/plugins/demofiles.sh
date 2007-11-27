#!/bin/sh
###############################################################################
#   demofiles.sh
#      it's a part of the rpmrebuild project
#
#    Copyright (C) 2004 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#      or          : valery_reznic@users.sourceforge.net
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
# code's file of demo plugin for rpmrebuild

# just a demo script to show what can be done
# with a file plugin

# go to the directory which contains all package's files
# in the same tree as the installed files :
# if the package contains /etc/cron.daily files, you will find etc/cron.daily directory here
cd $RPM_BUILD_ROOT

# you can now do what you want on the files : 
# add, remove, move, rename files (be carefull, you have to change the %files section too)
# modify files, change perms ...

# for this demo, we do not change anything, just display what we can see
find . -ls
