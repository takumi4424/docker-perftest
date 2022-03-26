FROM osrf/ros:noetic-desktop-full

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
      git \
      python3-catkin-tools \
      libsdl-image1.2-dev \
      libsdl-dev \
      ros-noetic-tf2-sensor-msgs \
      ros-noetic-move-base-msgs \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*
