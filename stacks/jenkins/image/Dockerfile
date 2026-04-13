FROM jenkins/jenkins:lts-jdk21

USER root
ARG COMPOSE_VERSION=2.32.4
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl python3-minimal \
  && ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in amd64) DC_ARCH=x86_64 ;; arm64) DC_ARCH=aarch64 ;; *) echo "unsupported arch: $ARCH"; exit 1 ;; esac \
  && mkdir -p /usr/local/lib/docker/cli-plugins \
  && curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-${DC_ARCH}" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose \
  && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
  && rm -rf /var/lib/apt/lists/*
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins casc /usr/share/jenkins/ref/casc
COPY --chown=jenkins:jenkins init.groovy.d /usr/share/jenkins/ref/init.groovy.d/

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Djava.awt.headless=true"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc
