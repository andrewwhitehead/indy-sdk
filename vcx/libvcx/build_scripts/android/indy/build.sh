#!/bin/bash

FINAL="0"

while getopts ":f" opt; do
    case ${opt} in
        f) FINAL="1";;
        \?);;
    esac
done
shift $((OPTIND -1))

TARGET_ARCH=$1
TARGET_API=$2
CROSS_COMPILE=$3
GIT_INSTALL=${4:-master}

if [ -z "${TARGET_ARCH}" ]; then
    echo STDERR "Missing TARGET_ARCH argument"
    echo STDERR "e.g. x86 or arm"
    exit 1
fi

if [ -z "${TARGET_API}" ]; then
    echo STDERR "Missing TARGET_API argument"
    echo STDERR "e.g. 21"
    exit 1
fi

if [ -z "${CROSS_COMPILE}" ]; then
    echo STDERR "Missing CROSS_COMPILE argument"
    echo STDERR "e.g. i686-linux-android"
    exit 1
fi

if [ -z "${GIT_INSTALL}" ] ; then
    echo STDERR "Missing GIT_INSTALL argument"
    echo STDERR "e.g. master or rc or tags/v1.4.0"
    exit 1
fi

if [ -z "${OPENSSL_DIR}" ]; then
    OPENSSL_DIR="openssl_${TARGET_ARCH}"
    if [ -d "${OPENSSL_DIR}" ] ; then
        echo "Found ${OPENSSL_DIR}"
    elif [ -z "$5" ]; then
        echo STDERR "Missing OPENSSL_DIR argument and environment variable"
        echo STDERR "e.g. set OPENSSL_DIR=<path> for environment or openssl_${TARGET_ARCH}"
        exit 1
    else
        OPENSSL_DIR=$5
    fi
fi

if [ -z "${SODIUM_DIR}" ]; then
    SODIUM_DIR="libsodium_${TARGET_ARCH}"
    if [ -d "${SODIUM_DIR}" ] ; then
        echo "Found ${SODIUM_DIR}"
    elif [ -z "$6" ]; then
        echo STDERR "Missing SODIUM_DIR argument and environment variable"
        echo STDERR "e.g. set SODIUM_DIR=<path> for environment or libsodium_${TARGET_ARCH}"
        exit 1
    else
        SODIUM_DIR=$6
    fi
fi

if [ -z "${LIBZMQ_DIR}" ] ; then
    LIBZMQ_DIR="libzmq_${TARGET_ARCH}"
    if [ -d "${LIBZMQ_DIR}" ] ; then
        echo "Found ${LIBZMQ_DIR}"
    elif [ -z "$7" ] ; then
        echo STDERR "Missing LIBZMQ_DIR argument and environment variable"
        echo STDERR "e.g. set LIBZMQ_DIR=<path> for environment or libzmq_${TARGET_ARCH}"
        exit 1
    else
        LIBZMQ_DIR=$7
    fi
fi

if [ ! -f "android-ndk-r20-linux-x86_64.zip" ] ; then
    echo "Downloading android-ndk-r20-linux-x86_64.zip"
    wget -q https://dl.google.com/android/repository/android-ndk-r20-linux-x86_64.zip
else
    echo "Skipping download android-ndk-r20-linux-x86_64.zip"
fi

_INDY_SDK_REPO="https://github.com/hyperledger/indy-sdk.git"

if [ ! -d "indy-sdk" ] ; then
    echo "git cloning indy-sdk"
    git clone --branch ${GIT_INSTALL} ${_INDY_SDK_REPO}
else
    echo "Skipping git clone of indy-sdk"
    _GIT_BRANCH=$(git --git-dir indy-sdk/.git branch | head -n 1 | sed -e 's/^..//g')
    echo "Current branch set to ${_GIT_BRANCH}"
    GIT_INSTALL="${GIT_INSTALL//\//\/\/}"
    echo "GIT_INSTALL set to ${GIT_INSTALL}"
    _MATCH=$(echo "${_GIT_BRANCH}" | egrep "${GIT_INSTALL}")

    if [ -z "${_MATCH}" ] ; then
        echo STDERR "Branch is not set properly in indy-sdk/.git"
        exit 1
    fi
fi
rm -f "indy-sdk/libindy/Cargo.lock"

docker build -t libindy-android:latest . --build-arg target_arch=${TARGET_ARCH} --build-arg target_api=${TARGET_API} --build-arg cross_compile=${CROSS_COMPILE} --build-arg openssl_dir=${OPENSSL_DIR} --build-arg sodium_dir=${SODIUM_DIR} --build-arg libzmq_dir=${LIBZMQ_DIR} --build-arg final=${FINAL} &&
docker run libindy-android:latest && \
docker_id=$(docker ps -a | grep libindy-android:latest | grep Exited | tail -n 1 | cut -d ' ' -f 1) && \
docker_image_id=$(docker image ls | grep libindy-android | perl -pe 's/\s+/ /g' | cut -d ' ' -f 3) && \
docker cp ${docker_id}:/home/indy_user/libindy.so . && \
docker cp ${docker_id}:/home/indy_user/libindy.a . && \
docker rm ${docker_id} > /dev/null && \
docker rmi ${docker_image_id} > /dev/null
