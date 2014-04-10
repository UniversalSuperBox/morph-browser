/*
 * Copyright 2013-2014 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQml 2.0

/*
 * Useful documentation:
 *   http://en.wikipedia.org/wiki/User_agent#Format
 *   https://developer.mozilla.org/en-US/docs/Gecko_user_agent_string_reference
 *   https://wiki.mozilla.org/B2G/User_Agent
 *   https://github.com/mozilla-b2g/gaia/blob/master/build/ua-override-prefs.js
 *   https://developers.google.com/chrome/mobile/docs/user-agent
 */

QtObject {
    // %1: Ubuntu version, e.g. "14.04"
    // %2: optional token to specify further attributes of the platform (must start with a whitespace), e.g. "like Android"
    // %3: optional hardware ID token (must start with a semi-colon if present)
    // %4: WebKit version, e.g. "537.36"
    // %5: Chromium version, e.g. "35.0.1870.2"
    // %6: optional token to provide additional free-form information (must start with a whitespace), e.g. "Mobile"
    // note #1: "Mozilla/5.0" is misinformation, but it is a legacy token that
    //   virtually every single UA out there has, it seems unwise to remove it
    // note #2: "AppleWebKit", as opposed to plain "WebKit", does make a
    //   difference in the content served by certain sites (e.g. gmail.com)
    readonly property string _template: "Mozilla/5.0 (Linux; Ubuntu %1%2%3) AppleWebKit/%4 Chromium/%5%6"

    // FIXME: compute at build time (using lsb_release)
    readonly property string _ubuntuVersion: "14.04"

    readonly property string _attributes: (formFactor === "mobile") ? " like Android 4.4" : ""

    readonly property string _hardwareID: ""

    // See chromium/src/webkit/build/webkit_version.h.in in oxide’s source tree.
    readonly property string _webkitVersion: "537.36"

    // See chromium/src/chrome/VERSION in oxide’s source tree.
    // Note: the actual version number probably doesn’t matter that much,
    //       however its format does, so we probably don’t need to bump it
    //       every time we rebase on a newer chromium.
    readonly property string _chromiumVersion: "35.0.1870.2"

    readonly property string _more: (formFactor === "mobile") ? " Mobile" : ""

    property string defaultUA: _template.arg(_ubuntuVersion).arg(_attributes).arg(_hardwareID).arg(_webkitVersion).arg(_chromiumVersion).arg(_more)
}