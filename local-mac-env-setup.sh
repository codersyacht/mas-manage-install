#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# GLOBAL CONFIG
###############################################################################
JAVA_VERSION="https://github.com/ibmruntimes/semeru25-binaries/releases/download/jdk-25.0.3.0/ibm-semeru-open-jdk_aarch64_mac_25.0.3.0.tar.gz"
WAS_VERSION="https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/26.0.0.5/wlp-webProfile8-26.0.0.5.zip"
LOCAL_BASE_DIR="/Users/jawahar/codersyacht"
DOWNLOAD_DIR="/Users/jawahar/Downloads"
REMOTE_HOST="codehub1.fyre.ibm.com"
REMOTE_USER="admin"
REMOTE_PASS="LabMachine4@Training"
REMOTE_SMP_DIR="/home/admin/apps/SMP"
REMOTE_TAR="/home/admin/apps/SMP.tar"
SQL_SA_PASSWORD="LabMachine4@Training"

###############################################################################
# DERIVED CONFIG
###############################################################################
JAVA_INSTALL_DIR="$LOCAL_BASE_DIR/java/ibmjdk25"
JAVA_SRC="$JAVA_INSTALL_DIR/Contents/Home"
LOCAL_SMP_DIR="$LOCAL_BASE_DIR/SMP"
LIBERTY_DIR="$LOCAL_BASE_DIR/wlp"
###############################################################################
# UTILS
###############################################################################
log() {
  echo
  echo "=============================="
  echo " $1"
  echo "=============================="
}

require_cmd() {
  command -v "$1" >/dev/null || {
    echo "❌ Required command not found: $1"
    exit 1
  }
}
###############################################################################
# PART I – ORACLE (PODMAN)
###############################################################################
log "PART I – ORACLE FOR MAC"

require_cmd podman

podman rm -f ORADB 2>/dev/null || true
podman rmi -f codersyacht/maximo-oracle-mac:base 2>/dev/null || true

log "Existing containers deleted."

podman pull codersyacht/maximo-oracle-mac:base

podman run -d --name ORADB -p 1521:1521 -p 5500:5500 -e ORACLE_PWD=LabMachine4@Training  codersyacht/maximo-oracle-mac:base

echo "✅ ORACLE container running."

###############################################################################
# PART II – JAVA + LIBERTY
###############################################################################
log "PART II - JAVA + LIBERTY"

log "Installing IBM Semeru JDK..."

cd "$LOCAL_BASE_DIR"

rm -rf "$JAVA_INSTALL_DIR"
mkdir -p "$JAVA_INSTALL_DIR"

wget -O "$DOWNLOAD_DIR/java.tgz" "$JAVA_VERSION"

tar -xf "$DOWNLOAD_DIR/java.tgz" -C "$DOWNLOAD_DIR"

EXTRACTED_DIR=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type d -name "jdk-25*" | head -1)

if [[ -z "$EXTRACTED_DIR" ]]; then
  echo "❌ Could not find extracted JDK folder in $DOWNLOAD_DIR"
  exit 1
fi

