FROM quay.io/amery/docker-ubuntu-vscode-builder:22.04

ENV OPENJDK_VERSION="19"
ENV ANDROID_API_VERSIONS="33 34"
ENV ANDROID_STUDIO_VERSION="2022.3.1.19"
ENV ANDROID_CMD_VERSION="10406996_latest"

#
# update world
#
RUN apt-get update && apt-get dist-upgrade -y && apt-get clean

#
# Java
#
ENV JAVA_HOME="/usr/lib/jvm/java-${OPENJDK_VERSION}-openjdk-amd64"

RUN apt-get update && apt-get install -y \
		gradle \
		openjdk-${OPENJDK_VERSION}-jdk-headless \
		unzip \
	&& apt-get clean

#
# Android SDK
#
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

RUN curl -LsS -o /tmp/commandlinetools-linux.zip \
		https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMD_VERSION}.zip \
	&& unzip /tmp/commandlinetools-linux.zip -d "$ANDROID_SDK_ROOT" \
	&& export SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT" \
	&& $SDKMANAGER --update \
	&& yes | $SDKMANAGER --licenses \
	&& $SDKMANAGER --install \
		"cmdline-tools;latest" \
		"emulator" \
		"platform-tools" \
		"tools" \
	&& for x in $ANDROID_API_VERSIONS; do \
			echo "platforms;android-$x"; \
		done | xargs -r $SDKMANAGER --install \
	&& cd "$ANDROID_SDK_ROOT/cmdline-tools" \
	&& rm -f /tmp/commandlinetools-linux.zip \
	&& ls -1d latest/* | cut -d/ -f2- | xargs -rt rm -rf

RUN apt-get update && apt-get install -y \
		libxtst6 \
	&& apt-get clean \
	&& curl -LsS -o /tmp/android-studio-linux.tar.gz \
		https://redirector.gvt1.com/edgedl/android/studio/ide-zips/${ANDROID_STUDIO_VERSION}/android-studio-${ANDROID_STUDIO_VERSION}-linux.tar.gz \
	&& tar -C "$ANDROID_SDK_ROOT" -zxf /tmp/android-studio-linux.tar.gz \
	&& rm -f /tmp/android-studio-linux.tar.gz \
	&& echo ${ANDROID_STUDIO_VERSION} > $ANDROID_SDK_ROOT/android-studio/.version

COPY 10-android-sdk.sh /etc/entrypoint.d/

COPY studio.sh /usr/local/bin/studio
COPY builder_version.sh /usr/local/bin/builder_version
