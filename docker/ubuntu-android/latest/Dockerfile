FROM amery/docker-ubuntu-builder:20.04

ENV OPENJDK_VERSION="8"
ENV ANDROID_VERSION="30"
ENV ANDROID_CMD_VERSION="6858069_latest"

# Android SDK
#
ENV ANDROID_SDK_ROOT "/opt/android-sdk"
ENV JAVA_HOME "/usr/lib/jvm/java-${OPENJDK_VERSION}-openjdk-amd64"
ENV PATH "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

RUN apt-get update && apt-get install -y \
		gradle \
		openjdk-${OPENJDK_VERSION}-jdk-headless \
		unzip \
		wget \
	&& apt-get clean

RUN wget -P /tmp/ https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMD_VERSION}.zip \
	&& unzip /tmp/commandlinetools-linux-${ANDROID_CMD_VERSION}.zip -d "$ANDROID_SDK_ROOT" \
	&& export SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT" \
	&& $SDKMANAGER --update \
	&& yes | $SDKMANAGER --licenses \
	&& $SDKMANAGER --install \
		"cmdline-tools;latest" \
		"platform-tools" \
		"platforms;android-${ANDROID_VERSION}" \
	&& cd "$ANDROID_SDK_ROOT/cmdline-tools" \
	&& rm -f /tmp/commandlinetools-linux-${ANDROID_CMD_VERSION}.zip \
	&& ls -1d latest/* | cut -d/ -f2- | xargs -rt rm -rf

COPY android-sdk.sh /etc/entrypoint.d/