mv "$EXTRACTED_DIR"/* "$JAVA_INSTALL_DIR/"

rm -f "$DOWNLOAD_DIR/java.tgz"
rm -rf "$EXTRACTED_DIR"

log "IBM Semeru JDK installed to $JAVA_INSTALL_DIR"

rm -f java-home.txt

cat > java-home.txt << EOF
export JAVA_HOME=$JAVA_SRC
export PATH=\$JAVA_HOME/bin:\$PATH
EOF


export JAVA_HOME="$JAVA_SRC"
export PATH="$JAVA_HOME/bin:$PATH"



java -version


if [ ! -d "wlp" ]; then
    echo "wlp directory not found. Downloading WebSphere Liberty..."
    wget -O wlp.zip \
      "$WAS_VERSION"
      unzip wlp.zip
      rm wlp.zip
else
    echo "wlp directory already exists. Skipping download."
fi

cd wlp/bin
./featureUtility installFeature jdbc-4.2 servlet-4.0 || true
./featureUtility installFeature javaMail-1.6 || true
./featureUtility installFeature jdbc-4.2 || true
./featureUtility installFeature jaxws-2.2 || true
./featureUtility installFeature servlet-4.0 || true
./featureUtility installFeature jndi-1.0 || true
./featureUtility installFeature wasJmsServer-1.0 || true
./featureUtility installFeature wasJmsClient-2.0 || true
 ./featureUtility installFeature wmqJmsClient-2.0 || true
./featureUtility installFeature ssl-1.0 || true
./featureUtility installFeature jmsMdb-3.2 || true
./featureUtility installFeature openidConnectClient-1.0 || true
./featureUtility installFeature ejbRemote-3.2 || true
./featureUtility installFeature ejbHome-3.2 || true
./featureUtility installFeature jsonp-1.1 || true
./featureUtility installFeature springBoot-3.0 || true
./featureUtility installFeature wasjmssecurity-1.0 || true

cd ../usr/servers
rm -rf manage
../../bin/server create manage

cd manage

cat >jvm.options<<'EOF'
-Dcom.ibm.mq.cfg.jmqi.useMQCSPauthentication=true
-Dfile.encoding=UTF8
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000
-Xms8192m
-Xmx8192m
EOF

cat >server.xml<<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<server description="new server">
	<!-- Enable features -->
	<featureManager>
		<feature>javaMail-1.6</feature>
		<feature>jdbc-4.2</feature>
		<feature>jaxws-2.2</feature>
		<feature>jndi-1.0</feature>
		<feature>wasJmsClient-2.0</feature>
		<feature>ssl-1.0</feature>
		<feature>webProfile-8.0</feature>
		<feature>wmqJmsClient-2.0</feature>
		<feature>jmsMdb-3.2</feature>
		<feature>ejbRemote-3.2</feature>
		<feature>ejbHome-3.2</feature>
		<feature>jsonp-1.1</feature>
	</featureManager>

	<!-- HTTP endpoint -->
	<httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9080" httpsPort="9443" protocolVersion="http/1.1">
		<compression serverPreferredAlgorithm="deflate|gzip|x-gzip|zlib|identity|none">
			<types>+application/*</types>
			<types>-text/plain</types>
			<types>-application/zip</types>
		</compression>
	</httpEndpoint>

	<webContainer extractHostHeaderPort="true"
	              trustHostHeaderPort="true"
	              disableXPoweredBy="true"
	              addstricttransportsecurityheader="max-age=31536000;includeSubDomains"/>

	<cdi12 enableImplicitBeanArchives="false"/>

	<!-- JNDI -->
	<jndiEntry jndiName="maxappname" value="maximoui"/>

	<!-- Application -->
	<application context-root="maximo" type="ear" id="maximoui" location="maximo-all.ear" name="maximoui">
		<application-bnd>
			<security-role name="any-authenticated">
				<special-subject type="ALL_AUTHENTICATED_USERS"/>
			</security-role>
			<security-role name="everyone">
				<special-subject type="EVERYONE"/>
			</security-role>
		</application-bnd>
	</application>

	<include optional="true" location="server-custom.xml"/>

	<!-- SSL -->
	<ssl id="defaultSSLConfig"
	     sslProtocol="TLSv1.2"
	     keyStoreRef="defaultKeyStore"
	     trustStoreRef="defaultTrustStore"
	     clientAuthenticationSupported="true"/>

	<ssl id="controllerConnectionConfig" sslProtocol="TLSv1.2"/>
	<ssl id="memberConnectionConfig" sslProtocol="TLSv1.2"/>

	<applicationManager autoExpand="true"/>
</server>
EOF


###############################################################################
# PART III – SMP SYNC (CORRECT & SAFE)
###############################################################################
log "PART III – SMP SYNC"

require_cmd sshpass

# Optional: clean only AFTER successful sync (commented for safety)
# rm -rf "$LOCAL_SMP_DIR"

LOCAL_TAR="$LOCAL_BASE_DIR/SMP.tar"

echo "➡️ Creating SMP.tar on remote (relative path, NOT absolute)..."

sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no \
"$REMOTE_USER@$REMOTE_HOST" "
  set -e
  cd /home/admin/apps
  tar -cvf SMP.tar SMP
"
echo "➡️ Copying SMP.tar to local machine..."
sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no \
"$REMOTE_USER@$REMOTE_HOST:/home/admin/apps/SMP.tar" \
"$LOCAL_TAR"

rm -rf "$LOCAL_SMP_DIR"

echo "➡️ Extracting SMP.tar into $LOCAL_BASE_DIR ..."
cd "$LOCAL_BASE_DIR"
tar -xvf "$LOCAL_TAR"

echo "➡️ Cleaning up local tar..."
rm -f "$LOCAL_TAR"

echo "➡️ Deleting remote SMP.tar..."
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no \
"$REMOTE_USER@$REMOTE_HOST" "rm -f /home/admin/apps/SMP.tar"

# Validate result
if [[ -d "$LOCAL_SMP_DIR/writeable/maximo" ]]; then
  echo "✅ SMP synced correctly to $LOCAL_SMP_DIR"
else
  echo "❌ SMP sync failed or layout unexpected"
  echo "   Expected: $LOCAL_SMP_DIR/writeable/maximo"
  exit 1
fi


###############################################################################
# PART IV – maximo.properties
###############################################################################
log "PART IV – maximo.properties"

PROPERTIES_FILE="$LOCAL_SMP_DIR/maximo/applications/maximo/properties/maximo.properties"

[[ -f "$PROPERTIES_FILE" ]] || {
  echo "❌ maximo.properties not found"
  exit 1
}

cp "$PROPERTIES_FILE" "$PROPERTIES_FILE.bak"

# --------------------------------
# REMOVE DB2 CONFIG ONLY
# --------------------------------
sed -i '' \
-e '/mxe.db.url=jdbc:db2:/d' \
-e '/mxe.db.driver=com.ibm.db2.jcc.DB2Driver/d' \
-e '/mxe.db.user=db2inst1/d' \
-e '/mxe.db.password=/d' \
-e '/mxe.db.schemaowner=maximo/d' \
-e '/mxe.db.DB2sslConnection=false/d' \
"$PROPERTIES_FILE"

# --------------------------------
# ADD ORACLE SERVER CONFIG
# --------------------------------
cat <<'EOF' >> "$PROPERTIES_FILE"

# -------------------------------
# Oracle Server configuration
# -------------------------------
mxe.db.url=jdbc:oracle:thin:@localhost:1521/OMDB
mxe.db.driver=oracle.jdbc.OracleDriver
mxe.db.user=maximo
mxe.db.password=LabMachine4@Training
mxe.db.schemaowner=maximo
EOF

echo "✅ maximo.properties updated"

###############################################################################
# PART V – JAVA FOR SMP
###############################################################################
log "PART V – JAVA FOR SMP"

rm -rf "$LOCAL_SMP_DIR/maximo/tools/java"
mkdir -p "$LOCAL_SMP_DIR/maximo/tools/java"

cp -R "$JAVA_SRC" "$LOCAL_SMP_DIR/maximo/tools/java/jre"

export JAVA_HOME="$LOCAL_SMP_DIR/maximo/tools/java/jre"
export PATH="$JAVA_HOME/bin:$PATH"

java -version

###############################################################################
# PART VI – MAXINST
###############################################################################
log "PART VI – MAXINST"

export JAVA_HOME="$LOCAL_SMP_DIR"/maximo/tools/java/jre

cd "$LOCAL_SMP_DIR"/maximo/tools/maximo
./maxinst.sh -sPRIMARY -tPRIMARY

###############################################################################
# PART VII – BUILD EAR
###############################################################################
log "PART VII – BUILD EAR"

cd "$LOCAL_SMP_DIR"/maximo/deployment/was-liberty-default/
./maximo-all.sh


###############################################################################
# PART VIII – DEPLOY EAR
###############################################################################
log "PART VIII – DEPLOY EAR"

mv "$LOCAL_SMP_DIR"/maximo/deployment/was-liberty-default/deployment/maximo-all/maximo-all-server/apps/maximo-all.ear "$LOCAL_BASE_DIR"/wlp/usr/servers/manage/dropins/maximo-all.ear

###############################################################################
# DONE
###############################################################################
log "ALL DONE ✅"
