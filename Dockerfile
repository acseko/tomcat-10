FROM redhat/ubi10:latest

LABEL org.opencontainers.image.title=MyTomcatDemo
LABEL org.opencontainers.image.description="Nothing to prod, only demo"
LABEL org.opencontainers.image.vendor=acseko
  
ARG OPENJDK_MAJOR_VERSION=21

RUN dnf install -y --disableplugin=subscription-manager https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
  dnf update -y --disableplugin=subscription-manager && \
  dnf upgrade -y --disableplugin=subscription-manager && \
  dnf install -y --disableplugin=subscription-manager java-${OPENJDK_MAJOR_VERSION}-openjdk-headless sed xmlstarlet jq lsof tini procps && \
  rm -rf /usr/lib/python*/site-packages/* usr/lib64/python*/site-packages/*

RUN mkdir -p /home/tomcat/apache-tomcat
WORKDIR /home/tomcat/apache-tomcat
COPY target/packages/tomcat-*.tar.gz /home/tomcat/apache-tomcat/
RUN tar -xvzf "$(ls tomcat-*.tar.gz |head -1)" --strip-components=1 --exclude=apache-tomcat-*/webapps/* && \
  sed -i -e 's|<Listener className="org.apache.catalina.core.AprLifecycleListener" />|<!-- <Listener className="org.apache.catalina.core.AprLifecycleListener" /> -->|g' \
    conf/server.xml && \
  echo "org.apache.tomcat.util.digester.REPLACE_SYSTEM_PROPERTIES=true" >> conf/catalina.properties && \
  echo "org.apache.tomcat.util.digester.PROPERTY_SOURCE=org.apache.tomcat.util.digester.EnvironmentPropertySource" >> conf/catalina.properties && \
  xmlstarlet ed -P -S -L -s /Server/Service/Engine/Host -t elem -n HCValve -v "" -i //HCValve -t attr -n "className" -v "org.apache.catalina.valves.HealthCheckValve" \
    -r //HCValve -v Valve conf/server.xml && \
  rm -rf tomcat-*.tar.gz && \
  ln -s $(dirname $(dirname $(realpath $(which java)))) /usr/lib/jvm/openjdk

ENV JAVA_HOME=/usr/lib/jvm/openjdk
ENV CATALINA_HOME=/home/tomcat/apache-tomcat
COPY target/packages/log4j*.jar ${CATALINA_HOME}/lib/
ENV PATH=${PATH}:/home/tomcat:${CATALINA_HOME}/bin

ADD entrypoint.sh /home/tomcat/entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["startup.sh"]
