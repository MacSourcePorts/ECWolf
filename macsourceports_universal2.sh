# game/app specific values
export APP_VERSION="1.3.99999"
# ecwolf builds an .icns file, we will use that once it's been built
export ICONSDIR="build-arm64/ecwolf.app/Contents/Resources"
export ICONSFILENAME="icon"
export PRODUCT_NAME="ecwolf"
export EXECUTABLE_NAME="ecwolf"
export PKGINFO="APPLECWF"
export COPYRIGHT_TEXT="Wolfenstein 3-D Copyright © 1992 id Software, Inc. All rights reserved."

#constants
source ../MSPScripts/constants.sh

rm -rf ${BUILT_PRODUCTS_DIR}

# create makefiles with cmake
rm -rf ${X86_64_BUILD_FOLDER}
mkdir ${X86_64_BUILD_FOLDER}
cd ${X86_64_BUILD_FOLDER}
/usr/local/bin/cmake -G "Unix Makefiles" -DCMAKE_C_FLAGS_RELEASE="-arch x86_64" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 -DSDL2=ON -DOPENAL_LIBRARY=~/Documents/GitHub/MSPStore/opt/openal-soft/lib/libopenal.dylib -DOPENAL_INCLUDE_DIR=~/Documents/GitHub/MSPStore/opt/openal-soft/include -DSDL2_DIR=/usr/local/opt/sdl2/lib/cmake/SDL2 -DSDL2_INCLUDE_DIRS=/usr/local/opt/sdl2/include/SDL2 -DSDL2_LIBRARIES=/usr/local/opt/sdl2/lib ..

cd ..
rm -rf ${ARM64_BUILD_FOLDER}
mkdir ${ARM64_BUILD_FOLDER}
cd ${ARM64_BUILD_FOLDER}
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 -DSDL2=ON -DOPENAL_LIBRARY=~/Documents/GitHub/MSPStore/opt/openal-soft/lib/libopenal.dylib -DOPENAL_INCLUDE_DIR=~/Documents/GitHub/MSPStore/opt/openal-soft/include .. 

# perform builds with make
cd ..
cd ${X86_64_BUILD_FOLDER}
make -j$NCPU

cd ..
cd ${ARM64_BUILD_FOLDER}
make -j$NCPU

cd ..

# create the app bundle
"../MSPScripts/build_app_bundle.sh"

#copy resources
cp build-x86_64/${EXECUTABLE_FOLDER_PATH}/ecwolf.pk3 "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"

#sign and notarize
"../MSPScripts/sign_and_notarize.sh" "$1"