#!/bin/sh
export CATALINA_OPTS="-Dconfluence.home={{ config.dirs.home }} {{ config.catalina_opts }} ${CATALINA_OPTS}"
export JAVA_HOME={{ config.java_home }}
export CATALINA_PID={{ config.pid }}
