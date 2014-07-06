#!/bin/bash
# Takes a confluence packaged EAR/WAR tarball and preps it for
# building into a debian package

# Some defaults
CONFLUENCE_DATA_DIR="/usr/share/confluence/data"

# BEGIN SANITY CHECKS
# We need an argument
if [ $# -eq 0 -o -z "$1" ] ; then
  echo "No arguments supplied."
  exit 1
fi

# It should be a file
if [ ! -f $1 ] ; then
  echo "Argument is not a file."
  exit 1
fi

# Assumption checks
# The first argument should have confluence in the name
echo $1 | grep -i confluence
if [ $? -eq 1 ] ; then
  echo "Supplied file does not contain confluence in name"
  echo "Up may be down. Black may be white. Bailing for safety."
  exit 1
fi

# We need tomcat6-instance-create to setup the standalone tomcat
INSTANCE_CREATE=`which tomcat6-instance-create`
if [ $? -eq 1 ] ; then
  echo "Unable to find tomcat6-instance-create via which."
  echo "Please install tomcat6-user package"
  exit 1
fi

# END SANITY CHECKS
# BEGIN CLI CONFIG

# Second arg overrides data directory
if [ ! -z "$2" ] ; then
  CONFLUENCE_DATA_DIR=$2
fi

# END CLI CONFIG
# BEGIN ACTUAL WORK
START_DIR=${PWD}
TMP_DIR="${START_DIR}/tmp"


# This is the exact moment i got lazy with this.
TARBALL=`readlink -f $1`
CONFLUENCE_VERSION=`echo ${TARBALL} | sed -e 's/^[^0-9]*//g' | sed -E 's/[^0-9]*$//g'`
BASE_DIR="${TMP_DIR}/confluence-${CONFLUENCE_VERSION}"

# Make the temp directory
mkdir -p ${TMP_DIR}

# Extract the exploded WAR
cd ${TMP_DIR}
tar -xzf ${TARBALL} --wildcards */confluence

# Get the confluence directory
CONF_DIR=`ls -1d ${TMP_DIR}/*confluence*`
# Pull the exploded war out
mv ${CONF_DIR}/confluence ${TMP_DIR}/ROOT
# Clean up after ourselves
rm -rf ${CONF_DIR}

echo "Setting up tomcat instance"
# Set up tomcat
${INSTANCE_CREATE} ${BASE_DIR}
# Install the exploded war
mv ${TMP_DIR}/ROOT ${BASE_DIR}/webapps

echo "Configuring confluence"
# Configure confluence
cat > "${BASE_DIR}/webapps/ROOT/WEB-INF/classes/confluence-init.properties" << EOT
###########################
# Configuration Directory #
###########################
confluence.home=${CONFLUENCE_DATA_DIR}
EOT

echo "  Modifying startup script"
# Fixup startup and shutdown to dynamically determine
# basedir
cat > "${BASE_DIR}/bin/startup.sh" << EOT
#!/bin/sh
export CATALINA_BASE=\`readlink -f \$0 | xargs -0 dirname | xargs -0 dirname\`
/usr/share/tomcat6/bin/startup.sh
echo "Tomcat started"
EOT

echo "  Modifying shutdown script"
cat > "${BASE_DIR}/bin/shutdown.sh" << EOT
#!/bin/sh
export CATALINA_BASE=\`readlink -f \$0 | xargs -0 dirname | xargs -0 dirname\`

/usr/share/tomcat6/bin/shutdown.sh
echo "Tomcat stopped"
EOT

echo "  Modifying env"
# And the defaults from the script set memory too low
# Increase it.
sed -i 's/Xmx128M/Xms256M -Xmx512M -XX:MaxPermSize=256M/g' ${BASE_DIR}/bin/setenv.sh 

echo "  Modifying bootstrap.jar link"
rm -f ${BASE_DIR}/bin/bootstrap.jar 
ln -s /usr/share/tomcat6/bin/bootstrap.jar ${BASE_DIR}/bin/bootstrap.jar

echo "Compressing...."
# Tar everything up
tar czf $START_DIR/confluence_${CONFLUENCE_VERSION}.orig.tar.gz *

echo "Setting up debian packaging..."
# Set up the build
cd ${START_DIR}
mv ${TMP_DIR}/confluence-${CONFLUENCE_VERSION} confluence-${CONFLUENCE_VERSION}

echo " (RE)Generating md5sums"
cd ${START_DIR}/debian
md5sum defaults.template > defaults.md5sum
md5sum logrotate.template > logrotate.md5sum

echo "  (RE)Generating changelog stub"
# Generate the changelog
cat > "${START_DIR}/debian/changelog" << EOT
confluence (${CONFLUENCE_VERSION}) unstable; urgency=low

  * Initial Release.

 -- unknown <vagrant@unknown>  Thu, 03 Jul 2014 00:04:19 +0000
EOT

echo "  Populating things"
cd ${START_DIR}
cp -pr ${START_DIR}/debian confluence-${CONFLUENCE_VERSION}

echo "Building package (dpkg-buildpackage -us -uc)"
cd confluence-${CONFLUENCE_VERSION}
dpkg-buildpackage -us -uc

cd ${START_DIR}
# Cleanup
echo "Cleaning up..."
echo "  Temporary directory"
rm -rf ${TMP_DIR}
echo "  Build directory..."
rm -rf confluence-${CONFLUENCE_VERSION}
echo "  Unneccesary artifacts...."
rm -f confluence_*.tar.gz
rm -f confluence_*.dsc
rm -f confluence_*.changes

# END ACTUAL WORK
