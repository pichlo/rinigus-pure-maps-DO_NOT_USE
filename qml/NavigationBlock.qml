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

import "js/util.js" as Util

// The navigation block comprises three main sections:
// 1. The progress bar;
// 2. A multi-purpose display area containing the next maneuver icon
//    and three configurable zones;
// 3. A narrative label, showing a street name, next maneuver etc.
// Depending on the screen orientation, the three sections are laid out
// either top to bottom or left to right.
// The multi-purpose display is equally laid out left to right (in portrait)
// or top to bottom (in landscape).

Grid {
    id: block
    columns: app.portrait ? 1 : 4
    rows: app.portrait ? 4 : 1
    width: notify ? app.screenWidth : 0
    height: notify ? (app.portrait ? (progressBar.height + displayArea.height + labels.height) : app.screenHeight) : 0

    property string destDist:  app.navigationStatus.destDist
    property string destEta:   app.navigationStatus.destEta
    property string destTime:  app.navigationStatus.destTime
    property string icon:      app.navigationStatus.icon
    property string manDist:   app.navigationStatus.manDist
    property string manTime:   app.navigationStatus.manTime
    property string narrative: app.navigationStatus.narrative
    property bool   notify:    app.navigationStatus.notify
    property var    street:    app.navigationStatus.street
    property int    shieldLeftHeight: !app.portrait && destDist && notify ? displayArea.height + Theme.paddingMedium + iconImage.height + iconImage.anchors.topMargin : 0
    property int    shieldLeftWidth:  !app.portrait && destDist && notify ? displayArea.anchors.leftMargin + Theme.paddingLarge + Math.max(displayAreaA.width, iconImage.width) : 0

    Rectangle {
        // Section one, the progress bar
        // Placed along the top or the left side of the screen
        id: progressBar
        width: block.notify ? (app.portrait ? block.width : Theme.paddingSmall) : 0
        height: block.notify ? (app.portrait ? Theme.paddingSmall : block.height) : 0
        color: app.styler.blockBg

        Rectangle {
            id: progressComplete
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.primaryColor
            height: app.portrait && block.notify ? Theme.paddingSmall : 0
            radius: Theme.paddingSmall / 2
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

        MouseArea {
            anchors.fill: parent
            onClicked: app.showNavigationPages();
        }
    }

    Rectangle {
        // Section two, display area, split into: maneuver icon and three display zones
        // Placed immediately below (or to the right of) the progress bar
        id: displayArea
        width: block.notify ? (app.portrait ? block.width : displayAreaGrid.width) : 0
        height: block.notify ? (app.portrait ? displayAreaGrid.height : block.height) : 0
        color: app.styler.blockBg

        Grid {
            id: displayAreaGrid
            columns: app.portrait ? 4 : 1
            rows: app.portrait ? 1 : 4
            height: app.portrait
                        ? Math.max(iconImage.height, displayAreaA.height, displayAreaB.height, displayAreaC.height)
                        : block.height
            width: app.portrait
                       ? block.width
                       : Math.max(iconImage.width, displayAreaA.width, displayAreaB.width, displayAreaC.width)

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
                width: app.portrait
                           ? (block.width - iconImage.width) / 3
                           : Math.max(iconImage.width, implicitWidth, displayAreaB.width, displayAreaC.width)
                value: token(block.manDist, " ", 0)
                caption: long_word_distance(token(block.manDist, " ", 1))
            }

            NavigationBlockElement {
                // Middle area, e.g. current speed
                id: displayAreaB
                width: app.portrait
                           ? (block.width - iconImage.width) / 3
                           : Math.max(iconImage.width, displayAreaA.width, implicitWidth, displayAreaC.width)
                value: speed_value()
                caption: speed_unit()
            }

            NavigationBlockElement {
                // Right (or bottom) area, e.g. a distance to the destination or ETA
                id: displayAreaC
                width: app.portrait
                           ? (block.width - iconImage.width) / 3
                           : Math.max(iconImage.width, displayAreaA.width, displayAreaB.width, implicitWidth)
                value: block.destEta
                caption: app.tr("ETA")
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: app.showNavigationPages();
        }
    }

    Rectangle {
        // Dummy spacer, only taking effect in landscape mode
        id: spacer
        width: (app.screenWidth - app.screenHeight - displayArea.width - progressBar.width) / 2
        height: app.portrait ? 0 : width
        opacity: 0
    }

    Rectangle {
        // Street name or instruction text for the next maneuver
        id: labels
        width: block.notify
                   ? (block.width - (app.portrait
                                         ? 0
                                         : displayArea.width + progressBar.width + (2 * spacer.width)))
                   : 0
        height: block.notify ? narrativeLabel.height : 0
        radius: app.portrait ? 0 : Theme.paddingLarge
        color: app.styler.blockBg

        Label {
            id: narrativeLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.paddingLarge
            anchors.rightMargin: Theme.paddingLarge
            color: Theme.primaryColor
            font.pixelSize: streetNameShown ? Theme.fontSizeExtraLarge : Theme.fontSizeMedium
            height: text ? implicitHeight + Theme.paddingMedium : 0
            maximumLineCount: streetNameShown ? 1 : 2
            truncationMode: TruncationMode.Fade
            text: block.notify
                      ? (app.navigationPageSeen
                             ? (block.street ? streetName : block.narrative)
                             : app.tr("Tap to review maneuvers or begin navigating"))
                      : ""
            verticalAlignment: Text.AlignTop
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap

            property bool streetNameShown: block.notify && app.navigationPageSeen && block.street
            property string streetName: {
                var s = "";
                for (var i in block.street) {
                    if (s != "") s += "; "
                    s += block.street[i];
                }
                return s;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: app.showNavigationPages();
        }
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
        return (s == app.tr("ft")) ? app.tr("feet")   :
               (s == app.tr("yd")) ? app.tr("yards")  :
               (s == app.tr("m"))  ? app.tr("meters") :
               (s == app.tr("mi")) ? app.tr("miles")  : s;
    }

    function speed_value() {
        if (!py.ready) {
            return "";
        } else if (!gps.position.speedValid) {
            return "—";
        } else if (app.conf.get("units") === "metric") {
            return Util.siground(gps.position.speed * 3.6);
        } else {
            return Util.siground(gps.position.speed * 2.23694);
        }
    }

    function speed_unit() {
        if (!py.ready) {
            return "";
        } else if (app.conf.get("units") === "metric") {
            return app.tr("km/h");
        } else {
            return app.tr("mph");
        }
    }
}
