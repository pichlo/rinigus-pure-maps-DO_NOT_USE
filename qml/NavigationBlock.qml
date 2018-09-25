/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa, 2018 Rinigus
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0

Rectangle {
    id: block
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    color: app.styler.blockBg
    height: (app.portrait && notify ? progressComplete.height + displayArea.height : 0) + Math.max(streetLabel.height, narrativeLabel.height)
    states: [
        State {
            when: !app.portrait && destDist && notify
            AnchorChanges {
                target: block
                anchors.left: undefined
            }
            PropertyChanges {
                target: block
                width: parent.width - shieldLeftWidth
            }
        }
    ]

    property string destDist:  app.navigationStatus.destDist
    property string destEta:   app.navigationStatus.destEta
    property string destTime:  app.navigationStatus.destTime
    property string icon:      app.navigationStatus.icon
    property string manDist:   app.navigationStatus.manDist
    property string manTime:   app.navigationStatus.manTime
    property string narrative: app.navigationStatus.narrative
    property bool   notify:    app.navigationStatus.notify
    property var    street:    app.navigationStatus.street
    property int    shieldLeftHeight: !app.portrait && destDist && notify ? displayAreaA.height + Theme.paddingMedium + iconImage.height + iconImage.anchors.topMargin : 0
    property int    shieldLeftWidth:  !app.portrait && destDist && notify ? displayAreaA.anchors.leftMargin + Theme.paddingLarge + Math.max(displayAreaA.width, iconImage.width) : 0

    Rectangle {
        id: progressComplete
        anchors.left: parent.left
        anchors.top: parent.top
        color: Theme.primaryColor
        height: app.portrait && block.notify ? Theme.paddingSmall : 0
        visible: height > 0
        radius: height / 2
        width: app.navigationStatus.progress * displayArea.width
    }

    Rectangle {
        id: progressRemaining
        anchors.left: progressComplete.left
        anchors.right: parent.right
        anchors.top: progressComplete.top
        color: Theme.primaryColor
        opacity: 0.1
        height: progressComplete.height
        visible: progressComplete.visible
        radius: progressComplete.radius
    }

    Item {
        // Display area, split into: maneuver icon, left, middle and right
        id: displayArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: progressComplete.bottom
        height: displayAreaGrid.height

        Grid {
            id: displayAreaGrid
            columns: 4
            rows: 1
            height: Math.max(iconImage.height, displayAreaA.height, displayAreaB.height, displayAreaC.height)
            width: parent.width

            Image {
                // Icon for the next maneuver
                id: iconImage
                anchors.leftMargin: Theme.paddingSmall
                anchors.rightMargin: Theme.paddingSmall
                anchors.topMargin: Theme.paddingSmall
                anchors.bottomMargin: Theme.paddingSmall
                fillMode: Image.Pad
                height: block.notify ? sourceSize.height : 0
                opacity: 0.9
                smooth: true
                source: block.notify ? "icons/navigation/%1.svg".arg(block.icon || "flag") : ""
                sourceSize.height: (Screen.sizeCategory >= Screen.Large ? 1.7 : 1) * Theme.iconSizeLarge
                sourceSize.width: (Screen.sizeCategory >= Screen.Large ? 1.7 : 1) * Theme.iconSizeLarge
                width: block.notify ? sourceSize.width : 0
            }

            NavigationBlockElement {
                // Left (or top) area, e.g. a distance to the next maneuver
                id: displayAreaA
                width: (displayArea.width - iconImage.width) / 3
                value: token(block.manDist, " ", 0)
                caption: long_word_distance(token(block.manDist, " ", 1))
            }

            NavigationBlockElement {
                // Middle area, e.g. current speed
                id: displayAreaB
                width: displayAreaA.width
                value: speed_value()
                caption: speed_unit()
            }

            NavigationBlockElement {
                // Right (or bottom) area, e.g. a distance to the destination or ETA
                id: displayAreaC
                width: displayAreaB.width
                value: block.destEta
                caption: app.tr("ETA")
            }
        }
    }

    Label {
        // Street name
        id: streetLabel
        anchors.left: parent.left
        anchors.leftMargin: Theme.paddingLarge
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingLarge
        anchors.top: displayArea.bottom
        color: Theme.primaryColor
        font.pixelSize: Theme.fontSizeExtraLarge
        height: text ? implicitHeight + Theme.paddingMedium : 0
        maximumLineCount: 1
        text: app.navigationPageSeen && block.notify ? streetName : ""
        truncationMode: TruncationMode.Fade
        verticalAlignment: Text.AlignTop
        horizontalAlignment: Text.AlignHCenter

        property string streetName: {
            if (!block.street) return "";
            var s = "";
            for (var i in block.street) {
                if (s != "") s += "; "
                s += block.street[i];
            }
            return s;
        }
    }

    Label {
        // Instruction text for the next maneuver
        id: narrativeLabel
        anchors.left: parent.left
        anchors.leftMargin: Theme.paddingLarge
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingLarge
        anchors.top: displayArea.bottom
        //anchors.topMargin: Theme.paddingSmall
        color: Theme.primaryColor
        font.pixelSize: Theme.fontSizeMedium
        height: text ? implicitHeight + Theme.paddingMedium : 0
        text: app.navigationPageSeen ?
            (block.notify && !streetLabel.text ? block.narrative : "") :
            (block.notify ? app.tr("Tap to review maneuvers or begin navigating") : "")
        verticalAlignment: Text.AlignTop
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    MouseArea {
        anchors.fill: parent
        onClicked: app.showNavigationPages();
    }

    function token(s, t, n) {
        var result = "";
        for (var i in s) {
            if (s[i] == t) {
                --n;
            } else if (n == 0) {
                result += s[i];
            }
        }
        return result;
    }

    function long_word_distance(s) {
        return (s == "ft") ? "feet"   :
               (s == "yd") ? "yards"  :
               (s == "m")  ? "meters" :
               (s == "mi") ? "miles"  : s;
    }

    function speed_value() {
        var speed = 0.0;
        if (!py.ready) {
            return "";
        } else if (!gps.position.speedValid) {
            return "";
        } else if (app.conf.get("units") === "metric") {
            speed = gps.position.speed * 3.6;
        } else {
            speed = gps.position.speed * 2.23694;
        }
        return speed < 10 ? Math.round(speed * 10.0) / 10.0 : Math.round(speed);
    }

    function speed_unit() {
        if (!py.ready) {
            return "";
        } else if (app.conf.get("units") === "metric") {
            return "km/h";
        } else {
            return "mph";
        }
    }
}
