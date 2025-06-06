set(QFIELD_CORE_SRCS
    platforms/platformutilities.cpp
    utils/coordinatereferencesystemutils.cpp
    utils/expressioncontextutils.cpp
    utils/featureutils.cpp
    utils/fileutils.cpp
    utils/geometryutils.cpp
    utils/layerutils.cpp
    utils/positioningutils.cpp
    utils/qfieldcloudutils.cpp
    utils/relationutils.cpp
    utils/snappingutils.cpp
    utils/stringutils.cpp
    utils/urlutils.cpp
    utils/ziputils.cpp
    qgsquick/qgsquickcoordinatetransformer.cpp
    qgsquick/qgsquickmapcanvasmap.cpp
    qgsquick/qgsquickelevationprofilecanvas.cpp
    qgsquick/qgsquickmapsettings.cpp
    qgsquick/qgsquickmaptransform.cpp
    locator/activelayerfeatureslocatorfilter.cpp
    locator/bookmarklocatorfilter.cpp
    locator/expressioncalculatorlocatorfilter.cpp
    locator/featureslocatorfilter.cpp
    locator/finlandlocatorfilter.cpp
    locator/gotolocatorfilter.cpp
    locator/locatormodelsuperbridge.cpp
    positioning/gnsspositioninformation.cpp
    positioning/internalgnssreceiver.cpp
    positioning/nmeagnssreceiver.cpp
    positioning/tcpreceiver.cpp
    positioning/udpreceiver.cpp
    positioning/positioning.cpp
    positioning/positioningdevicemodel.cpp
    appcoordinateoperationhandlers.cpp
    appinterface.cpp
    attributeformmodel.cpp
    attributeformmodelbase.cpp
    audiorecorder.cpp
    barcodedecoder.cpp
    badlayerhandler.cpp
    bookmarkmodel.cpp
    changelogcontents.cpp
    deltafilewrapper.cpp
    deltalistmodel.cpp
    digitizinglogger.cpp
    distancearea.cpp
    expressionevaluator.cpp
    expressionvariablemodel.cpp
    featurechecklistmodel.cpp
    featurelistextentcontroller.cpp
    featurelistmodel.cpp
    featurelistmodelselection.cpp
    featuremodel.cpp
    focusstack.cpp
    geometry.cpp
    geometryeditorsmodel.cpp
    identifytool.cpp
    layerobserver.cpp
    layerresolver.cpp
    layertreemapcanvasbridge.cpp
    layertreemodel.cpp
    legendimageprovider.cpp
    linepolygonhighlight.cpp
    localfilesimageprovider.cpp
    localfilesmodel.cpp
    maptoscreen.cpp
    messagelogmodel.cpp
    modelhelper.cpp
    multifeaturelistmodel.cpp
    multifeaturelistmodelbase.cpp
    navigation.cpp
    navigationmodel.cpp
    nearfieldreader.cpp
    networkmanager.cpp
    networkreply.cpp
    orderedrelationmodel.cpp
    peliasgeocoder.cpp
    resourcesource.cpp
    printlayoutlistmodel.cpp
    projectinfo.cpp
    projectsource.cpp
    projectsimageprovider.cpp
    qfieldappauthrequesthandler.cpp
    qfieldcloudconnection.cpp
    qfieldcloudprojectsmodel.cpp
    qgismobileapp.cpp
    qgsgeometrywrapper.cpp
    qgsgpkgflusher.cpp
    qgssggeometry.cpp
    recentprojectlistmodel.cpp
    referencingfeaturelistmodel.cpp
    rubberband.cpp
    rubberbandmodel.cpp
    scalebarmeasurement.cpp
    screendimmer.cpp
    sensorlistmodel.cpp
    settings.cpp
    sgrubberband.cpp
    snappingresult.cpp
    submodel.cpp
    tracker.cpp
    trackingmodel.cpp
    valuemapmodel.cpp
    vertexmodel.cpp
    viewstatus.cpp)

