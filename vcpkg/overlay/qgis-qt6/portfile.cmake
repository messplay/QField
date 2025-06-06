set(QGIS_REF final-3_32_2)
set(QGIS_SHA512 689d6b17166fe5c91f91c801b93f384e9539f56708cf90aa8dda93bc3b69005ccc279e1a82b4a850116c34851989afe71f17acdbe468dbc0814c7e3003538180)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO qgis/QGIS
    REF ${QGIS_REF}
    SHA512   ${QGIS_SHA512}
    HEAD_REF master
    PATCHES
        # Make qgis support python's debug library
        qgspython.patch
        gdal.patch
        keychain.patch
        libxml2.patch
        exiv2.patch
        crssync.patch
        bigobj.patch
        poly2tri.patch
        mesh.patch
        project_load.patch
        vectortilelabels.patch # Remove when updating to QGIS 3.34
        version.patch # Remove when updating to QGIS 3.34
        snapping_properties.patch # Remove when updating to QGIS 3.34
        exiv2-0.28.patch # Remove when updating to QGIS 3.34
        profiler.patch # Remove when updating to QGIS 3.34
        exif_orientation_fix.patch # Remove when updating to QGIS 3.34.1
        layout_fix.patch # Remove when updating to QGIS 3.34
)

file(REMOVE ${SOURCE_PATH}/cmake/FindQtKeychain.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindGDAL.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindGEOS.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindEXIV2.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindExpat.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindIconv.cmake)
file(REMOVE ${SOURCE_PATH}/cmake/FindPoly2Tri.cmake)

vcpkg_find_acquire_program(FLEX)
vcpkg_find_acquire_program(BISON)

list(APPEND QGIS_OPTIONS "-DENABLE_TESTS:BOOL=OFF")
list(APPEND QGIS_OPTIONS "-DWITH_QTWEBKIT:BOOL=OFF")
list(APPEND QGIS_OPTIONS "-DWITH_GRASS7:BOOL=OFF")
list(APPEND QGIS_OPTIONS "-DWITH_SPATIALITE:BOOL=ON")
list(APPEND QGIS_OPTIONS "-DWITH_QSPATIALITE:BOOL=OFF")
list(APPEND QGIS_OPTIONS "-DWITH_PDAL:BOOL=OFF")

list(APPEND QGIS_OPTIONS "-DBISON_EXECUTABLE=${BISON}")
list(APPEND QGIS_OPTIONS "-DFLEX_EXECUTABLE=${FLEX}")
# By default QGIS installs includes into "include" on Windows and into "include/qgis" everywhere else
# let's keep things clean and tidy and put them at a predictable location
list(APPEND QGIS_OPTIONS "-DQGIS_INCLUDE_SUBDIR=include/qgis")
list(APPEND QGIS_OPTIONS "-DBUILD_WITH_QT6=ON")
list(APPEND QGIS_OPTIONS "-DQGIS_MACAPP_FRAMEWORK=FALSE")

if("opencl" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DUSE_OPENCL:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DUSE_OPENCL:BOOL=OFF)
endif()

if("bindings" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_BINDINGS:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_BINDINGS:BOOL=OFF)
endif()

if("gui" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_GUI:BOOL=ON)
else()
    if("desktop" IN_LIST FEATURES OR "customwidgets" IN_LIST FEATURES)
        message(FATAL_ERROR "If QGIS is built without gui, desktop and customwidgets cannot be built. Enable gui or disable customwidgets and desktop.")
    endif()
    list(APPEND QGIS_OPTIONS -DWITH_GUI:BOOL=OFF)
endif()

if("desktop" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_DESKTOP:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_DESKTOP:BOOL=OFF)
endif()

if("customwidgets" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_CUSTOM_WIDGETS:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_CUSTOM_WIDGETS:BOOL=OFF)
endif()

if("server" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_SERVER:BOOL=ON)
    if("bindings" IN_LIST FEATURES)
        list(APPEND QGIS_OPTIONS -DWITH_SERVER_PLUGINS:BOOL=ON)
    else()
        list(APPEND QGIS_OPTIONS -DWITH_SERVER_PLUGINS:BOOL=OFF)
    endif()
