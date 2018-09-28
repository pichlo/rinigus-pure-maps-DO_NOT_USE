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

// The navigation block comprises two main sections:
// 1. The progress bar;
// 2. A multi-purpose display area containing the next maneuver icon
//    and three configurable zones.
// Depending on the screen orientation, the sections are laid out
// either top to bottom or left to right.
// The multi-purpose display is equally laid out left to right (in portrait)
// or top to bottom (in landscape).

Grid {
    id: block
    columns: app.portrait ? 1 : 2
    rows: app.portrait ? 2 : 1
    width: notify ? (app.portrait ? app.screenWidth : (progressBar.width + displayArea.width)) : 0
    height: notify ? (app.portrait ? (progressBar.height + displayArea.height) : app.screenHeight) : 0

    property string destDist:  app.navigationStatus.destDist
    property string destEta:   app.navigationStatus.destEta
    property string destTime:  app.navigationStatus.destTime
    property string icon:      app.navigationStatus.icon
    property string manDist:   app.navigationStatus.manDist
    property string manTime:   app.navigationStatus.manTime
    property bool   notify:    app.navigationStatus.notify

    Rectangle {
        // Section one, the progress bar
        // Placed along the top or the left side of the screen
        id: progressBar
        width: block.notify ? (app.portrait ? app.screenWidth : Theme.paddingSmall) : 0
        height: block.notify ? (app.portrait ? Theme.paddingSmall : app.screenHeight) : 0
        color: app.styler.blockBg

        Rectangle {
            // It would be nice to do away with this rectangle, by making the parent the right colour.
            // Suggestions are welcome.
            id: progressShading
            anchors.fill: parent
            color: Theme.primaryColor
            opacity: 0.1
        }

        Rectangle {
            id: progressComplete
            anchors.left: parent.left
            color: Theme.primaryColor
            radius: Theme.paddingSmall / 2
            states: [
                State {
                    when: app.portrait
                    AnchorChanges {
                        target: progressComplete
                        anchors.top: parent.top
                        anchors.bottom: undefined
                    }
                    PropertyChanges {
                        target: progressComplete
                        height: parent.height
                        width: app.navigationStatus.progress * displayArea.width
                    }
                },
                State {
                    when: !app.portrait
                    AnchorChanges {
                        target: progressComplete
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                    }
                    PropertyChanges {
                        target: progressComplete
                        height: app.navigationStatus.progress * displayArea.height
                        width: parent.width
                    }
                }
            ]
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
        width: block.notify ? (app.portrait ? app.screenWidth : displayAreaGrid.width) : 0
        height: block.notify ? (app.portrait ? displayAreaGrid.height : app.screenHeight) : 0
        color: app.styler.blockBg

        Grid {
            id: displayAreaGrid
            columns: app.portrait ? 6 : 1
            rows: app.portrait ? 1 : 6
            height: app.portrait
                        ? Math.max(iconImage.height, displayAreaA.height, displayAreaB.height, displayAreaC.height)
                        : app.screenHeight
            width: app.portrait ? app.screenWidth : calculatedWidth

            // The display area comprises a next maneuver icon and three information zones,
            // lined up side by side or top to bottom.
            // Here, we work out what each zone's width would be in portrait and save it
            // to use in both portraid and landscape, when elements are stocked vertically.
            property real calculatedWidth: (((app.portrait ? app.screenWidth : app.screenHeight) - iconImage.sourceSize.width) / 3)
                                           + (app.portrait ? 0 : (Theme.paddingMedium * 2))

            Image {
                // Icon for the next maneuver
                id: iconImage
                anchors.leftMargin: Theme.paddingSmall
                anchors.rightMargin: Theme.paddingSmall
                anchors.topMargin: Theme.paddingSmall
                anchors.bottomMargin: Theme.paddingSmall
                fillMode: Image.Pad
                smooth: true
                source: block.notify ? "icons/navigation/%1.svg".arg(block.icon || "flag") : ""
                sourceSize.height: (Screen.sizeCategory >= Screen.Large ? 1.7 : 1) * Theme.iconSizeLarge
                sourceSize.width: (Screen.sizeCategory >= Screen.Large ? 1.7 : 1) * Theme.iconSizeLarge
                height: sourceSize.height
                width: app.portrait ? sourceSize.width : parent.calculatedWidth
            }

            NavigationBlockElement {
                // Left (or top) area, e.g. a distance to the next maneuver
                id: displayAreaA
                width: parent.calculatedWidth
                value: token(block.manDist, " ", 0)
                caption: long_word_distance(token(block.manDist, " ", 1))
            }

            Rectangle {
                // Dummy spacer, only taking effect in landscape mode
                id: spacerAB
                width: app.portrait ?  0 : (app.screenHeight - iconImage.height - displayAreaA.height - displayAreaB.height - displayAreaC.height) / 3
                height: width
                opacity: 0
            }

            NavigationBlockElement {
                // Middle area, e.g. current speed
                id: displayAreaB
                width: parent.calculatedWidth
                value: speed_value()
                caption: speed_unit()
            }

            Rectangle {
                // Dummy spacer, only taking effect in landscape mode
                id: spacerBC
                width: spacerAB.height
                height: width
                opacity: 0
            }

            NavigationBlockElement {
                // Right (or bottom) area, e.g. a distance to the destination or ETA
                id: displayAreaC
                width: parent.calculatedWidth
                value: block.destEta
                caption: app.tr("ETA")
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
            return Util.siground(gps.position.speed * 3.6, 2);
        } else {
            return Util.siground(gps.position.speed * 2.23694, 2);
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