set(QFIELD_CORE_HDRS
    platforms/platformutilities.h
    utils/coordinatereferencesystemutils.h
    utils/expressioncontextutils.h
    utils/featureutils.h
    utils/fileutils.h
    utils/geometryutils.h
    utils/layerutils.h
    utils/positioningutils.h
    utils/qfieldcloudutils.h
    utils/relationutils.h
    utils/snappingutils.h
    utils/stringutils.h
    utils/urlutils.h
    utils/ziputils.h
    qgsquick/qgsquickcoordinatetransformer.h
    qgsquick/qgsquickmapcanvasmap.h
    qgsquick/qgsquickelevationprofilecanvas.h
    qgsquick/qgsquickmapsettings.h
    qgsquick/qgsquickmaptransform.h
    locator/activelayerfeatureslocatorfilter.h
    locator/bookmarklocatorfilter.h
    locator/expressioncalculatorlocatorfilter.h
    locator/featureslocatorfilter.h
    locator/finlandlocatorfilter.h
    locator/gotolocatorfilter.h
    locator/locatormodelsuperbridge.h
    positioning/abstractgnssreceiver.h
    positioning/gnsspositioninformation.h
    positioning/positioning.h
    positioning/positioningdevicemodel.h
    positioning/internalgnssreceiver.h
    positioning/nmeagnssreceiver.h
    positioning/tcpreceiver.h
    positioning/udpreceiver.h
    appcoordinateoperationhandlers.h
    appinterface.h
    attributeformmodel.h
    attributeformmodelbase.h
    audiorecorder.h
    barcodedecoder.h
    badlayerhandler.h
    bookmarkmodel.h
    changelogcontents.h
    deltafilewrapper.h
    deltalistmodel.h
    digitizinglogger.h
    distancearea.h
    expressionevaluator.h
    expressionvariablemodel.h
    featurechecklistmodel.h
    featurelistextentcontroller.h
    featurelistmodel.h
    featurelistmodelselection.h
    featuremodel.h
    fieldexpressionvaluesgatherer.h
    focusstack.h
    geometry.h
    geometryeditorsmodel.h
    identifytool.h
    layerobserver.h
    layerresolver.h
    layertreemapcanvasbridge.h
    layertreemodel.h
    legendimageprovider.h
    linepolygonhighlight.h
    localfilesimageprovider.h
    localfilesmodel.h
    maptoscreen.h
    messagelogmodel.h
    modelhelper.h
    multifeaturelistmodel.h
    multifeaturelistmodelbase.h
    navigation.h
    navigationmodel.h
    nearfieldreader.h
    networkmanager.h
    networkreply.h
    orderedrelationmodel.h
    peliasgeocoder.h
    resourcesource.h
    printlayoutlistmodel.h
    projectinfo.h
    projectsource.h
    projectsimageprovider.h
    qfieldappauthrequesthandler.h
    qfieldcloudconnection.h
    qfieldcloudprojectsmodel.h
    qgismobileapp.h
    qgsgeometrywrapper.h
    qgsgpkgflusher.h
    qgssggeometry.h
    recentprojectlistmodel.h
    referencingfeaturelistmodel.h
    rubberband.h
    rubberbandmodel.h
    scalebarmeasurement.h
    screendimmer.h
    sensorlistmodel.h
    settings.h
    sgrubberband.h
    snappingresult.h
    submodel.h
    tracker.h
    trackingmodel.h
    valuemapmodel.h
    vertexmodel.h
    viewstatus.h
    ${CMAKE_CURRENT_BINARY_DIR}/qfield.h)

if(NOT BUILD_WITH_QT6)
  list(APPEND QFIELD_CORE_SRCS barcodevideofilter.cpp)
  list(APPEND QFIELD_CORE_HDRS barcodevideofilter.h)
endif()

if(WITH_BLUETOOTH)
  list(APPEND QFIELD_CORE_SRCS positioning/bluetoothdevicemodel.cpp
       positioning/bluetoothreceiver.cpp
       positioning/vendorcommandhelper.cpp)
  list(APPEND QFIELD_CORE_HDRS positioning/bluetoothdevicemodel.h
       positioning/bluetoothreceiver.h
       positioning/vendorcommandhelper.h)
endif()

if(WITH_SERIALPORT)
  list(APPEND QFIELD_CORE_SRCS positioning/serialportmodel.cpp
       positioning/serialportreceiver.cpp)
  list(APPEND QFIELD_CORE_HDRS positioning/serialportmodel.h
       positioning/serialportreceiver.h)
endif()

if(ANDROID)
  set(QFIELD_CORE_HDRS
      ${QFIELD_CORE_HDRS}
      platforms/android/androidplatformutilities.h
      platforms/android/androidresourcesource.h
      platforms/android/androidviewstatus.h
      platforms/android/androidprojectsource.h
      ${CMAKE_CURRENT_BINARY_DIR}/qfield_android.h)
  set(QFIELD_CORE_SRCS
      ${QFIELD_CORE_SRCS}
      platforms/android/androidplatformutilities.cpp
      platforms/android/androidresourcesource.cpp
      platforms/android/androidviewstatus.cpp
      platforms/android/androidprojectsource.cpp)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  set(QFIELD_CORE_HDRS
      ${QFIELD_CORE_HDRS} platforms/ios/iosplatformutilities.h
      platforms/ios/iosresourcesource.h platforms/ios/iosprojectsource.h)
  set(QFIELD_CORE_SRCS
      ${QFIELD_CORE_SRCS} platforms/ios/iosplatformutilities.mm
      platforms/ios/iosresourcesource.mm platforms/ios/iosprojectsource.mm)
endif()

find_package(SQLite3 REQUIRED)
find_package(ZXing REQUIRED)

add_library(qfield_core STATIC ${QFIELD_CORE_SRCS} ${QFIELD_CORE_HDRS})

string(SUBSTRING ${ZXing_VERSION} 0 1 ZXing_VERSION_MAJOR)
target_compile_definitions(qfield_core
                           PRIVATE ZXing_VERSION_MAJOR=${ZXing_VERSION_MAJOR})

