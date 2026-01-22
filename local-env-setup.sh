cd /home/admin/apps

rm -rf jdk17

rm -rf SMP

wget -O java.tgz https://github.com/ibmruntimes/semeru17-certified-binaries/releases/download/jdk-17.0.16%2B8_openj9-0.53.0/ibm-semeru-certified-jdk_x64_linux_17.0.16.0.tar.gz

tar -xvf java.tgz

rm -rf java.tgz

mv jdk-17.0.16+8 jdk17

chmod 755 -R jdk17

eval $(crc oc-env)

POD_NAME=$(oc get pods -n mas-max-manage --no-headers | grep manage-maxinst | awk '{print $1}')

echo "$POD_NAME"

oc cp -n mas-max-manage ${POD_NAME}:/opt/IBM/SMP SMP

chmod 775 -R SMP

cd /home/admin/apps/SMP/maximo/tools

mkdir -p java/jre

cd java

cp -r /home/admin/apps/jdk17/* ./jre

export JAVA_HOME=/home/admin/apps/SMP/maximo/tools/java/jre

export PATH=$JAVA_HOME/bin:$PATH

cd /home/admin/apps/SMP/maximo/applications/maximo/properties

PUBLIC_IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)

echo "$PUBLIC_IP"

cat > maximo.properties <<EOF
mxe.name=MXServer
mxe.db.url=jdbc:db2://${PUBLIC_IP}:50000/MAXIMO
mxe.db.driver=com.ibm.db2.jcc.DB2Driver
mxe.db.user=db2inst1
mxe.db.password=LabMachine4@Training
mxe.db.schemaowner=MAXIMO
mxe.db.DB2sslConnection=false
mxe.logging.CorrelationEnabled=0
EOF

cd /home/admin/apps/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maximouiweb/webmodule/WEB-INF
mv web.xml web-original.xml
mv web-dev.xml web.xml
echo "maximouiweb completed"
cd /home/admin/apps/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maxrestweb/webmodule/WEB-INF
mv web.xml web-original.xml
mv web-dev.xml web.xml
echo "maxrestweb completed"
cd /home/admin/apps/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/mboweb/webmodule/WEB-INF
mv web.xml web-original.xml
mv web-dev.xml web.xml
echo "mboweb completed"
cd /home/admin/apps/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/meaweb/webmodule/WEB-INF
mv web.xml web-original.xml
mv web-dev.xml web.xml
echo "meaweb completed"
cd /home/admin/apps/SMP/maximo/deployment/was-liberty-default/
./maximo-all.sh


cd /home/admin/apps

cat > java-home.txt <<'EOF'
export JAVA_HOME=/home/admin/apps/jdk17
export PATH=$JAVA_HOME/bin:$PATH
EOF
export JAVA_HOME=/home/admin/apps/jdk17
export PATH=$JAVA_HOME/bin:$PATH

java -version

if [ ! -d "webprofile-8" ]; then
    echo "webprofile-8 directory not found. Downloading WebSphere Liberty..."
    wget -O webprofile-8.zip \
      https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/24.0.0.11/wlp-webProfile8-24.0.0.11.zip
      unzip webprofile-8.zip
      rm webprofile-8.zip
      mv wlp webprofile-8
else
    echo "webprofile-8 directory already exists. Skipping download."
fi

cd /home/admin/apps/webprofile-8/bin
      ./featureUtility installFeature javaMail-1.6
      ./featureUtility installFeature jdbc-4.2
      ./featureUtility installFeature jaxws-2.2
      ./featureUtility installFeature servlet-4.0
      ./featureUtility installFeature jndi-1.0
      ./featureUtility installFeature wasJmsServer-1.0
      ./featureUtility installFeature wasJmsClient-2.0
      ./featureUtility installFeature wmqJmsClient-2.0
      ./featureUtility installFeature ssl-1.0
      ./featureUtility installFeature jmsMdb-3.2
      ./featureUtility installFeature openidConnectClient-1.0
      ./featureUtility installFeature ejbRemote-3.2
      ./featureUtility installFeature ejbHome-3.2
      ./featureUtility installFeature jsonp-1.1
      ./featureUtility installFeature springBoot-3.0
      ./featureUtility installFeature wasjmssecurity-1.0

cd /home/admin/apps/webprofile-8/usr/servers
rm -rf manage
/home/admin/apps/webprofile-8/bin/server create manage
cd manage


cat > server.xml <<'EOF'
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


cat > jvm.options <<'EOF'
-Dcom.ibm.mq.cfg.jmqi.useMQCSPauthentication=true
-Dfile.encoding=UTF8
-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8000
-Xms8192m
-Xmx8192m
EOF


cd /home/admin/apps/webprofile-8/usr/servers/manage/dropins

mv /home/admin/apps/SMP/maximo/deployment/was-liberty-default/deployment/maximo-all/maximo-all-server/apps/maximo-all.ear /home/admin/apps/webprofile-8/usr/servers/manage/dropins/maximo-all.ear

ls

