import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
// Qt 6.12 adds a QtQuick Color type that shadows the shell palette singleton.
// Qualified references resolve to the palette on every Qt version.
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.faeric.omasnake"

  readonly property int columns: 20
  readonly property int rows: 16
  readonly property int cellSize: 14
  readonly property color lcdLight: "#9bbc0f"
  readonly property color lcdMid: "#8bac0f"
  readonly property color lcdDark: "#306230"
  readonly property color lcdInk: "#0f380f"
  readonly property color popupText: Commons.Color.popups.text
  readonly property color popupBorder: Commons.Color.popups.border
  readonly property color popupAccent: Commons.Color.accent
  readonly property string popupFont: Style.font.family

  property bool popupOpen: false
  property bool running: false
  property bool paused: false
  property bool gameOver: false
  property int directionX: 1
  property int directionY: 0
  property int queuedX: 1
  property int queuedY: 0
  property var snake: []
  property var food: ({ x: 14, y: 8 })
  property int score: 0
  property int highScore: 0
  property int boardRevision: 0

  readonly property bool opened: popupOpen
  readonly property string statusText: gameOver ? "GAME OVER" : paused ? "PAUSED" : running ? "OMASNAKE" : "READY?"

  function open() {
    popupOpen = true
    if (snake.length === 0 || gameOver) resetGame(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    popupOpen = false
    if (running) paused = true
  }

  function closeForPopoutSwitch() {
    close()
  }

  function togglePanel() {
    if (popupOpen) close()
    else open()
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(root, direction)
    return false
  }

  function resetGame(autoStart) {
    var midY = Math.floor(rows / 2)
    snake = [
      { x: 6, y: midY },
      { x: 5, y: midY },
      { x: 4, y: midY }
    ]
    directionX = 1
    directionY = 0
    queuedX = 1
    queuedY = 0
    score = 0
    gameOver = false
    paused = false
    running = autoStart === true
    spawnFood()
    boardRevision++
  }

  function startOrTogglePause() {
    if (gameOver) {
      resetGame(true)
      return
    }
    if (!running) {
      running = true
      paused = false
      return
    }
    paused = !paused
  }

  function requestDirection(dx, dy) {
    if (gameOver) return
    if (!running) running = true
    paused = false
    if (dx === -directionX && dy === -directionY) return
    queuedX = dx
    queuedY = dy
  }

  function occupies(x, y, limit) {
    var count = limit === undefined ? snake.length : limit
    for (var i = 0; i < count; i++) {
      if (snake[i].x === x && snake[i].y === y) return true
    }
    return false
  }

  function snakeIndex(x, y) {
    var rev = boardRevision
    for (var i = 0; i < snake.length; i++) {
      if (snake[i].x === x && snake[i].y === y) return i
    }
    return -1
  }

  function spawnFood() {
    var free = []
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (!occupies(x, y)) free.push({ x: x, y: y })
      }
    }
    if (free.length === 0) {
      finishGame()
      return
    }
    food = free[Math.floor(Math.random() * free.length)]
  }

  function finishGame() {
    running = false
    paused = false
    gameOver = true
    highScore = Math.max(highScore, score)
  }

  function advance() {
    if (!running || paused || gameOver || snake.length === 0) return

    directionX = queuedX
    directionY = queuedY
    var head = snake[0]
    var next = { x: head.x + directionX, y: head.y + directionY }
    var ate = next.x === food.x && next.y === food.y
    var collisionLimit = snake.length - (ate ? 0 : 1)

    if (next.x < 0 || next.x >= columns || next.y < 0 || next.y >= rows
        || occupies(next.x, next.y, collisionLimit)) {
      finishGame()
      boardRevision++
      return
    }

    var moved = [next]
    for (var i = 0; i < snake.length; i++) moved.push(snake[i])
    if (!ate) moved.pop()
    snake = moved

    if (ate) {
      score++
      highScore = Math.max(highScore, score)
      spawnFood()
    }
    boardRevision++
  }

  function handleTextKey(text) {
    var key = String(text || "").toLowerCase()
    if (key === "w") requestDirection(0, -1)
    else if (key === "s") requestDirection(0, 1)
    else if (key === "a") requestDirection(-1, 0)
    else if (key === "d") requestDirection(1, 0)
    else if (key === "p") startOrTogglePause()
    else if (key === "r") resetGame(true)
  }

  // Three-by-five square-pixel digits, matching the classic LCD treatment.
  function digitPattern(digit) {
    var patterns = [
      "111101101101111",
      "010110010010111",
      "111001111100111",
      "111001111001111",
      "101101111001001",
      "111100111001111",
      "111100111101111",
      "111001001001001",
      "111101111101111",
      "111101111001111"
    ]
    var value = Math.max(0, Math.min(9, Number(digit) || 0))
    return patterns[value]
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onPopupOpenChanged: {
    if (popupOpen) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Timer {
    interval: Math.max(68, 165 - root.score * 4)
    running: root.popupOpen && root.running && !root.paused && !root.gameOver
    repeat: true
    onTriggered: root.advance()
  }

  IpcHandler {
    target: "io.github.faeric.omasnake"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function restart(): void { root.resetGame(true) }
    function pause(): void { root.startOrTogglePause() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "S"
    active: root.running && !root.paused
    tooltipText: root.gameOver
      ? "Omasnake · score " + root.score + " · click to play again"
      : "Omasnake · click to play"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.resetGame(true)
      else if (mouseButton === Qt.MiddleButton) root.startOrTogglePause()
      else root.togglePanel()
    }
  }

  KeyboardPanel {
    id: gamePanel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    // Game geometry is pixel-exact, so the host must not be reduced by the
    // theme spacing scale. This leaves 20 physical pixels of casing on both
    // sides of the 304 px LCD.
    contentWidth: gamePanel.fittedContentWidth(root.columns * root.cellSize + 64)
    contentHeight: gamePanel.fittedContentHeight(gameColumn.implicitHeight, 510)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) root.requestDirection(dx, dy)
      }
      onActivateRequested: root.startOrTogglePause()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { root.handleTextKey(text) }

      Column {
        id: gameColumn
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: root.statusText
          color: root.popupText
          font.family: root.popupFont
          font.pixelSize: Style.font.subtitle
          font.bold: true
          font.letterSpacing: 2
        }

        Rectangle {
          id: phone
          width: parent.width
          height: lcdScreen.height + 32
          radius: Style.space(13)
          color: Style.selectedFillFor(root.popupText, root.popupAccent)
          border.width: Math.max(1, Style.normalBorderWidth)
          border.color: root.popupBorder

          Behavior on color { ColorAnimation { duration: 160 } }

          Rectangle {
            id: lcdScreen
            width: root.columns * root.cellSize + 24
            height: playfieldFrame.height + 54
            anchors.centerIn: parent
            color: root.lcdLight
            border.width: 3
            border.color: root.lcdInk
            clip: true

            Row {
              id: lcdScore
              anchors.left: scoreSeparator.left
              anchors.top: parent.top
              anchors.topMargin: 7
              spacing: 5

              Repeater {
                model: String(root.score).padStart(4, "0").slice(-4).split("")

                Item {
                  required property string modelData
                  readonly property string pattern: root.digitPattern(Number(modelData))
                  width: 11
                  height: 19

                  Repeater {
                    model: 15

                    Rectangle {
                      required property int index
                      visible: parent.pattern.charAt(index) === "1"
                      x: (index % 3) * 4
                      y: Math.floor(index / 3) * 4
                      width: 3
                      height: 3
                      color: root.lcdInk
                    }
                  }
                }
              }
            }

            Item {
              id: scoreSeparator
              width: playfieldFrame.width
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: lcdScore.bottom
              anchors.topMargin: 6
              height: 3

              Repeater {
                model: Math.floor(scoreSeparator.width / 4)

                Rectangle {
                  required property int index
                  x: index * 4
                  width: 3
                  height: 3
                  color: root.lcdInk
                }
              }
            }

            Item {
              id: playfieldFrame
              width: root.columns * root.cellSize + 8
              height: root.rows * root.cellSize + 8
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: scoreSeparator.bottom
              anchors.topMargin: 5

              Repeater {
                model: Math.floor(playfieldFrame.width / 4)
                Rectangle {
                  required property int index
                  x: index * 4
                  width: 3
                  height: 3
                  color: root.lcdInk
                }
              }

              Repeater {
                model: Math.floor(playfieldFrame.width / 4)
                Rectangle {
                  required property int index
                  x: index * 4
                  y: playfieldFrame.height - 3
                  width: 3
                  height: 3
                  color: root.lcdInk
                }
              }

              Repeater {
                model: Math.floor(playfieldFrame.height / 4)
                Rectangle {
                  required property int index
                  y: index * 4
                  width: 3
                  height: 3
                  color: root.lcdInk
                }
              }

              Repeater {
                model: Math.floor(playfieldFrame.height / 4)
                Rectangle {
                  required property int index
                  x: playfieldFrame.width - 3
                  y: index * 4
                  width: 3
                  height: 3
                  color: root.lcdInk
                }
              }

              Item {
                id: board
                anchors.fill: parent
                anchors.margins: 4
                clip: true

                Repeater {
                  model: root.columns * root.rows

                  Item {
                    required property int index
                    readonly property int gridX: index % root.columns
                    readonly property int gridY: Math.floor(index / root.columns)
                    readonly property int bodyIndex: root.snakeIndex(gridX, gridY)
                    readonly property bool isFood: gridX === root.food.x && gridY === root.food.y

                    x: gridX * root.cellSize
                    y: gridY * root.cellSize
                    width: root.cellSize
                    height: root.cellSize

                    Item {
                      id: snakePixel
                      visible: parent.bodyIndex >= 0
                      anchors.centerIn: parent
                      width: 11
                      height: 11

                      Repeater {
                        model: 9

                        Rectangle {
                          required property int index
                          x: (index % 3) * 4
                          y: Math.floor(index / 3) * 4
                          width: 3
                          height: 3
                          radius: 0
                          antialiasing: false
                          color: root.lcdInk
                        }
                      }
                    }

                    Rectangle {
                      visible: parent.isFood
                      anchors.fill: parent
                      anchors.margins: 1
                      radius: 1
                      color: root.lcdInk

                      Image {
                        anchors.centerIn: parent
                        width: parent.width - 2
                        height: parent.height - 2
                        source: Qt.resolvedUrl("assets/omarchy-mark.svg")
                        sourceSize.width: width * 4
                        sourceSize.height: height * 4
                        fillMode: Image.PreserveAspectFit
                      }
                    }
                  }
                }

                Item {
                  id: welcomeFrame
                  visible: !root.running || root.paused || root.gameOver
                  anchors.centerIn: parent
                  width: root.paused || root.gameOver
                    ? Math.ceil((overlayLabel.implicitWidth + 24) / 4) * 4
                    : Math.ceil((welcomeContent.width + 16) / 4) * 4
                  height: root.paused || root.gameOver
                    ? Math.ceil((overlayLabel.implicitHeight + 16) / 4) * 4
                    : Math.ceil((welcomeContent.height + 16) / 4) * 4

                  Rectangle {
                    anchors.fill: parent
                    color: root.lcdLight
                  }

                  Repeater {
                    model: Math.floor(welcomeFrame.width / 4)
                    Rectangle {
                      required property int index
                      x: index * 4
                      width: 3
                      height: 3
                      color: root.lcdInk
                    }
                  }

                  Repeater {
                    model: Math.floor(welcomeFrame.width / 4)
                    Rectangle {
                      required property int index
                      x: index * 4
                      y: welcomeFrame.height - 3
                      width: 3
                      height: 3
                      color: root.lcdInk
                    }
                  }

                  Repeater {
                    model: Math.floor(welcomeFrame.height / 4)
                    Rectangle {
                      required property int index
                      y: index * 4
                      width: 3
                      height: 3
                      color: root.lcdInk
                    }
                  }

                  Repeater {
                    model: Math.floor(welcomeFrame.height / 4)
                    Rectangle {
                      required property int index
                      x: welcomeFrame.width - 3
                      y: index * 4
                      width: 3
                      height: 3
                      color: root.lcdInk
                    }
                  }

                  Text {
                    id: overlayLabel
                    visible: root.paused || root.gameOver
                    anchors.centerIn: parent
                    text: root.gameOver ? "GAME OVER\nSPACE TO PLAY AGAIN"
                      : "PAUSED\nSPACE TO RESUME"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.lcdInk
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.bold: true
                  }

                  Column {
                    id: welcomeContent
                    visible: !root.running && !root.paused && !root.gameOver
                    anchors.centerIn: parent
                    width: board.width - 32
                    height: asciiTitleViewport.height + spacing + welcomePrompt.implicitHeight
                    spacing: 6

                    Item {
                      id: asciiTitleViewport
                      width: parent.width
                      height: 48
                      clip: true

                      Text {
                        id: asciiTitle
                        anchors.centerIn: parent
                        text: " ▄██████▄    ▄▄▄▄███▄▄▄▄      ▄████████    ▄████████ ███▄▄▄▄      ▄████████    ▄█   ▄█▄    ▄████████\n"
                          + "███    ███ ▄██▀▀▀███▀▀▀██▄   ███    ███   ███    ███ ███▀▀▀██▄   ███    ███   ███ ▄███▀   ███    ███\n"
                          + "███    ███ ███   ███   ███   ███    ███   ███    █▀  ███   ███   ███    ███   ███▐██▀     ███    █▀\n"
                          + "███    ███ ███   ███   ███   ███    ███   ███        ███   ███   ███    ███  ▄█████▀     ▄███▄▄▄\n"
                          + "███    ███ ███   ███   ███ ▀███████████ ▀███████████ ███   ███ ▀███████████ ▀▀█████▄    ▀▀███▀▀▀\n"
                          + "███    ███ ███   ███   ███   ███    ███          ███ ███   ███   ███    ███   ███▐██▄     ███    █▄\n"
                          + "███    ███ ███   ███   ███   ███    ███    ▄█    ███ ███   ███   ███    ███   ███ ▀███▄   ███    ███\n"
                          + " ▀██████▀   ▀█   ███   █▀    ███    █▀   ▄████████▀   ▀█   █▀    ███    █▀    ███   ▀█▀   ██████████\n"
                          + "                                                                              ▀"
                        color: root.lcdInk
                        font.family: "monospace"
                        font.pixelSize: 14
                        wrapMode: Text.NoWrap
                        transformOrigin: Item.Center
                        scale: Math.min(
                          asciiTitleViewport.width / Math.max(1, implicitWidth),
                          asciiTitleViewport.height / Math.max(1, implicitHeight)
                        )
                        layer.enabled: true
                        layer.smooth: true
                      }
                    }

                    Text {
                      id: welcomePrompt
                      width: parent.width
                      text: "ARROW KEY TO PLAY"
                      color: root.lcdInk
                      font.family: "monospace"
                      font.pixelSize: 11
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }
                }
              }
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Repeater {
            model: [
              { label: "←", dx: -1, dy: 0 },
              { label: "↑", dx: 0, dy: -1 },
              { label: "↓", dx: 0, dy: 1 },
              { label: "→", dx: 1, dy: 0 }
            ]

            Button {
              required property var modelData
              width: Style.space(40)
              height: Style.space(30)
              text: modelData.label
              foreground: root.popupText
              accent: root.popupAccent
              fontFamily: root.popupFont
              fontSize: Style.font.heading
              bordered: true
              onClicked: {
                root.requestDirection(modelData.dx, modelData.dy)
                keyCatcher.forceActiveFocus()
              }
            }
          }

          Button {
            width: Style.space(72)
            height: Style.space(30)
            text: root.gameOver ? "PLAY AGAIN" : root.running && !root.paused ? "PAUSE" : "PLAY"
            foreground: root.popupText
            accent: root.popupAccent
            fontFamily: root.popupFont
            fontSize: Style.font.caption
            bordered: true
            selected: root.running && !root.paused
            onClicked: {
              root.startOrTogglePause()
              keyCatcher.forceActiveFocus()
            }
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Arrows · WASD · HJKL   Space pause   R restart"
          color: root.popupText
          opacity: 0.62
          font.family: root.popupFont
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
