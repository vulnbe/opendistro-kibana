ARG KIBANA_VERSION="6.6.1"
ARG NODE_TAG="10.15-alpine"
ARG MAVEN_TAG="3.6.0-jdk-8-alpine"
ARG PLUGIN_NAME="opendistro_security_kibana_plugin-v0"

FROM node:${NODE_TAG} as node-build
ARG KIBANA_VERSION
ARG PLUGIN_NAME
ENV PLUGIN_DEST="build/kibana/${PLUGIN_NAME}"
COPY opendistro-security-kibana-plugin /root/opendistro-security-kibana-plugin
COPY pom.xml /root/
COPY .git /root/.git
RUN cd /root/opendistro-security-kibana-plugin && \
  sed -i "s/\"version\": *\"[^\"]*\"/\"version\": \"${KIBANA_VERSION}\"/1" package.json && \
  npm install && \
  mkdir -p "${PLUGIN_DEST}" && \
	cp -a "index.js" "${PLUGIN_DEST}" && \
	cp -a "package.json" "${PLUGIN_DEST}" && \
	cp -a "lib" "${PLUGIN_DEST}" && \
	cp -a "node_modules" "${PLUGIN_DEST}" && \
	cp -a "public" "${PLUGIN_DEST}"

FROM maven:${MAVEN_TAG} as maven-build
COPY --from=node-build /root /root
RUN cd /root/opendistro-security-kibana-plugin/ && mvn clean install

FROM docker.elastic.co/kibana/kibana:${KIBANA_VERSION}
ARG PLUGIN_NAME
LABEL Author="Alexey Pronin <a@vuln.be>"
COPY --from=maven-build /root/opendistro-security-kibana-plugin/target/releases/${PLUGIN_NAME}.zip /tmp/
RUN NODE_OPTIONS="--max-old-space-size=8192" bin/kibana-plugin install file:///tmp/${PLUGIN_NAME}.zip && \
  echo 'xpack.security.enabled: false' >> /usr/share/kibana/config/kibana.yml
