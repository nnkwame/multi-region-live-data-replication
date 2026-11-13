# Derived from the Strimzi 1.3.1 Connect build Dockerfile.
# Kept in the repository for local Docker and cloud CI builds.

FROM quay.io/strimzi/kafka:1.3.1-kafka-4.3.1@sha256:3d3bd43298d606299a2ede84ffe926606d8f1ef90f32982429e0a32a8e91d85a

USER root:root

##########
# Connector plugin debezium-mariadb
##########
RUN 'mkdir' '-p' '/opt/kafka/plugins/debezium-mariadb/747384a5' \
      && 'curl' '-f' '-L' '--output' '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz' 'https://repo.maven.apache.org/maven2/io/debezium/debezium-connector-mariadb/3.7.1.Final/debezium-connector-mariadb-3.7.1.Final-plugin.tar.gz' \
      && 'echo' 'eb01700b43216ad3edcc0401b88747d92fdfbe310f32ccbdc85a372c184e40390f00d7ed146235190527c9629de901f7da7613d180a5f8fb35d98b99eb23b2ce /opt/kafka/plugins/debezium-mariadb/747384a5.tgz' > '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz.sha512' \
      && 'sha512sum' '-c' '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz.sha512' \
      && 'rm' '-f' '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz.sha512' \
      && 'tar' 'xvfz' '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz' '-C' '/opt/kafka/plugins/debezium-mariadb/747384a5' \
      && 'rm' '-vf' '/opt/kafka/plugins/debezium-mariadb/747384a5.tgz'

##########
# Connector plugin debezium-jdbc
##########
RUN 'mkdir' '-p' '/opt/kafka/plugins/debezium-jdbc/de8aed92' \
      && 'curl' '-f' '-L' '--output' '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz' 'https://repo.maven.apache.org/maven2/io/debezium/debezium-connector-jdbc/3.7.1.Final/debezium-connector-jdbc-3.7.1.Final-plugin.tar.gz' \
      && 'echo' 'c8520f33a2176a55db677a164c3b77353242a422937f7056e0d53a85a9f078328a9a2ce62c6f803c447ae2b978df2a2d0af02792b0e27f7f751222c1e62e63fb /opt/kafka/plugins/debezium-jdbc/de8aed92.tgz' > '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz.sha512' \
      && 'sha512sum' '-c' '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz.sha512' \
      && 'rm' '-f' '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz.sha512' \
      && 'tar' 'xvfz' '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz' '-C' '/opt/kafka/plugins/debezium-jdbc/de8aed92' \
      && 'rm' '-vf' '/opt/kafka/plugins/debezium-jdbc/de8aed92.tgz'

USER 1001
