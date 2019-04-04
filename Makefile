IMAGE_NAME			:= opendistro-kibana
REPO						?= vulnbe
KIBANA_VERSION 	?= 6.6.1
PLUGIN_VERSION	?= 0.7.0.1
PLUGIN_NAME			?= opendistro_security_kibana_plugin-${PLUGIN_VERSION}
PLUGIN_DEST			?= build/kibana/${PLUGIN_NAME}
NODE_TAG				?= 10.15.2-alpine
MAVEN_TAG				?= 3.6.0-jdk-8-alpine

.PHONY: image push submodules

submodules:
	git submodule update --recursive

image: submodules
	docker build \
		--build-arg PLUGIN_NAME=${PLUGIN_NAME} \
		--build-arg KIBANA_VERSION=${KIBANA_VERSION} \
		--build-arg NODE_TAG=${NODE_TAG} \
		--build-arg MAVEN_TAG=${MAVEN_TAG} \
		-t ${IMAGE_NAME}:${KIBANA_VERSION}-${PLUGIN_VERSION} \
		--pull .

plugin: submodules
	-mkdir output
	docker run -it --rm \
		-v $$PWD:/plugin:ro \
		-v $$PWD/output:/output \
		node:${NODE_TAG} \
		ash -c "\
			cp -r /plugin /tmp/ods && \
			cd /tmp/ods/opendistro-security-kibana-plugin && \
			npm install && \
			mkdir -p ${PLUGIN_DEST} && \
			cp -a index.js ${PLUGIN_DEST} && \
			cp -a package.json ${PLUGIN_DEST} && \
			cp -a lib ${PLUGIN_DEST} && \
			cp -a node_modules ${PLUGIN_DEST} && \
			cp -a public ${PLUGIN_DEST} && \
			cp -r /tmp/ods /output/tmp"
	docker run -it --rm \
		-v $$PWD/output:/output \
		maven:${MAVEN_TAG} \
		bash -c "\
			cd /output/tmp/opendistro-security-kibana-plugin && \
			mvn clean install && \
			cp /output/tmp/opendistro-security-kibana-plugin/target/releases/${PLUGIN_NAME}.zip /output && \
			rm -rf /output/tmp"

push:
	docker tag ${IMAGE_NAME}:${KIBANA_VERSION}-${PLUGIN_VERSION} \
		${REPO}/${IMAGE_NAME}:${KIBANA_VERSION}-${PLUGIN_VERSION}
	docker push ${REPO}/${IMAGE_NAME}:${KIBANA_VERSION}-${PLUGIN_VERSION}