if(WITH_BLUETOOTH)
  target_compile_definitions(qfield_core PRIVATE WITH_BLUETOOTH)
endif()
if(WITH_SERIALPORT)
  target_compile_definitions(qfield_core PRIVATE WITH_SERIALPORT)
endif()
if(WITH_NFC)
  target_compile_definitions(qfield_core PRIVATE WITH_NFC)
endif()

include(GenerateExportHeader)
generate_export_header(qfield_core)

configure_file(qfield.h.in ${CMAKE_CURRENT_BINARY_DIR}/qfield.h @ONLY)

target_include_directories(qfield_core SYSTEM
                           PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

if(BUILD_WITH_QT6)
  target_link_libraries(qfield_core PRIVATE Qt6::CorePrivate)
endif()

# to include <qpa/qplatformnativeinterface.h>
target_include_directories(qfield_core SYSTEM
                           PRIVATE ${${QT_PKG}Gui_PRIVATE_INCLUDE_DIRS})
if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  target_compile_options(qfield_core PRIVATE "-fobjc-arc")
endif()

target_include_directories(
  qfield_core
  PUBLIC ${CMAKE_SOURCE_DIR}/src/core
         ${CMAKE_SOURCE_DIR}/src/core/locator
         ${CMAKE_SOURCE_DIR}/src/core/platforms
         ${CMAKE_SOURCE_DIR}/src/core/qgsquick
         ${CMAKE_SOURCE_DIR}/src/core/utils
         ${CMAKE_SOURCE_DIR}/src/core/positioning)
if(ANDROID)
  string(REPLACE "_" "_1" APP_PACKAGE_JNI_NAME "${APP_PACKAGE_NAME}")
  configure_file(platforms/android/qfield_android.h.in
                 ${CMAKE_CURRENT_BINARY_DIR}/qfield_android.h @ONLY)
  target_include_directories(
    qfield_core PUBLIC ${CMAKE_SOURCE_DIR}/src/core/platforms/android)

  # GLESv3 needed by barcode reader's use of OpenGL functions
  target_link_libraries(qfield_core PUBLIC GLESv3)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  target_include_directories(qfield_core
                             PUBLIC ${CMAKE_SOURCE_DIR}/src/core/platforms/ios)
endif()

target_compile_features(qfield_core PUBLIC cxx_std_17)
set_target_properties(qfield_core PROPERTIES AUTOMOC TRUE)

target_link_libraries(
  qfield_core
  PUBLIC ${QT_PKG}::Core
         ${QT_PKG}::Gui
         ${QT_PKG}::Xml
         ${QT_PKG}::Positioning
         ${QT_PKG}::Widgets
         ${QT_PKG}::Network
         ${QT_PKG}::Quick
         ${QT_PKG}::Svg
         ${QT_PKG}::OpenGL
         ${QT_PKG}::Sensors
         ${QT_PKG}::Sql
         ${QT_PKG}::Concurrent
         ${QT_PKG}::WebView
         ${QT_PKG}::Multimedia
         QGIS::Core
         QGIS::Analysis
         ZXing::ZXing
         PROJ::proj
         GDAL::GDAL
         SQLite::SQLite3
         Qca::qca
         QtKeychain::QtKeychain
         libzip::zip)

if(WITH_BLUETOOTH)
  find_package(
    ${QT_PKG}
    COMPONENTS Bluetooth
    REQUIRED)
  target_link_libraries(qfield_core PUBLIC ${QT_PKG}::Bluetooth)
endif()

if(WITH_SERIALPORT)
  find_package(
    ${QT_PKG}
    COMPONENTS SerialPort
    REQUIRED)
  target_link_libraries(qfield_core PUBLIC ${QT_PKG}::SerialPort)
endif()

if(WITH_NFC)
  find_package(
    ${QT_PKG}
    COMPONENTS Nfc
    REQUIRED)
  target_link_libraries(qfield_core PUBLIC ${QT_PKG}::Nfc)
endif()

if(WITH_SENTRY)
  target_link_libraries(qfield_core PRIVATE qfield_sentry)
endif()

if(ANDROID)
  if(NOT BUILD_WITH_QT6)
    target_link_libraries(qfield_core PUBLIC ${QT_PKG}::AndroidExtras)
  endif()
endif()

if(TARGET ${QT_PKG}::PrintSupport)
  target_link_libraries(qfield_core PUBLIC ${QT_PKG}::PrintSupport)
endif()

install(FILES ${QFIELD_CORE_HDRS} DESTINATION ${QFIELD_INCLUDE_DIR})
install(
  TARGETS qfield_core
  BUNDLE DESTINATION ${QFIELD_BIN_DIR}
  RUNTIME DESTINATION ${QFIELD_BIN_DIR}
  LIBRARY DESTINATION ${QFIELD_LIB_DIR}
  ARCHIVE DESTINATION ${QFIELD_LIB_DIR}
  FRAMEWORK DESTINATION ${QFIELD_FW_SUBDIR}
  PUBLIC_HEADER DESTINATION ${QFIELD_INCLUDE_DIR})
