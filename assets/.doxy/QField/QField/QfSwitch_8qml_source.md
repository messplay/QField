

# File QfSwitch.qml

[**File List**](files.md) **>** [**imports**](dir_3be62dd4600925273911e91e0c7964f3.md) **>** [**Theme**](dir_1633596792308d5fdfbf00fb99c556ce.md) **>** [**QfSwitch.qml**](QfSwitch_8qml.md)

[Go to the documentation of this file](QfSwitch_8qml.md)


```C++
import QtQuick
import QtQuick.Controls

SwitchDelegate {
  property bool small: false

  width: small ? 34 : 48
  padding: 10
  indicator: Rectangle {
    implicitWidth: small ? 34 : 48
    implicitHeight: small ? 16 : 26
    x: parent.leftPadding
    y: (parent.height + parent.topPadding - 6) / 2 - height / 2
    radius: implicitHeight / 2
    color: parent.checked ? Theme.mainColor : Theme.controlBorderColor
    border.color: parent.checked ? Theme.mainColor : Theme.controlBorderColor

    Rectangle {
      x: parent.parent.checked ? parent.width - width : 0
      width: parent.implicitHeight
      height: parent.implicitHeight
      radius: parent.implicitHeight / 2
      opacity: parent.parent.down ? 0.85 : 1
      color: Theme.mainBackgroundColor
      border.color: parent.parent.checked ? Theme.mainColor : Theme.controlBorderColor
      Behavior on x  {
        PropertyAnimation {
          duration: 150
          easing.type: Easing.Linear
        }
      }
    }
  }

  background: Rectangle {
    implicitWidth: 100
    implicitHeight: 40
    visible: false
    color: "transparent"
  }
}
```


