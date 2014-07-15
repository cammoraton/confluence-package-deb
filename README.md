Shell script and debian directory to generate dpkg from upstream confluence tarball.

Download tarball from https://www.atlassian.com/software/confluence/download

Run generate.sh ${tarball} on an ubuntu box with:
tomcat6-user build-essential
installed

Do whatever with the resulting .deb

Example of sorta doing the same thing with fpm on the conlfuence 3.5.17 tarball
fpm -s tar -t deb -n confluence -v 3.5.17 --prefix /var/lib/confluence 
-C confluence-3.5.17/confluence  --deb-init debian/confluence.init confluence-3.5.17.tar.gz