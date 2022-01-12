# game/app specific values
export APP_VERSION="1.3.99999"
# ecwolf builds an .icns file, we will use that once it's been built
export ICONSDIR="build-arm64/ecwolf.app/Contents/Resources"
export ICONSFILENAME="icon"
export PRODUCT_NAME="ecwolf"
export EXECUTABLE_NAME="ecwolf"
export PKGINFO="APPLECWF"
export COPYRIGHT_TEXT="Wolfenstein 3-D Copyright © 1992 id Software, Inc. All rights reserved."

# constants
export BUILT_PRODUCTS_DIR="release"
export WRAPPER_NAME="${PRODUCT_NAME}.app"
export CONTENTS_FOLDER_PATH="${WRAPPER_NAME}/Contents"
export EXECUTABLE_FOLDER_PATH="${CONTENTS_FOLDER_PATH}/MacOS"
export UNLOCALIZED_RESOURCES_FOLDER_PATH="${CONTENTS_FOLDER_PATH}/Resources"
export ICONS="${ICONSFILENAME}.icns"
export BUNDLE_ID="com.macsourceports.${PRODUCT_NAME}"

# For parallel make on multicore boxes...
NCPU=`sysctl -n hw.ncpu`

# create makefiles with cmake
rm -rf build-x86_64
mkdir build-x86_64
cd build-x86_64
/usr/local/bin/cmake -G "Unix Makefiles" -DCMAKE_C_FLAGS_RELEASE="-arch x86_64" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 -DSDL2=ON -DOPENAL_LIBRARY=~/Documents/GitHub/MSPStore/opt/openal-soft/lib/libopenal.dylib -DOPENAL_INCLUDE_DIR=~/Documents/GitHub/MSPStore/opt/openal-soft/include -DSDL2_DIR=/usr/local/opt/sdl2/lib/cmake/SDL2 -DSDL2_INCLUDE_DIRS=/usr/local/opt/sdl2/include/SDL2 -DSDL2_LIBRARIES=/usr/local/opt/sdl2/lib ..
# -Wno-dev

cd ..
rm -rf build-arm64
mkdir build-arm64
cd build-arm64
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 -DSDL2=ON -DOPENAL_LIBRARY=~/Documents/GitHub/MSPStore/opt/openal-soft/lib/libopenal.dylib -DOPENAL_INCLUDE_DIR=~/Documents/GitHub/MSPStore/opt/openal-soft/include .. 
#-Wno-dev

# perform builds with make
cd ..
cd build-x86_64
make -j$NCPU

cd ..
cd build-arm64
make -j$NCPU

cd ..

# create the app bundle
"../MSPScripts/build_app_bundle.sh"

#lipo the executable
lipo build-x86_64/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME} build-arm64/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME} -output "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}" -create

#copy resources
cp build-x86_64/${EXECUTABLE_FOLDER_PATH}/ecwolf.pk3 "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"

cp ~/Documents/GitHub/MSPStore/lib/libSDL2-2.0.0.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libjpeg.9.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libSDL2_mixer-2.0.0.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libmodplug.1.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libvorbisfile.3.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libvorbis.0.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libFLAC.8.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libmpg123.0.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
cp ~/Documents/GitHub/MSPStore/lib/libogg.0.dylib "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"

# use install_name tool to point executable to bundled resources (probably wrong long term way to do it)
#modify x86_64
install_name_tool -change /usr/local/opt/sdl2/lib/libSDL2-2.0.0.dylib @executable_path/libSDL2-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}
install_name_tool -change /usr/local/opt/jpeg/lib/libjpeg.9.dylib @executable_path/libjpeg.9.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}
install_name_tool -change /usr/local/opt/sdl2_mixer/lib/libSDL2_mixer-2.0.0.dylib @executable_path/libSDL2_mixer-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}

install_name_tool -change /usr/local/opt/sdl2/lib/libSDL2-2.0.0.dylib @executable_path/libSDL2-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib

install_name_tool -change /usr/local/opt/libmodplug/lib/libmodplug.1.dylib @executable_path/libmodplug.1.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /usr/local/opt/libvorbis/lib/libvorbisfile.3.dylib @executable_path/libvorbisfile.3.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /usr/local/opt/libvorbis/lib/libvorbis.0.dylib @executable_path/libvorbis.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /usr/local/opt/flac/lib/libFLAC.8.dylib @executable_path/libFLAC.8.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /usr/local/opt/mpg123/lib/libmpg123.0.dylib @executable_path/libmpg123.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib

install_name_tool -change /usr/local/Cellar/libvorbis/1.3.7/lib/libvorbis.0.dylib @executable_path/libvorbis.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbisfile.3.dylib
install_name_tool -change /usr/local/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbisfile.3.dylib

install_name_tool -change /usr/local/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbis.0.dylib

install_name_tool -change /usr/local/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libFLAC.8.dylib

#modify arm64
install_name_tool -change /opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib @executable_path/libSDL2-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}
install_name_tool -change /opt/homebrew/opt/jpeg/lib/libjpeg.9.dylib @executable_path/libjpeg.9.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}
install_name_tool -change /opt/homebrew/opt/sdl2_mixer/lib/libSDL2_mixer-2.0.0.dylib @executable_path/libSDL2_mixer-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/${EXECUTABLE_NAME}

install_name_tool -change /opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib @executable_path/libSDL2-2.0.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /opt/homebrew/opt/libmodplug/lib/libmodplug.1.dylib @executable_path/libmodplug.1.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /opt/homebrew/opt/libvorbis/lib/libvorbisfile.3.dylib @executable_path/libvorbisfile.3.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /opt/homebrew/opt/libvorbis/lib/libvorbis.0.dylib @executable_path/libvorbis.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /opt/homebrew/opt/flac/lib/libFLAC.8.dylib @executable_path/libFLAC.8.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib
install_name_tool -change /opt/homebrew/opt/mpg123/lib/libmpg123.0.dylib @executable_path/libmpg123.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libSDL2_mixer-2.0.0.dylib

install_name_tool -change /opt/homebrew/Cellar/libvorbis/1.3.7/lib/libvorbis.0.dylib @executable_path/libvorbis.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbisfile.3.dylib
install_name_tool -change /opt/homebrew/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbisfile.3.dylib

install_name_tool -change /opt/homebrew/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libvorbis.0.dylib

install_name_tool -change /opt/homebrew/opt/libogg/lib/libogg.0.dylib @executable_path/libogg.0.dylib ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/libFLAC.8.dylib

echo "bundle done."

#sign and notarize
"../MSPScripts/sign_and_notarize.sh" "$1"