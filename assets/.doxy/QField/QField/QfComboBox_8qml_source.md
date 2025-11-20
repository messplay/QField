

# File QfComboBox.qml

[**File List**](files.md) **>** [**imports**](dir_3be62dd4600925273911e91e0c7964f3.md) **>** [**Theme**](dir_1633596792308d5fdfbf00fb99c556ce.md) **>** [**QfComboBox.qml**](QfComboBox_8qml.md)

[Go to the documentation of this file](QfComboBox_8qml.md)


```C++
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

ComboBox {
  id: comboBox

  contentItem: Text {
    leftPadding: enabled ? 5 : 0

    text: comboBox.displayText
    font: comboBox.font
    color: enabled ? Theme.mainTextColor : Theme.mainTextDisabledColor
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignLeft
    elide: Text.ElideRight
  }

  background: Item {
    implicitWidth: 120
    implicitHeight: 36

    Rectangle {
      visible: !enabled
      y: comboBox.height - 2
      width: comboBox.width
      height: comboBox.activeFocus ? 2 : 1
      color: comboBox.activeFocus ? Theme.accentColor : Theme.accentLightColor
    }

    Rectangle {
      id: backgroundRect
      visible: enabled
      anchors.fill: parent
      border.color: comboBox.pressed ? Theme.accentColor : Theme.accentLightColor
      border.width: comboBox.visualFocus ? 2 : 1
      color: Theme.controlBackgroundAlternateColor
      radius: 2
    }
  }
}
```


