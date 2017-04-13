FROM ubuntu:16.04

RUN apt-get -y update
RUN apt-get -y install python2.7-dev python-pip python3-dev python3-pip vim wget unzip \
                       build-essential cmake git pkg-config libatlas-base-dev gfortran \
                       libjasper-dev libgtk2.0-dev libavcodec-dev libavformat-dev \
                       libswscale-dev libjpeg-dev libpng-dev libtiff-dev libjasper-dev libv4l-dev \
                       software-properties-common python-software-properties \
                       ant ninja-build

RUN apt-get update && apt-get -y install lib32stdc++6 lib32ncurses5 lib32z1

RUN pip install numpy matplotlib && pip3 install numpy matplotlib

# Install Oracle Java
RUN \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Download opencv 3.2.0
RUN wget https://github.com/opencv/opencv/archive/3.2.0.zip -O opencv3.zip && \
    unzip -q opencv3.zip && \
    mv /opencv-3.2.0 /opencv && \
    rm -rf opencv3.zip

# Download opencv contrib 3.2.0
RUN wget https://github.com/opencv/opencv_contrib/archive/3.2.0.zip -O opencv_contrib3.zip && \
    unzip -q opencv_contrib3.zip && \
    mv /opencv_contrib-3.2.0 /opencv_contrib && \
    rm -rf opencv_contrib3.zip

# Setup android ndk
RUN wget https://dl.google.com/android/repository/android-ndk-r14b-linux-x86_64.zip -O android-ndk-r14b-linux-x86_64.zip && \
    unzip -q android-ndk-r14b-linux-x86_64.zip && \
    rm -rf android-ndk-r14b-linux-x86_64.zip && ls /

ENV ANDROID_NDK=/android-ndk-r14b

# Setup android sdk
RUN wget http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz
RUN \
    tar -xvf android-sdk_r24.4.1-linux.tgz && \
    rm -rf android-sdk_r24.4.1-linux.tgz    

RUN echo y | /android-sdk-linux/tools/android update sdk --no-ui --all --filter platform-tools
RUN echo y | /android-sdk-linux/tools/android update sdk --no-ui --all --filter build-tools-24.0.3
RUN echo y | /android-sdk-linux/tools/android update sdk --no-ui --all --filter android-21,android-11

# for SIFT, SURF, etc
ADD ./features2d_manual.hpp /opencv/modules/features2d/misc/java/src/cpp/features2d_manual.hpp
# for OPENCL support, Toolchain 4.9 
ADD ./build_sdk.py /opencv/platforms/android/

# for Android build
WORKDIR /opencv
RUN python ./platforms/android/build_sdk.py --ndk_path /android-ndk-r14b --sdk_path /android-sdk-linux --extra_modules_path /opencv_contrib/modules .. ./

# for ubuntu library
RUN mkdir -p /opencv/build && mkdir -p /opencv/bin
WORKDIR /opencv/build
RUN cmake -D CMAKE_BUILD_TYPE=RELEASE \
        -D BUILD_PYTHON_SUPPORT=ON \
        -D CMAKE_INSTALL_PREFIX=/opencv/bin \
        -D INSTALL_C_EXAMPLES=ON \
        -D INSTALL_PYTHON_EXAMPLES=ON \
        -D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
        -D BUILD_EXAMPLES=ON \
        -D BUILD_NEW_PYTHON_SUPPORT=ON \
        -D WITH_IPP=OFF \
        -D WITH_V4L=ON \
        -D BUILD_opencv_dnn=OFF \
        -D BUILD_SHARED_LIBS=OFF ..

RUN make -j$NUM_CORES
RUN make install
RUN ldconfig
