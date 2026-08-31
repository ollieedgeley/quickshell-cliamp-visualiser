import QtQuick

Canvas {
  id: root

  property var bands: []
  property string mode: "bars"
  property color foregroundColor: "#c5c9c5"
  property color accentColor: "#658594"
  property color lowColor: "#8a9a7b"
  property color midColor: "#c4b28a"
  property color highColor: "#c4746e"
  property int frame: 0
  property var peaks: []

  antialiasing: true
  renderTarget: Canvas.FramebufferObject

  function clamp(value) {
    value = Number(value)
    return !isFinite(value) ? 0 : Math.max(0, Math.min(1, value))
  }

  function bandAt(position) {
    var source = bands || []
    if (!source.length)
      return 0
    if (source.length === 1)
      return clamp(source[0])
    var x = Math.max(0, Math.min(1, position)) * (source.length - 1)
    var index = Math.floor(x)
    if (index >= source.length - 1)
      return clamp(source[source.length - 1])
    var fraction = x - index
    return clamp(source[index] * (1 - fraction) + source[index + 1] * fraction)
  }

  function average(from, to) {
    var total = 0
    for (var i = 0; i < 8; i++)
      total += bandAt(from + (to - from) * (i + 0.5) / 8)
    return total / 8
  }

  function spectrumGradient(ctx) {
    var gradient = ctx.createLinearGradient(0, height, 0, 0)
    gradient.addColorStop(0, lowColor)
    gradient.addColorStop(0.62, midColor)
    gradient.addColorStop(1, highColor)
    return gradient
  }

  function seeded(index, salt) {
    var value = Math.sin((index + 1) * 12.9898 + (salt + 1) * 78.233) * 43758.5453
    return value - Math.floor(value)
  }

  function paintBars(ctx, variant) {
    var count = variant === "columns" ? Math.max(18, Math.floor(width / 3))
              : variant === "classicled" ? Math.max(10, Math.floor(width / 5))
              : Math.max(10, Math.min(24, bands.length || 10))
    var gap = variant === "columns" ? 1 : variant === "classicled" ? 2 : 1.5
    var barWidth = Math.max(1, (width - gap * (count - 1)) / count)
    ctx.strokeStyle = accentColor
    ctx.lineWidth = 1

    for (var i = 0; i < count; i++) {
      var value = bandAt((i + 0.5) / count)
      var barHeight = Math.max(value > 0 ? 1 : 0, value * height)
      var x = i * (barWidth + gap)
      var y = height - barHeight

      if (variant === "barsoutline") {
        ctx.strokeRect(x + 0.5, y + 0.5, Math.max(1, barWidth - 1), Math.max(1, barHeight - 1))
      } else if (variant === "barsdot") {
        ctx.fillStyle = lowColor
        for (var dotY = height - 2; dotY >= y; dotY -= 3)
          ctx.fillRect(x, dotY, Math.max(1, barWidth - 1), 1)
      } else if (variant === "bricks" || variant === "classicled") {
        var segment = variant === "classicled" ? 2 : 3
        for (var row = height - segment; row >= y; row -= segment + 1) {
          var ratio = 1 - row / height
          ctx.fillStyle = ratio > 0.82 ? highColor : ratio > 0.55 ? midColor : lowColor
          ctx.fillRect(x, row, barWidth, segment)
        }
      } else {
        ctx.fillStyle = spectrumGradient(ctx)
        ctx.fillRect(x, y, barWidth, barHeight)
      }

      if (variant === "classicpeak" || variant === "classicled") {
        var peak = peaks[i] || value
        ctx.fillStyle = midColor
        ctx.fillRect(x, Math.max(0, height - peak * height - 1), barWidth, 1)
      }
    }
  }

  function paintWave(ctx, heartbeat) {
    ctx.strokeStyle = heartbeat ? highColor : accentColor
    ctx.lineWidth = heartbeat ? 1.6 : 1.4
    ctx.beginPath()
    var points = Math.max(24, Math.floor(width / 2))
    for (var i = 0; i < points; i++) {
      var x = i * width / (points - 1)
      var phase = i / (points - 1)
      var energy = bandAt(phase)
      var y
      if (heartbeat) {
        var cycle = (phase * 3 + frame * 0.012) % 1
        var spike = cycle > 0.42 && cycle < 0.48 ? -1
                  : cycle >= 0.48 && cycle < 0.54 ? 0.7 : 0
        y = height * 0.55 + spike * energy * height * 0.42
      } else {
        y = height * 0.5 + Math.sin(i * 1.35 + frame * 0.18)
            * energy * height * 0.42
      }
      if (i === 0)
        ctx.moveTo(x, y)
      else
        ctx.lineTo(x, y)
    }
    ctx.stroke()
  }

  function paintParticles(ctx, kind) {
    var count = Math.max(14, Math.floor(width / 4))
    var energy = average(0, 1)
    for (var i = 0; i < count; i++) {
      var x = seeded(i, 2) * width
      var speed = 0.25 + seeded(i, 3) * 1.3
      var phase = (seeded(i, 4) * height + frame * speed) % height
      var y = kind === "sand" ? height - phase * energy
            : kind === "firefly" ? height * 0.35 + Math.sin(frame * 0.08 + i) * height * 0.28
            : kind === "sakura" || kind === "matrix" || kind === "binary" || kind === "rain" ? phase
            : height - phase
      var local = bandAt(x / width)
      ctx.globalAlpha = 0.3 + local * 0.7
      ctx.fillStyle = kind === "sakura" ? highColor
                    : kind === "matrix" || kind === "rain" ? lowColor
                    : i % 3 === 0 ? highColor : i % 2 === 0 ? midColor : lowColor
      if (kind === "binary") {
        ctx.font = "7px monospace"
        ctx.fillText((i + frame) % 2 ? "1" : "0", x, y)
      } else if (kind === "sakura") {
        ctx.fillRect(x, y, 2.5, 1.5)
      } else if (kind === "matrix" || kind === "rain") {
        ctx.fillRect(x, y, Math.max(1, width / count - 1), kind === "matrix" ? 3 : 2)
      } else {
        var size = 1 + local * 2
        ctx.beginPath()
        ctx.arc(x, y, size, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    ctx.globalAlpha = 1
  }

  function paintTerrain(ctx) {
    ctx.beginPath()
    ctx.moveTo(0, height)
    var points = Math.max(18, Math.floor(width / 3))
    for (var i = 0; i < points; i++)
      ctx.lineTo(i * width / (points - 1), height - bandAt(i / (points - 1)) * height * 0.88)
    ctx.lineTo(width, height)
    ctx.closePath()
    ctx.fillStyle = spectrumGradient(ctx)
    ctx.fill()
    ctx.strokeStyle = highColor
    ctx.lineWidth = 1
    ctx.stroke()
  }

  function paintButterfly(ctx) {
    var center = width / 2
    ctx.fillStyle = spectrumGradient(ctx)
    var count = Math.max(8, Math.floor(width / 8))
    for (var i = 0; i < count; i++) {
      var wing = bandAt(i / Math.max(1, count - 1)) * center * 0.78
      var y = i * height / count
      var thickness = Math.max(1, height / count - 1)
      ctx.fillRect(center - wing, y, wing, thickness)
      ctx.fillRect(center, y, wing, thickness)
    }
  }

  function paintScope(ctx) {
    var energy = average(0, 1)
    ctx.strokeStyle = accentColor
    ctx.lineWidth = 1.2
    ctx.beginPath()
    for (var i = 0; i <= 72; i++) {
      var angle = i / 72 * Math.PI * 2
      var x = width / 2 + Math.sin(angle * 2) * width * (0.18 + energy * 0.24)
      var y = height / 2 + Math.sin(angle * 3 + frame * 0.035) * height * (0.18 + energy * 0.3)
      if (i === 0)
        ctx.moveTo(x, y)
      else
        ctx.lineTo(x, y)
    }
    ctx.stroke()
  }

  function paintRetro(ctx) {
    var horizon = height * 0.55
    ctx.strokeStyle = lowColor
    ctx.lineWidth = 0.8
    for (var i = 0; i < 7; i++) {
      ctx.beginPath()
      ctx.moveTo(width / 2, horizon)
      ctx.lineTo(i * width / 6, height)
      ctx.stroke()
    }
    for (var row = 0; row < 4; row++) {
      var y = horizon + (height - horizon) * Math.pow(row / 3, 1.7)
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(width, y)
      ctx.stroke()
    }
    paintWave(ctx, false)
  }

  function paintPulse(ctx, bubbles) {
    var energy = average(0, 1)
    var count = bubbles ? 6 : 3
    for (var i = 0; i < count; i++) {
      var local = bubbles ? bandAt(i / Math.max(1, count - 1)) : energy
      var x = bubbles ? (i + 0.5) * width / count : width / 2
      var y = bubbles ? height - ((frame * (0.3 + i * 0.04) + i * 5) % height) : height / 2
      var radius = bubbles ? 1 + local * 4 : 3 + local * height * (0.22 + i * 0.09)
      ctx.strokeStyle = i % 3 === 0 ? lowColor : i % 2 === 0 ? highColor : midColor
      ctx.globalAlpha = 1 - i / (count + 1)
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      ctx.stroke()
    }
    ctx.globalAlpha = 1
  }

  function paintFirework(ctx) {
    var energy = Math.max(average(0, 0.3), 0.12)
    var centerX = width * (0.35 + 0.25 * Math.sin(frame * 0.03))
    var centerY = height * 0.48
    for (var i = 0; i < 14; i++) {
      var angle = i / 14 * Math.PI * 2
      var length = energy * height * (0.5 + seeded(i, frame >> 3))
      ctx.strokeStyle = i % 3 === 0 ? highColor : i % 2 === 0 ? midColor : lowColor
      ctx.beginPath()
      ctx.moveTo(centerX, centerY)
      ctx.lineTo(centerX + Math.cos(angle) * length, centerY + Math.sin(angle) * length)
      ctx.stroke()
    }
  }

  function paintFlame(ctx, geyser) {
    var count = Math.max(12, Math.floor(width / 5))
    for (var i = 0; i < count; i++) {
      var position = (i + 0.5) / count
      var value = bandAt(position)
      var x = geyser ? width / 2 + (seeded(i, frame >> 2) - 0.5) * width * 0.35 : position * width
      ctx.strokeStyle = i % 3 === 0 ? highColor : i % 2 === 0 ? midColor : lowColor
      ctx.globalAlpha = 0.45 + value * 0.55
      ctx.beginPath()
      ctx.moveTo(x, height)
      ctx.lineTo(x + Math.sin(frame * 0.1 + i) * 3, height - value * height * (geyser ? 1 : 0.9))
      ctx.stroke()
    }
    ctx.globalAlpha = 1
  }

  function paintMosaic(ctx) {
    var size = 4
    for (var y = 0; y < height; y += size + 1) {
      for (var x = 0; x < width; x += size + 1) {
        var value = bandAt(x / width)
        if (seeded(x + y, frame >> 2) > value)
          continue
        ctx.fillStyle = y < height * 0.35 ? highColor : y < height * 0.68 ? midColor : lowColor
        ctx.globalAlpha = 0.35 + value * 0.65
        ctx.fillRect(x, y, size, size)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintAscii(ctx) {
    var glyphs = " .:-=+*#%@"
    var columns = Math.max(12, Math.floor(width / 6))
    ctx.font = Math.max(7, height * 0.48) + "px monospace"
    ctx.textAlign = "center"
    ctx.textBaseline = "bottom"
    for (var i = 0; i < columns; i++) {
      var value = bandAt((i + 0.5) / columns)
      var glyph = glyphs[Math.min(glyphs.length - 1, Math.floor(value * glyphs.length))]
      ctx.fillStyle = value > 0.78 ? highColor : value > 0.48 ? midColor : lowColor
      ctx.fillText(glyph, (i + 0.5) * width / columns, height)
    }
  }

  function paintStereo(ctx) {
    var levels = [average(0, 0.5), average(0.5, 1)]
    ctx.font = "7px monospace"
    ctx.textBaseline = "middle"
    for (var channel = 0; channel < 2; channel++) {
      var y = (channel + 0.5) * height / 2
      ctx.fillStyle = foregroundColor
      ctx.fillText(channel === 0 ? "L" : "R", 0, y)
      ctx.fillStyle = spectrumGradient(ctx)
      ctx.fillRect(8, y - 2, Math.max(0, width - 8) * levels[channel], 4)
    }
  }

  function paintLogo(ctx) {
    var energy = average(0, 1)
    ctx.fillStyle = energy > 0.72 ? highColor : energy > 0.4 ? midColor : lowColor
    ctx.font = "bold " + Math.max(8, height * 0.52) + "px monospace"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText("CLIAMP", width / 2, height / 2 + Math.sin(frame * 0.08) * energy * 2)
  }

  function updatePeaks() {
    var count = Math.max(10, Math.min(24, bands.length || 10))
    var next = []
    for (var i = 0; i < count; i++) {
      var value = bandAt((i + 0.5) / count)
      next.push(Math.max(value, (peaks[i] || 0) - 0.025))
    }
    peaks = next
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    if (!bands || bands.length === 0 || mode === "none")
      return

    if (mode === "bars" || mode === "barsdot" || mode === "barsoutline"
        || mode === "bricks" || mode === "columns" || mode === "classicpeak"
        || mode === "classicled")
      paintBars(ctx, mode)
    else if (mode === "wave")
      paintWave(ctx, false)
    else if (mode === "heartbeat")
      paintWave(ctx, true)
    else if (mode === "terrain")
      paintTerrain(ctx)
    else if (mode === "butterfly")
      paintButterfly(ctx)
    else if (mode === "scope")
      paintScope(ctx)
    else if (mode === "retro")
      paintRetro(ctx)
    else if (mode === "pulse")
      paintPulse(ctx, false)
    else if (mode === "bubbles")
      paintPulse(ctx, true)
    else if (mode === "firework")
      paintFirework(ctx)
    else if (mode === "flame" || mode === "geyser")
      paintFlame(ctx, mode === "geyser")
    else if (mode === "mosaic")
      paintMosaic(ctx)
    else if (mode === "ascii")
      paintAscii(ctx)
    else if (mode === "stereo")
      paintStereo(ctx)
    else if (mode === "logo")
      paintLogo(ctx)
    else
      paintParticles(ctx, mode)
  }

  onBandsChanged: {
    updatePeaks()
    requestPaint()
  }
  onModeChanged: {
    peaks = []
    requestPaint()
  }
  onForegroundColorChanged: requestPaint()
  onAccentColorChanged: requestPaint()
  onLowColorChanged: requestPaint()
  onMidColorChanged: requestPaint()
  onHighColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  Timer {
    interval: 50
    running: root.visible
    repeat: true
    onTriggered: {
      root.frame++
      root.updatePeaks()
      root.requestPaint()
    }
  }
}
