/***************************************************************************
                            qgismobileapp.qml
                              -------------------
              begin                : 10.12.2014
              copyright            : (C) 2014 by Matthias Kuhn
              email                : matthias (at) opengis.ch
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Controls.Material 2.14
import QtQuick.Window 2.14
import QtQml 2.14
import QtSensors 5.14
import Qt.labs.settings 1.0 as LabSettings

import org.qgis 1.0
import org.qfield 1.0

import Theme 1.0
import QFieldControls 1.0

ApplicationWindow {
  id: mainWindow
  objectName: 'mainWindow'
  visible: true
  flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint |
         (Qt.platform.os === "ios" ? Qt.MaximizeUsingFullscreenGeometryHint : 0) |
         (Qt.platform.os !== "ios" && Qt.platform.os !== "android" ? Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint : 0)

  Material.theme: Theme.darkTheme ? "Dark" : "Light"
  Material.accent: Theme.mainColor

  property double sceneTopMargin: platformUtilities.sceneMargins(mainWindow)["top"]
  property double sceneBottomMargin: platformUtilities.sceneMargins(mainWindow)["bottom"]

  Timer {
    id: refreshSceneMargins
    running: false
    repeat: false
    interval: 50

    readonly property bool screenIsPortrait: (Screen.primaryOrientation === Qt.PortraitOrientation ||
                                              Screen.primaryOrientation === Qt.InvertedPortraitOrientation)
    onScreenIsPortraitChanged:{
      start()
    }

    onTriggered: {
      mainWindow.sceneTopMargin = platformUtilities.sceneMargins(mainWindow)["top"];
      mainWindow.sceneBottomMargin = platformUtilities.sceneMargins(mainWindow)["bottom"];
    }
  }

  LabSettings.Settings {
    property alias x: mainWindow.x
    property alias y: mainWindow.y
    property alias width: mainWindow.width
    property alias height: mainWindow.height

    property int minimumSize: Qt.platform.os !== "ios" && Qt.platform.os !== "android" ? 300 : 50

    Component.onCompleted: {
      if (Qt.platform.os !== "ios" && Qt.platform.os !== "android") {
        width = Math.max(width, minimumSize)
        height = Math.max(height, minimumSize)
        x = Math.min(x, mainWindow.screen.width - width)
        y = Math.min(y, mainWindow.screen.height - height)
      }
    }
  }

  FocusStack{
    id: focusstack
  }

  //this keyHandler is because otherwise the back-key is not handled in the mainWindow. Probably this could be solved cuter.
  Item {
    id: keyHandler
    objectName: "keyHandler"

    visible: true
    focus: true

    property int previousVisibilityState: Window.Windowed

    Keys.onReleased: (event) => {
      if ( event.key === Qt.Key_Back || event.key === Qt.Key_Escape ) {
        if ( featureForm.visible ) {
            featureForm.hide();
        } else if ( stateMachine.state === 'measure' ) {
          mainWindow.closeMeasureTool()
        } else {
          mainWindow.close();
        }
        event.accepted = true
      } else if ( event.key === Qt.Key_F11 ) {
        if (Qt.platform.os !== "android" && Qt.platform.os !== "ios") {
          if (mainWindow.visibility !== Window.FullScreen) {
            previousVisibilityState = mainWindow.visibility;
            mainWindow.visibility = Window.FullScreen;
          } else {
            mainWindow.visibility = Window.Windowed;
            if (previousVisibilityState === Window.Maximized) {
              mainWindow.showMaximized();
            }
          }
        }
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  //currentRubberband provides the rubberband depending on the current state (digitize or measure)
  property Rubberband currentRubberband
  property LayerObserver layerObserverAlias: layerObserver
  property QgsGpkgFlusher gpkgFlusherAlias: gpkgFlusher

  signal closeMeasureTool()
  signal changeMode( string mode )

  Item {
    id: stateMachine

    property string lastState

    states: [
      State {
        name: "browse"
        PropertyChanges { target: identifyTool; deactivated: false }
      },

      State {
        name: "digitize"
        PropertyChanges { target: identifyTool; deactivated: false }
        PropertyChanges { target: mainWindow; currentRubberband: digitizingRubberband }
      },

      State {
        name: 'measure'
        PropertyChanges { target: identifyTool; deactivated: true }
        PropertyChanges { target: mainWindow; currentRubberband: measuringTool.measuringRubberband }
        PropertyChanges { target: featureForm; state: "Hidden" }
      }
    ]
    state: "browse"
  }

  onChangeMode: (mode) => {
    if ( stateMachine.state === mode )
      return

    stateMachine.lastState = stateMachine.state
    stateMachine.state = mode
    switch ( stateMachine.state )
    {
      case 'browse':
        projectInfo.stateMode = mode
        platformUtilities.setHandleVolumeKeys(false)
        displayToast( qsTr( 'You are now in browse mode' ) );
        break;
      case 'digitize':
        projectInfo.stateMode = mode
        platformUtilities.setHandleVolumeKeys(qfieldSettings.digitizingVolumeKeys)
        dashBoard.ensureEditableLayerSelected();
        if (dashBoard.activeLayer)
        {
          displayToast( qsTr( 'You are now in digitize mode on layer %1' ).arg( dashBoard.activeLayer.name ) );
        }
        else
        {
          displayToast( qsTr( 'You are now in digitize mode' ) );
        }
        break;
      case 'measure':
        platformUtilities.setHandleVolumeKeys(qfieldSettings.digitizingVolumeKeys)
        elevationProfile.populateLayersFromProject();
        displayToast( qsTr( 'You are now in measure mode' ) );
        break;
    }
  }

  onCloseMeasureTool: {
    overlayFeatureFormDrawer.close()
    changeMode( stateMachine.lastState)
  }

  /**
   * The position source to access GNSS devices
   */
  Positioning {
    id: positionSource
    deviceId: positioningSettings.positioningDevice

    property bool currentness: false;
    property alias destinationCrs: positionSource.coordinateTransformer.destinationCrs
    property real bearingTrueNorth: 0.0

    coordinateTransformer: CoordinateTransformer {
      destinationCrs: mapCanvas.mapSettings.destinationCrs
      transformContext: qgisProject ? qgisProject.transformContext : CoordinateReferenceSystemUtils.emptyTransformContext()
      deltaZ: 0
      skipAltitudeTransformation: positioningSettings.skipAltitudeCorrection
      verticalGrid: positioningSettings.verticalGrid
    }

    elevationCorrectionMode: positioningSettings.elevationCorrectionMode
    antennaHeight: positioningSettings.antennaHeightActivated ? positioningSettings.antennaHeight : 0
    logging: positioningSettings.logging

    onProjectedPositionChanged: {
      if (active) {
        bearingTrueNorth = PositioningUtils.bearingTrueNorth(positionSource.projectedPosition, mapCanvas.mapSettings.destinationCrs)
        if (gnssButton.followActive) {
          gnssButton.followLocation(false);
        }
      }
    }

    onOrientationChanged: {
      if (active && gnssButton.followOrientationActive) {
        gnssButton.followOrientation();
      }
    }
  }

  Connections {
    target: positionSource.device

    function onLastErrorChanged() {
        displayToast(qsTr('Positioning device error: %1').arg(positionSource.device.lastError), 'error')
    }
  }

  Timer {
    id: positionTimer

    property bool geocoderLocatorFiltersChecked: false;

    interval: 2500
    repeat: true
    running: positionSource.active
    triggeredOnStart: true
    onTriggered: {
      if ( positionSource.positionInformation ) {
        positionSource.currentness = ((Date.now() - positionSource.positionInformation.utcDateTime.getTime()) / 1000) < 30;
        if (!geocoderLocatorFiltersChecked && positionSource.valid) {
          locatorItem.locatorFiltersModel.setGeocoderLocatorFiltersDefaulByPosition(positionSource.positionInformation);
          geocoderLocatorFiltersChecked = true;
        }
      }
    }
  }

  Item {
    id: mapCanvas
    clip: true

    DragHandler {
        id: freehandHandler
        property bool isDigitizing: false
        enabled: freehandButton.visible && freehandButton.freehandDigitizing && !digitizingToolbar.rubberbandModel.frozen && (!featureForm.visible || digitizingToolbar.geometryRequested)
        acceptedDevices: !qfieldSettings.mouseAsTouchScreen ? PointerDevice.Stylus | PointerDevice.Mouse : PointerDevice.Stylus
        grabPermissions: PointerHandler.CanTakeOverFromHandlersOfSameType | PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything

        onActiveChanged: {
            if (active) {
                geometryEditorsToolbar.canvasFreehandBegin();
            } else {
                geometryEditorsToolbar.canvasFreehandEnd();
                var screenLocation = centroid.position;
                var screenFraction = settings.value( "/QField/Digitizing/FreehandRecenterScreenFraction", 5 );
                var threshold = Math.min( mainWindow.width, mainWindow.height ) / screenFraction;
                if ( screenLocation.x < threshold || screenLocation.x > mainWindow.width - threshold ||
                        screenLocation.y < threshold || screenLocation.y > mainWindow.height - threshold )
                {
                    mapCanvas.mapSettings.setCenter(mapCanvas.mapSettings.screenToCoordinate(screenLocation));
                }
            }
        }

        onCentroidChanged: {
            if (active) {
                if (centroid.position !== Qt.point(0, 0)) {
                    coordinateLocator.sourceLocation = centroid.position
                    if (!geometryEditorsToolbar.canvasClicked(centroid.position)) {
                        digitizingToolbar.addVertex();
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: !qfieldSettings.mouseAsTouchScreen
                 && !(positionSource.active && positioningSettings.positioningCoordinateLock)
                 && (!digitizingToolbar.rubberbandModel || !digitizingToolbar.rubberbandModel.frozen)
        acceptedDevices: PointerDevice.Stylus | PointerDevice.Mouse
        grabPermissions: PointerHandler.TakeOverForbidden

        property bool hasBeenHovered: false
        property bool skipHover: false

        function pointInItem(point, item) {
            var itemCoordinates = item.mapToItem(mainWindow.contentItem, 0, 0);
            return point.position.x >= itemCoordinates.x && point.position.x <= itemCoordinates.x + item.width &&
                   point.position.y >= itemCoordinates.y && point.position.y <= itemCoordinates.y + item.height;
        }

        onPointChanged: {
            if (skipHover) {
              return
            }

            // when hovering various toolbars, reset coordinate locator position for nicer UX
            if ( !freehandHandler.active && ( pointInItem( point, digitizingToolbar ) || pointInItem( point, elevationProfileButton ) ) ) {
                coordinateLocator.sourceLocation = mapCanvas.mapSettings.coordinateToScreen( digitizingToolbar.rubberbandModel.lastCoordinate )
            } else if ( !freehandHandler.active && pointInItem( point, geometryEditorsToolbar ) ) {
                coordinateLocator.sourceLocation = mapCanvas.mapSettings.coordinateToScreen( geometryEditorsToolbar.editorRubberbandModel.lastCoordinate )
            } else if ( !freehandHandler.active ) {
                // after a click, it seems that the position is sent once at 0,0 => weird)
                if (point.position !== Qt.point(0, 0))
                    coordinateLocator.sourceLocation = point.position
            }
        }

        onActiveChanged: {
            if ( !active ) {
                coordinateLocator.sourceLocation = undefined
            }
        }

        onHoveredChanged: {
            if (skipHover) {
              skipHover = hovered
              return
            }

            mapCanvasMap.hovered = hovered
            if ( hovered ) {
                hasBeenHovered = true;
            } else {
                coordinateLocator.sourceLocation = undefined
            }
        }
    }

    /* The second hover handler is a workaround what appears to be an issue with
     * Qt whereas synthesized mouse event would trigger the first HoverHandler even though
     * PointerDevice.TouchScreen was explicitly taken out of the accepted devices.
     */
    HoverHandler {
        id: dummyHoverHandler
        enabled: !qfieldSettings.mouseAsTouchScreen
                 && !(positionSource.active && positioningSettings.positioningCoordinateLock)
        acceptedDevices: PointerDevice.TouchScreen
        grabPermissions: PointerHandler.TakeOverForbidden

        onHoveredChanged: {
            if ( hovered ) {
                hoverHandler.skipHover = true
            }
        }
    }

    /* Initialize a MapSettings object. This will contain information about
     * the current canvas extent. It is shared between the base map and all
     * map canvas items and is used to transform map coordinates to pixel
     * coordinates.
     * It may change any time and items that hold a reference to this property
     * are responsible to handle this properly.
     */
    property MapSettings mapSettings: mapCanvasMap.mapSettings

    /* Placement and size. Share right anchor with featureForm */
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: informationView.visible ? informationView.top : parent.bottom

    Rectangle {
      id: mapCanvasBackground
      anchors.fill: parent
      color: mapCanvas.mapSettings.backgroundColor
    }

    /* The map canvas */
    MapCanvas {
      id: mapCanvasMap
      property bool isEnabled: !dashBoard.opened && !welcomeScreen.visible && !qfieldSettings.visible && !cloudPopup.visible && !codeReader.visible
      interactive: isEnabled && !screenLocker.enabled
      incrementalRendering: true
      quality: qfieldSettings.quality
      forceDeferredLayersRepaint: trackings.count > 0
      freehandDigitizing: freehandButton.freehandDigitizing && freehandHandler.active

      anchors.fill: parent

      function pointInItem(point, item) {
          var itemCoordinates = item.mapToItem(mainWindow.contentItem, 0, 0);
          return point.x >= itemCoordinates.x && point.x <= itemCoordinates.x + item.width &&
                 point.y >= itemCoordinates.y && point.y <= itemCoordinates.y + item.height;
      }

      onClicked: (point, type) => {
          if (type === "stylus" &&
              ( overlayFeatureFormDrawer.opened || ( featureForm.visible && pointInItem( point, featureForm ) ) ) ) {
              return;
          }

          if (!digitizingToolbar.geometryRequested && featureForm.state == "FeatureFormEdit") {
              featureForm.requestCancel();
              return;
          }

          if (locatorItem.state == "on") {
              locatorItem.state = "off"
              return;
          }

          if ( type === "stylus" ) {
              if ( pointInItem( point, digitizingToolbar ) ||
                   pointInItem( point, zoomToolbar ) ||
                   pointInItem( point, mainToolbar ) ||
                   pointInItem( point, mainMenuBar ) ||
                   pointInItem( point, geometryEditorsToolbar ) ||
                   pointInItem( point, locationToolbar ) ||
                   pointInItem( point, locatorItem ) ) {
                  return;
              }

              // Check if geometry editor is taking over
              if ( !(positionSource.active && positioningSettings.positioningCoordinateLock) && geometryEditorsToolbar.canvasClicked(point) )
                  return;

              if ( !(positionSource.active && positioningSettings.positioningCoordinateLock) && (!featureForm.visible || digitizingToolbar.geometryRequested ) &&
                   ( ( stateMachine.state === "digitize" && digitizingFeature.currentLayer ) || stateMachine.state === 'measure' ) ) {
                  if ( Number( currentRubberband.model.geometryType ) === Qgis.GeometryType.Point ||
                          Number( currentRubberband.model.geometryType ) === Qgis.GeometryType.Null ) {
                      digitizingToolbar.confirm()
                  } else {
                      digitizingToolbar.addVertex()
                  }
              } else {
                  if (!overlayFeatureFormDrawer.visible || !featureForm.canvasOperationRequested) {
                      identifyTool.isMenuRequest = false
                      identifyTool.identify(point)
                  }
              }
          }
      }

      onConfirmedClicked: (point) => {
          if (!featureForm.canvasOperationRequested && !overlayFeatureFormDrawer.visible && featureForm.state != "FeatureFormEdit")
          {
              identifyTool.isMenuRequest = false
              identifyTool.identify(point)
          }
      }

      onLongPressed: (point, type) => {
        if ( type === "stylus" ) {
          if ( overlayFeatureFormDrawer.opened || ( featureForm.visible && pointInItem( point, featureForm ) ) ) {
            return
          }

          if ( geometryEditorsToolbar.canvasLongPressed( point ) ) {
            // for instance, the vertex editor will select a vertex if possible
            return
          }

          if ( stateMachine.state === "digitize" && dashBoard.activeLayer ) { // the sourceLocation test checks if a (stylus) hover is active
            if ( ( Number( currentRubberband.model.geometryType ) === Qgis.GeometryType.Line && currentRubberband.model.vertexCount >= 2 )
               || ( Number( currentRubberband.model.geometryType ) === Qgis.GeometryType.Polygon && currentRubberband.model.vertexCount >= 2 ) ) {
                digitizingToolbar.addVertex();

                // When it's released, it will normally cause a release event to close the attribute form.
                // We get around this by temporarily switching the closePolicy.
                overlayFeatureFormDrawer.closePolicy = Popup.CloseOnEscape

                digitizingToolbar.confirm()
                return
            }
          }

          // do not use else, as if it was catch it has return before
          identifyTool.isMenuRequest = false
          identifyTool.identify(point)
        } else {
          canvasMenu.point = mapCanvas.mapSettings.screenToCoordinate(point)
          canvasMenu.popup(point.x, point.y)
          identifyTool.isMenuRequest = true
          identifyTool.identify(point)
        }
      }

      onRightClicked: (point, type) => {
        canvasMenu.point = mapCanvas.mapSettings.screenToCoordinate(point)
        canvasMenu.popup(point.x, point.y)
        identifyTool.isMenuRequest = true
        identifyTool.identify(point)
      }

      onLongPressReleased: (type) => {
        if ( type === "stylus" ) {
          // The user has released the long press. We can re-enable the default close behavior for the feature form.
          // The next press will be intentional to close the form.
          overlayFeatureFormDrawer.closePolicy = Popup.CloseOnEscape | Popup.CloseOnPressOutside
        }
      }
    }


  /**************************************************
   * Overlays, including:
   * - Coordinate Locator
   * - Location Marker
   * - Identify Highlight
   * - Digitizing Rubberband
   **************************************************/

    /** The identify tool **/
    IdentifyTool {
      id: identifyTool

      property bool isMenuRequest: false

      mapSettings: mapCanvas.mapSettings
      model:  isMenuRequest ? canvasMenuFeatureListModel : featureForm.model
      searchRadiusMm: 3
    }

    /** A rubberband for measuring **/
    MeasuringTool {
      id: measuringTool
      visible: stateMachine.state === 'measure'
      anchors.fill: parent

      measuringRubberband.model.currentCoordinate: coordinateLocator.currentCoordinate
      measuringRubberband.mapSettings: mapCanvas.mapSettings
    }

    /** Tracking sessions **/
    Repeater {
        id: trackings
        model: trackingModel

        TrackingSession {}
    }

    /** A rubberband for ditizing **/
    Rubberband {
      id: digitizingRubberband
      lineWidth: 2.5

      mapSettings: mapCanvas.mapSettings

      model: RubberbandModel {
        frozen: false
        currentCoordinate: coordinateLocator.currentCoordinate
        measureValue: {
          if (coordinateLocator.positionLocked) {
            switch(positioningSettings.digitizingMeasureType) {
              case Tracker.Timestamp:
                return coordinateLocator.positionInformation.utcDateTime.getTime()
              case Tracker.GroundSpeed:
                return coordinateLocator.positionInformation.speed
              case Tracker.Bearing:
                return coordinateLocator.positionInformation.direction
              case Tracker.HorizontalAccuracy:
                return coordinateLocator.positionInformation.hacc
              case Tracker.VerticalAccuracy:
                return coordinateLocator.positionInformation.vacc
              case Tracker.PDOP:
                return coordinateLocator.positionInformation.pdop
              case Tracker.HDOP:
                return coordinateLocator.positionInformation.hdop
              case Tracker.VDOP:
                return coordinateLocator.positionInformation.vdop
            }
          } else {
            return Number.NaN;
          }
        }
        vectorLayer: digitizingToolbar.geometryRequested ? digitizingToolbar.geometryRequestedLayer : dashBoard.activeLayer
        crs: mapCanvas.mapSettings.destinationCrs
      }

      visible: stateMachine.state === "digitize"
    }

    GeometryRenderer {
      id: geometryEditorRenderer
    }

    /** A rubberband for the different geometry editors **/
    Rubberband {
      id: geometryEditorsRubberband
      lineWidth: 2.5
      color: '#80000000'

      mapSettings: mapCanvas.mapSettings

      model: RubberbandModel {
        frozen: false
        currentCoordinate: coordinateLocator.currentCoordinate
        crs: mapCanvas.mapSettings.destinationCrs
        geometryType: Qgis.GeometryType.Line
      }
    }

    BookmarkHighlight {
        id: bookmarkHighlight
        mapSettings: mapCanvas.mapSettings
    }

    Navigation {
      id: navigation
      mapSettings: mapCanvas.mapSettings
      location: positionSource.active ? positionSource.projectedPosition : GeometryUtils.emptyPoint()

      proximityAlarm: positioningSettings.preciseViewProximityAlarm
                      && positioningPreciseView.visible
                      && positioningPreciseView.hasAcceptableAccuracy
                      && !positioningPreciseView.hasAlarmSnoozed
      proximityAlarmThreshold: positioningSettings.preciseViewPrecision
    }

    NavigationHighlight {
      id: navigationHighlight
      navigation: navigation
    }

    LinePolygonHighlight {
      id: elevationProfileHighlight

      visible: elevationProfile.visible
      mapSettings: mapCanvas.mapSettings
      geometry:   QgsGeometryWrapper {
        qgsGeometry: elevationProfile.profileCurve
        crs: elevationProfile.crs
      }
      color: "#FFFFFF"
      lineWidth: 4
    }

    /** A coordinate locator for digitizing **/
    CoordinateLocator {
      id: coordinateLocator
      anchors.fill: parent
      visible: stateMachine.state === "digitize" || stateMachine.state === 'measure'
      highlightColor: digitizingToolbar.isDigitizing ? currentRubberband.color : "#CFD8DC"
      mapSettings: mapCanvas.mapSettings
      currentLayer: dashBoard.activeLayer
      positionInformation: positionSource.positionInformation
      positionLocked: positionSource.active && positioningSettings.positioningCoordinateLock
      averagedPosition: positionSource.averagedPosition
      averagedPositionCount: positionSource.averagedPositionCount
      overrideLocation: positionLocked ? positionSource.projectedPosition : undefined
    }

    /* Location marker reflecting the current GNSS position */
    LocationMarker {
      id: locationMarker
      visible: positionSource.active && positionSource.positionInformation && positionSource.positionInformation.latitudeValid

      mapSettings: mapCanvas.mapSettings

      location: positionSource.projectedPosition
      accuracy: positionSource.projectedHorizontalAccuracy
      direction: positionSource.positionInformation
                 && positionSource.positionInformation.directionValid
                 ? positionSource.positionInformation.direction
                 : -1
      speed: positionSource.positionInformation
             && positionSource.positionInformation.speedValid
             ? positionSource.positionInformation.speed
             : -1
      orientation: !isNaN(positionSource.orientation)
                   ? positionSource.orientation + positionSource.bearingTrueNorth < 0
                     ? 360 + positionSource.orientation + positionSource.bearingTrueNorth
                     : positionSource.orientation + positionSource.bearingTrueNorth
                   : -1
    }

    /* Rubberband for vertices  */
    Item {
      // highlighting vertices
      VertexRubberband {
        id: vertexRubberband
        model: geometryEditingVertexModel
        mapSettings: mapCanvas.mapSettings
      }

      // highlighting geometry (point, line, surface)
      Rubberband {
        id: editingRubberband
        vertexModel: geometryEditingVertexModel
        mapSettings: mapCanvas.mapSettings
        lineWidth: 4
      }
    }

    /* Highlight the currently selected item on the feature list */
    FeatureListSelectionHighlight {
      id: featureListHighlight
      visible: !moveFeaturesToolbar.moveFeaturesRequested

      selectionModel: featureForm.selection
      mapSettings: mapCanvas.mapSettings

      color: "yellow"
      focusedColor: "#ff7777"
      selectedColor: Theme.mainColor
      width: 5
    }

    /* Highlight the currently selected item being moved */
    FeatureListSelectionHighlight {
      id: moveFeaturesHighlight
      visible: moveFeaturesToolbar.moveFeaturesRequested
      showSelectedOnly: true

      selectionModel: featureForm.selection
      mapSettings: mapCanvas.mapSettings

      // take rotation into account
      property double rotationRadians: -mapSettings.rotation * Math.PI / 180
      translateX: mapToScreenTranslateX.screenDistance * Math.cos( rotationRadians ) - mapToScreenTranslateY.screenDistance * Math.sin( rotationRadians )
      translateY: mapToScreenTranslateY.screenDistance * Math.cos( rotationRadians ) + mapToScreenTranslateX.screenDistance * Math.sin( rotationRadians )

      color: "yellow"
      focusedColor: "#ff7777"
      selectedColor: Theme.mainColor
      width: 5
    }

    /* Highlight features identified by locator or relation editor widgets */
    GeometryHighlighter {
      id: locatorHighlightItem
    }

    MapToScreen {
      id: mapToScreenTranslateX
      mapSettings: mapCanvas.mapSettings
      mapDistance: moveFeaturesToolbar.moveFeaturesRequested ? mapCanvas.mapSettings.center.x - moveFeaturesToolbar.startPoint.x : 0
    }
    MapToScreen {
      id: mapToScreenTranslateY
      mapSettings: mapCanvas.mapSettings
      mapDistance: moveFeaturesToolbar.moveFeaturesRequested ? mapCanvas.mapSettings.center.y - moveFeaturesToolbar.startPoint.y : 0
    }
  }

  Column {
    id: informationView
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottomMargin: mainWindow.sceneBottomMargin
    visible: navigation.isActive ||
             positioningSettings.showPositionInformation ||
             positioningPreciseView.visible ||
             sensorInformationView.activeSensors > 0 ||
             (stateMachine.state === 'measure' && elevationProfileButton.elevationProfileActive)

    width: parent.width

    ElevationProfile {
        id: elevationProfile

        visible: stateMachine.state === 'measure' && elevationProfileButton.elevationProfileActive

        width: parent.width
        height: Math.max(220, mainWindow.height / 4)

        project: qgisProject
        crs: mapCanvas.mapSettings.destinationCrs
    }

    NavigationInformationView {
      id: navigationInformationView
      visible: navigation.isActive && !elevationProfile.visible
      navigation: navigation
    }

    Rectangle {
      visible: navigationInformationView.visible && positioningPreciseView.visible
      width: parent.width
      height: 1
      color: Theme.navigationBackgroundColor
    }

    PositioningPreciseView {
      id: positioningPreciseView

      precision: positioningSettings.preciseViewPrecision

      visible: !isNaN(navigation.distance)
               && (positioningSettings.alwaysShowPreciseView
                   || (hasAcceptableAccuracy && navigation.distance < precision))
               && !elevationProfile.visible
      width: parent.width
      height: Math.min(mainWindow.height / 2.5, 400)
    }

    Rectangle {
      visible: positioningInformationView.visible
               && (positioningPreciseView.visible || navigationInformationView.visible)
      width: parent.width
      height: 1
      color: Theme.navigationBackgroundColor
    }

    PositioningInformationView {
      id: positioningInformationView
      visible: positioningSettings.showPositionInformation && !elevationProfile.visible
      positionSource: positionSource
      antennaHeight: positioningSettings.antennaHeightActivated ? positioningSettings.antennaHeight : NaN
    }

    Rectangle {
      visible: positioningInformationView.visible && sensorInformationView.visible
      width: parent.width
      height: 1
      color: Theme.sensorBackgroundColor
    }

    SensorInformationView {
      id: sensorInformationView
    }
  }

  QfDropShadow {
    anchors.fill: informationView
    visible: informationView.visible
    verticalOffset: -2
    radius: 6.0
    color: "#30000000"
    source: informationView
  }

  /**************************************************
   * Map Canvas Decorations like
   * - Position Information View
   * - Scale Bar
   **************************************************/

  Text {
    id: coordinateLocatorInformationOverlay

    property bool coordinatesIsXY: CoordinateReferenceSystemUtils.defaultCoordinateOrderForCrsIsXY(projectInfo.coordinateDisplayCrs)
    property bool coordinatesIsGeographic: projectInfo.coordinateDisplayCrs.isGeographic

    DistanceArea {
      id: digitizingGeometryMeasure

      property VectorLayer currentLayer: dashBoard.activeLayer

      rubberbandModel: currentRubberband ? currentRubberband.model : null
      project: qgisProject
      crs: qgisProject ? qgisProject.crs : CoordinateReferenceSystemUtils.invalidCrs()
    }

    // The position is dynamically calculated to follow the coordinate locator
    x: {
        var newX = coordinateLocator.displayPosition.x + 20;
        if (newX + width > mapCanvas.x + mapCanvas.width)
            newX -= width + 40;
        return newX;
    }
    y: {
        var newY = coordinateLocator.displayPosition.y + 10
        if (newY + height > mapCanvas.y + mapCanvas.height)
            newY -= height - 20;
        return newY;
    }

    textFormat: Text.PlainText
    text: {
      if ((qfieldSettings.numericalDigitizingInformation && stateMachine.state === "digitize" ) || stateMachine.state === 'measure') {
        var point = GeometryUtils.reprojectPoint(coordinateLocator.currentCoordinate, coordinateLocator.mapSettings.destinationCrs, projectInfo.coordinateDisplayCrs)
        var coordinates;
        if (coordinatesIsXY) {
          coordinates = '%1: %2\n%3: %4\n'
                        .arg(coordinatesIsGeographic ? qsTr( 'Lon' ) : 'X')
                        .arg(point.x.toLocaleString( Qt.locale(), 'f', coordinatesIsGeographic ? 5 : 2 ))
                        .arg(coordinatesIsGeographic ? qsTr( 'Lat' ) : 'Y')
                        .arg(point.y.toLocaleString( Qt.locale(), 'f', coordinatesIsGeographic ? 5 : 2 ));
        } else {
          coordinates = '%1: %2\n%3: %4\n'
                        .arg(coordinatesIsGeographic ? qsTr( 'Lat' ) : 'Y')
                        .arg(point.y.toLocaleString( Qt.locale(), 'f', coordinatesIsGeographic ? 5 : 2 ))
                        .arg(coordinatesIsGeographic ? qsTr( 'Lon' ) : 'X')
                        .arg(point.x.toLocaleString( Qt.locale(), 'f', coordinatesIsGeographic ? 5 : 2 ));
        }

        return '%1%2%3%4%5%6'
                .arg(stateMachine.state === 'digitize' || !digitizingToolbar.isDigitizing
                     ? coordinates
                     : '')

                .arg(digitizingGeometryMeasure.lengthValid && digitizingGeometryMeasure.segmentLength != 0.0
                     ? '%1: %2\n'
                       .arg( digitizingGeometryMeasure.segmentLength != digitizingGeometryMeasure.length ? qsTr( 'Segment') : qsTr( 'Length' ) )
                       .arg(UnitTypes.formatDistance( digitizingGeometryMeasure.convertLengthMeansurement( digitizingGeometryMeasure.segmentLength, projectInfo.distanceUnits ) , 3, projectInfo.distanceUnits ) )
                     : '')

                .arg(digitizingGeometryMeasure.lengthValid && digitizingGeometryMeasure.segmentLength != 0.0
                     ? '%1: %2\n'
                       .arg( qsTr( 'Azimuth') )
                       .arg( UnitTypes.formatAngle( digitizingGeometryMeasure.azimuth < 0 ? digitizingGeometryMeasure.azimuth + 360 : digitizingGeometryMeasure.azimuth, 2, Qgis.AngleUnit.Degrees ) )
                     : '')

                .arg(currentRubberband.model && currentRubberband.model.geometryType === Qgis.GeometryType.Polygon
                     ? digitizingGeometryMeasure.perimeterValid
                       ? '%1: %2\n'
                         .arg( qsTr( 'Perimeter') )
                         .arg(UnitTypes.formatDistance( digitizingGeometryMeasure.convertLengthMeansurement( digitizingGeometryMeasure.perimeter, projectInfo.distanceUnits ), 3, projectInfo.distanceUnits ) )
                       : ''
                     : digitizingGeometryMeasure.lengthValid && digitizingGeometryMeasure.segmentLength != digitizingGeometryMeasure.length
                     ? '%1: %2\n'
                       .arg( qsTr( 'Length') )
                       .arg(UnitTypes.formatDistance( digitizingGeometryMeasure.convertLengthMeansurement( digitizingGeometryMeasure.length, projectInfo.distanceUnits ),3, projectInfo.distanceUnits ) )
                     : '')

                .arg(digitizingGeometryMeasure.areaValid
                     ? '%1: %2\n'
                     .arg( qsTr( 'Area') )
                     .arg(UnitTypes.formatArea( digitizingGeometryMeasure.convertAreaMeansurement( digitizingGeometryMeasure.area, projectInfo.areaUnits ), 3, projectInfo.areaUnits ) )
                     : '')

                .arg(stateMachine.state === 'measure' && digitizingToolbar.isDigitizing
                     ? coordinates
                     : '')
      } else {
        return '';
      }
    }

    font: Theme.strongTipFont
    style: Text.Outline
    styleColor: Theme.light
  }

  QfToolButton {
    id: compassArrow
    rotation: mapCanvas.mapSettings.rotation
    visible: rotation != 0

    anchors.left: mapCanvas.left
    anchors.bottom: mapCanvas.bottom
    anchors.leftMargin: 4
    anchors.bottomMargin: informationView.visible
                          ? 54
                          : mainWindow.sceneBottomMargin + 54

    round: true
    bgcolor: Theme.darkGraySemiOpaque
    iconSource: Theme.getThemeVectorIcon('ic_compass_arrow_24dp')

    onClicked: mapCanvas.mapSettings.rotation = 0
  }

  ScaleBar {
    visible: qfieldSettings.showScaleBar
    mapSettings: mapCanvas.mapSettings

    anchors.left: mapCanvas.left
    anchors.bottom: mapCanvas.bottom
    anchors.leftMargin: 4
    anchors.bottomMargin: informationView.visible
                          ? 10
                          : mainWindow.sceneBottomMargin + 10
  }

  QfDropShadow {
    anchors.fill: featureForm
    horizontalOffset: mainWindow.width >= mainWindow.height ? -2: 0
    verticalOffset: mainWindow.width < mainWindow.height ? -2: 0
    radius: 6.0
    color: "#80000000"
    source: featureForm
  }

  QfToolButton {
    id: alertIcon
    iconSource: Theme.getThemeVectorIcon( "ic_alert_black_24dp" )
    round: true
    bgcolor: "transparent"

    visible: !screenLocker.enabled && messageLog.unreadMessages

    anchors.right: locatorItem.right
    anchors.top: locatorItem.top
    anchors.topMargin: 52

    onClicked: messageLog.visible = true
  }

  Column {
    id: zoomToolbar
    anchors.right: mapCanvas.right
    anchors.rightMargin: 10
    anchors.bottom: mapCanvas.bottom
    anchors.bottomMargin: ( mapCanvas.height - zoomToolbar.height / 2 ) / 2
    spacing: 8

    visible: !screenLocker.enabled && locationToolbar.height / mapCanvas.height < 0.41

    QfToolButton {
      id: zoomInButton
      round: true
      anchors.right: parent.right

      bgcolor: Theme.darkGray
      iconSource: Theme.getThemeIcon( "ic_add_white_24dp" )

      width: 36
      height: 36

      onClicked: {
          if ( gnssButton.followActive ) gnssButton.followActiveSkipExtentChanged = true;
          mapCanvasMap.zoomIn(Qt.point(mapCanvas.x + mapCanvas.width / 2,mapCanvas.y + mapCanvas.height / 2));
      }
    }
    QfToolButton {
      id: zoomOutButton
      round: true
      anchors.right: parent.right

      bgcolor: Theme.darkGray
      iconSource: Theme.getThemeIcon( "ic_remove_white_24dp" )

      width: 36
      height: 36

      onClicked: {
          if ( gnssButton.followActive ) gnssButton.followActiveSkipExtentChanged = true;
          mapCanvasMap.zoomOut(Qt.point(mapCanvas.x + mapCanvas.width / 2,mapCanvas.y + mapCanvas.height / 2));
      }
    }
  }

  LocatorItem {
    id: locatorItem

    locatorModelSuperBridge.navigation: navigation
    locatorModelSuperBridge.bookmarks: bookmarkModel
    locatorModelSuperBridge.activeLayer: dashBoard.activeLayer

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: mainWindow.sceneTopMargin + 4
    anchors.rightMargin: 4

    visible: !screenLocker.enabled && stateMachine.state !== 'measure'

    Keys.onReleased: (event) => {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        state = "off"
      }
    }

    onStateChanged: {
      if ( state == "off" ) {
        focus = false
        if ( featureForm.visible ) {
          featureForm.focus = true
        } else {
          keyHandler.focus = true
        }
      }
    }
  }

  LocatorSettings {
      id: locatorSettings
      locatorFiltersModel: locatorItem.locatorFiltersModel

      modal: true
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
      parent: ApplicationWindow.overlay
  }

  QfDropShadow {
    anchors.fill: locatorItem
    visible: locatorItem.searchFieldVisible
    verticalOffset: 2
    radius: 10
    color: "#66212121"
    source: locatorItem
  }

  DashBoard {
    id: dashBoard
    allowLayerChange: !digitizingToolbar.isDigitizing
    mapSettings: mapCanvas.mapSettings
    interactive: !welcomeScreen.visible
                 && !qfieldSettings.visible
                 && !qfieldCloudScreen.visible
                 && !qfieldLocalDataPickerScreen.visible
                 && !codeReader.visible
                 && !screenLocker.enabled

    onOpenedChanged: {
      if ( !opened ) {
        if ( featureForm.visible ) {
          featureForm.focus = true;
        }
      }
    }

    function ensureEditableLayerSelected() {
      var firstEditableLayer = null;
      var activeLayerLocked = false;
      for (var i = 0; i < layerTree.rowCount(); i++)
      {
        var index = layerTree.index(i, 0)
        if (firstEditableLayer === null)
        {
          if (
              layerTree.data(index,FlatLayerTreeModel.Type) === 'layer'
              && layerTree.data(index, FlatLayerTreeModel.ReadOnly) === false
              && layerTree.data(index, FlatLayerTreeModel.GeometryLocked) === false)
          {
             firstEditableLayer = layerTree.data(index, FlatLayerTreeModel.VectorLayerPointer);
          }
        }
        if (activeLayer != null && activeLayer === layerTree.data(index, FlatLayerTreeModel.VectorLayerPointer))
        {
           if (
               layerTree.data(index, FlatLayerTreeModel.ReadOnly) === true
               || layerTree.data(index, FlatLayerTreeModel.GeometryLocked) === true
           )
           {
             activeLayerLocked = true;
           }
           else
           {
             break;
           }
        }
        if (
            firstEditableLayer !== null
            && (activeLayer == null || activeLayerLocked === true)
        )
        {
          activeLayer = firstEditableLayer;
          break;
        }
      }
    }
  }

  /* The main menu */
  Row {
    id: mainMenuBar
    visible: !screenLocker.enabled
    width: childrenRect.width + 8
    height: childrenRect.height + 8
    topPadding: mainWindow.sceneTopMargin + 4
    leftPadding: 4
    spacing: 4

    QfToolButton {
      id: menuButton
      round: true
      iconSource: Theme.getThemeIcon( "ic_menu_white_24dp" )
      bgcolor: dashBoard.opened ? Theme.mainColor : Theme.darkGray

      onClicked: dashBoard.opened ? dashBoard.close() : dashBoard.open()

      onPressAndHold: {
        mainMenu.popup(menuButton.x, menuButton.y)
      }
    }

    CloseTool {
      id: closeMeasureTool
      visible: stateMachine.state === 'measure'
      toolImage: Theme.getThemeVectorIcon( "ic_measurement_black_24dp" )
      toolText: qsTr( 'Close measure tool' )
      onClosedTool: mainWindow.closeMeasureTool()
    }

    CloseTool {
      id: closeGeometryEditorsTool
      visible: ( stateMachine.state === "digitize" && geometryEditingVertexModel.vertexCount > 0 )
      toolImage: geometryEditorsToolbar.image
      toolText: qsTr( 'Stop editing' )
      onClosedTool: geometryEditorsToolbar.cancelEditors()
    }

    CloseTool {
      id: abortRequestGeometry
      visible: digitizingToolbar.geometryRequested
      toolImage: Theme.getThemeIcon( "ic_edit_geometry_white" )
      toolText: qsTr( 'Cancel addition' )
      onClosedTool: digitizingToolbar.cancel()
    }
  }

  Column {
    id: mainToolbar
    visible: !screenLocker.enabled
    anchors.left: mainMenuBar.left
    anchors.top: mainMenuBar.bottom
    anchors.leftMargin: 4
    spacing: 4

    QfToolButton {
      id: snappingButton
      round: true
      visible: stateMachine.state === "digitize"
          && dashBoard.activeLayer
          && dashBoard.activeLayer.isValid
          && (
                   dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Polygon
                   || dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Line
                   || dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Point
        )
      state: qgisProject && qgisProject.snappingConfig.enabled ? "On" : "Off"
      iconSource: Theme.getThemeVectorIcon( "ic_snapping_white_24dp" )
      iconColor: "white"
      bgcolor: Theme.darkGray

      states: [
        State {

          name: "Off"
          PropertyChanges {
            target: snappingButton
            iconColor: "white"
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: snappingButton
            iconColor: Theme.mainColor
            bgcolor: Theme.darkGray
          }
        }
      ]

      onClicked: {
        var snappingConfig = qgisProject.snappingConfig
        snappingConfig.enabled = !snappingConfig.enabled
        qgisProject.snappingConfig = snappingConfig
        projectInfo.saveSnappingConfiguration()
        displayToast( snappingConfig.enabled ? qsTr( "Snapping turned on" ) : qsTr( "Snapping turned off" ) )
      }
    }

    QfToolButton {
      id: topologyButton
      round: true
      visible: stateMachine.state === "digitize"
          && dashBoard.activeLayer
          && dashBoard.activeLayer.isValid
          && (
                   dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Polygon
                   || dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Line
                   || dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Point
        )
      state: qgisProject && qgisProject.topologicalEditing ? "On" : "Off"
      iconSource: Theme.getThemeVectorIcon( "ic_topology_white_24dp" )
      iconColor: "white"
      bgcolor: Theme.darkGray

      states: [
        State {

          name: "Off"
          PropertyChanges {
            target: topologyButton
            iconColor: "white"
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: topologyButton
            iconColor: Theme.mainColor
            bgcolor: Theme.darkGray
          }
        }
      ]

      onClicked: {
        qgisProject.topologicalEditing = !qgisProject.topologicalEditing;
        displayToast( qgisProject.topologicalEditing ? qsTr( "Topological editing turned on" ) : qsTr( "Topological editing turned off" ) );
      }
    }

    QfToolButton {
      id: freehandButton
      round: true
      visible: hoverHandler.hasBeenHovered && !(positionSource.active && positioningSettings.positioningCoordinateLock) && stateMachine.state === "digitize"
               && ((digitizingToolbar.geometryRequested && digitizingToolbar.geometryRequestedLayer && digitizingToolbar.geometryRequestedLayer.isValid &&
                   (digitizingToolbar.geometryRequestedLayer.geometryType() === Qgis.GeometryType.Polygon
                    || digitizingToolbar.geometryRequestedLayer.geometryType() === Qgis.GeometryType.Line))
                   || (!digitizingToolbar.geometryRequested && dashBoard.activeLayer && dashBoard.activeLayer.isValid &&
                   (dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Polygon
                    || dashBoard.activeLayer.geometryType() === Qgis.GeometryType.Line)))
      iconSource: Theme.getThemeVectorIcon( "ic_freehand_white_24dp" )
      iconColor: "white"
      bgcolor: Theme.darkGray

      property bool freehandDigitizing: false
      state: freehandDigitizing ? "On" : "Off"

      states: [
        State {
          name: "Off"
          PropertyChanges {
            target: freehandButton
            iconColor: "white"
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: freehandButton
            iconColor: Theme.mainColor
            bgcolor: Theme.darkGray
          }
        }
      ]

      onClicked: {
        freehandDigitizing = !freehandDigitizing

        if (freehandDigitizing && positioningSettings.positioningCoordinateLock) {
          positioningSettings.positioningCoordinateLock = false;
        }

        displayToast( freehandDigitizing ? qsTr( "Freehand digitizing turned on" ) : qsTr( "Freehand digitizing turned off" ) );
        settings.setValue( "/QField/Digitizing/FreehandActive", freehandDigitizing );
      }

      Component.onCompleted: {
        freehandDigitizing = settings.valueBool( "/QField/Digitizing/FreehandActive", false )
      }
    }

    QfToolButton {
      id: elevationProfileButton
      round: true
      visible: stateMachine.state === 'measure'
      iconSource: Theme.getThemeVectorIcon( "ic_elevation_white_24dp" )

      bgcolor: Theme.darkGray

      property bool elevationProfileActive: false
      state: elevationProfileActive ? "On" : "Off"

      states: [
        State {
          name: "Off"
          PropertyChanges {
            target: elevationProfileButton
            iconSource: Theme.getThemeVectorIcon( "ic_elevation_white_24dp" )
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: elevationProfileButton
            iconSource: Theme.getThemeVectorIcon( "ic_elevation_green_24dp" )
            bgcolor: Theme.darkGray
          }
        }
      ]

      onClicked: {
        elevationProfileActive = !elevationProfileActive

        // Draw an elevation profile if we have enough points to do so
        if ( digitizingToolbar.rubberbandModel.vertexCount > 2 ) {
          // Clear the pre-existing profile to trigger a zoom to full updated profile curve
          elevationProfile.clear();
          elevationProfile.profileCurve = GeometryUtils.lineFromRubberband(digitizingToolbar.rubberbandModel, elevationProfile.crs)
          elevationProfile.refresh();
        }

        settings.setValue( "/QField/Measuring/ElevationProfile", elevationProfileActive );
      }

      Component.onCompleted: {
        elevationProfileActive = settings.valueBool( "/QField/Measuring/ElevationProfile", false )
      }
    }
  }

  Column {
    id: locationToolbar
    anchors.right: mapCanvas.right
    anchors.rightMargin: 4
    anchors.bottom: mapCanvas.bottom
    anchors.bottomMargin: informationView.visible
                          ? 4
                          : mainWindow.sceneBottomMargin + 4
    spacing: 4

    QfToolButton {
      id: navigationButton
      visible: navigation.isActive
      round: true
      anchors.right: parent.right

      property bool isFollowLocationActive: positionSource.active && gnssButton.followActive && followIncludeDestination
      iconSource: isFollowLocationActive
                  ? Theme.getThemeIcon( "ic_navigation_flag_white_24dp" )
                  : Theme.getThemeIcon( "ic_navigation_flag_purple_24dp" )
      bgcolor: isFollowLocationActive
               ? Theme.navigationColor
               : Theme.darkGray

      /*
      / When set to true, when the map follows the device's current position, the extent
      / will always include the destination marker.
      */
      property bool followIncludeDestination: true

      onClicked: {
        if (positionSource.active && gnssButton.followActive) {
          followIncludeDestination = !followIncludeDestination
          settings.setValue("/QField/Navigation/FollowIncludeDestination", followIncludeDestination);

          gnssButton.followLocation(true)
        } else {
          mapCanvas.mapSettings.setCenter(navigation.destination)
        }
      }

      onPressAndHold: {
        navigationMenu.popup(
          locationToolbar.x + locationToolbar.width - navigationMenu.width,
          locationToolbar.y + locationToolbar.height - navigationMenu.height
        )
      }

      Component.onCompleted: {
        followIncludeDestination = settings.valueBool("/QField/Navigation/FollowIncludeDestination", true)
      }
    }

    QfToolButton {
      id: gnssLockButton
      anchors.right: parent.right
      state: positionSource.active && positioningSettings.positioningCoordinateLock ? "On" : "Off"
      visible: gnssButton.state === "On" && ( stateMachine.state === "digitize" || stateMachine.state === 'measure' )
      round: true
      checkable: true
      checked: positioningSettings.positioningCoordinateLock

      states: [
        State {
          name: "Off"
          PropertyChanges {
            target: gnssLockButton
            iconSource: Theme.getThemeIcon( "ic_gps_link_white_24dp" )
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: gnssLockButton
            iconSource: Theme.getThemeIcon( "ic_gps_link_activated_white_24dp" )
            bgcolor: Theme.darkGray
          }
        }
      ]

      onCheckedChanged: {
        if (gnssButton.state === "On") {
          if (checked) {
              if (freehandButton.freehandDigitizing) {
                  // deactivate freehand digitizing when cursor locked is on
                  freehandButton.clicked();
              }
              displayToast( qsTr( "Coordinate cursor now locked to position" ) )
              if (positionSource.positionInformation.latitudeValid) {
                var screenLocation = mapCanvas.mapSettings.coordinateToScreen(locationMarker.location);
                if ( screenLocation.x < 0 || screenLocation.x > mainWindow.width ||
                     screenLocation.y < 0 || screenLocation.y > mainWindow.height ) {
                  mapCanvas.mapSettings.setCenter(positionSource.projectedPosition);
                }
              }
              positioningSettings.positioningCoordinateLock = true;
          } else {
            displayToast( qsTr( "Coordinate cursor unlocked" ) )
            positioningSettings.positioningCoordinateLock = false;
            // deactivate any active averaged position collection
            positionSource.averagedPosition = false;
          }
        }
      }
    }

    QfToolButton {
      id: gnssButton
      state: positionSource.active ? "On" : "Off"
      visible: positionSource.valid
      round: true

      anchors.right: parent.right

      onIconSourceChanged: {
        if( state === "On" ){
          if( positionSource.positionInformation && positionSource.positionInformation.latitudeValid ) {
            displayToast( qsTr( "Received position" ) )
          } else {
            displayToast( qsTr( "Searching for position" ) )
          }
        }
      }

      /*
      / When set to true, the map will follow the device's current position; the map
      / will stop following the position whe the user manually drag the map.
      */
      property bool followActive: false
      /*
      / When set to true, map canvas extent changes will not result in the
      / deactivation of the above followActive mode.
      */
      property bool followActiveSkipExtentChanged: false
      /*
      / When set to true, the map will rotate to match the device's current magnetometer/compass orientatin.
      */
      property bool followOrientationActive: false
      /*
      / When set to true, map canvas rotation changes will not result in the
      / deactivation of the above followOrientationActive mode.
      */
      property bool followActiveSkipRotationChanged: false

      states: [
        State {
          name: "Off"
          PropertyChanges {
            target: gnssButton
            iconSource: Theme.getThemeVectorIcon( "ic_location_disabled_white_24dp" )
            bgcolor: Theme.darkGraySemiOpaque
          }
        },

        State {
          name: "On"
          PropertyChanges {
            target: gnssButton
            iconSource: positionSource.positionInformation && positionSource.positionInformation.latitudeValid
                        ? Theme.getThemeVectorIcon( "ic_location_valid_white_24dp" )
                        : Theme.getThemeVectorIcon( "ic_location_white_24dp" )
            iconColor: followActive ? "white" : Theme.positionColor
            bgcolor: followActive ? Theme.positionColor : Theme.darkGray
          }
        }
      ]

      onClicked: {
        if (followActive) {
          followOrientationActive = true
          followOrientation();
          displayToast( qsTr( "Canvas follows location and compass orientation" ) )
        } else {
          followActive = true
          if ( positionSource.projectedPosition.x )
          {
            if ( !positionSource.active )
            {
              positioningSettings.positioningActivated = true
            }
            else
            {
                followLocation(true);
                displayToast( qsTr( "Canvas follows location" ) )
            }
          }
          else
          {
            if ( positionSource.valid )
            {
              if ( positionSource.active )
              {
                displayToast( qsTr( "Waiting for location" ) )
              }
              else
              {
                positioningSettings.positioningActivated = true
              }
            }
          }
        }
      }

      onPressAndHold: {
        gnssMenu.popup(locationToolbar.x + locationToolbar.width - gnssMenu.width, locationToolbar.y + locationToolbar.height - gnssMenu.height)
      }

      property int followLocationMinScale: 125
      property int followLocationMinMargin: 40
      property int followLocationScreenFraction: settings ? settings.value( "/QField/Positioning/FollowScreenFraction", 5 ) : 5

      function followLocation(forceRecenter) {
        var screenLocation = mapCanvas.mapSettings.coordinateToScreen(positionSource.projectedPosition);
        if (navigation.isActive && navigationButton.followIncludeDestination) {
          if (mapCanvas.mapSettings.scale > followLocationMinScale) {
            var screenDestination = mapCanvas.mapSettings.coordinateToScreen(navigation.destination);
            if (forceRecenter
                || screenDestination.x < followLocationMinMargin
                || screenDestination.x > (mainWindow.width - followLocationMinMargin)
                || screenDestination.y < followLocationMinMargin
                || screenDestination.y > (mainWindow.height - followLocationMinMargin)
                || screenLocation.x < followLocationMinMargin
                || screenLocation.x > (mainWindow.width - followLocationMinMargin)
                || screenLocation.y < followLocationMinMargin
                || screenLocation.y > (mainWindow.height - followLocationMinMargin)
                || (Math.abs(screenDestination.x - screenLocation.x) < mainWindow.width / 3
                    && Math.abs(screenDestination.y - screenLocation.y) < mainWindow.height / 3)) {
              gnssButton.followActiveSkipExtentChanged = true;
              var points = [positionSource.projectedPosition, navigation.destination];
              mapCanvas.mapSettings.setExtentFromPoints(points, followLocationMinScale)
            }
          }
        } else {
          var threshold = Math.min( mainWindow.width, mainWindow.height ) / followLocationScreenFraction;
          if ( forceRecenter
               || screenLocation.x < mapCanvas.x + threshold
               || screenLocation.x > mapCanvas.width - threshold
               || screenLocation.y < mapCanvas.y + threshold
               || screenLocation.y > mapCanvas.height - threshold )
          {
            gnssButton.followActiveSkipExtentChanged = true;
            mapCanvas.mapSettings.setCenter(positionSource.projectedPosition);
          }
        }
      }
      function followOrientation() {
        if (!isNan(positionSource.orientation) && Math.abs(-positionSource.orientation - mapCanvas.mapSettings.rotation) >= 10) {
          gnssButton.followActiveSkipRotationChanged = true
          mapCanvas.mapSettings.rotation = -positionSource.orientation
        }
      }

      Rectangle {
          anchors {
              top: parent.top
              right: parent.right
              rightMargin: 2
              topMargin: 2
          }

          width: 12
          height: 12
          radius: width / 2

          border.width: 1.5
          border.color: 'white'

          visible: positioningSettings.accuracyIndicator && gnssButton.state === "On"
          color: !positionSource.positionInformation
                 || !positionSource.positionInformation.haccValid
                 || positionSource.positionInformation.hacc > positioningSettings.accuracyBad
                     ? Theme.accuracyBad
                     : positionSource.positionInformation.hacc > positioningSettings.accuracyExcellent
                       ? Theme.accuracyTolerated
                       : Theme.accuracyExcellent
      }
    }

    Connections {
        target: mapCanvas.mapSettings

        function onExtentChanged() {
            if ( gnssButton.followActive ) {
                if ( gnssButton.followActiveSkipExtentChanged ) {
                    gnssButton.followActiveSkipExtentChanged = false;
                } else {
                    gnssButton.followActive = false
                    gnssButton.followOrientationActive = false
                    displayToast( qsTr( "Canvas stopped following location" ) )
                }
            }
        }

        function onRotationChanged() {
            if ( gnssButton.followOrientationActive ) {
                if ( gnssButton.followActiveSkipRotationChanged ) {
                    gnssButton.followActiveSkipRotationChanged = false
                } else {
                    gnssButton.followOrientationActive = false
                }
            }
        }
    }

    DigitizingToolbar {
      id: digitizingToolbar

      stateVisible: !screenLocker.enabled &&
                    ((stateMachine.state === "digitize"
                     && dashBoard.activeLayer
                     && !dashBoard.activeLayer.readOnly
                     // unfortunately there is no way to call QVariant::toBool in QML so the value is a string
                     && dashBoard.activeLayer.customProperty( 'QFieldSync/is_geometry_locked' ) !== 'true'
                     && !geometryEditorsToolbar.stateVisible
                     && !moveFeaturesToolbar.stateVisible
                     && (projectInfo.editRights || projectInfo.insertRights))
                    || stateMachine.state === 'measure'
                    || (stateMachine.state === "digitize" && digitizingToolbar.geometryRequested))
      rubberbandModel: currentRubberband ? currentRubberband.model : null
      mapSettings: mapCanvas.mapSettings
      showConfirmButton: stateMachine.state === "digitize"
      screenHovering: mapCanvasMap.hovered

      digitizingLogger.type: stateMachine.state === 'measure' ? '' : 'add'

      FeatureModel {
        id: digitizingFeature
        project: qgisProject
        currentLayer: digitizingToolbar.geometryRequested ? digitizingToolbar.geometryRequestedLayer : dashBoard.activeLayer
        positionInformation: positionSource.positionInformation
        topSnappingResult: coordinateLocator.topSnappingResult
        positionLocked: positionSource.active && positioningSettings.positioningCoordinateLock
        cloudUserInformation: cloudConnection.userInformation
        geometry: Geometry {
          id: digitizingGeometry
          rubberbandModel: digitizingRubberband.model
          vectorLayer: digitizingToolbar.geometryRequested ? digitizingToolbar.geometryRequestedLayer : dashBoard.activeLayer
        }
      }

      property string previousStateMachineState: ''
      onGeometryRequestedChanged: {
          if ( geometryRequested ) {
              digitizingRubberband.model.reset()
              previousStateMachineState = stateMachine.state
              stateMachine.state = "digitize"
          }
          else
          {
              stateMachine.state = previousStateMachineState
          }
      }

      onVertexCountChanged: {
        if ( stateMachine.state === 'measure' && elevationProfileButton.elevationProfileActive ) {
          if ( rubberbandModel.vertexCount > 2 ) {
            // Clear the pre-existing profile to trigger a zoom to full updated profile curve
            elevationProfile.clear();
            elevationProfile.profileCurve = GeometryUtils.lineFromRubberband(rubberbandModel, elevationProfile.crs)
            elevationProfile.refresh();
          }
        } else if( qfieldSettings.autoSave && stateMachine.state === "digitize" ) {
          if ( digitizingToolbar.geometryValid ) {
            if (digitizingRubberband.model.geometryType === Qgis.GeometryType.Null)
            {
              digitizingRubberband.model.reset()
            }
            else
            {
              digitizingFeature.geometry.applyRubberband()
              digitizingFeature.applyGeometry()
            }

            if ( !overlayFeatureFormDrawer.featureForm.featureCreated )
            {
                overlayFeatureFormDrawer.featureModel.geometry = digitizingFeature.geometry
                overlayFeatureFormDrawer.featureModel.applyGeometry()
                overlayFeatureFormDrawer.featureModel.resetAttributes()
                if( overlayFeatureFormDrawer.featureForm.model.constraintsHardValid ) {
                  // when the constrainst are fulfilled
                  // indirect action, no need to check for success and display a toast, the log is enough
                  overlayFeatureFormDrawer.featureForm.featureCreated = overlayFeatureFormDrawer.featureForm.create()
                }
            } else {
              // indirect action, no need to check for success and display a toast, the log is enough
              overlayFeatureFormDrawer.featureModel.geometry = digitizingFeature.geometry
              overlayFeatureFormDrawer.featureModel.applyGeometry()
              overlayFeatureFormDrawer.featureForm.save()
            }
          } else {
            if ( overlayFeatureFormDrawer.featureForm.featureCreated ) {
              // delete the feature when the geometry gets invalid again
              // indirect action, no need to check for success and display a toast, the log is enough
              overlayFeatureFormDrawer.featureForm.featureCreated = !overlayFeatureFormDrawer.featureForm.deleteFeature()
            }
          }
        }
      }

      onCancel: {
          if ( stateMachine.state === 'measure' && elevationProfileButton.elevationProfileActive ) {
              elevationProfile.clear()
              elevationProfile.refresh()
          } else {
              if ( geometryRequested ) {
                  if ( overlayFeatureFormDrawer.isAdding ) {
                      overlayFeatureFormDrawer.open()
                  }
                  geometryRequested = false
              }
          }
      }

      onConfirmed: {
        if ( geometryRequested )
        {
            if ( overlayFeatureFormDrawer.isAdding ) {
                overlayFeatureFormDrawer.open()
            }

            coordinateLocator.flash()
            digitizingFeature.geometry.applyRubberband()
            geometryRequestedItem.requestedGeometryReceived(digitizingFeature.geometry)
            digitizingRubberband.model.reset()
            geometryRequested = false
            return;
        }

        if (digitizingRubberband.model.geometryType === Qgis.GeometryType.Null)
        {
          digitizingRubberband.model.reset()
        }
        else
        {
          coordinateLocator.flash()
          digitizingFeature.geometry.applyRubberband()
          digitizingFeature.applyGeometry()
          digitizingRubberband.model.frozen = true
          digitizingFeature.updateRubberband()
        }

        if ( !digitizingFeature.suppressFeatureForm() )
        {
          overlayFeatureFormDrawer.featureModel.geometry = digitizingFeature.geometry
          overlayFeatureFormDrawer.featureModel.applyGeometry()
          overlayFeatureFormDrawer.featureModel.resetAttributes()
          overlayFeatureFormDrawer.open()
          overlayFeatureFormDrawer.state = "Add"
        }
        else
        {
          if ( !overlayFeatureFormDrawer.featureForm.featureCreated ) {
              overlayFeatureFormDrawer.featureModel.geometry = digitizingFeature.geometry
              overlayFeatureFormDrawer.featureModel.applyGeometry()
              overlayFeatureFormDrawer.featureModel.resetAttributes()
              if ( !overlayFeatureFormDrawer.featureModel.create() ) {
                displayToast( qsTr( "Failed to create feature!" ), 'error' )
              }
          } else {
              if ( !overlayFeatureFormDrawer.featureModel.save() ) {
                displayToast( qsTr( "Failed to save feature!" ), 'error' )
              }
          }
          digitizingRubberband.model.reset()
          digitizingFeature.resetFeature();
        }
      }
    }

    GeometryEditorsToolbar {
      id: geometryEditorsToolbar

      featureModel: geometryEditingFeature
      mapSettings: mapCanvas.mapSettings
      editorRubberbandModel: geometryEditorsRubberband.model
      editorRenderer: geometryEditorRenderer
      screenHovering: mapCanvasMap.hovered

      stateVisible: !screenLocker.enabled && (stateMachine.state === "digitize" && geometryEditingVertexModel.vertexCount > 0)
    }

    ConfirmationToolbar {
        id: moveFeaturesToolbar

        property bool moveFeaturesRequested: false
        property var startPoint: undefined // QgsPoint or undefined
        property var endPoint: undefined // QgsPoint or undefined
        signal moveConfirmed
        signal moveCanceled

        stateVisible: moveFeaturesRequested

        onConfirm: {
            endPoint = GeometryUtils.point(mapCanvas.mapSettings.center.x, mapCanvas.mapSettings.center.y)
            moveFeaturesRequested = false
            moveConfirmed()
        }
        onCancel: {
            startPoint = undefined
            endPoint = undefined
            moveFeaturesRequested = false
            moveCanceled()
        }

        function initializeMoveFeatures() {
            if ( featureForm  && featureForm.selection.model.selectedCount === 1 ) {
              featureForm.extentController.zoomToSelected()
            }

            startPoint = GeometryUtils.point(mapCanvas.mapSettings.center.x, mapCanvas.mapSettings.center.y)
            moveFeaturesRequested = true
        }
    }
  }

  BookmarkProperties {
    id: bookmarkProperties
  }

  Menu {
    id: mainMenu
    title: qsTr( "Main Menu" )

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return result + padding * 2;
    }

    MenuItem {
      text: qsTr( 'Measure Tool' )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_measurement_black_24dp" )
      height: 48
      leftPadding: 10

      onTriggered: {
        dashBoard.close()
        changeMode( 'measure' )
        highlighted = false
      }
    }

    MenuItem {
      id: printItem
      text: qsTr( "Print to PDF" )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_print_black_24dp" )
      height: 48
      leftPadding: 10
      rightPadding: 40

      arrow: Canvas {
          x: parent.width - width
          y: (parent.height - height) / 2
          implicitWidth: 40
          implicitHeight: 40
          opacity: layoutListInstantiator.count > 1 ? 1 : 0
          onPaint: {
              var ctx = getContext("2d")
              ctx.strokeStyle = Theme.mainColor
              ctx.lineWidth = 1
              ctx.moveTo(15, 15)
              ctx.lineTo(width - 15, height / 2)
              ctx.lineTo(15, height - 15)
              ctx.stroke();
          }
      }

      onTriggered: {
        if (layoutListInstantiator.count > 1)
        {
          printMenu.popup( mainMenu.x, mainMenu.y + printItem.y )
        }
        else if (layoutListInstantiator.count == 1)
        {
          mainMenu.close();
          displayToast( qsTr( 'Printing...') )
          printMenu.printName =layoutListInstantiator.model.titleAt( 0 );
          printMenu.printTimer.restart();
        }
        else
        {
          mainMenu.close();
          toast.show(qsTr('No print layout available'), 'info', qsTr('Learn more'), function() { Qt.openUrlExternally('https://docs.qfield.org/how-to/print-to-pdf/') })
        }
        highlighted = false
      }
    }

    MenuItem {
      id: sensorItem
      text: qsTr( "Sensors" )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_sensor_on_black_24dp" )
      height: 48
      leftPadding: 10
      rightPadding: 40

      arrow: Canvas {
          x: parent.width - width
          y: (parent.height - height) / 2
          implicitWidth: 40
          implicitHeight: 40
          opacity: sensorListInstantiator.count > 0 ? 1 : 0
          onPaint: {
              var ctx = getContext("2d")
              ctx.strokeStyle = Theme.mainColor
              ctx.lineWidth = 1
              ctx.moveTo(15, 15)
              ctx.lineTo(width - 15, height / 2)
              ctx.lineTo(15, height - 15)
              ctx.stroke();
          }
      }

      onTriggered: {
        if (sensorListInstantiator.count > 0) {
          sensorMenu.popup( mainMenu.x, mainMenu.y + sensorItem.y )
        } else {
          mainMenu.close();
          toast.show(qsTr('No sensor available'), 'info', qsTr('Learn more'), function() { Qt.openUrlExternally('https://docs.qfield.org/how-to/sensors/') })
        }
        highlighted = false
      }
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      id: openProjectMenuItem
      text: qsTr( "Go to Home Screen" )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_home_black_24dp" )
      height: 48
      leftPadding: 10

      onTriggered: {
        dashBoard.close()
        welcomeScreen.visible = true
        welcomeScreen.focus = true
        highlighted = false
      }
    }

    MenuItem {
      id: openProjectFolderMenuItem
      text: qsTr( "Open Project Folder" )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_folder_open_black_24dp" )
      height: 48
      leftPadding: 10

      onTriggered: {
        dashBoard.close()
        qfieldLocalDataPickerScreen.projectFolderView = true
        qfieldLocalDataPickerScreen.model.resetToPath(projectInfo.filePath)
        qfieldLocalDataPickerScreen.visible = true
      }
    }

    MenuItem {
      text: qsTr( 'Lock Screen' )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_lock_black_24dp" )
      height: 48
      leftPadding: 10

      onTriggered: {
        screenLocker.enabled = true
        dashBoard.close()
      }
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      text: qsTr( "Settings" )

      font: Theme.defaultFont
      height: 48
      leftPadding: 50

      onTriggered: {
        dashBoard.close()
        qfieldSettings.visible = true
        highlighted = false
      }
    }

    MenuItem {
      text: qsTr( "Message Log" )

      font: Theme.defaultFont
      height: 48
      leftPadding: 50

      onTriggered: {
        dashBoard.close()
        messageLog.visible = true
        highlighted = false
      }
    }

    MenuItem {
      text: qsTr( "About QField" )

      font: Theme.defaultFont
      height: 48
      leftPadding: 50

      onTriggered: {
        dashBoard.close()
        aboutDialog.visible = true
        highlighted = false
      }
    }
  }

  Menu {
    id: sensorMenu

    property alias printTimer: timer
    property alias printName: timer.printName

    title: qsTr( "Sensors" )

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return Math.min( result + padding * 2,mainWindow.width - 20);
    }

    MenuItem {
      text: qsTr( 'Select sensor below' )

      font: Theme.defaultFont
      height: 48
      leftPadding: 10

      enabled: false
    }

    Instantiator {
      id: sensorListInstantiator

      model: SensorListModel {
        project: qgisProject

        onSensorErrorOccurred: (errorString) => {
          displayToast(qsTr('Sensor error: %1').arg(errorString), 'error')
        }
      }

      MenuItem {
        text: SensorName
        icon.source: SensorStatus == Qgis.DeviceConnectionStatus.Connected
                     ? Theme.getThemeVectorIcon( "ic_sensor_on_black_24dp" )
                     : Theme.getThemeVectorIcon( "ic_sensor_off_black_24dp" )

        font: Theme.defaultFont
        leftPadding: 10

        onTriggered: {
          if (SensorStatus == Qgis.DeviceConnectionStatus.Connected) {
            displayToast( qsTr( 'Disconnecting sensor \'%1\'...').arg(SensorName) )
            sensorListInstantiator.model.disconnectSensorId(SensorId)
            highlighted = false
          } else {
            displayToast( qsTr( 'Connecting sensor \'%1\'...').arg(SensorName) )
            sensorListInstantiator.model.connectSensorId(SensorId)
            highlighted = false
          }
        }
      }

      onObjectAdded: (index, object) => { sensorMenu.insertItem(index+1, object) }
      onObjectRemoved: (index, object) => { sensorMenu.removeItem(object) }
    }
  }

  Menu {
    id: printMenu

    property alias printTimer: timer
    property alias printName: timer.printName

    title: qsTr( "Print" )

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return Math.min( result + padding * 2,mainWindow.width - 20);
    }

    MenuItem {
      text: qsTr( 'Select layout below' )

      font: Theme.defaultFont
      height: 48
      leftPadding: 10

      enabled: false
    }

    Instantiator {
      id: layoutListInstantiator

      model: PrintLayoutListModel {
        project: qgisProject
      }

      MenuItem {
        text: Title

        font: Theme.defaultFont
        leftPadding: 10

        onTriggered: {
            highlighted = false
            displayToast( qsTr( 'Printing...') )
            printMenu.printName = Title
            printMenu.printTimer.restart();
        }
      }
      onObjectAdded: (index, object) => { printMenu.insertItem(index+1, object) }
      onObjectRemoved: (index, object) => { printMenu.removeItem(object) }
    }

    Timer {
      id: timer

      property string printName: ''

      interval: 500
      repeat: false
      onTriggered: iface.print( printName )
    }
  }

  PositioningSettings {
    id: positioningSettings

    onPositioningActivatedChanged: {
      if ( positioningActivated ) {
        if ( platformUtilities.checkPositioningPermissions() ) {
          displayToast( qsTr( "Activating positioning service" ) )
          positionSource.active = true
        } else {
          displayToast( qsTr( "QField has no permissions to use positioning." ), 'warning' )
          positioningSettings.positioningActivated = false
        }
      } else {
          positionSource.active = false
      }
    }
  }

  Menu {
    id: canvasMenu
    title: qsTr( "Map Canvas Options" )
    font: Theme.defaultFont

    property var point
    onPointChanged: {
      var displayPoint = GeometryUtils.reprojectPoint(canvasMenu.point, mapCanvas.mapSettings.destinationCrs, projectInfo.coordinateDisplayCrs)
      var isXY = CoordinateReferenceSystemUtils.defaultCoordinateOrderForCrsIsXY(projectInfo.coordinateDisplayCrs);
      var isGeographic = projectInfo.coordinateDisplayCrs.isGeographic

      var xLabel = isGeographic ? qsTr( 'Lon' ) : 'X';
      var xValue = Number( displayPoint.x ).toLocaleString( Qt.locale(), 'f', isGeographic ? 7 : 3 )
      var yLabel = isGeographic ? qsTr( 'Lat' ) : 'Y'
      var yValue = Number( displayPoint.y ).toLocaleString( Qt.locale(), 'f', isGeographic ? 7 : 3 )
      xItem.text = isXY
                   ? xLabel + ': ' + xValue
                   : yLabel + ': ' + yValue
      yItem.text = isXY
                   ? yLabel + ': ' + yValue
                   : xLabel + ': ' + xValue
    }

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return Math.min( result + padding * 2,mainWindow.width - 20);
    }

    MenuItem {
        id: xItem
        text: ""
        height: 48
        font: Theme.defaultFont
        enabled:false
    }

    MenuItem {
        id: yItem
        text: ""
        height: 48
        font: Theme.defaultFont
        enabled:false
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      id: addBookmarkItem
      text: qsTr( "Add Bookmark" )
      icon.source: Theme.getThemeIcon( "ic_bookmark_black_24dp" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont

      onTriggered: {
        var name = qsTr('Untitled bookmark');
        var group = ''
        var id = bookmarkModel.addBookmarkAtPoint(canvasMenu.point, name, group);
        if (id !== '') {
          bookmarkProperties.bookmarkId = id;
          bookmarkProperties.bookmarkName = name;
          bookmarkProperties.bookmarkGroup = group;
          bookmarkProperties.open();
        }
      }
    }

    MenuItem {
      id: setDestinationItem
      text: qsTr( "Set as Destination" )
      icon.source: Theme.getThemeIcon( "ic_navigation_flag_purple_24dp" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont

      onTriggered: {
        navigation.destination = canvasMenu.point
      }
    }

    MenuItem {
      id: copyCoordinatesItem
      text: qsTr( "Copy Coordinates" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_copy_black_24dp" )

      onTriggered: {
        var displayPoint = GeometryUtils.reprojectPoint(canvasMenu.point, mapCanvas.mapSettings.destinationCrs, projectInfo.coordinateDisplayCrs)
        platformUtilities.copyTextToClipboard(StringUtils.pointInformation(displayPoint, projectInfo.coordinateDisplayCrs))
        displayToast(qsTr('Coordinates copied to clipboard'));
      }
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      text: qsTr( 'Lock Screen' )

      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_lock_black_24dp" )
      height: 48
      leftPadding: 10

      onTriggered: {
        screenLocker.enabled = true
      }
    }

    MenuSeparator {
      enabled: canvasMenuFeatureListInstantiator.count > 0
      width: parent.width
      visible: enabled
      height: enabled ? undefined : 0
    }

    Instantiator {
      id: canvasMenuFeatureListInstantiator

      model: MultiFeatureListModel {
        id: canvasMenuFeatureListModel
      }

      Menu {
        id: featureMenu

        property int fid: featureId
        property var featureLayer: currentLayer

        topMargin: sceneTopMargin
        bottomMargin: sceneBottomMargin

        title: layerName + ': ' + featureName
        font: Theme.defaultFont

        width: {
            var result = 0;
            var padding = 0;
            for (var i = 0; i < count; ++i) {
                var item = itemAt(i);
                result = Math.max(item.contentItem.implicitWidth, result);
                padding = Math.max(item.leftPadding, padding);
            }
            return Math.min(result + padding * 2,mainWindow.width - 20);
        }

        Component.onCompleted: {
          if (featureMenu.icon !== undefined) {
            featureMenu.icon.source = Theme.getThemeVectorIcon('ic_info_white_24dp')
          }
        }

        MenuItem {
          text: qsTr('Layer:') + ' ' + layerName
          enabled: false
        }
        MenuItem {
          text: qsTr('Feature:') + ' ' + featureName
          enabled: false
        }
        MenuSeparator { width: parent.width }

        MenuItem {
          text: qsTr('Open Feature Form')
          font: Theme.defaultFont
          icon.source: Theme.getThemeIcon( "ic_baseline-list_alt-24px" )
          leftPadding: 10

          onTriggered: {
            featureForm.model.setFeatures(menu.featureLayer, '$id = ' + menu.fid)
            featureForm.selection.focusedItem = 0
            featureForm.state = "FeatureForm"
          }
        }

        MenuItem {
          text: qsTr('Duplicate Feature')
          font: Theme.defaultFont
          enabled: projectInfo.insertRights
          icon.source: Theme.getThemeVectorIcon( "ic_duplicate_black_24dp" )
          leftPadding: 10

          onTriggered: {
            featureForm.model.setFeatures(menu.featureLayer, '$id = ' + menu.fid)
            featureForm.selection.focusedItem = 0
            featureForm.multiSelection = true
            featureForm.selection.toggleSelectedItem(0)
            featureForm.state = "FeatureList"
            if (featureForm.model.canDuplicateSelection) {
              if (featureForm.selection.model.duplicateFeature(featureForm.selection.focusedLayer,featureForm.selection.focusedFeature)) {
                displayToast(qsTr('Successfully duplicated feature'))

                featureForm.selection.focusedItem = -1
                moveFeaturesToolbar.initializeMoveFeatures()
                return;
              }
            }
            displayToast(qsTr('Feature duplication not available'))
          }
        }
      }

      onObjectAdded: (index, object) => { canvasMenu.insertMenu(index+9, object) }
      onObjectRemoved: (index, object) => { canvasMenu.removeMenu(object) }
    }
  }

  Menu {
    id: navigationMenu
    title: qsTr( "Navigation Options" )
    font: Theme.defaultFont

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.leftPadding + item.rightPadding, padding);
        }
        return Math.min(result + padding, mainWindow.width - 20);
    }

    MenuItem {
      id: preciseViewItem
      text: qsTr( "Precise View Settings" )

      font: Theme.defaultFont
      height: 48
      leftPadding: 10
      rightPadding: 40

      arrow: Canvas {
          x: parent.width - width
          y: (parent.height - height) / 2
          implicitWidth: 40
          implicitHeight: 40
          visible: true
          onPaint: {
              var ctx = getContext("2d")
              ctx.strokeStyle = Theme.mainColor
              ctx.lineWidth = 1
              ctx.moveTo(15, 15)
              ctx.lineTo(width - 15, height / 2)
              ctx.lineTo(15, height - 15)
              ctx.stroke();
          }
      }

      onTriggered: {
        preciseViewMenu.popup( navigationMenu.x, navigationMenu.y - preciseViewItem.y )
        highlighted = false
      }
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      id: cancelNavigationItem
      text: qsTr( "Clear Destination" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont

      onTriggered: {
        navigation.clear();
      }
    }
  }

  Menu {
    id: preciseViewMenu
    title: qsTr( "Precise View Settings" )
    font: Theme.defaultFont

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return Math.min( result + padding * 2,mainWindow.width - 20);
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(0.10, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 0.10
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 0.10
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(0.25, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 0.25
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 0.25
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(0.5, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 0.5
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 0.5
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(1, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 1
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 1
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(2.5, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 2.5
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 2.5
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(5, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 5
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 5
    }

    MenuItem {
      text: qsTr( "%1 Precision" ).arg(UnitTypes.formatDistance(10, 2, navigation.distanceUnits))
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      enabled: !checked
      checkable: true
      checked: positioningSettings.preciseViewPrecision == 10
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: if (checked) positioningSettings.preciseViewPrecision = 10
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      text: qsTr( "Always Show Precise View" )
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      checkable: true
      checked: positioningSettings.alwaysShowPreciseView
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: positioningSettings.alwaysShowPreciseView = checked
    }

    MenuItem {
      text: qsTr( "Enable Audio Proximity Feedback" )
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      checkable: true
      checked: positioningSettings.preciseViewProximityAlarm
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: positioningSettings.preciseViewProximityAlarm = checked
    }
  }

  Menu {
    id: gnssMenu
    title: qsTr( "Positioning Options" )
    font: Theme.defaultFont

    topMargin: sceneTopMargin
    bottomMargin: sceneBottomMargin

    width: {
        var result = 0;
        var padding = 0;
        for (var i = 0; i < count; ++i) {
            var item = itemAt(i);
            result = Math.max(item.contentItem.implicitWidth, result);
            padding = Math.max(item.padding, padding);
        }
        return Math.max(10, Math.min(result + padding * 2,mainWindow.width - 20));
    }

    MenuItem {
        id: positioningDeviceName
        text: positioningSettings.positioningDeviceName
        height: 48
        font: Theme.defaultFont
        enabled:false
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      id: positioningItem
      text: qsTr( "Enable Positioning" )
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      checkable: true
      checked: positioningSettings.positioningActivated
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: positioningSettings.positioningActivated = checked
    }

    MenuItem {
      text: qsTr( "Show Position Information" )
      height: 48
      leftPadding: 15
      font: Theme.defaultFont

      checkable: true
      checked: positioningSettings.showPositionInformation
      indicator.height: 20
      indicator.width: 20
      indicator.implicitHeight: 24
      indicator.implicitWidth: 24
      onCheckedChanged: positioningSettings.showPositionInformation = checked
    }

    MenuItem {
      text: qsTr( "Positioning Settings" )
      height: 48
      leftPadding: 50
      font: Theme.defaultFont

      onTriggered: {
        qfieldSettings.currentPanel = 1
        qfieldSettings.visible = true
      }
    }

    MenuSeparator { width: parent.width }

    MenuItem {
      text: qsTr( "Center to Location" )
      height: 48
      leftPadding: 50
      font: Theme.defaultFont

      onTriggered: {
        mapCanvas.mapSettings.setCenter(positionSource.projectedPosition)
      }
    }

    MenuItem {
      text: qsTr( "Add Bookmark at Location" )
      icon.source: Theme.getThemeIcon( "ic_bookmark_black_24dp" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont

      onTriggered: {
        if (!positioningSettings.positioningActivated || positionSource.positionInformation === undefined || !positionSource.positionInformation.latitudeValid) {
          displayToast(qsTr('Current location unknown'));
          return;
        }

        var name = qsTr('My location') + ' (' + new Date().toLocaleString() + ')';
        var group = 'blue';
        var id = bookmarkModel.addBookmarkAtPoint(positionSource.projectedPosition, name, group)
        if (id !== '') {
          bookmarkProperties.bookmarkId = id;
          bookmarkProperties.bookmarkName = name;
          bookmarkProperties.bookmarkGroup = group;
          bookmarkProperties.open();
        }
      }
    }

    MenuItem {
      text: qsTr( "Copy Location Coordinates" )
      height: 48
      leftPadding: 10
      font: Theme.defaultFont
      icon.source: Theme.getThemeVectorIcon( "ic_copy_black_24dp" )

      onTriggered: {
        if (!positioningSettings.positioningActivated || positionSource.positionInformation === undefined || !positionSource.positionInformation.latitudeValid) {
          displayToast(qsTr('Current location unknown'));
          return;
        }

        var point = GeometryUtils.reprojectPoint(positionSource.sourcePosition, CoordinateReferenceSystemUtils.wgs84Crs(), projectInfo.coordinateDisplayCrs)
        var coordinates = StringUtils.pointInformation(point, projectInfo.coordinateDisplayCrs)
        coordinates += ' ('+ qsTr('Accuracy') + ' ' +
                       ( positionSource.positionInformation && positionSource.positionInformation.haccValid
                         ? positionSource.positionInformation.hacc.toLocaleString(Qt.locale(), 'f', 3) + " m"
                         : qsTr( "N/A" ) ) + ')';

        platformUtilities.copyTextToClipboard(coordinates)
        displayToast(qsTr('Current location copied to clipboard'));
      }
    }
  }

  /* The feature form */
  FeatureListForm {
    id: featureForm

    objectName: "featureForm"
    mapSettings: mapCanvas.mapSettings
    digitizingToolbar: digitizingToolbar
    moveFeaturesToolbar: moveFeaturesToolbar
    codeReader: codeReader

    focus: visible

    anchors { right: parent.right; bottom: parent.bottom }

    allowEdit: stateMachine.state === "digitize"
    allowDelete: stateMachine.state === "digitize"

    model: MultiFeatureListModel {}

    selection: FeatureListModelSelection {
      id: featureListModelSelection
      model: featureForm.model
    }

    selectionColor: "#ff7777"

    onShowMessage: displayToast(message)

    onEditGeometry: {
      // Set overall selected (i.e. current) layer to that of the feature geometry being edited,
      // important for snapping settings to make sense when set to current layer
      if ( dashBoard.activeLayer != featureForm.selection.focusedLayer ) {
        dashBoard.activeLayer = featureForm.selection.focusedLayer
        displayToast( qsTr( "Current layer switched to the one holding the selected geometry." ) );
      }
      geometryEditingFeature.vertexModel.geometry = featureForm.selection.focusedGeometry
      geometryEditingFeature.vertexModel.crs = featureForm.selection.focusedLayer.crs
      geometryEditingFeature.currentLayer = featureForm.selection.focusedLayer
      geometryEditingFeature.feature = featureForm.selection.focusedFeature

      if (!geometryEditingVertexModel.editingAllowed)
      {
        displayToast( qsTr( "Editing of multi geometry layer is not supported yet." ) )
        geometryEditingVertexModel.clear()
      }
      else
      {
        featureForm.state = "Hidden"
      }

      geometryEditorsToolbar.init()
    }

    Component.onCompleted: focusstack.addFocusTaker( this )

    //that the focus is set by selecting the empty space
    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      enabled: !parent.activeFocus

      //onPressed because onClicked shall be handled in underlying MouseArea
      onPressed: (mouse) => {
        parent.focus=true
        mouse.accepted=false
      }
    }
  }

  OverlayFeatureFormDrawer {
    id: overlayFeatureFormDrawer
    digitizingToolbar: digitizingToolbar
    codeReader: codeReader
    featureModel.currentLayer: dashBoard.activeLayer
  }

  function displayToast( message, type ) {
    //toastMessage.text = message
    if( !welcomeScreen.visible )
      toast.show(message, type)
  }

  Timer {
    id: readProjectTimer

    interval: 250
    repeat: false
    onTriggered: iface.readProject()
  }

  Connections {
    target: iface

    function onVolumeKeyUp(volumeKeyCode) {
      if (stateMachine.state === 'browse' || !mapCanvasMap.isEnabled) {
        return;
      }

      switch (volumeKeyCode) {
        case  Qt.Key_VolumeDown:
          if (mapCanvasMap.interactive) {
            digitizingToolbar.removeVertex();
          }
          break;
        case Qt.Key_VolumeUp:
          if (!geometryEditorsToolbar.canvasClicked(coordinateLocator.currentCoordinate)) {
            digitizingToolbar.triggerAddVertex();
          }
          break;
        default:
          break;
      }
    }

    function onImportTriggered(name) {
      busyOverlay.text = qsTr("Importing %1").arg(name)
      busyOverlay.state = "visible"
    }

    function onImportProgress(progress) {
      busyOverlay.progress = progress;
    }

    function onImportEnded(path) {
      busyOverlay.state = "hidden"
      if (path !== '') {
        qfieldLocalDataPickerScreen.model.currentPath = path
        qfieldLocalDataPickerScreen.visible = true
        welcomeScreen.visible = false
      } else {
        displayToast(qsTr('Import URL failed'))
      }
    }

    function onLoadProjectTriggered(path,name) {
      qfieldLocalDataPickerScreen.visible = false
      qfieldLocalDataPickerScreen.focus = false
      welcomeScreen.visible = false
      welcomeScreen.focus = false

      if (changelogPopup.visible)
        changelogPopup.close()

      dashBoard.layerTree.freeze()
      mapCanvasMap.freeze('projectload')

      busyOverlay.text = qsTr( "Loading %1" ).arg( name !== '' ? name : path )
      busyOverlay.state = "visible"

      navigation.clearDestinationFeature();

      projectInfo.filePath = '';
      readProjectTimer.start()
    }

    function onLoadProjectEnded(path,name) {
      mapCanvasMap.unfreeze('projectload')
      busyOverlay.state = "hidden"

      projectInfo.filePath = path
      stateMachine.state = projectInfo.stateMode
      platformUtilities.setHandleVolumeKeys(qfieldSettings.digitizingVolumeKeys && stateMachine.state != 'browse')
      dashBoard.activeLayer = projectInfo.activeLayer

      mapCanvasBackground.color = mapCanvas.mapSettings.backgroundColor

      recentProjectListModel.reloadModel()

      var cloudProjectId = QFieldCloudUtils.getProjectId(qgisProject.fileName)
      cloudProjectsModel.currentProjectId = cloudProjectId
      cloudProjectsModel.refreshProjectModification(cloudProjectId)
      if (cloudProjectId !== '') {
        var cloudProjectData = cloudProjectsModel.getProjectData(cloudProjectId)
        switch(cloudProjectData.UserRole) {
          case 'reader':
            stateMachine.state = "browse"
            projectInfo.hasInsertRights = false
            projectInfo.hasEditRights = false
            break;
          case 'reporter':
            projectInfo.hasInsertRights = true
            projectInfo.hasEditRights = false
            break;
          case 'editor':
          case 'manager':
          case 'admin':
            projectInfo.hasInsertRights = true
            projectInfo.hasEditRights = true
            break;
          default:
            projectInfo.hasInsertRights = true
            projectInfo.hasEditRights = true
            break;
        }

        if (cloudProjectsModel.layerObserver.deltaFileWrapper.hasError()) {
          cloudPopup.show()
        }
      } else {
        projectInfo.hasInsertRights = true
        projectInfo.hasEditRights = true
      }

      if (stateMachine.state === "digitize") {
          dashBoard.ensureEditableLayerSelected();
      }

      var distanceString = iface.readProjectEntry("Measurement" ,"/DistanceUnits", "")
      projectInfo.distanceUnits = distanceString !== "" ? UnitTypes.decodeDistanceUnit(distanceString) : Qgis.DistanceUnit.Meters
      var areaString = iface.readProjectEntry("Measurement" ,"/AreaUnits", "")
      projectInfo.areaUnits = areaString !== "" ? UnitTypes.decodeAreaUnit(areaString) : Qgis.AreaUnit.SquareMeters

      if (qgisProject.displaySettings) {
        projectInfo.coordinateDisplayCrs = qgisProject.displaySettings.coordinateCrs
      } else {
        projectInfo.coordinateDisplayCrs = !mapCanvas.mapSettings.destinationCrs.isGeographic
                                           && iface.readProjectEntry("PositionPrecision", "/DegreeFormat", "MU") !== "MU"
                                           ? CoordinateReferenceSystemUtils.wgs84Crs()
                                           : mapCanvas.mapSettings.destinationCrs
      }

      layoutListInstantiator.model.reloadModel()

      settings.setValue( "/QField/FirstRunFlag", false )
    }

    function onSetMapExtent(extent) {
        mapCanvas.mapSettings.extent = extent;
    }
  }

  ProjectInfo {
    id: projectInfo

    mapSettings: mapCanvas.mapSettings
    layerTree: dashBoard.layerTree
    trackingModel: trackings.model

    property var distanceUnits: Qgis.DistanceUnit.Meters
    property var areaUnits: Qgis.AreaUnit.SquareMeters
    property var coordinateDisplayCrs: CoordinateReferenceSystemUtils.wgs84Crs()

    property bool hasInsertRights: true
    property bool hasEditRights: true

    property bool insertRights: hasInsertRights && (cloudProjectsModel.currentProjectId == '' || cloudProjectsModel.currentProjectData.Status === QFieldCloudProjectsModel.Idle)
    property bool editRights: hasEditRights && (cloudProjectsModel.currentProjectId == '' || cloudProjectsModel.currentProjectData.Status === QFieldCloudProjectsModel.Idle)
  }

  BusyIndicator {
    id: busyIndicator
    anchors.left: mainMenuBar.left
    anchors.top: mainToolbar.bottom
    width: menuButton.width + 10
    height: width
    running: mapCanvasMap.isRendering
  }

  MessageLog {
    id: messageLog
    objectName: 'messageLog'

    anchors.fill: parent
    focus: visible
    visible: false

    model: messageLogModel

    onFinished: {
      visible = false
    }

    Keys.onReleased: (event) => {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        visible = false
      }
    }

    Component.onCompleted: {
      focusstack.addFocusTaker( this )
      unreadMessages = messageLogModel.rowCount() !== 0
    }
  }

  BadLayerItem {
    id: badLayersView

    anchors.fill: parent
    model: BadLayerHandler {
      project: qgisProject

      onBadLayersFound: {
        badLayersView.visible = true
      }
    }

    visible: false

    onFinished: {
      visible = false
    }
  }

  Item {
    id: layerLogin

    Connections {
      target: iface

      function onLoadProjectEnded() {
        dashBoard.layerTree.unfreeze( true );
        if( !qfieldAuthRequestHandler.handleLayerLogins() )
        {
          //project loaded without more layer handling needed
          messageLogModel.unsuppressTags(["WFS","WMS"])
        }
      }
    }
    Connections {
        target: iface

        function onLoadProjectTriggered(path) {
          messageLogModel.suppressTags(["WFS","WMS"])
        }
    }

    Connections {
      target: qfieldAuthRequestHandler

      function onShowLoginDialog(realm) {
          loginDialogPopup.realm = realm || ""
          badLayersView.visible = false
          loginDialogPopup.open()
      }

      function onReloadEverything() {
          iface.reloadProject()
      }

      function onShowLoginBrowser(url) {
          browserPopup.url = url;
          browserPopup.fullscreen = false;
          browserPopup.clearCookiesOnOpen = true
          browserPopup.open();
      }

      function onHideLoginBrowser() {
          browserPopup.close();
      }
    }

    BrowserPanel {
      id: browserPopup
      parent: ApplicationWindow.overlay

      onCancel: {
        qfieldAuthRequestHandler.abortAuthBrowser();
        browserPopup.close();
      }
    }

    Popup {
      id: loginDialogPopup
      parent: ApplicationWindow.overlay

      property var realm: ""

      x: 24
      y: 24
      width: parent.width - 48
      height: parent.height - 48
      padding: 0
      modal: true
      closePolicy: Popup.CloseOnEscape

      LayerLoginDialog {
        id: loginDialog

        anchors.fill: parent

        visible: true

        realm: loginDialogPopup.realm
        inCancelation: false

        onEnter: {
          qfieldAuthRequestHandler.enterCredentials( realm, usr, pw)
          inCancelation = false;
          loginDialogPopup.close()
        }
        onCancel: {
          inCancelation = true;
          loginDialogPopup.close(true)
        }
      }

      onClosed: {
        // handled here with parameter inCancelation because the loginDialog needs to be closed before the signal is fired
        qfieldAuthRequestHandler.loginDialogClosed(loginDialog.realm, loginDialog.inCancelation )
      }
    }

  }

  About {
    id: aboutDialog
    anchors.fill: parent
    focus: visible

    visible: false

    Keys.onReleased: (event) => {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        visible = false
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  TrackerSettings {
    id: trackerSettings
  }

  QFieldSettings {
    id: qfieldSettings

    anchors.fill: parent
    visible: false
    focus: visible

    onFinished: {
      visible = false
    }

    Keys.onReleased: (event) => {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        event.accepted = true
        finished()
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  QFieldCloudConnection {
    id: cloudConnection

    property int previousStatus: QFieldCloudConnection.Disconnected

    onStatusChanged: {
      if (cloudConnection.status === QFieldCloudConnection.Disconnected && previousStatus === QFieldCloudConnection.LoggedIn) {
        displayToast(qsTr('Signed out'))
      } else if (cloudConnection.status === QFieldCloudConnection.Connecting) {
        displayToast(qsTr('Connecting...'))
      } else if (cloudConnection.status === QFieldCloudConnection.LoggedIn) {
        displayToast(qsTr('Signed in'))
        // Go ahead and upload pending attachments in the background
        platformUtilities.uploadPendingAttachments(cloudConnection);
      }
      previousStatus = cloudConnection.status
    }
    onLoginFailed: function(reason) { displayToast( reason ) }
  }

  QFieldCloudProjectsModel {
    id: cloudProjectsModel
    cloudConnection: cloudConnection
    layerObserver: layerObserverAlias
    gpkgFlusher: gpkgFlusherAlias

    onProjectDownloaded: function ( projectId, projectName, hasError, errorString ) {
      return hasError
          ? displayToast( qsTr( "Project %1 failed to download" ).arg( projectName ), 'error' )
          : displayToast( qsTr( "Project %1 successfully downloaded, it's now available to open" ).arg( projectName ) );
    }

    onPushFinished: function ( projectId, hasError, errorString ) {
      if ( hasError ) {
        displayToast( qsTr( "Changes failed to reach QFieldCloud: %1" ).arg( errorString ), 'error' )
        return;
      }

      displayToast( qsTr( "Changes successfully pushed to QFieldCloud" ) )

      // Go ahead and upload pending attachments in the background
      platformUtilities.uploadPendingAttachments(cloudConnection);
    }

    onWarning: displayToast( message )

    onDeltaListModelChanged: function () {
      qfieldCloudDeltaHistory.model = cloudProjectsModel.currentProjectData.DeltaList
    }
  }

  QFieldCloudDeltaHistory {
      id: qfieldCloudDeltaHistory

      modal: true
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
      parent: ApplicationWindow.overlay
  }

  QFieldCloudScreen {
    id: qfieldCloudScreen

    anchors.fill: parent
    visible: false
    focus: visible

    onFinished: {
      visible = false
      welcomeScreen.visible = true
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  QFieldCloudPopup {
    id: cloudPopup
    visible: false
    focus: visible
    parent: ApplicationWindow.overlay

    width: parent.width
    height: parent.height
  }

  QFieldCloudPackageLayersFeedback {
    id: cloudPackageLayersFeedback
    visible: false
    parent: ApplicationWindow.overlay

    width: parent.width
    height: parent.height
  }

  QFieldLocalDataPickerScreen {
    id: qfieldLocalDataPickerScreen

    anchors.fill: parent
    visible: false
    focus: visible

    onFinished: {
      visible = false
      if (model.currentPath === 'root') {
        welcomeScreen.visible = loading ? false : true
      }
    }

    Component.onCompleted: focusstack.addFocusTaker( this )
  }

  WelcomeScreen {
    id: welcomeScreen
    objectName: 'welcomeScreen'
    visible: !iface.hasProjectOnLaunch()

    model: RecentProjectListModel {
      id: recentProjectListModel
    }
    property ProjectSource __projectSource

    anchors.fill: parent
    focus: visible

    onOpenLocalDataPicker: {
      if (platformUtilities.capabilities & PlatformUtilities.CustomLocalDataPicker) {
        welcomeScreen.visible = false
        qfieldLocalDataPickerScreen.projectFolderView = false
        qfieldLocalDataPickerScreen.model.resetToRoot()
        qfieldLocalDataPickerScreen.visible = true
      } else {
        __projectSource = platformUtilities.openProject(this)
      }
    }

    onShowQFieldCloudScreen: {
      welcomeScreen.visible = false
      qfieldCloudScreen.visible = true
    }

    Keys.onReleased: (event) => {
      if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
        if ( qgisProject.fileName != '') {
          event.accepted = true
          visible = false
          focus = false
        } else {
          event.accepted = false
          mainWindow.close()
        }
      }
    }

    Component.onCompleted: {
      focusstack.addFocusTaker( this )
    }
  }

  Changelog {
    id: changelogPopup
    objectName: 'changelogPopup'

    parent: ApplicationWindow.overlay

    property var expireDate: new Date(2038,1,19)
    visible: settings && settings.value( "/QField/ChangelogVersion", "" ) !== appVersion && expireDate > new Date()
  }

  Toast {
    id: toast
  }

  MouseArea {
    id: codeReaderCatcher
    anchors.fill: parent
    enabled: codeReader.visible

    onClicked: (mouse) => {
      // Needed to avoid people interacting with the UI while the barcode reader is visible
      // (e.g. close the feature form while scanning a code to fill an attribute)
      return;
    }
  }

  CodeReader {
    id: codeReader
    visible: false
  }

  Connections {
    target: locatorItem

    function onSearchTermChanged(searchTerm) {
      var lowered = searchTerm.toLowerCase();
      if ( lowered === 'hello nyuki') {
        Qt.inputMethod.hide();
        locatorItem.searchTermHandled = true;
        nyuki.state = "shown";
      } else if (lowered === 'bye nyuki') {
        Qt.inputMethod.hide();
        locatorItem.searchTermHandled = true;
        nyuki.state = "hidden";
      }
    }
  }

  Nyuki {
    id: nyuki
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -200
    anchors.left: parent.left
    width: 200
    height: 200
  }

  DropArea {
    id: dropArea
    anchors.fill: parent
    onEntered: (drag) => {
      if ( drag.urls.length !== 1 || !iface.isFileExtensionSupported( drag.urls[0] ) ) {
          drag.accepted = false
      }
      else {
        drag.accept (Qt.CopyAction)
        drag.accepted = true
      }
    }
    onDropped: (drop) => {
      iface.loadFile( drop.urls[0] )
    }
  }

  BusyOverlay {
    id: busyOverlay
    state: iface.hasProjectOnLaunch() ? "visible" : "hidden"
  }

  property bool alreadyCloseRequested: false

  onClosing: (close) => {
      if( !alreadyCloseRequested )
      {
        close.accepted = false
        alreadyCloseRequested = true
        displayToast( qsTr( "Press back again to close project and app" ) )
        closingTimer.start()
      }
      else
      {
        close.accepted = true
      }
  }

  Timer {
    id: closingTimer
    interval: 2000
    onTriggered: {
        alreadyCloseRequested = false
    }
  }

  Connections {
    target: welcomeScreen.__projectSource

    function onProjectOpened(path) {
      iface.loadFile(path)
    }
  }

  // ! MODELS !
  FeatureModel {
    id: geometryEditingFeature
    project: qgisProject
    currentLayer: null
    positionInformation: positionSource.positionInformation
    positionLocked: positionSource.active && positioningSettings.positioningCoordinateLock
    vertexModel: geometryEditingVertexModel
    cloudUserInformation: cloudConnection.userInformation
  }

  VertexModel {
    id: geometryEditingVertexModel
    currentPoint: coordinateLocator.currentCoordinate
    mapSettings: mapCanvas.mapSettings
    isHovering: mapCanvasMap.hovered
  }

  ScreenLocker {
    id: screenLocker
    enabled: false
  }
}
