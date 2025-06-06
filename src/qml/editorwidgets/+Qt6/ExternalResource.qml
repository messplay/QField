import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import QtQuick.Window 2.14
import QtMultimedia

import org.qgis 1.0
import org.qfield 1.0
import Theme 1.0
import QFieldControls 1.0

import "."
import ".."

EditorWidgetBase {
  anchors.left: parent.left
  anchors.right: parent.right

  height: childrenRect.height + 4

  ExpressionEvaluator {
    id: rootPathEvaluator
  }
  property string prefixToRelativePath: {
    if (qgisProject == undefined)
      return "";

    var path = ""
    if (config["RelativeStorage"] === 1 ) {
      path = qgisProject.homePath
      if (!path.endsWith("/")) path = path +  "/"
    } else if (config["RelativeStorage"] === 2 ) {
      var collection = config["PropertyCollection"]
      var props = collection["properties"]
      if (props) {
        if(props["propertyRootPath"]) {
          var rootPathProps = props["propertyRootPath"]
          rootPathEvaluator.expressionText = rootPathProps["expression"]
        }
      }
      rootPathEvaluator.feature = currentFeature
      rootPathEvaluator.layer = currentLayer
      var evaluatedFilepath = rootPathEvaluator.evaluate().replace("\\", "/")
      if (evaluatedFilepath) {
        path = evaluatedFilepath
      } else {
        path = config["DefaultRoot"] ? config["DefaultRoot"] : qgisProject.homePath
        if (!path.endsWith("/")) path = path +  "/"
      }
    }

    // since we've hardcoded the project path by default so far, let's maintain that until we improve things in qfieldsync
    if (path == "") {
      path = qgisProject.homePath
      if (!path.endsWith("/")) path = path +  "/"
    }

    return path
  }

  property ResourceSource __resourceSource
  property ViewStatus __viewStatus

  // DocumentViewer values
  readonly property int document_FILE: 0
  readonly property int document_IMAGE: 1
  readonly property int document_WEB: 2 // TODO: implement
  readonly property int document_AUDIO: 3
  readonly property int document_VIDEO: 4
  property int documentViewer: config.DocumentViewer

  property bool isImage: false
  property bool isAudio: false
  property bool isVideo: false

  //to not break any binding of image.source
  property var currentValue: value
  onCurrentValueChanged: {
    isImage = !config.UseLink && FileUtils.mimeTypeName(prefixToRelativePath + value ).startsWith("image/")
    isAudio = !config.UseLink && FileUtils.mimeTypeName(prefixToRelativePath + value).startsWith("audio/")
    isVideo = !config.UseLink && FileUtils.mimeTypeName(prefixToRelativePath + value).startsWith("video/")

    if (currentValue != undefined && currentValue !== '') {
      image.visible = isImage
      geoTagBadge.visible = isImage
      if (isImage) {
        mediaFrame.height = 200

        image.visible = true
        image.hasImage = true
        image.opacity = 1
        image.anchors.topMargin = 0
        image.source = 'file://' + prefixToRelativePath + value
        geoTagBadge.hasGeoTag = ExifTools.hasGeoTag(prefixToRelativePath + value)
      } else if (isAudio || isVideo) {
        mediaFrame.height = 48
        player.source = 'file://' + prefixToRelativePath + value
      }
    } else {
      image.source = ''
      image.visible = documentViewer == document_IMAGE
      image.opacity = 0.15
      geoTagBadge.visible = false
      mediaFrame.height = 48
    }
  }

  ExpressionEvaluator {
    id: expressionEvaluator
    feature: currentFeature
    layer: currentLayer
    expressionText: {
      var value;
      if (currentLayer && currentLayer.customProperty('QFieldSync/attachment_naming') !== undefined) {
        value = JSON.parse(currentLayer.customProperty('QFieldSync/attachment_naming'))[field.name];
        return value !== undefined ? value : ''
      } else if (currentLayer && currentLayer.customProperty('QFieldSync/photo_naming') !== undefined) {
        // Fallback to old configuration key
        value = JSON.parse(currentLayer.customProperty('QFieldSync/photo_naming'))[field.name];
        return value !== undefined ? value : ''
      }
      return ''
    }
  }

  function getResourceFilePath() {
    var evaluatedFilepath = expressionEvaluator.evaluate()
    var filepath = evaluatedFilepath;
    if (FileUtils.fileSuffix(evaluatedFilepath) === '') {
      // we need an extension for media types (image, audio, video), fallback to hardcoded values
      if (documentViewer == document_IMAGE) {
        filepath = 'DCIM/JPEG_' + (new Date()).toISOString().replace(/[^0-9]/g, '') + '.{extension}';
      } else if (documentViewer == document_AUDIO) {
        filepath = 'audio/AUDIO_' + (new Date()).toISOString().replace(/[^0-9]/g, '') + '.{extension}';
      } else if (documentViewer == document_VIDEO) {
        filepath = 'video/VIDEO_' + (new Date()).toISOString().replace(/[^0-9]/g, '') + '.{extension}';
      } else {
        filepath = 'files/' + (new Date()).toISOString().replace(/[^0-9]/g, '') + '_{filename}';
      }
    }
    filepath = filepath.replace('\\', '/')
    return filepath;
  }

  Label {
    id: linkField

    topPadding: 10
    bottomPadding: 10
    height: fontMetrics.height + 30

    property bool hasValue: false
    visible: hasValue && !isImage && !isAudio && !isVideo

    anchors.left: parent.left
    anchors.right: cameraButton.left
    color: FileUtils.fileExists(prefixToRelativePath + value) ? Theme.mainColor : 'gray'

    text: {
      var fieldValue = prefixToRelativePath + currentValue
      if (UrlUtils.isRelativeOrFileUrl(fieldValue)) {
        fieldValue = config.FullUrl ? fieldValue : FileUtils.fileName(fieldValue)
      }
      fieldValue = StringUtils.insertLinks(fieldValue)

      hasValue = currentValue !== undefined && !!fieldValue
      return hasValue ? fieldValue : qsTr('No Value')
    }

    font.pointSize: Theme.defaultFont.pointSize
    font.italic: !hasValue
    font.underline: FileUtils.fileExists(prefixToRelativePath + value) || FileUtils.fileExists(value)
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideMiddle

    background: Rectangle {
      y: linkField.height - height - linkField.bottomPadding / 2
      implicitWidth: 120
      height: 1
      color: Theme.accentLightColor
    }

    MouseArea {
      anchors.fill: parent

      onClicked: {
        if ( !value )
          return

        if (!UrlUtils.isRelativeOrFileUrl(value)) { // matches `http://...` but not `file://...` paths
          Qt.openUrlExternally(value)
        } else if (FileUtils.fileExists(prefixToRelativePath + value)) {
          __viewStatus = platformUtilities.open(prefixToRelativePath + value, isEnabled)
        }
      }
    }
  }

  FontMetrics {
    id: fontMetrics
    font: linkField.font
  }

  Rectangle {
    id: mediaFrame
    width: parent.width - fileButton.width - galleryButton.width - cameraButton.width - cameraVideoButton.width - microphoneButton.width - (isEnabled ? 5 : 0)
    height: 48
    visible: !linkField.visible
    color: isEnabled ? Theme.controlBackgroundAlternateColor : "transparent"
    radius: 2
    clip: true

    Image {
      id: image

      property bool hasImage: false

      visible: isImage
      enabled: isImage
      anchors.centerIn: parent
      width: hasImage ? parent.width : 24
      height: hasImage ? parent.height : 24
      opacity: 0.25
      autoTransform: true
      fillMode: Image.PreserveAspectFit
      horizontalAlignment: Image.AlignHCenter
      verticalAlignment: Image.AlignVCenter

      source: Theme.getThemeIcon("ic_photo_notavailable_black_24dp")
      cache: false

      Image {
        property bool hasGeoTag: false
        id: geoTagBadge
        visible: false
        anchors.top: image.top
        anchors.right: image.right
        anchors.rightMargin: 10
        anchors.topMargin: 12
        fillMode: Image.PreserveAspectFit
        width: 24
        height: 24
        source: hasGeoTag ? Theme.getThemeIcon("ic_geotag_24dp") : Theme.getThemeIcon("ic_geotag_missing_24dp")
        sourceSize.width: 24 * Screen.devicePixelRatio
        sourceSize.height: 24 * Screen.devicePixelRatio
      }

      QfDropShadow {
        anchors.fill: geoTagBadge
        visible: geoTagBadge.visible
        horizontalOffset: 0
        verticalOffset: 0
        radius: 6.0
        color: "#DD000000"
        source: geoTagBadge
      }
    }

    Loader {
      id: player
      active: isAudio || isVideo

      property string source: ''

      anchors.left: parent.left
      anchors.top: parent.top

      width: parent.width
      height: parent.height - 54

      sourceComponent: Component {
        Video {
          visible: isVideo

          anchors.fill: parent

          property bool firstFrameDrawn: false

          source: player.source

          onHasVideoChanged: {
            mediaFrame.height = hasVideo ? 254 : 48
            firstFrameDrawn = false
            if (hasVideo) {
              play();
            }
          }

          onDurationChanged: {
            positionSlider.to = duration / 1000;
            positionSlider.value = 0;
          }

          onPositionChanged: {
            if (!firstFrameDrawn && playbackState == MediaPlayer.PlayingState) {
              firstFrameDrawn = true;
              pause();
            }
            positionSlider.value = position / 1000;
          }
        }
      }
    }

    MouseArea {
      enabled: mediaFrame.visible
      width: parent.width
      height: playerControls.visible
              ? player.height - 54
              : image.height

      onClicked: {
        if ( FileUtils.fileExists( prefixToRelativePath + value ) ) {
          __viewStatus = platformUtilities.open( prefixToRelativePath + value, isEnabled );
        }
      }
    }

    RowLayout {
      id: playerControls

      visible: player.active && player.item.duration > 0

      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: 5
      anchors.rightMargin: 5
      width: parent.width - 10

      QfToolButton {
        id: playButton

        iconSource: player.active && player.item.playbackState === MediaPlayer.PlayingState
                    ? Theme.getThemeVectorIcon('ic_pause_black_24dp')
                    : Theme.getThemeVectorIcon('ic_play_black_24dp')
        iconColor: Theme.mainTextColor
        bgcolor: "transparent"

        onClicked: {
          if (player.item.playbackState === MediaPlayer.PlayingState) {
            player.item.pause()
          } else {
            player.item.play()
          }
        }
      }

      Slider {
        id: positionSlider
        Layout.fillWidth: true

        from: 0
        to: 0

        enabled: to > 0

        onMoved: {
          player.item.seek(value * 1000)
        }
      }

      Label {
        id: durationLabel
        Layout.preferredWidth: durationLabelMetrics.boundingRect('00:00:00').width
        Layout.rightMargin: 14

        color: player.active && player.item.playbackState === MediaPlayer.PlayingState ? Theme.mainTextColor : Theme.mainTextDisabledColor
        font: Theme.tipFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: {
          if (player.active && player.item.duration > 0) {
            var seconds = Math.ceil(player.item.duration / 1000);
            var hours = Math.floor(seconds / 60 / 60) + '';
            seconds -= hours * 60 * 60;
            var minutes = Math.floor(seconds / 60) + '';
            seconds = (seconds - minutes * 60) + '';
            return hours.padStart(2,'0') + ':' + minutes.padStart(2,'0') + ':' + seconds.padStart(2,'0');
          } else {
            return '-';
          }
        }
      }

      FontMetrics {
        id: durationLabelMetrics
        font: durationLabel.font
      }
    }

    Rectangle {
      color: "transparent"
      anchors.left: parent.left
      anchors.right: parent.right
      height: isEnabled ? parent.height : 1
      y: isEnabled ? 0 : parent.height - 1
      border.width: 1
      border.color: Theme.accentLightColor
      radius: 2
    }
  }

  QfToolButton {
    id: cameraButton
    width: visible ? 48 : 0
    height: 48

    // QField has historically handled no viewer type as image, let's carry that on
    visible: (documentViewer == document_FILE || documentViewer == document_IMAGE) && isEnabled

    anchors.right: cameraVideoButton.left
    anchors.top: parent.top

    iconSource: Theme.getThemeVectorIcon("ic_camera_photo_black_24dp")
    iconColor: Theme.mainTextColor
    bgcolor: "transparent"

    onClicked: {
      Qt.inputMethod.hide()
      if ( platformUtilities.capabilities & PlatformUtilities.NativeCamera && settings.valueBool("nativeCamera", true) ) {
        var filepath = getResourceFilePath()
        // Pictures taken by cameras will always be JPG
        filepath = filepath.replace('{extension}', 'JPG')
        __resourceSource = platformUtilities.getCameraPicture(this, qgisProject.homePath+'/', filepath, FileUtils.fileSuffix(filepath) )
      } else {
        platformUtilities.createDir(qgisProject.homePath, 'DCIM')
        cameraLoader.isVideo = false
        cameraLoader.active = true
      }
    }
  }

  QfToolButton {
    id: cameraVideoButton
    width: visible ? 48 : 0
    height: 48

    visible: documentViewer == document_VIDEO && isEnabled

    anchors.right: microphoneButton.left
    anchors.top: parent.top

    iconSource: Theme.getThemeVectorIcon("ic_camera_video_black_24dp")
    iconColor: Theme.mainTextColor
    bgcolor: "transparent"

    onClicked: {
      Qt.inputMethod.hide()
      if ( platformUtilities.capabilities & PlatformUtilities.NativeCamera && settings.valueBool("nativeCamera", true) ) {
        var filepath = getResourceFilePath()
        // Video taken by cameras will always be MP4
        filepath = filepath.replace('{extension}', 'MP4')
        __resourceSource = platformUtilities.getCameraVideo(this, qgisProject.homePath+'/', filepath, FileUtils.fileSuffix(filepath))
      } else {
        platformUtilities.createDir(qgisProject.homePath, 'DCIM')
        cameraLoader.isVideo = true
        cameraLoader.active = true
      }
    }
  }

  QfToolButton {
    id: microphoneButton
    width: visible ? 48 : 0
    height: 48

    visible: documentViewer == document_AUDIO && isEnabled

    anchors.right: fileButton.left
    anchors.top: parent.top

    iconSource: Theme.getThemeVectorIcon("ic_microphone_black_24dp")
    iconColor: Theme.mainTextColor
    bgcolor: "transparent"

    onClicked: {
      Qt.inputMethod.hide()
      audioRecorderLoader.active = true
    }
  }

  QfToolButton {
    id: fileButton
    width: visible ? 48 : 0
    height: 48

    visible: platformUtilities.capabilities & PlatformUtilities.FilePicker && (documentViewer == document_FILE || documentViewer == document_AUDIO) && isEnabled

    anchors.right: galleryButton.left
    anchors.top: parent.top

    iconSource: Theme.getThemeIcon("ic_file_black_24dp")
    iconColor: Theme.mainTextColor
    bgcolor: "transparent"

    onClicked: {
      Qt.inputMethod.hide()
      var filepath = getResourceFilePath()
      if (documentViewer == document_AUDIO) {
        __resourceSource = platformUtilities.getFile(this, qgisProject.homePath+'/', filepath, PlatformUtilities.AudioFiles)
      } else {
        __resourceSource = platformUtilities.getFile(this, qgisProject.homePath+'/', filepath)
      }
    }
  }

  QfToolButton {
    id: galleryButton
    width: visible ? 48 : 0
    height: 48

    // QField has historically handled no viewer type as image, let's carry that on
    visible: (documentViewer == document_FILE || documentViewer == document_IMAGE || documentViewer == document_VIDEO) && isEnabled

    anchors.right: parent.right
    anchors.top: parent.top

    iconSource: Theme.getThemeVectorIcon("ic_gallery_black_24dp")
    iconColor: Theme.mainTextColor
    bgcolor: "transparent"

    onClicked: {
      Qt.inputMethod.hide()
      var filepath = getResourceFilePath()
      if (documentViewer == document_VIDEO) {
        __resourceSource = platformUtilities.getGalleryVideo(this, qgisProject.homePath+'/', filepath)
      } else {
        __resourceSource = platformUtilities.getGalleryPicture(this, qgisProject.homePath+'/', filepath)
      }
    }
  }

  Loader {
    id: audioRecorderLoader
    sourceComponent: audioRecorderComponent
    active:false
  }

  Loader {
    id: cameraLoader
    property bool isVideo: false
    sourceComponent: cameraComponent
    active: false
  }

  Component {
    id: audioRecorderComponent

    QFieldAudioRecorder {
      z: 10000
      visible: false

      Component.onCompleted: {
        if (platformUtilities.checkMicrophonePermissions()) {
          open()
        }
      }

      onFinished: {
        var filepath = getResourceFilePath()
        filepath = filepath.replace('{filename}', FileUtils.fileName(path))
        filepath = filepath.replace('{extension}', FileUtils.fileSuffix(path))
        platformUtilities.renameFile(path, prefixToRelativePath + filepath)

        valueChangeRequested(filepath, false)
        close()
      }

      onCanceled: {
        close()
      }

      onClosed: {
        audioRecorderLoader.active = false
      }
    }
  }

  Component {
    id: cameraComponent

    QFieldCamera {
      id: qfieldCamera
      visible: false

      Component.onCompleted: {
        if (isVideo) {
          if (platformUtilities.checkCameraPermissions() && platformUtilities.checkMicrophonePermissions()) {
            qfieldCamera.state = 'VideoCapture'
            open()
          }
        } else {
          if (platformUtilities.checkCameraPermissions()) {
            qfieldCamera.state = 'PhotoCapture'
            open()
          }
        }
      }

      onFinished: {
        var filepath = getResourceFilePath()
        filepath = filepath.replace('{filename}', FileUtils.fileName(path))
        filepath = filepath.replace('{extension}', FileUtils.fileSuffix(path))
        platformUtilities.renameFile(path, prefixToRelativePath + filepath)

        if (!cameraLoader.isVideo) {
          var maximumWidhtHeight = iface.readProjectNumEntry("qfieldsync", "maximumImageWidthHeight", 0)
          if(maximumWidhtHeight > 0) {
            FileUtils.restrictImageSize(prefixToRelativePath + filepath, maximumWidhtHeight)
          }
        }

        valueChangeRequested(filepath, false)
        close()
      }

      onCanceled: {
        close()
      }

      onClosed: {
        cameraLoader.active = false
      }
    }
  }

  Connections {
    target: __resourceSource
    function onResourceReceived(path) {
      if( path )
      {
        var maximumWidhtHeight = iface.readProjectNumEntry("qfieldsync", "maximumImageWidthHeight", 0)
        if(maximumWidhtHeight > 0) {
          FileUtils.restrictImageSize(prefixToRelativePath + path, maximumWidhtHeight)
        }

        valueChangeRequested(path, false)
      }
    }
  }

  Connections {
    target: __viewStatus

    onFinished: {
      if (isImage) {
        // In order to make sure the image shown reflects edits, reset the source
        var imageSource = image.source;
        image.source = '';
        image.source = imageSource;
      }
    }

    onStatusReceived: {
      if( status )
      {
        //default message (we would have the passed error message still)
        displayToast( qsTr("Cannot handle this file type"), 'error')
      }
    }
  }
}
