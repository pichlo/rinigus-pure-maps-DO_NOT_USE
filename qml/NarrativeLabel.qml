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

Rectangle {
    id: block
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: notify
               ? (app.portrait ? app.screenWidth : app.screenHeight)
               : 0
    height: notify ? narrativeLabelText.height : 0
    radius: app.portrait ? 0 : Theme.paddingMedium
    color: app.styler.blockBg

    property bool   notify:    app.navigationStatus.notify
    property string narrative: app.navigationStatus.narrative
    property var    street:    app.navigationStatus.street

    Label {
        id: narrativeLabelText
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
