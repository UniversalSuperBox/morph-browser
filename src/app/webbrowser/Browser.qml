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

import QtQuick 2.0
import com.canonical.Oxide 1.0 as Oxide
import Ubuntu.Components 1.1
import webbrowserapp.private 0.1
import webbrowsercommon.private 0.1
import "../actions" as Actions
import ".."
import "../UrlUtils.js" as UrlUtils

BrowserView {
    id: browser

    property bool restoreSession: true

    currentWebview: tabsModel.currentTab ? tabsModel.currentTab.webview : null

    property var historyModel: (historyModelLoader.status == Loader.Ready) ? historyModelLoader.item : null
    property var bookmarksModel: (bookmarksModelLoader.status == Loader.Ready) ? bookmarksModelLoader.item : null

    property url homepage
    property QtObject searchEngine

    // XXX: we might want to tweak this value depending
    // on the form factor and/or the available memory
    readonly property int maxLiveWebviews: 2

    // Restore only the n most recent tabs at startup,
    // to limit the overhead of instantiating too many
    // tab objects (see http://pad.lv/1376433).
    readonly property int maxTabsToRestore: 10

    actions: [
        Actions.GoTo {
            onTriggered: currentWebview.url = value
        },
        Actions.Back {
            enabled: currentWebview ? currentWebview.canGoBack : false
            onTriggered: currentWebview.goBack()
        },
        Actions.Forward {
            enabled: currentWebview ? currentWebview.canGoForward : false
            onTriggered: currentWebview.goForward()
        },
        Actions.Reload {
            enabled: currentWebview
            onTriggered: currentWebview.reload()
        },
        Actions.Bookmark {
            enabled: currentWebview && browser.bookmarksModel
            onTriggered: browser.bookmarksModel.add(currentWebview.url, currentWebview.title, currentWebview.icon)
        },
        Actions.NewTab {
            onTriggered: browser.openUrlInNewTab("", true)
        },
        Actions.ClearHistory {
            enabled: browser.historyModel
            onTriggered: browser.historyModel.clearAll()
        }
    ]

    Item {
        id: mainView

        anchors.fill: parent
        visible: !historyViewContainer.visible && !tabsViewContainer.visible

        FocusScope {
            id: tabContainer
            anchors {
                left: parent.left
                right: parent.right
                top: chrome.bottom
            }
            height: parent.height - chrome.visibleHeight - osk.height
        }

        Loader {
            anchors.fill: tabContainer
            sourceComponent: ErrorSheet {
                visible: currentWebview ? currentWebview.lastLoadFailed : false
                url: currentWebview ? currentWebview.url : ""
                onRefreshClicked: currentWebview.reload()
            }
            asynchronous: true
        }

        Loader {
            anchors.fill: tabContainer
            sourceComponent: InvalidCertificateErrorSheet {
                visible: currentWebview && currentWebview.certificateError != null
                certificateError: currentWebview ? currentWebview.certificateError : null
                onAllowed: {
                    // Automatically allow future requests involving this
                    // certificate for the duration of the session.
                    internal.allowCertificateError(currentWebview.certificateError)
                    currentWebview.resetCertificateError()
                }
                onDenied: {
                    currentWebview.resetCertificateError()
                }
            }
            asynchronous: true
        }

        Chrome {
            id: chrome

            webview: browser.currentWebview
            searchUrl: browser.searchEngine ? browser.searchEngine.template : ""

            function isCurrentUrlBookmarked() {
                return ((webview && browser.bookmarksModel) ? browser.bookmarksModel.contains(webview.url) : false)
            }
            bookmarked: isCurrentUrlBookmarked()
            onBookmarkedChanged: {
                if (bookmarked && !isCurrentUrlBookmarked()) {
                    browser.bookmarksModel.add(webview.url, webview.title, webview.icon)
                } else if (!bookmarked && isCurrentUrlBookmarked()) {
                    browser.bookmarksModel.remove(webview.url)
                }
            }
            onWebviewChanged: bookmarked = isCurrentUrlBookmarked()
            Connections {
                target: chrome.webview
                onUrlChanged: chrome.bookmarked = chrome.isCurrentUrlBookmarked()
            }
            Connections {
                target: browser.bookmarksModel
                onAdded: if (!chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = true
                onRemoved: if (chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = false
            }

            anchors {
                left: parent.left
                right: parent.right
            }
            height: units.gu(6)

            drawerActions: [
                Action {
                    objectName: "share"
                    text: i18n.tr("Share")
                    iconName: "share"
                    enabled: (formFactor == "mobile") && browser.currentWebview && browser.currentWebview.url.toString()
                    onTriggered: {
                        var component = Qt.createComponent("../Share.qml")
                        if (component.status == Component.Ready) {
                            var share = component.createObject(browser)
                            share.onDone.connect(share.destroy)
                            share.shareLink(browser.currentWebview.url, browser.currentWebview.title)
                        }
                    }
                },
                Action {
                    objectName: "history"
                    text: i18n.tr("History")
                    iconName: "history"
                    enabled: browser.historyModel
                    onTriggered: historyViewComponent.createObject(historyViewContainer)
                },
                Action {
                    objectName: "tabs"
                    text: i18n.tr("Open tabs")
                    iconName: "browser-tabs"
                    onTriggered: tabsViewComponent.createObject(tabsViewContainer)
                },
                Action {
                    objectName: "newtab"
                    text: i18n.tr("New tab")
                    iconName: "tab-new"
                    onTriggered: browser.openUrlInNewTab("", true)
                }
            ]

            Connections {
                target: browser.currentWebview
                onLoadingChanged: {
                    if (browser.currentWebview.loading) {
                        chrome.state = "shown"
                    } else if (browser.currentWebview.fullscreen) {
                        chrome.state = "hidden"
                    }
                }
                onFullscreenChanged: {
                    if (browser.currentWebview.fullscreen) {
                        chrome.state = "hidden"
                    } else {
                        chrome.state = "shown"
                    }
                }
            }
        }

        ChromeStateTracker {
            webview: browser.currentWebview
            header: chrome
        }

        Suggestions {
            opacity: ((chrome.state == "shown") && chrome.activeFocus && (count > 0) && !chrome.drawerOpen) ? 1.0 : 0.0
            Behavior on opacity {
                UbuntuNumberAnimation {}
            }
            enabled: opacity > 0
            anchors {
                top: chrome.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: chrome.width - units.gu(5)
            height: enabled ? Math.min(contentHeight, tabContainer.height - units.gu(2)) : 0
            model: HistoryMatchesModel {
                sourceModel: browser.historyModel
                query: chrome.text
            }
            onSelected: {
                browser.currentWebview.url = url
                browser.currentWebview.forceActiveFocus()
                chrome.requestedUrl = url
            }
        }
    }

    Item {
        id: tabsViewContainer

        visible: children.length > 0
        anchors.fill: parent

        Component {
            id: tabsViewComponent

            TabsView {
                anchors.fill: parent
                model: tabsModel
                onNewTabRequested: browser.openUrlInNewTab("", true)
                onDone: {
                    tabsModel.currentTab.load()
                    this.destroy()
                }
            }
        }
    }

    Item {
        id: historyViewContainer

        visible: children.length > 0
        anchors.fill: parent

        Component {
            id: historyViewComponent

            HistoryView {
                anchors.fill: parent
                visible: historyViewContainer.children.length == 1

                Timer {
                    // Set the model asynchronously to ensure
                    // the view is displayed as early as possible.
                    running: true
                    interval: 1
                    onTriggered: historyModel = browser.historyModel
                }

                onSeeMoreEntriesClicked: {
                    var view = expandedHistoryViewComponent.createObject(historyViewContainer, {model: model})
                    view.onHistoryEntryClicked.connect(destroy)
                }
                onHistoryDomainRemoved: browser.historyModel.removeEntriesByDomain(domain)
                onDone: destroy()
            }
        }

        Component {
            id: expandedHistoryViewComponent

            ExpandedHistoryView {
                anchors.fill: parent

                onHistoryEntryClicked: {
                    browser.openUrlInNewTab(url, true)
                    done()
                }
                onHistoryEntryRemoved: browser.historyModel.removeEntryByUrl(url)
                onDone: destroy()
            }
        }
    }

    TabsModel {
        id: tabsModel

        // Ensure that at most n webviews are instantiated at all times,
        // to reduce memory consumption (see http://pad.lv/1376418).
        onCurrentTabChanged: {
            if (count > browser.maxLiveWebviews) {
                get(browser.maxLiveWebviews).unload()
            }
        }
    }

    Loader {
        id: historyModelLoader
        source: "HistoryModel.qml"
        asynchronous: true
    }

    Loader {
        id: bookmarksModelLoader
        source: "BookmarksModel.qml"
        asynchronous: true
    }

    Component {
        id: tabComponent

        TabComponent {
            anchors.fill: parent
            webviewComponent: WebViewImpl {
                id: webviewimpl

                currentWebview: browser.currentWebview

                anchors.fill: parent
                focus: true

                readonly property bool current: currentWebview === this
                enabled: current
                visible: current

                //experimental.preferences.developerExtrasEnabled: developerExtrasEnabled
                preferences.localStorageEnabled: true
                preferences.appCacheEnabled: true

                contextualActions: ActionList {
                    Actions.OpenLinkInNewTab {
                        enabled: contextualData.href.toString()
                        onTriggered: browser.openUrlInNewTab(contextualData.href, true)
                    }
                    Actions.BookmarkLink {
                        enabled: contextualData.href.toString() && browser.bookmarksModel
                        onTriggered: browser.bookmarksModel.add(contextualData.href, contextualData.title, "")
                    }
                    Actions.CopyLink {
                        enabled: contextualData.href.toString()
                        onTriggered: Clipboard.push([contextualData.href])
                    }
                    Actions.OpenImageInNewTab {
                        enabled: contextualData.img.toString()
                        onTriggered: browser.openUrlInNewTab(contextualData.img, true)
                    }
                    Actions.CopyImage {
                        enabled: contextualData.img.toString()
                        onTriggered: Clipboard.push([contextualData.img])
                    }
                    Actions.SaveImage {
                        enabled: contextualData.img.toString() && downloadLoader.status == Loader.Ready
                        onTriggered: downloadLoader.item.downloadPicture(contextualData.img)
                    }
                }

                onNewViewRequested: {
                    var tab = tabComponent.createObject(tabContainer, {"request": request})
                    var setCurrent = (request.disposition == Oxide.NewViewRequest.DispositionNewForegroundTab)
                    internal.addTab(tab, setCurrent)
                }

                onLoadingChanged: {
                    if (lastLoadSucceeded && browser.historyModel) {
                        browser.historyModel.add(url, title, icon)
                    }
                }

                onGeolocationPermissionRequested: requestGeolocationPermission(request)

                property var certificateError
                function resetCertificateError() {
                    certificateError = null
                }
                onCertificateError: {
                    if (!error.isMainFrame || error.isSubresource) {
                        // Not a main frame document error, just block the content
                        // (it’s not overridable anyway).
                        return
                    }
                    if (internal.isCertificateErrorAllowed(error)) {
                        error.allow()
                    } else {
                        certificateError = error
                        error.onCancelled.connect(webviewimpl.resetCertificateError)
                    }
                }

                Loader {
                    id: newTabViewLoader
                    anchors.fill: parent

                    sourceComponent: !parent.url.toString() ? newTabViewComponent : undefined

                    Component {
                        id: newTabViewComponent

                        NewTabView {
                            anchors.fill: parent

                            historyModel: browser.historyModel
                            bookmarksModel: browser.bookmarksModel
                            onBookmarkClicked: {
                                chrome.requestedUrl = url
                                currentWebview.url = url
                                currentWebview.forceActiveFocus()
                            }
                            onBookmarkRemoved: browser.bookmarksModel.remove(url)
                            onHistoryEntryClicked: {
                                chrome.requestedUrl = url
                                currentWebview.url = url
                                currentWebview.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: downloadLoader
        source: formFactor == "desktop" ? "" : "../Downloader.qml"
        asynchronous: true
    }

    QtObject {
        id: internal

        function addTab(tab, setCurrent) {
            var index = tabsModel.add(tab)
            if (setCurrent) {
                tabsModel.setCurrent(index)
                chrome.requestedUrl = tab.initialUrl
            }
        }

        function focusAddressBar() {
            chrome.forceActiveFocus()
            Qt.inputMethod.show() // work around http://pad.lv/1316057
        }

        // Invalid certificates the user has explicitly allowed for this session
        property var allowedCertificateErrors: []

        function allowCertificateError(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            allowedCertificateErrors.push([host, code, fingerprint])
        }

        function isCertificateErrorAllowed(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            for (var i in allowedCertificateErrors) {
                var allowed = allowedCertificateErrors[i]
                if ((host == allowed[0]) &&
                    (code == allowed[1]) &&
                    (fingerprint == allowed[2])) {
                    return true
                }
            }
            return false
        }
    }

    function openUrlInNewTab(url, setCurrent, load) {
        load = typeof load !== 'undefined' ? load : true
        var tab = tabComponent.createObject(tabContainer, {"initialUrl": url})
        internal.addTab(tab, setCurrent)
        if (load) {
            tabsModel.currentTab.load()
        }
        if (!url.toString() && (formFactor == "desktop")) {
            internal.focusAddressBar()
        }
    }

    SessionStorage {
        id: session

        dataFile: dataLocation + "/session.json"

        function save() {
            if (!locked) {
                return
            }
            var tabs = []
            for (var i = 0; i < tabsModel.count; ++i) {
                var tab = tabsModel.get(i)
                tabs.push(serializeTabState(tab))
            }
            store(JSON.stringify({tabs: tabs}))
        }

        function restore() {
            if (!locked) {
                return
            }
            var state = null
            try {
                state = JSON.parse(retrieve())
            } catch (e) {
                return
            }
            if (state) {
                var tabs = state.tabs
                if (tabs) {
                    for (var i = 0; i < Math.min(tabs.length, browser.maxTabsToRestore); ++i) {
                        var tab = createTabFromState(tabs[i])
                        internal.addTab(tab, i == 0)
                    }
                }
            }
        }

        // Those two functions are used to save/restore the current state of a tab.
        // The current implementation is naive, it only saves/restores the current URL.
        // In the future, we’ll want to rely on oxide to save and restore a full state
        // of the corresponding webview as a binary blob, which includes navigation
        // history, current scroll offset and form data. See http://pad.lv/1353143.
        function serializeTabState(tab) {
            var state = {}
            state.uniqueId = tab.uniqueId
            state.url = tab.url.toString()
            state.title = tab.title
            state.preview = tab.preview.toString()
            return state
        }

        function createTabFromState(state) {
            var properties = {"initialUrl": state.url, "initialTitle": state.title}
            if ('uniqueId' in state) {
                properties["uniqueId"] = state.uniqueId
            }
            if ('preview' in state) {
                properties["preview"] = state.preview
            }
            return tabComponent.createObject(tabContainer, properties)
        }
    }
    Connections {
        target: tabsModel
        onCurrentTabChanged: session.save()
        onCountChanged: session.save()
    }
    Connections {
        target: browser.currentWebview
        onUrlChanged: session.save()
        onTitleChanged: session.save()
    }

    // Delay instantiation of the first webview by 1 msec to allow initial
    // rendering to happen. Clumsy workaround for http://pad.lv/1359911.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (browser.restoreSession) {
                session.restore()
            }
            // Sanity check
            console.assert(tabsModel.count <= browser.maxTabsToRestore,
                           "WARNING: too many tabs were restored")
            for (var i in browser.initialUrls) {
                browser.openUrlInNewTab(browser.initialUrls[i], true, false)
            }
            if (tabsModel.count == 0) {
                browser.openUrlInNewTab(browser.homepage, true, false)
            }
            tabsModel.currentTab.load()
            if (!tabsModel.currentTab.url.toString() && (formFactor == "desktop")) {
                internal.focusAddressBar()
            }
        }
    }
}
