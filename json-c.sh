#!/bin/bash



###########################################################################
#
# Don't change anything under this line!
#
###########################################################################


# No need to change this since xcode build will only compile in the
# necessary bits from the libraries we create
ARCHS="x86_64 armv7 armv7s arm64"

DEVELOPER=`xcode-select -print-path`
#DEVELOPER="/Applications/Xcode.app/Contents/Developer"


REPOROOT=$(pwd)

# Where we'll end up storing things in the end
OUTPUTDIR="${REPOROOT}/dependencies"
mkdir -p ${OUTPUTDIR}/include
mkdir -p ${OUTPUTDIR}/lib


BUILDDIR="${REPOROOT}/build"

# where we will keep our sources and build from.
SRCDIR="${BUILDDIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILDDIR}/built"
mkdir -p $INTERDIR

########################################

VERSION="0.13.1-20180305"

PACKAGENAME="json-c-json-c-${VERSION}"
PACKAGENAME_ZIP="json-c-${VERSION}.tar.gz"


cd $SRCDIR

# Exit the script if an error happens
set -e

if [ ! -e "${SRCDIR}/${PACKAGENAME_ZIP}" ]; then
	echo "Downloading ${PACKAGENAME_ZIP}"
    curl -LO https://github.com/json-c/json-c/archive/${PACKAGENAME_ZIP}

fi

echo "https://github.com/json-c/json-c/archive/${PACKAGENAME_ZIP}"
echo "Using ${PACKAGENAME}"


tar zxf $PACKAGENAME_ZIP -C $SRCDIR
cd "${SRCDIR}/${PACKAGENAME}"

set +e # don't bail out of bash script if ccache doesn't exist
CCACHE=`which ccache`
if [ $? == "0" ]; then
	echo "Building with ccache: $CCACHE"
	CCACHE="${CCACHE} "
else
	echo "Building without ccache"
	CCACHE=""
fi
set -e # back to regular "bail out on error" mode

export ORIGINALPATH=$PATH

for ARCH in ${ARCHS}
do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ]; then
        PLATFORM="iPhoneSimulator"
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_CONFIG="--host=x86_64"
    else
        PLATFORM="iPhoneOS"
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_CONFIG="--host=arm-apple-darwin"
    fi

	mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

    XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
    CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"

    CFLAGS="-arch $ARCH"
    CXXFLAGS="$CFLAGS"
    LDFLAGS="$CFLAGS"

	./configure --disable-shared --enable-static --disable-doc ${EXTRA_CONFIG} \
    --prefix="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" \
    CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
#    LDFLAGS="$LDFLAGS ${OPT_LDFLAGS} -L${OUTPUTDIR}/lib" \
#    CFLAGS="$CFLAGS ${EXTRA_CFLAGS} ${OPT_CFLAGS}  -I${OUTPUTDIR}/include -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk" \


    # Build the application and install it to the fake SDK intermediary dir
    # we have set up. Make sure to clean up afterward because we will re-use
    # this source tree to cross-compile other targets.
	make -j4
	make install
	make clean
done

########################################

echo "Build library...libjson-c.a"

# These are the libs that comprise libjson-c.a
OUTPUT_LIBS="libjson-c.a"
for OUTPUT_LIB in ${OUTPUT_LIBS}; do
	INPUT_LIBS=""
	for ARCH in ${ARCHS}; do
		if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
		then
			PLATFORM="iPhoneSimulator"
		else
			PLATFORM="iPhoneOS"
		fi
		INPUT_ARCH_LIB="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/lib/${OUTPUT_LIB}"
		if [ -e $INPUT_ARCH_LIB ]; then
			INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
		fi
	done
	# Combine the three architectures into a universal library.
	if [ -n "$INPUT_LIBS"  ]; then
		lipo -create $INPUT_LIBS \
		-output "${OUTPUTDIR}/lib/${OUTPUT_LIB}"
	else
		echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
	fi
done

for ARCH in ${ARCHS}; do
	if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
	then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
	cp -R ${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/include/* ${OUTPUTDIR}/include/
	if [ $? == "0" ]; then
		# We only need to copy the headers over once. (So break out of forloop
		# once we get first success.)
		break
	fi
done


####################

echo "Building done."
echo "Cleaning up..."
#rm -fr ${INTERDIR}
#rm -fr "${SRCDIR}/opus-${VERSION}"
echo "Done."
