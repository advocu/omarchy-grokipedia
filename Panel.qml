import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Grokipedia.js" as Grok

// Grokipedia search panel. Network rules live in Grokipedia.js; this file
// only decides when a request may start (panel open, explicit submit) and
// keeps at most one request in flight.
Panel {
    id: root
    moduleName: "io.github.advocu.grokipedia"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null

    readonly property color textColor: root.barForeground
    readonly property color bodyText: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.90)
    readonly property color secondaryText: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.78)
    readonly property color accentColor: Commons.Color.accent
    readonly property color warnColor: Commons.Color.warning
    readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

    // Featured shelf: "idle", "loading", "ready", "empty", "error".
    property string featuredState: "idle"
    property string featuredError: ""
    property var featured: null
    property double featuredLoadedAt: 0
    readonly property int featuredFreshMs: 10 * 60 * 1000

    // Search: "idle", "loading", "ready", "empty", "error".
    property string searchState: "idle"
    property string searchError: ""
    property string lastQuery: ""
    property var results: []

    // The one in-flight request (a Grokipedia.js handle), or null.
    property var request: null
    readonly property string reasonClosed: "Panel closed."
    readonly property string reasonReplaced: "Replaced by a newer request."

    onOpenedChanged: {
        if (root.opened) {
            root.loadFeatured()
        } else {
            root.cancelRequest(root.reasonClosed)
        }
    }

    function open() {
        root.controller.show()
    }

    function close() {
        root.cancelRequest(root.reasonClosed)
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    // ---- requests

    function cancelRequest(reason) {
        var r = root.request
        root.request = null
        watchdog.stop()
        timeoutTimer.stop()
        if (r && !r.finished) r.abort(reason)
    }

    // Starts a GET for an allowlisted URL. Any request already in flight is
    // aborted first. Grokipedia.js refuses other URLs before open().
    function startRequest(url, onDone) {
        root.cancelRequest(root.reasonReplaced)
        var handle = null
        handle = Grok.startGet(new XMLHttpRequest(), url, function(error, text) {
            if (root.request === handle) {
                root.request = null
                watchdog.stop()
                timeoutTimer.stop()
            }
            onDone(error, text)
        })
        if (handle && !handle.finished) {
            root.request = handle
            watchdog.start()
            timeoutTimer.restart()
        }
    }

    function cancelled(error) {
        return error === root.reasonClosed || error === root.reasonReplaced
    }

    function loadFeatured() {
        var now = Date.now()
        if (root.featuredState === "ready" && now - root.featuredLoadedAt < root.featuredFreshMs) return
        if (root.searchState === "loading") return
        root.featuredState = "loading"
        root.featuredError = ""
        root.startRequest(Grok.HOME_URL, function(error, text) {
            if (root.cancelled(error)) {
                root.featuredState = "idle"
                return
            }
            if (error) {
                root.featuredState = "error"
                root.featuredError = error
                return
            }
            var items = Grok.parseFeatured(text)
            text = ""
            if (items.length === 0) {
                root.featured = null
                root.featuredState = "empty"
                return
            }
            root.featured = items[0]
            root.featuredLoadedAt = Date.now()
            root.featuredState = "ready"
        })
    }

    function submitSearch() {
        var query = searchField.text.trim()
        if (query.length === 0) return
        var url = Grok.searchUrl(query)
        root.lastQuery = query
        root.results = []
        if (!url) {
            root.searchState = "error"
            root.searchError = "Search text must be 1 to " + Grok.MAX_QUERY_CHARS + " characters."
            return
        }
        root.searchState = "loading"
        root.searchError = ""
        root.startRequest(url, function(error, text) {
            if (root.cancelled(error)) {
                root.searchState = "idle"
                return
            }
            if (error) {
                root.searchState = "error"
                root.searchError = error
                return
            }
            var items = Grok.parseSearch(text)
            text = ""
            root.results = items
            root.searchState = items.length > 0 ? "ready" : "empty"
        })
    }

    // Opens only https://grokipedia.com/page/{slug}, or the search page or
    // homepage as a fallback. The URL is rebuilt from a validated slug, never
    // taken from the server.
    function openMore(slug, fallbackQuery) {
        var url = Grok.moreUrl(slug, fallbackQuery)
        if (Grok.isAllowedOpenUrl(url)) Qt.openUrlExternally(url)
    }

    Timer {
        id: timeoutTimer
        interval: Grok.TIMEOUT_MS
        repeat: false
        onTriggered: if (root.request) root.request.timeout()
    }

    // Size check on the buffered body while a request is in flight. Stops
    // when the request ends; never runs while the panel is closed.
    Timer {
        id: watchdog
        interval: 100
        repeat: true
        onTriggered: {
            if (root.request) root.request.checkBuffer()
            else stop()
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: searchField
        contentWidth: panel.fittedContentWidth(Style.space(520))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: searchField.activeFocus
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                root.switchPanel(direction)
            }

            Column {
                id: mainColumn
                width: parent.width
                spacing: Style.space(10)

                // ---- Search row
                Row {
                    width: parent.width
                    spacing: Style.space(8)

                    TextField {
                        id: searchField
                        width: parent.width - searchButton.width - parent.spacing
                        placeholderText: "Search Grokipedia"
                        foreground: root.textColor
                        font.family: root.fontFamily
                        maximumLength: Grok.MAX_QUERY_CHARS
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.submitSearch()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                root.switchPanel(event.key === Qt.Key_Backtab ? -1 : 1)
                                event.accepted = true
                            }
                        }
                    }

                    Button {
                        id: searchButton
                        text: "Search"
                        bordered: true
                        foreground: root.textColor
                        fontFamily: root.fontFamily
                        anchors.verticalCenter: searchField.verticalCenter
                        onClicked: root.submitSearch()
                    }
                }

                // ---- Search status
                Text {
                    width: parent.width
                    visible: root.searchState === "loading" || root.searchState === "empty" || root.searchState === "error"
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    text: root.searchState === "loading" ? "Searching\u2026"
                        : root.searchState === "empty" ? "No results for \u201c" + root.lastQuery + "\u201d."
                        : root.searchError
                    color: root.searchState === "error" ? root.warnColor : root.secondaryText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                }

                Button {
                    visible: root.searchState === "error" || root.searchState === "empty"
                    text: "Open search on grokipedia.com"
                    bordered: true
                    foreground: root.textColor
                    fontFamily: root.fontFamily
                    onClicked: root.openMore("", root.lastQuery)
                }

                // ---- Search results
                Flickable {
                    id: resultsScroll
                    width: parent.width
                    visible: root.searchState === "ready"
                    height: visible ? Math.min(resultsColumn.implicitHeight, Style.space(380)) : 0
                    contentWidth: width
                    contentHeight: resultsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: resultsColumn
                        width: resultsScroll.width
                        spacing: Style.space(6)

                        Repeater {
                            model: root.results

                            delegate: Rectangle {
                                id: resultCard
                                required property var modelData
                                width: resultsColumn.width
                                height: resultRow.implicitHeight + Style.space(16)
                                radius: Style.cornerRadius
                                color: Style.normalFill

                                Row {
                                    id: resultRow
                                    x: Style.space(8)
                                    y: Style.space(8)
                                    width: parent.width - Style.space(16)
                                    spacing: Style.space(8)

                                    Column {
                                        width: parent.width - resultMore.width - parent.spacing
                                        spacing: Style.space(2)

                                        Text {
                                            width: parent.width
                                            textFormat: Text.PlainText
                                            text: resultCard.modelData.title
                                            elide: Text.ElideRight
                                            color: root.textColor
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.subtitle
                                            font.bold: true
                                        }

                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            textFormat: Text.PlainText
                                            text: resultCard.modelData.snippet
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            color: root.bodyText
                                            font.family: root.fontFamily
                                            font.pixelSize: Style.font.bodySmall
                                        }
                                    }

                                    Button {
                                        id: resultMore
                                        text: "More"
                                        bordered: true
                                        foreground: root.textColor
                                        fontFamily: root.fontFamily
                                        tooltipText: "Open on grokipedia.com"
                                        onClicked: root.openMore(resultCard.modelData.slug, root.lastQuery)
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Featured (Grokipedia's Featured shelf, not an article of the day)
                Rectangle {
                    width: parent.width
                    visible: root.searchState !== "ready"
                    height: visible ? featuredColumn.implicitHeight + Style.space(20) : 0
                    radius: Style.cornerRadius
                    color: Style.normalFill

                    Column {
                        id: featuredColumn
                        x: Style.space(10)
                        y: Style.space(10)
                        width: parent.width - Style.space(20)
                        spacing: Style.space(6)

                        Text {
                            textFormat: Text.PlainText
                            text: "Featured"
                            color: root.accentColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Text {
                            width: parent.width
                            visible: root.featuredState !== "ready"
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            text: root.featuredState === "error" ? "Featured did not load. " + root.featuredError
                                : root.featuredState === "empty" ? "No Featured items found on grokipedia.com."
                                : root.featuredState === "loading" ? "Loading Featured\u2026"
                                : "Featured loads when the panel opens."
                            color: root.featuredState === "error" ? root.warnColor : root.secondaryText
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                        }

                        Text {
                            width: parent.width
                            visible: root.featuredState === "ready" && root.featured !== null
                            textFormat: Text.PlainText
                            text: root.featured ? root.featured.title : ""
                            elide: Text.ElideRight
                            color: root.textColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.heading
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            visible: root.featuredState === "ready" && text !== ""
                            textFormat: Text.PlainText
                            text: root.featured ? root.featured.dek : ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: root.bodyText
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                        }

                        Button {
                            visible: root.featuredState !== "loading"
                            text: root.featuredState === "ready" ? "More" : "Open grokipedia.com"
                            bordered: true
                            foreground: root.textColor
                            fontFamily: root.fontFamily
                            onClicked: root.openMore(root.featuredState === "ready" && root.featured ? root.featured.slug : "", "")
                        }
                    }
                }

                // ---- Attribution
                Column {
                    width: parent.width
                    spacing: Style.space(2)

                    Text {
                        textFormat: Text.PlainText
                        text: "Powered by SpaceXSI"
                        color: root.textColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        text: "Content from Grokipedia under the SpaceXSI Community License; some articles CC BY-SA 4.0. Unofficial client."
                        color: root.secondaryText
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }
}
