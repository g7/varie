varie
=====

Various stuff and silly scripts that might be useful to someone (including
the future me).

No warranty whatsoever, keep in mind that this stuff has been thrown out
in minutes and it's pretty ugly.

apt_buildable
-------------

Builds a list of buildable packages present in a directory, given
a list of deb+deb-src repositories.

Background: following the [OVH SBG blaze](https://help.ovhcloud.com/en/faq/strasbourg-incident/),
we lost control of the hybris-mobian repository.  
No backups were made, since things were still experimental and
the service is easy to rebuild (software is inside a public Docker
image, signing keys were backed up, actual source is in GitHub and
in a bunch of hard drives :D).  
This script has been helpful to get a list of which packages can be
rebuilt straight away.

Requirements: apt, devscripts, equivs

Usage: modify your script to your liking, add your repositories (keep
in mind that both deb and deb-src repositories must be present), then
run it.  
The packages printed in the output are safe to rebuild as-is, as it means
that every dependency can be satisfied with what is present on the
repositories.

Run the script multiple times until no packages are printed anymore.

Current state is stored in `$PWD/REGISTRY`. Remove it to start over.

Do a double-check afterwards, as some complex packages might have been
skipped.

You can download every package metadata (`debian/control`) for a whole
organization in GitHub by using the `github_fetch_debian_control_for_org`
script, see below.

github_fetch_debian_control_for_org
-----------------------------------

Gets a debian/control file for every repository in the given organization.
Based on [this comment in a public gist](https://gist.github.com/caniszczyk/3856584#gistcomment-1888281)
(@boussou)

Requirements: curl
