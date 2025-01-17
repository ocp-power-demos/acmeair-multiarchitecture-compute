# Builds the WAR using Maven
FROM maven:3.9.1-ibm-semeru-11-focal as build_war
ADD source/ .
RUN mvn clean package -DskipTests

### CREATE SMALL LIBERTY IMAGE ###
FROM icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi as buildLiberty_minify

ENV CONFIG_DIRECTORY=source/src/main/liberty/config

# Install unzip; needed to unzip Open Liberty
USER 0
RUN dnf clean all \
    && rm -r /var/cache/dnf \
    && dnf install -y unzip
USER 1001

# Copy in a server.xml to start server with correct features set
COPY --chown=1001:0 ${CONFIG_DIRECTORY} /config
RUN features.sh

# Create a minified openliberty package for use in final image
RUN /opt/ol/wlp/bin/server package --archive=/tmp/ol_minified.zip --include=minify --os=Linux

WORKDIR /tmp

RUN unzip -q /tmp/ol_minified.zip -d /tmp/ol

### CREATE SMALL JRE IMAGE ###
FROM ibmsemeruruntime/open-11-jdk:ubi-jdk as buildjre

ENV WAR_FILE=source/target/acmeair-monolithic-jakarta.war

RUN dnf install -y unzip

COPY --chown=1001:0 --from=buildLiberty_minify /tmp/ol /opt/ol/
# If you already know the Java modules required, you can list them in deps/java_modules.txt and
# uncomment the line directly below. Then comment out all the lines below that line until the jlink invocation.
#COPY /deps/java_modules.txt /tmp

COPY --chown=1001:0 ${WAR_FILE} /tmp
COPY deps/getJavaDependencies.sh /tmp
COPY deps/java_modules_append.txt /tmp
COPY deps/java_modules_exclude.txt /tmp

# Scan the jars in /opt/ol/wlp/lib, the jars in the app at WEB-INF/lib
# and the classes in WEB-INF/classes for Java Module Dependencies (deps)
# Exlcude any deps listed in java_modules_exclude.txt
# and add any deps found in java_modules_append.txt.
RUN cd /tmp && unzip $(basename ${WAR_FILE}) \
      && /tmp/getJavaDependencies.sh /opt/ol/wlp/lib --jars \
      && /tmp/getJavaDependencies.sh /tmp/WEB-INF/lib --jars \
      && /tmp/getJavaDependencies.sh /tmp/WEB-INF/classes \
      && echo -n "," >> /tmp/java_modules.txt \ 
      && cat /tmp/java_modules_append.txt >> /tmp/java_modules.txt \
      && cat /tmp/java_modules.txt

RUN /opt/java/openjdk/bin/jlink --no-header-files \
           --no-man-pages --compress=2 \
           --strip-debug \
           --add-modules $(cat /tmp/java_modules.txt) \
           --output /opt/jdk11-minified

### CREATE BASE SCC LAYER ###
FROM registry.access.redhat.com/ubi8/ubi-minimal as buildscc

RUN mkdir -p /output/workarea && mkdir -p /output/.classCache \
    && chown -R 1001:0 /output && chmod -R g+rw /output

USER 1001

ENV CONFIG_DIRECTORY=source/src/main/liberty/config
ENV WAR_FILE=source/target/acmeair-monolithic-jakarta.war

### copy in the minified java11 jre
COPY --chown=1001:0 --from=buildjre /opt/jdk11-minified /opt/jdk11-minified

## copy in the minified package of open liberty
COPY --chown=1001:0 --from=buildLiberty_minify /tmp/ol /opt/ol/
COPY --chown=1001:0 --from=buildLiberty_minify /opt/ol/helpers/build/populate_scc.sh /opt/ol/helpers/build/populate_scc.sh

# Config
COPY --chown=1001:0 ${CONFIG_DIRECTORY}/* /opt/ol/wlp/usr/servers/defaultServer/

ENV JAVA_HOME=/opt/jdk11-minified

#### Run populate_scc.sh script
ENV PATH=/opt/ol/wlp/bin:/opt/ol/helpers/build:/opt/jdk11-minified/bin:$PATH
ENV VERBOSE=true
RUN populate_scc.sh -i 1

### FINAL BASE IMAGE ###

### Get the ubi
FROM registry.access.redhat.com/ubi8/ubi-minimal

RUN mkdir -p /output/workarea && mkdir -p /output/.classCache \
    && chown -R 1001:0 /output && chmod -R g+rw /output 

USER 1001

ENV CONFIG_DIRECTORY=source/src/main/liberty/config

### copy in the minified java11 jre
COPY --chown=1001:0 --from=buildjre /opt/jdk11-minified /opt/jdk11-minified

## copy in the minified package of open liberty
COPY --chown=1001:0 --from=buildLiberty_minify /tmp/ol /opt/ol/
COPY --chown=1001:0 --from=buildLiberty_minify /opt/ol/helpers/build/populate_scc.sh /opt/ol/helpers/build/populate_scc.sh

## copy in the populated SCC from build_scc
COPY --chown=1001:0 --from=buildscc /output/.classCache /output/.classCache

# Config
COPY --chown=1001:0 ${CONFIG_DIRECTORY}/* /opt/ol/wlp/usr/servers/defaultServer/

ENV PATH=/opt/ol/wlp/bin:/opt/ol/helpers/build:/opt/jdk11-minified/bin:$PATH
ENV JAVA_HOME=/opt/jdk11-minified
ENV OPENJ9_JAVA_OPTIONS="-XX:+IgnoreUnrecognizedVMOptions -XX:+IdleTuningGcOnIdle -Xshareclasses:name=liberty,readonly,cacheDir=/output/.classCache -Dosgi.checkConfiguration=false"

ENV CONFIG_DIRECTORY=source/src/main/liberty/config
ENV WAR_FILE=source/target/acmeair-monolithic-jakarta.war

COPY --chown=1001:0 ${CONFIG_DIRECTORY}/* /opt/ol/wlp/usr/servers/defaultServer/
COPY --chown=1001:0 ${WAR_FILE} /opt/ol/wlp/usr/servers/defaultServer/apps/

ENV VERBOSE=true
RUN populate_scc.sh -i 1

# Set SCC to readonly
ENV OPENJ9_JAVA_OPTIONS="-XX:+IgnoreUnrecognizedVMOptions -XX:+IdleTuningGcOnIdle -Xshareclasses:name=liberty,readonly,cacheDir=/output/.classCache -Dosgi.checkConfiguration=false"

CMD ["/opt/ol/wlp/bin/server", "run", "defaultServer"]