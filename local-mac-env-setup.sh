#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# GLOBAL CONFIG
###############################################################################
LOCAL_BASE_DIR="/Users/jawahar/codersyacht"
LOCAL_SMP_DIR="$LOCAL_BASE_DIR/SMP"
LIBERTY_DIR="$LOCAL_BASE_DIR/webprofile-8"
JAVA_SRC="/Users/jawahar/codersyacht/java/ibmjdk17/Contents/Home"

REMOTE_HOST="codehub1.fyre.ibm.com"
REMOTE_USER="admin"
REMOTE_PASS="LabMachine4@Training"
REMOTE_SMP_DIR="/home/admin/apps/SMP"
REMOTE_TAR="/home/admin/apps/SMP.tar"

SQL_SA_PASSWORD="LabMachine4@Training"

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
# PART I – MSSQL (PODMAN)
###############################################################################
log "PART I – MSSQL FOR MAC"

require_cmd podman

podman rm -f maximo-mssql 2>/dev/null || true
podman rmi -f codersyacht/maximo-mssql:V1 2>/dev/null || true

podman pull codersyacht/maximo-mssql:V1

podman run -d \
  --name maximo-mssql \
  --hostname sql2022 \
  -e ACCEPT_EULA=Y \
  -e MSSQL_SA_PASSWORD="$SQL_SA_PASSWORD" \
  -e MSSQL_PID=Developer \
  -p 1433:1433 \
  codersyacht/maximo-mssql:V1

echo "✅ MSSQL container running"

###############################################################################
# PART II – JAVA + LIBERTY
###############################################################################
log "PART II – JAVA + LIBERTY"

if [[ ! -d "$JAVA_SRC" ]]; then
  echo "❌ IBM Semeru JDK not found: $JAVA_SRC"
  exit 1
fi

export JAVA_HOME="$JAVA_SRC"
export PATH="$JAVA_HOME/bin:$PATH"

java -version

cd "$LOCAL_BASE_DIR"

if [[ ! -d "webprofile-8" ]]; then
  wget https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/24.0.0.11/wlp-webProfile8-24.0.0.11.zip
  unzip wlp-webProfile8-24.0.0.11.zip
  mv wlp webprofile-8
  rm wlp-webProfile8-24.0.0.11.zip
fi

cd webprofile-8/bin
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
# ADD SQL SERVER CONFIG
# --------------------------------
cat <<'EOF' >> "$PROPERTIES_FILE"

# -------------------------------
# SQL Server configuration
# -------------------------------
mxe.db.url=jdbc:sqlserver://localhost:1433;databaseName=Maximo;encrypt=true;trustServerCertificate=true;
mxe.db.driver=com.microsoft.sqlserver.jdbc.SQLServerDriver
mxe.db.user=sa
mxe.db.password=LabMachine4@Training
mxe.db.schemaowner=dbo
mxe.db.vendor=sqlserver
mxe.db.dbproduct=sqlserver
mxe.db.server.version=2022
mxe.db.start=sqlserver
mxe.db.sqlserver.varchar=MAXDATA
mxe.db.sqlserver.longvarchar=MAXDATA

# LOB types also stored in MAXDATA
mxe.db.sqlserver.maxvarchar=MAXDATA
mxe.db.sqlserver.dbclob=MAXDATA
mxe.db.sqlserver.text=MAXDATA

# Indexes → MAXINDEX
mxe.db.sqlserver.index=MAXINDEX

# Optional fallback (ignored if above are present)
mxe.db.fileGroup=PRIMARY
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

mv "$LOCAL_SMP_DIR"/maximo/deployment/was-liberty-default/deployment/maximo-all/maximo-all-server/apps/maximo-all.ear "$LOCAL_BASE_DIR"/webprofile-8/usr/servers/manage/dropins/maximo-all.ear

###############################################################################
# DONE
###############################################################################
log "ALL DONE ✅"
