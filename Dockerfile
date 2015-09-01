FROM debian:jessie
MAINTAINER Krzysztof Kardasz <krzysztof@kardasz.eu>

# Update system and install required packages
ENV DEBIAN_FRONTEND noninteractive

# Install git, download and extract Stash and create the required directory layout.
# Try to limit the number of RUN instructions to minimise the number of layers that will need to be created.
RUN apt-get update -qq \
    && apt-get install -y wget curl git unzip \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

# Download Oracle JDK
ENV ORACLE_JDK_VERSION jdk-8u51
ENV ORACLE_JDK_URL     http://download.oracle.com/otn-pub/java/jdk/8u51-b16/jdk-8u51-linux-x64.tar.gz
RUN mkdir -p /opt/jdk/$ORACLE_JDK_VERSION && \
    wget --header "Cookie: oraclelicense=accept-securebackup-cookie" -O /opt/jdk/$ORACLE_JDK_VERSION/$ORACLE_JDK_VERSION.tar.gz $ORACLE_JDK_URL && \
    tar -zxf /opt/jdk/$ORACLE_JDK_VERSION/$ORACLE_JDK_VERSION.tar.gz --strip-components=1 -C /opt/jdk/$ORACLE_JDK_VERSION && \
    rm /opt/jdk/$ORACLE_JDK_VERSION/$ORACLE_JDK_VERSION.tar.gz && \
    update-alternatives --install /usr/bin/java java /opt/jdk/$ORACLE_JDK_VERSION/bin/java 100 && \
    update-alternatives --install /usr/bin/javac javac /opt/jdk/$ORACLE_JDK_VERSION/bin/javac 100

ENV DOWNLOAD_URL        https://downloads.atlassian.com/software/confluence/downloads/atlassian-confluence-

# https://confluence.atlassian.com/display/STASH/Stash+home+directory
ENV CONFLUENCE_HOME          /var/atlassian/application-data/confluence

ENV JAVA_HOME /opt/jdk/$ORACLE_JDK_VERSION

ENV CATALINA_OPTS "-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStorePassword=changeit"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
ENV RUN_USER            atlassian
ENV RUN_USER_UID        5000
ENV RUN_GROUP           atlassian
ENV RUN_GROUP_GID       5000

RUN \
    groupadd --gid ${RUN_GROUP_GID} -r ${RUN_GROUP} && \
    useradd -r --uid ${RUN_USER_UID} -g ${RUN_GROUP} ${RUN_USER}

# Install Atlassian Stash to the following location
ENV CONFLUENCE_INSTALL_DIR   /opt/atlassian/confluence

ENV CONFLUENCE_VERSION 5.8.5

RUN mkdir -p                             ${CONFLUENCE_INSTALL_DIR} \
    && curl -L --silent                  ${DOWNLOAD_URL}${CONFLUENCE_VERSION}.tar.gz | tar -xz --strip=1 -C "$CONFLUENCE_INSTALL_DIR" \
    && mkdir -p                          ${CONFLUENCE_INSTALL_DIR}/conf/Catalina      \
    && chown -R nobody:nogroup           ${CONFLUENCE_INSTALL_DIR}/                   \
    && chmod -R 755                      ${CONFLUENCE_INSTALL_DIR}/                   \
    && chmod -R 700                      ${CONFLUENCE_INSTALL_DIR}/conf/Catalina      \
    && chmod -R 700                      ${CONFLUENCE_INSTALL_DIR}/logs               \
    && chmod -R 700                      ${CONFLUENCE_INSTALL_DIR}/temp               \
    && chmod -R 700                      ${CONFLUENCE_INSTALL_DIR}/work               \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/logs               \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/temp               \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/work               \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/conf

# MySQL connector, mail api, activation api
RUN \
    wget --header "Cookie: oraclelicense=accept-securebackup-cookie" -O ${CONFLUENCE_INSTALL_DIR}/jaf-1_1_1.zip http://download.oracle.com/otn-pub/java/jaf/1.1.1/jaf-1_1_1.zip && \
    unzip ${CONFLUENCE_INSTALL_DIR}/jaf-1_1_1.zip -d ${CONFLUENCE_INSTALL_DIR} && \
    mv ${CONFLUENCE_INSTALL_DIR}/jaf-1.1.1/activation.jar ${CONFLUENCE_INSTALL_DIR}/lib/ && \
    rm -rf ${CONFLUENCE_INSTALL_DIR}/jaf-1.1.1 ${CONFLUENCE_INSTALL_DIR}/jaf-1_1_1.zip && \
    wget -O ${CONFLUENCE_INSTALL_DIR}/mail-1.5.4.jar http://java.net/projects/javamail/downloads/download/javax.mail.jar && \
    mv ${CONFLUENCE_INSTALL_DIR}/mail-1.5.4.jar ${CONFLUENCE_INSTALL_DIR}/lib/ && \
    wget -O ${CONFLUENCE_INSTALL_DIR}/mysql-connector-java-5.1.36.tar.gz http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.36.tar.gz && \
    tar xzf ${CONFLUENCE_INSTALL_DIR}/mysql-connector-java-5.1.36.tar.gz -C ${CONFLUENCE_INSTALL_DIR} && \
    mv ${CONFLUENCE_INSTALL_DIR}/mysql-connector-java-5.1.36/mysql-connector-java-5.1.36-bin.jar ${CONFLUENCE_INSTALL_DIR}/lib/ && \
    rm -rf ${CONFLUENCE_INSTALL_DIR}/mysql-connector-java-5.1.36.tar.gz ${CONFLUENCE_INSTALL_DIR}/mysql-connector-java-5.1.36 && \
    rm -f ${CONFLUENCE_INSTALL_DIR}confluence/WEB-INF/lib/{activation,mail}-*.jar

# Confluence home dir
RUN \
    echo "confluence.home=${CONFLUENCE_HOME}" > ${CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/classes/confluence-init.properties

USER ${RUN_USER}:${RUN_GROUP}

VOLUME ["${CONFLUENCE_INSTALL_DIR}"]

# HTTP Port
EXPOSE 8090

WORKDIR $CONFLUENCE_INSTALL_DIR

# Run in foreground
CMD ["./bin/start-confluence.sh", "-fg"]