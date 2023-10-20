#!/bin/bash
# Environment File for live-scripting_fmw



# Project Sources
export PROJECT_HOME=/home/wls/live-scripting_fmw
export FMW_HOME=/opt/install/fmw

# Java Variables
export JAVA_DIR=/opt/install/java
export JAVA_HOME=/opt/install/java/jdk1.8.0_311
export JAVA_TEMP_DIR=/opt/install/java_temp

# Software Installations
export DIST_DIR=/opt/install/dist
export DIST_JAVA=/opt/install/dist/p18143322_1800_Linux-x86-64.zip
export DIST_FMW=/opt/install/dist/fmw_12.2.1.4.0_infrastructure_Disk1_1of1.zip
export DIST_OSB=/opt/install/dist/p30188305_122140_Generic.zip

export INV_PTR_LOC=/opt/install/dist/oraInst.loc
export TEMP_DIR_FMW=/opt/install/temp_fmw


# Domain Variables
export DOMAINS=/opt/install/domains
export DOMAIN_HOME=/opt/install/domains/osb_domain
export DOMAIN_NAME=osb_domain
export DOMAIN_USER=wls
export DOMAIN_PASSWORD=ham2burg


# RCU Variables
export CONNECT_STRING=localhost:1521:xepdb1
export CONNECT_STRING2=localhost:1521/xepdb1
export SCHEMA_PREFIX=OSBA
export SCHEMA_PASSWORD=ham2burg



# Aliases

alias dom="cd $DOMAIN_HOME"
alias nmh="cd $DOMAIN_HOME/common/nodemanager"
alias fmh="cd $FMW_HOME"