else()
    list(APPEND QGIS_OPTIONS -DWITH_SERVER:BOOL=OFF)
endif()

if("process" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_QGIS_PROCESS:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_QGIS_PROCESS:BOOL=OFF)
endif()

if("3d" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_3D:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_3D:BOOL=OFF)
endif()

if("quick" IN_LIST FEATURES)
    list(APPEND QGIS_OPTIONS -DWITH_QUICK:BOOL=ON)
else()
    list(APPEND QGIS_OPTIONS -DWITH_QUICK:BOOL=OFF)
endif()

# Configure debug and release library paths
macro(FIND_LIB_OPTIONS basename relname debname suffix libsuffix)
   file(TO_NATIVE_PATH "${CURRENT_INSTALLED_DIR}/lib/${VCPKG_TARGET_IMPORT_LIBRARY_PREFIX}${relname}${libsuffix}" ${basename}_LIBRARY_RELEASE)
   file(TO_NATIVE_PATH "${CURRENT_INSTALLED_DIR}/debug/lib/${VCPKG_TARGET_IMPORT_LIBRARY_PREFIX}${debname}${libsuffix}" ${basename}_LIBRARY_DEBUG)
   if( ${basename}_LIBRARY_DEBUG AND ${basename}_LIBRARY_RELEASE AND NOT ${basename}_LIBRARY_DEBUG STREQUAL ${basename}_LIBRARY_RELEASE )
        list(APPEND QGIS_OPTIONS_RELEASE -D${basename}_${suffix}:FILEPATH=${${basename}_LIBRARY_RELEASE})
        list(APPEND QGIS_OPTIONS_DEBUG -D${basename}_${suffix}:FILEPATH=${${basename}_LIBRARY_DEBUG})
   elseif( ${basename}_LIBRARY_RELEASE )
        list(APPEND QGIS_OPTIONS -D${basename}_${suffix}:FILEPATH=${${basename}_LIBRARY_RELEASE})
   elseif( ${basename}_LIBRARY_DEBUG )
        list(APPEND QGIS_OPTIONS -D${basename}_${suffix}:FILEPATH=${${basename}_LIBRARY_DEBUG})
   endif()
endmacro()

