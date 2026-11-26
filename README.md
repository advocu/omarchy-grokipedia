# Grokipedia for Omarchy

An unofficial Grokipedia client for the Omarchy top bar. Click the `Gk` button to open a panel. Type a search, press Enter, and read a short brief for each result. **More** opens the article on grokipedia.com in your browser.

When the panel opens it also shows one item from Grokipedia's **Featured** shelf: the item the homepage is featuring at that moment. It is not an "article of the day".

Needs Omarchy 4.x (the Quattro shell with plugin support). Plain QML and JavaScript. It starts no processes, writes no files, and talks only to `https://grokipedia.com`.

## Install

```sh
omarchy plugin add https://github.com/advocu/omarchy-grokipedia --enable
```

The widget goes to the right side of the bar. To put it somewhere else:

```sh
omarchy bar move io.github.advocu.grokipedia --section left
```

Sections are `left`, `centerBegin`, `center`, `centerEnd`, `tray`, and `right`.

## Use

| Input | What it does |
| --- | --- |
| Click `Gk` | Open or close the panel. The search box has focus. |
| Type, then `Enter` or **Search** | Search Grokipedia |
| **More** on a result or on Featured | Open that article in your browser |
| `Esc` | Close the panel |
| `Tab` / `Shift+Tab` | Move to the next or previous bar popup |

Nothing is sent while you type. A search runs only when you press Enter or click **Search**.

You can also open and close it from a terminal or a key binding:

```sh
omarchy-shell shell summon io.github.advocu.grokipedia '{}'
omarchy-shell shell hide io.github.advocu.grokipedia
```

## Network and privacy

Plugins run inside the `omarchy-shell` process, so this one keeps its network use small and bounded:

- **Requests**: Qt's built-in `XMLHttpRequest`, in process. HTTPS `GET` only.
- **Host**: `grokipedia.com` only. Only two URLs are ever requested: `https://grokipedia.com/` (for Featured) and `https://grokipedia.com/search?q=<your query>`. Any other URL is refused before the request opens. A redirect to anything else is treated as an error.
- **When**: Featured loads when you open the panel (at most once every 10 minutes after a success). Search runs only when you submit it. Nothing runs while the panel is closed: no polling, no typeahead.
- **Size**: each response is capped at 256 KiB. A larger `Content-Length` aborts the request at once, the body is checked every 100 ms while it arrives, and an oversized body is dropped without being parsed.
- **Time**: each request times out after 10 seconds and shows an error. There are no automatic retries.
- **One at a time**: starting a search, or closing the panel, cancels the request in flight.
- **Not used**: `/api/*` (disallowed by the site's `robots.txt`), article pages (`/page/*` is never downloaded), images, analytics, accounts, and login. The plugin sets no cookies or auth headers and stores nothing on disk.
- **Opening links**: **More** calls `Qt.openUrlExternally` with a URL the plugin builds itself: `https://grokipedia.com/page/<slug>` after the slug is checked, or the search page or homepage if there is no valid slug. It never opens a URL taken from the server's response.

Grokipedia sits behind Cloudflare and its markup can change. If the site sends a challenge page, an error, or HTML the plugin does not recognise, the panel says so and offers a button to open grokipedia.com in your browser.

Requests go to grokipedia.com, operated by SpaceX Super Intelligence LLC (SpaceXSI), and are covered by the SpaceXSI Privacy Policy linked below. Qt may keep cookies the site sets (for example Cloudflare's) in memory for the life of the shell session; the plugin does not read, set, or save them.

## Attribution and legal

**Powered by SpaceXSI.** Grokipedia content is made available under the SpaceXSI Community License Agreement (SpaceX Super Intelligence LLC; `grokipedia.com` also displays SpaceXAI in its footer), and some articles also under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The panel shows this attribution under the results.

- [SpaceXSI Terms of Service](https://x.ai/legal/terms-of-service)
- [SpaceXSI Privacy Policy](https://x.ai/legal/privacy-policy)
- [SpaceXSI Acceptable Use Policy](https://x.ai/legal/acceptable-use-policy)

This is an unofficial client. It is not made, endorsed, or supported by SpaceXSI (SpaceX Super Intelligence LLC) or SpaceXAI.

## Remove

```sh
omarchy plugin remove io.github.advocu.grokipedia
```

The plugin writes no files of its own, so removing it leaves nothing behind.

## Check a local copy

```sh
omarchy plugin validate ./omarchy-grokipedia
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

## License

The plugin code is MIT. See [LICENSE](LICENSE), which also covers the Grokipedia content notice.
