import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Controls.Material 2.14
import QtQuick.Layouts 1.14
import QtQml.Models 2.14
import QtQml 2.14
import QtCharts 2.14 // Not actually used here but added so the android deploy script adds the relevant package
import QtWebView 1.14

import org.qgis 1.0
import org.qfield 1.0
import Theme 1.0
import QFieldControls 1.0

Page {
  id: form

  signal confirmed
  signal cancelled
  signal temporaryStored
  signal valueChanged(var field, var oldValue, var newValue)
  signal aboutToSave

  signal requestGeometry(var item, var layer)
  signal requestBarcode(var item)

  property DigitizingToolbar digitizingToolbar
  property CodeReader codeReader

  property AttributeFormModel model
  property alias currentTab: swipeView.currentIndex
  property alias toolbarVisible: toolbar.visible
  //! if embedded form called by RelationEditor or RelationReferenceWidget
  property bool embedded: false
  property int embeddedLevel: 0
  //setupOnly means data would be neither saved nor cleared (feature creation is handled elsewhere like e.g. in the tracking)
  property bool setupOnly: false
  property bool featureCreated: false

  property double topMargin: 0.0
  property double bottomMargin: 0.0

  function requestCancel() {
    if (!qfieldSettings.autoSave) {
      cancelDialog.open();
    } else {
      cancel()
    }
  }

  clip: true
  states: [
    State {
      name: 'ReadOnly'
    },
    State {
      name: 'Edit'
    },
    State {
      name: 'Add'
    }
  ]

  /**
   * This is a relay to forward private signals to internal components.
   */
  QtObject {
    id: master

    /**
     * When set to true, changed value signals are ignored to avoid double feature creation / save when in fast editing mode
     */
    property bool ignoreChanges: false
  }

  ColumnLayout {
    id: container
    anchors.fill: parent

    Flickable {
      id: flickable
      Layout.fillWidth: true
      Layout.preferredHeight: tabRow.height

      flickableDirection: Flickable.HorizontalFlick
      contentWidth: tabRow.width

      // Tabs
      TabBar {
        id: tabRow
        visible: model.hasTabs
        height: form.model.hasTabs ? 48 : 0

        Connections {
          target: swipeView

          function onCurrentIndexChanged(currentIndex) {
            tabRow.currentIndex = swipeView.currentIndex
          }
        }

        Repeater {
          model: form.model.hasTabs ? form.model : 0

          TabButton {
            id: tabButton
            property bool isCurrentIndex: index == tabRow.currentIndex
            text: Name
            topPadding: 0
            bottomPadding: 0
            leftPadding: !ConstraintHardValid || !ConstraintSoftValid ? 22 : 8
            rightPadding: 8

            width: contentItem.width + leftPadding + rightPadding
            height: 48

            background: Rectangle {
              implicitWidth: parent.width
              implicitHeight: parent.height
              color: "transparent"

              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: !ConstraintHardValid ? Theme.errorColor : Theme.warningColor
                visible: !ConstraintHardValid || !ConstraintSoftValid
              }
            }

            contentItem: Text {
              // Make sure the width is derived from the text so we can get wider
              // than the parent item and the Flickable is useful
              width: paintedWidth
              height: parent.height
              text: tabButton.text
              color: !tabButton.enabled ? Theme.darkGray : tabButton.down ? Qt.darker(Theme.mainColor,1.5) : Theme.mainColor
              font.pointSize: Theme.tipFont.pointSize
              font.weight: isCurrentIndex ? Font.DemiBold : Font.Normal

              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }

    /**
     * The main form content area
     */
    SwipeView {
      id: swipeView
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: tabRow.currentIndex

      Repeater {
        // One page per tab in tabbed forms, 1 page in auto forms
        model: form.model.hasTabs ? form.model : 1

        Flickable {
          id: contentView

          property int contentIndex: index

          width: form.width
          contentWidth: content.width
          contentHeight: content.height
          bottomMargin: form.bottomMargin
          clip: true

          ScrollBar.vertical: ScrollBar {
            policy: content.height > contentView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 6
            contentItem: Rectangle {
              implicitWidth: 6
              implicitHeight: 25
              color: Theme.mainColor
            }
          }

          Rectangle {
            anchors.fill: parent
            color: Theme.mainBackgroundColor
          }

          Flow {
            id: content
            width: form.width

            SubModel {
              id: contentModel
              model: form.model
              rootIndex: form.model.index(form.model.hasTabs ? contentIndex : -1, 0)
            }

            Repeater {
              // Note: digitizing a child geometry will temporarily hide the feature form,
              // we need to preserve items so signal connections are kept alive
              model: form.model.hasTabs
                     ? contentModel
                     : form.model
              delegate: fieldItem
            }
          }
        }
      }
    }
  }

  Component {
    id: textContainer

    Item {
      height: childrenRect.height
      anchors {
        left: parent.left
        right: parent.right
        leftMargin: 12
      }

      Label {
        id: textLabel
        width: parent.width
        text: containerName
        wrapMode: Text.WordWrap
        font.pointSize: Theme.tinyFont.pointSize
        font.bold: true
        topPadding: 10
        bottomPadding: 5
        opacity: form.state === 'ReadOnly' || embedded && EditorWidget === 'RelationEditor'
                 ? 0.45
                 : 1
        color: labelOverrideColor !== undefined && labelOverrideColor ? labelColor : Theme.mainTextColor
      }

      Text {
        id: textContent
        width: parent.width
        text: containerCode
        wrapMode: Text.WordWrap
        font: Theme.defaultFont
        anchors {
          left: parent.left
          right: parent.right
          top: textLabel.bottom
        }
        opacity: textLabel.opacity
        color: Theme.mainTextColor
        linkColor: Theme.mainColor
        onLinkActivated: Qt.openUrlExternally(link)
      }
    }
  }

  Component {
    id: qmlContainer

    Item {
      height: childrenRect.height
      anchors {
        left: parent.left
        right: parent.right
        leftMargin: 12
      }

      Label {
        id: qmlLabel
        width: parent.width
        text: containerName
        wrapMode: Text.WordWrap
        font.pointSize: Theme.tinyFont.pointSize
        font.bold: true
        topPadding: 10
        bottomPadding: 5
        opacity: form.state === 'ReadOnly' || embedded && EditorWidget === 'RelationEditor'
                 ? 0.45
                 : 1
        color: labelOverrideColor !== undefined && labelOverrideColor ? labelColor : Theme.mainTextColor
      }

      Item {
        id: qmlItem

        property string code: containerCode
        onCodeChanged: {
          var obj = Qt.createQmlObject(code,qmlItem,'qmlContent');
        }

        height: childrenRect.height
        anchors {
          left: parent.left
          rightMargin: 12
          right: parent.right
          top: qmlLabel.bottom
        }
      }
    }
  }

  Component {
    id: htmlContainer

    Item {
      property string htmlCode: containerCode
      property var htmlItem: undefined

      height: childrenRect.height
      anchors {
        left: parent.left
        right: parent.right
        leftMargin: 12
      }

      Label {
        id: htmlLabel
        width: parent.width
        text: containerName
        wrapMode: Text.WordWrap
        font.pointSize: Theme.tinyFont.pointSize
        font.bold: true
        topPadding: 10
        bottomPadding: 5
        opacity: form.state === 'ReadOnly' || embedded && EditorWidget === 'RelationEditor'
                 ? 0.45
                 : 1
        color: labelOverrideColor !== undefined && labelOverrideColor ? labelColor : Theme.mainTextColor
      }

      Item {
        id: htmlContent
        height: childrenRect.height
        anchors {
          left: parent.left
          right: parent.right
          top: htmlLabel.bottom
        }
      }

      Component.onCompleted: {
        if (visible) {
          if (htmlItem === undefined) {
            // avoid cost of WevView creation until needed
            htmlItem = Qt.createQmlObject('import QtWebView 1.14;
              WebView {
                id: htmlItem;
                height: 0;
                opacity: 0;
                anchors { top: parent.top; left: parent.left; right: parent.right; }
                onLoadingChanged: { if (!loading) { runJavaScript("document.body.offsetHeight", function(result) { anchors.left = parent.left; width = parent.width; height = (result + 18); opacity = 1.0; } ) } }
              }'
              , htmlContent);
          }
          htmlItem.loadHtml(htmlCode)
        }
      }
      onHtmlCodeChanged: {
        if (visible && htmlItem) {
          htmlItem.loadHtml(htmlCode);
        }
      }
    }
  }

  Component {
    id: innerContainer

    Item {
      height: childrenRect.height
      anchors {
        left: parent.left
        right: parent.right
      }

      Flow {
        id: innerContainerContent
        anchors {
          left: parent.left
          right: parent.right
        }

        Repeater {
          model: SubModel {
            id: innerSubModel
            model: form.model
            rootIndex: form.model.mapFromSource(containerGroupIndex)
          }
          delegate: fieldItem
        }

        Connections {
          target: form.model

          function onModelReset() {
            if (containerGroupIndex !== undefined && innerContainer.visible) {
              innerSubModel.rootIndex = form.model.mapFromSource(containerGroupIndex)
            }
          }
        }
      }
    }
  }

  Component {
    id: dummyContainer

    Item {}
  }

  /**
   * A field editor
   */
  Component {
    id: fieldItem

    Item {
      width: parent && parent.width > 0
             ? parent.width / ColumnCount > 200
               ? parent.width / ColumnCount
               : parent.width
      : form.width
      height: fieldGroupTitle.height + fieldContent.childrenRect.height

      Rectangle {
        id: fieldGroupBackground

        anchors.fill: parent
        visible: GroupColor ? true : false
        color: GroupColor ? Qt.hsla(GroupColor.hslHue, GroupColor.hslSaturation, GroupColor.hslLightness, 0.05) : "transparent"
      }

      Rectangle {
        id: fieldGroupTitle

        width: parent.width
        height: GroupName !== '' ? childrenRect.height : 0
        color: GroupColor ? Qt.hsla(GroupColor.hslHue, GroupColor.hslSaturation, GroupColor.hslLightness, 0.5) : Theme.controlBorderColor

        Rectangle {
          width: 5
          height: parent.height
          anchors.top: parent.top
          anchors.left: parent.left
          color: GroupColor ? GroupColor : "transparent"
        }

        Text {
          leftPadding: 10
          rightPadding: 10
          topPadding: 5
          bottomPadding: 5
          width: parent.width
          font.pointSize: Theme.tipFont.pointSize
          font.bold: true
          color: Theme.mainTextColor
          text: GroupName || ''
          wrapMode: Text.WordWrap
        }
      }

      Item {
        id: fieldContent

        anchors {
          top: fieldGroupTitle.bottom
          left: parent.left
          right: parent.right
        }

        Loader {
          property string containerName: Name || ''
          property string containerCode: EditorWidgetCode || ''
          property var containerGroupIndex: GroupIndex
          property var labelOverrideColor: LabelOverrideColor
          property var labelColor: LabelColor

          active: (Type === 'container' && GroupIndex !== undefined && GroupIndex.valid) ||
                  ((Type === 'text' || Type === 'html' || Type === 'qml') && form.model.featureModel.modelMode != FeatureModel.MultiFeatureModel)
          height: active ? item.childrenRect.height : 0
          anchors {
            left: parent.left
            right: parent.right
          }

          sourceComponent: Type === 'container' && GroupIndex !== undefined && GroupIndex.valid
                           ? innerContainer
                           : Type === 'qml'
                             ? qmlContainer
                             : Type === 'html'
                               ? htmlContainer
                               : Type === 'text'
                                 ? textContainer
                                 : dummyContainer
        }

        Item {
          id: fieldContainer

          property bool isVisible: Type === 'field' || Type === 'relation'

          visible: isVisible
          height: isVisible ? childrenRect.height : 0
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: 12
          }

          Label {
            id: fieldLabel
            width: parent.width
            text: Name || ''
            wrapMode: Text.WordWrap
            font.family: LabelOverrideFont ? LabelFont.family : Theme.tinyFont.family
            font.pointSize: Theme.tinyFont.pointSize
            font.bold: LabelOverrideFont ? LabelFont.bold : true
            font.italic: LabelOverrideFont ? LabelFont.italic : false
            font.underline: LabelOverrideFont ? LabelFont.underline : false
            font.strikeout: LabelOverrideFont ? LabelFont.strikeout : false
            topPadding: 10
            bottomPadding: 5
            opacity: (form.state === 'ReadOnly' || !AttributeEditable) || embedded && EditorWidget === 'RelationEditor'
                     ? 0.45
                     : 1
            color: LabelOverrideColor ? LabelColor : Theme.mainTextColor
          }

          Label {
            id: constraintDescriptionLabel
            anchors {
              left: parent.left
              right: parent.right
              top: fieldLabel.bottom
            }

            font.pointSize: fieldLabel.font.pointSize/3*2
            text: {
              if ( ConstraintHardValid && ConstraintSoftValid )
                return '';

              return ConstraintDescription || '';
            }
            height: !ConstraintHardValid || !ConstraintSoftValid ? undefined : 0
            visible: !ConstraintHardValid || !ConstraintSoftValid
            opacity: fieldLabel.opacity
            color: !ConstraintHardValid ? Theme.errorColor : Theme.warningColor
          }

          Item {
            id: placeholder
            height: attributeEditorLoader.childrenRect.height
            anchors { left: parent.left; right: menuButton.left; top: constraintDescriptionLabel.bottom; }

            Loader {
              id: attributeEditorLoader

              anchors { left: parent.left; right: parent.right }

              //disable widget if it's:
              // - not activated in multi edit mode
              // - not set to editable in the widget configuration
              // - not in edit mode (ReadOnly)
              // - a relation in multi edit mode
              property bool isAdding: form.state === 'Add'
              property bool isEditing: form.state === 'Edit'
              property bool isEnabled: !!AttributeEditable
                                       && form.state !== 'ReadOnly'
                                       && !( Type === 'relation' && form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel )
              property var value: AttributeValue
              property var config: ( EditorWidgetConfig || {} )
              property var widget: EditorWidget
              property var relationEditorWidget: RelationEditorWidget
              property var relationEditorWidgetConfig: RelationEditorWidgetConfig
              property var field: Field
              property var fieldLabel: Name
              property var relationId: RelationId
              property var nmRelationId: NmRelationId
              property var constraintHardValid: ConstraintHardValid
              property var constraintSoftValid: ConstraintSoftValid
              property bool constraintsHardValid: form.model.constraintsHardValid
              property bool constraintsSoftValid: form.model.constraintsSoftValid
              property var currentFeature: form.model.featureModel.feature
              property var currentLayer: form.model.featureModel.currentLayer
              property bool autoSave: qfieldSettings.autoSave
              // TODO investigate why StringUtils are not available in ./editorwidget/*.qml files
              property var stringUtilities: StringUtils

              active: widget !== 'Hidden'
              source: {
                if ( widget === 'RelationEditor' ) {
                  return 'editorwidgets/relationeditors/' + ( RelationEditorWidget || 'relation_editor' ) + '.qml'
                }
                return 'editorwidgets/' + ( widget || 'TextEdit' ) + '.qml'
              }

              onLoaded: {
                item.isLoaded = true;
              }

              onStatusChanged: {
                if ( attributeEditorLoader.status === Loader.Error ) {
                  source = ( widget === 'RelationEditor' )
                      ? 'editorwidgets/relationeditors/relation_editor.qml'
                      : 'editorwidgets/TextEdit.qml'
                }
              }
            }

            Connections {
              target: form

              function onAboutToSave() {
                // it may not be implemented
                if ( attributeEditorLoader.item.pushChanges ) {
                  attributeEditorLoader.item.pushChanges( form.model.featureModel.feature )
                }
              }

              function onValueChanged(field, oldValue, newValue) {
                // it may not be implemented
                if ( attributeEditorLoader.item.siblingValueChanged ) {
                  attributeEditorLoader.item.siblingValueChanged( field, form.model.featureModel.feature )
                }
              }
            }

            Connections {
              target: attributeEditorLoader.item

              function onValueChangeRequested(value, isNull) {
                //do not compare AttributeValue and value with strict comparison operators
                if( ( AttributeValue != value || ( AttributeValue !== undefined && isNull ) ) && !( AttributeValue === undefined && isNull ) )
                {
                  var oldValue = AttributeValue
                  AttributeValue = isNull ? undefined : value

                  valueChanged(Field, oldValue, AttributeValue)

                  if ( !AttributeAllowEdit && form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ) {
                    AttributeAllowEdit = true;
                  }

                  if ( qfieldSettings.autoSave && !setupOnly && !master.ignoreChanges ) {
                    // indirect action, no need to check for success and display a toast, the log is enough
                    save()
                  }
                }
              }
              function onRequestGeometry(item, layer) {
                form.digitizingToolbar.geometryRequested = true
                form.digitizingToolbar.geometryRequestedItem = item
                form.digitizingToolbar.geometryRequestedLayer = layer
              }

              function onRequestBarcode(item) {
                form.codeReader.barcodeRequestedItem = item
                form.codeReader.open()
              }
            }
          }

          QfToolButton {
            id: menuButton
            anchors { right: rememberCheckbox.left; top: constraintDescriptionLabel.bottom; rightMargin: 10; }

            visible: attributeEditorLoader.isEnabled && attributeEditorLoader.item.hasMenu
            enabled: visible
            width: visible ? 48 : 0

            iconSource: Theme.getThemeIcon("ic_dot_menu_gray_24dp")
            iconColor: Theme.mainTextColor
            bgcolor: "transparent"

            onClicked: {
              attributeEditorLoader.item.menu.popup(menuButton.x, menuButton.y)
            }
          }

          CheckBox {
            id: rememberCheckbox
            checked: RememberValue ? true : false
            visible: form.state === "Add" && EditorWidget !== "Hidden" && EditorWidget !== 'RelationEditor'
            width: visible ? undefined : 0

            anchors { right: parent.right; top: constraintDescriptionLabel.bottom; verticalCenter: menuButton.verticalCenter }

            onCheckedChanged: {
              RememberValue = checked
            }

            indicator.height: 16
            indicator.width: 16
            icon.height: 16
            icon.width: 16
          }

          Label {
            id: multiEditAttributeLabel
            text: (AttributeAllowEdit ? qsTr( "Value applied" ) : qsTr( "Value skipped" ) ) + qsTr( " (click to toggle)" )
            visible: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel && Type !== 'relation'
            height: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ? undefined : 0
            bottomPadding: form.model.featureModel.modelMode == FeatureModel.MultiFeatureModel ? 15 : 0
            anchors { left: parent.left; top: placeholder.bottom;  rightMargin: 10; }
            font: Theme.tipFont
            color: AttributeAllowEdit ? Theme.mainColor : Theme.secondaryTextColor

            MouseArea {
              anchors.fill: parent
              onClicked: {
                AttributeAllowEdit = !AttributeAllowEdit
              }
            }
          }
        }
      }
    }
  }

  function confirm() {
    //if this is not handled before (e.g. when this is called because the drawer is closed by tipping on the map)
    if ( !model.constraintsHardValid )
    {
      displayToast( qsTr( 'Constraints not valid'), 'warning' )
      cancel()
      return
    }
    else if ( !model.constraintsSoftValid )
    {
      displayToast( qsTr( 'Note: soft constraints were not met') )
    }

    parent.focus = true

    if( setupOnly ) {
      temporaryStored()
      return
    }

    if ( !save() ) {
      displayToast( qsTr( 'Unable to save changes'), 'error' )
      featureCreated = false
      return
    }

    state = 'Edit'
    featureCreated = false

    confirmed()
  }

  function save() {
    if( !model.constraintsHardValid ) {
      return false
    }

    aboutToSave()

    master.ignoreChanges = true;

    var isSuccess = false;
    if( form.state === 'Add' && !featureCreated ) {
      isSuccess = model.create()
      featureCreated = isSuccess
    } else {
      isSuccess = model.save()
    }

    master.ignoreChanges = false;
    return isSuccess
  }

  function cancel() {
    if( form.state === 'Add' && featureCreated ) {
      // indirect action, no need to check for success and display a toast, the log is enough
      model.deleteFeature()
    }
    cancelled()
    featureCreated = false
  }

  Connections {
    target: Qt.inputMethod

    function onVisibleChanged() {
      Qt.inputMethod.commit()
    }
  }

  /** The title toolbar **/
  header: ToolBar {
    id: toolbar
    height: visible ? form.topMargin + 48 : 0
    visible: form.state === 'Add'

    anchors {
      top: parent.top
      topMargin: -1 // fix scene rounding issue leading to a white line
    }

    background: Rectangle {
      color: !model.constraintsHardValid ?  Theme.errorColor : !model.constraintsSoftValid ? Theme.warningColor : Theme.mainColor
    }

    RowLayout {
      anchors.fill: parent
      anchors.topMargin: form.topMargin
      Layout.margins: 0

      QfToolButton {
        id: saveButton

        Layout.alignment: Qt.AlignTop | Qt.AlignLeft

        visible: ( form.state === 'Add' || form.state === 'Edit' )
        width: 48
        height: 48
        clip: true

        iconSource: Theme.getThemeIcon( "ic_check_white_48dp" )
        opacity: typeof featureFormList !== "undefined" ? featureFormList.model.constraintsHardValid ? 1.0 : 0.3 : 1.0

        onClicked: {
          if( model.constraintsHardValid ) {
            if ( !model.constraintsSoftValid ) {
              displayToast( qsTr('Note: soft constraints were not met') )
            }
            confirm()
          } else {
            displayToast( qsTr('Constraints not valid'), 'warning' )
          }
        }
      }

      Text {
        id: titleLabel
        Layout.fillWidth: true
        Layout.preferredHeight: parent.height

        font: Theme.strongFont
        color: Theme.light

        text:
        {
          var currentLayer = model.featureModel.currentLayer
          var layerName = 'N/A'
          if (currentLayer != null)
            layerName = currentLayer.name

          if ( form.state === 'Add' )
            qsTr( 'Add feature on %1' ).arg(layerName )
          else if ( form.state === 'Edit' )
            qsTr( 'Edit feature on %1' ).arg(layerName)
          else
            qsTr( 'View feature on %1' ).arg(layerName)
        }

        fontSizeMode: Text.Fit
        wrapMode: Text.Wrap
        elide: Label.ElideRight
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
      }

      QfToolButton {
        id: closeButton

        Layout.alignment: Qt.AlignTop | Qt.AlignRight

        width: 49
        height: 48
        clip: true
        visible: !setupOnly

        iconSource: form.state === 'Add' ? Theme.getThemeIcon( 'ic_delete_forever_white_24dp' ) : Theme.getThemeIcon( 'ic_close_white_24dp' )

        onClicked: {
          Qt.inputMethod.hide()
          if ((form.state === 'Add' || form.state === 'Edit')) {
            form.requestCancel()
          } else {
            cancel();
          }
        }
      }
    }
  }

  Dialog {
    id: cancelDialog
    parent: mainWindow.contentItem

    visible: false
    modal: true
    font: Theme.defaultFont

    z: 10000 // 1000s are embedded feature forms, user a higher value to insure the dialog will always show above embedded feature forms
    x: ( mainWindow.width - width ) / 2
    y: ( mainWindow.height - height ) / 2

    title: qsTr( "Cancel editing" )
    Label {
      width: parent.width
      wrapMode: Text.WordWrap
      text: form.state === 'Add'
            ? qsTr( "You are about to dismiss the new feature, proceed?" )
            : qsTr( "You are about to leave editing state, any changes will be lost. Proceed?" )
    }

    standardButtons: Dialog.Ok | Dialog.Cancel
    onAccepted: {
      form.cancel()
    }
  }
}