if (VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  list(APPEND QGIS_OPTIONS -DFORCE_STATIC_LIBS=TRUE)
  # QGIS likes to install auth and providers to different locations on each platform
  # let's keep things clean and tidy and put them at a predictable location
  list(APPEND QGIS_OPTIONS -DQGIS_PLUGIN_SUBDIR=lib)
endif()

if(VCPKG_CROSSCOMPILING)
   list(APPEND QGIS_OPTIONS -DQT_HOST_PATH=${CURRENT_HOST_INSTALLED_DIR})
   list(APPEND QGIS_OPTIONS -DQT_HOST_PATH_CMAKE_DIR:PATH=${CURRENT_HOST_INSTALLED_DIR}/share)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    FIND_LIB_OPTIONS(GDAL gdal gdald LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(GEOS geos_c geos_cd LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(GSL gsl gsld LIB ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(GSLCBLAS gslcblas gslcblasd LIB ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(POSTGRES libpq libpq LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(PROJ proj proj_d LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    FIND_LIB_OPTIONS(QCA qca qcad LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    if (VCPKG_LIBRARY_LINKAGE STREQUAL "static")
      FIND_LIB_OPTIONS(ZSTD zstd_static zstd_staticd LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    endif()
    if("server" IN_LIST FEATURES)
        FIND_LIB_OPTIONS(FCGI libfcgi libfcgi LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
        list(APPEND QGIS_OPTIONS -DFCGI_INCLUDE_DIR="${CURRENT_INSTALLED_DIR}/include/fastcgi")
    endif()
    if("gui" IN_LIST FEATURES)
        FIND_LIB_OPTIONS(QWT qwt qwtd LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    endif()

    set(SPATIALINDEX_LIB_NAME spatialindex)
    if( VCPKG_TARGET_ARCHITECTURE STREQUAL "x64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" )
        set( SPATIALINDEX_LIB_NAME "spatialindex-64" )
    else()
        set( SPATIALINDEX_LIB_NAME "spatialindex-32" )
    endif()
    FIND_LIB_OPTIONS(SPATIALINDEX ${SPATIALINDEX_LIB_NAME} ${SPATIALINDEX_LIB_NAME}d LIBRARY ${VCPKG_TARGET_IMPORT_LIBRARY_SUFFIX})
    list(APPEND QGIS_OPTIONS -DWITH_INTERNAL_POLY2TRI=OFF)
    list(APPEND QGIS_OPTIONS -DPoly2Tri_LIBRARY=poly2tri::poly2tri)
else() # Build in UNIX
    list(APPEND QGIS_OPTIONS -DGSL_CONFIG=" ")
    list(APPEND QGIS_OPTIONS -DGSL_INCLUDE_DIR:PATH=${CURRENT_INSTALLED_DIR}/include)
    list(APPEND QGIS_OPTIONS -DPROJ_INCLUDE_DIR:PATH=${CURRENT_INSTALLED_DIR}/include)
    list(APPEND QGIS_OPTIONS_DEBUG -DGSL_LIBRARIES:FILEPATH=${CURRENT_INSTALLED_DIR}/debug/lib/${VCPKG_TARGET_STATIC_LIBRARY_PREFIX}gsld${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX};${CURRENT_INSTALLED_DIR}/debug/lib/${VCPKG_TARGET_STATIC_LIBRARY_PREFIX}gslcblasd${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})
    list(APPEND QGIS_OPTIONS -DPROJ_INCLUDE_DIR:PATH=${CURRENT_INSTALLED_DIR}/include)
    list(APPEND QGIS_OPTIONS_RELEASE -DQCA_LIBRARY=${CURRENT_INSTALLED_DIR}/lib/libqca.a)
    list(APPEND QGIS_OPTIONS_DEBUG -DQCA_LIBRARY=${CURRENT_INSTALLED_DIR}/debug/lib/libqca.a)
    list(APPEND QGIS_OPTIONS_RELEASE -DGSL_LIBRARIES:FILEPATH=${CURRENT_INSTALLED_DIR}/lib/${VCPKG_TARGET_STATIC_LIBRARY_PREFIX}gsl${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX} ${CURRENT_INSTALLED_DIR}/lib/${VCPKG_TARGET_STATIC_LIBRARY_PREFIX}gslcblas${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX})
    if("server" IN_LIST FEATURES)
        FIND_LIB_OPTIONS(FCGI fcgi fcgi LIBRARY ${VCPKG_TARGET_SHARED_LIBRARY_SUFFIX})
        list(APPEND QGIS_OPTIONS -DFCGI_INCLUDE_DIR="${CURRENT_INSTALLED_DIR}/include/fastcgi")
    endif()
    list(APPEND QGIS_OPTIONS -DWITH_INTERNAL_POLY2TRI=OFF)
    if(EXISTS "${CURRENT_INSTALLED_DIR}/lib/libqt_poly2tri.a")
        set(QT_POLY2TRI_DIR_RELEASE "${CURRENT_INSTALLED_DIR}/lib")
        set(QT_POLY2TRI_DIR_DEBUG "${CURRENT_INSTALLED_DIR}/debug/lib")
    elseif(EXISTS "${Qt6_DIR}/../../libqt_poly2tri.a")
        set(QT_POLY2TRI_DIR_RELEASE "${Qt6_DIR}/../..")
        set(QT_POLY2TRI_DIR_DEBUG "${Qt6_DIR}/../..")
    else()
        list(APPEND QGIS_OPTIONS -DPoly2Tri_LIBRARY=poly2tri::poly2tri)
    endif()
    if(DEFINED QT_POLY2TRI_DIR_RELEASE)
        list(APPEND QGIS_OPTIONS -DPoly2Tri_INCLUDE_DIR:PATH=${CMAKE_CURRENT_LIST_DIR}/poly2tri)
        list(APPEND QGIS_OPTIONS_DEBUG -DPoly2Tri_LIBRARY:PATH=${QT_POLY2TRI_DIR_DEBUG}/debug/lib/libqt_poly2tri_debug.a) # static qt only
        list(APPEND QGIS_OPTIONS_RELEASE -DPoly2Tri_LIBRARY:PATH=${QT_POLY2TRI_DIR_RELEASE}/lib/libqt_poly2tri.a) # static qt only
    endif()
endif()

if(VCPKG_TARGET_IS_IOS)
    list(APPEND QGIS_OPTIONS -DWITH_QTSERIALPORT=FALSE)
endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    #PREFER_NINJA
    OPTIONS ${QGIS_OPTIONS} 
    OPTIONS_DEBUG ${QGIS_OPTIONS_DEBUG}
    OPTIONS_RELEASE ${QGIS_OPTIONS_RELEASE}
)

vcpkg_install_cmake()

if(VCPKG_TARGET_IS_WINDOWS)
    function(copy_path basepath targetdir)
        file(GLOB ${basepath}_PATH ${CURRENT_PACKAGES_DIR}/${basepath}/*)
        if( ${basepath}_PATH )
            file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/${targetdir}/qgis/${basepath})
            file(COPY ${${basepath}_PATH} DESTINATION ${CURRENT_PACKAGES_DIR}/${targetdir}/qgis/${basepath})
        endif()
 
        if(EXISTS "${CURRENT_PACKAGES_DIR}/${basepath}/")
            file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/${basepath}/)
        endif()
    endfunction()

    file(GLOB QGIS_TOOL_PATH ${CURRENT_PACKAGES_DIR}/bin/*${VCPKG_TARGET_EXECUTABLE_SUFFIX} ${CURRENT_PACKAGES_DIR}/*${VCPKG_TARGET_EXECUTABLE_SUFFIX})
    if(QGIS_TOOL_PATH)
        file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools/qgis/bin)
        file(COPY ${QGIS_TOOL_PATH} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/qgis/bin)
        file(REMOVE_RECURSE ${QGIS_TOOL_PATH})
        file(GLOB QGIS_TOOL_PATH ${CURRENT_PACKAGES_DIR}/bin/* )
        file(COPY ${QGIS_TOOL_PATH} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/qgis/bin)
    endif()
    
    file(GLOB QGIS_TOOL_PATH_DEBUG ${CURRENT_PACKAGES_DIR}/debug/bin/*${VCPKG_TARGET_EXECUTABLE_SUFFIX} ${CURRENT_PACKAGES_DIR}/debug/*${VCPKG_TARGET_EXECUTABLE_SUFFIX})
    if(QGIS_TOOL_PATH_DEBUG)
        if("debug-tools" IN_LIST FEATURES)
            file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/debug/tools/qgis/bin)
            file(COPY ${QGIS_TOOL_PATH_DEBUG} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/tools/qgis/bin)
            file(REMOVE_RECURSE ${QGIS_TOOL_PATH_DEBUG})
            file(GLOB QGIS_TOOL_PATH_DEBUG ${CURRENT_PACKAGES_DIR}/debug/bin/* )
            file(COPY ${QGIS_TOOL_PATH_DEBUG} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/tools/qgis/bin)
        else()
            file(REMOVE_RECURSE ${QGIS_TOOL_PATH_DEBUG})
        endif()
    endif()

    copy_path(doc share)
    copy_path(i18n share)
    copy_path(icons share)
    copy_path(images share)
    copy_path(plugins tools)
    copy_path(resources share)
    copy_path(svg share)
endif()

file(GLOB QGIS_CMAKE_PATH ${CURRENT_PACKAGES_DIR}/*.cmake)
if(QGIS_CMAKE_PATH)
    file(COPY ${QGIS_CMAKE_PATH} DESTINATION ${CURRENT_PACKAGES_DIR}/share/cmake/qgis)
    file(REMOVE_RECURSE ${QGIS_CMAKE_PATH})
endif()

file(GLOB QGIS_CMAKE_PATH_DEBUG ${CURRENT_PACKAGES_DIR}/debug/*.cmake)
if( QGIS_CMAKE_PATH_DEBUG )
    file(REMOVE_RECURSE ${QGIS_CMAKE_PATH_DEBUG})
endif()

file(REMOVE_RECURSE
    ${CURRENT_PACKAGES_DIR}/debug/include
)
file(REMOVE_RECURSE # Added for debug porpose
    ${CURRENT_PACKAGES_DIR}/debug/share
)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/qgis RENAME copyright)
