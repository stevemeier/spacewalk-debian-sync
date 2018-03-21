#!/usr/bin/python -tt

# Add missing "Multi-Arch" headers to "Packages" file
# You have to use my modified version of Steve Meiers
# spacewalk-debian-sync script, so the Multi-Arch headers
# get written to a temporary file while the original
# Packages file gets parsed
#
# You also need python-debian (which is installed on
# Spacewalk server) to run this script
#
# Author: Robert Paschedag <robert.paschedag@netlution.de>
# Version: 20171017

import sys
import os
from debian.deb822 import *

if len(sys.argv) < 3:
    print "Usage: %s <path_to_unzipped_Packages> <path_to_file_with_multiarch_headers>" % sys.argv[0]
    sys.exit(1)

package_file = sys.argv[1]
multiarch_file = sys.argv[2]

if not os.path.isfile(package_file):
    print "Error: Inputfile '%s' not available." % package_file
    sys.exit(1)
if not os.path.isfile(multiarch_file):
    print "Error: Inputfile '%s' not available." % multiarch_file
    sys.exit(1)

packages = {}

with open(package_file, 'r') as pkgs:
    for pkg in Packages.iter_paragraphs(pkgs):
        packages[pkg['Package'] + pkg['Version'] + pkg['Architecture']] = pkg

new_package = open(package_file + '.new', 'w')
with open(multiarch_file, 'r') as m_file:
    for line in m_file:
        p, v, a, multi = line.rstrip().split(" ")
        if packages.has_key(p + v + a):
            packages[p + v + a]['Multi-Arch'] = multi
        else:
            print "Package %s with version %s and architecture %s not found in list." % (p, v, a)

for pkg in packages.values():
    pkg.dump(new_package)
    new_package.write("\n")
new_package.close()
sys.exit(0)

