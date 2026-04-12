FROM jenkins/jenkins:lts-jdk21

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins casc /usr/share/jenkins/ref/casc
COPY --chown=jenkins:jenkins init.groovy.d /usr/share/jenkins/ref/init.groovy.d/

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Djava.awt.headless=true"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc
