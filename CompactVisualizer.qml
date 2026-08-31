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
  property var terrainHistory: []

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

  function spectrumColor(level) {
    return level > 0.72 ? highColor : level > 0.42 ? midColor : lowColor
  }

  function drawEllipse(ctx, x, y, radiusX, radiusY) {
    ctx.save()
    ctx.translate(x, y)
    ctx.scale(Math.max(0.01, radiusX), Math.max(0.01, radiusY))
    ctx.beginPath()
    ctx.arc(0, 0, 1, 0, Math.PI * 2)
    ctx.restore()
  }

  function paintBars(ctx, variant) {
    var count = variant === "columns" ? Math.max(18, Math.floor(width / 3))
              : variant === "classicled" ? Math.max(10, Math.floor(width / 5))
              : Math.max(10, Math.min(24, bands.length || 10))
    var gap = variant === "columns" ? 1 : variant === "classicled" ? 2 : 1.5
    var barWidth = Math.max(1, (width - gap * (count - 1)) / count)
    ctx.lineWidth = 1

    for (var i = 0; i < count; i++) {
      var value = bandAt((i + 0.5) / count)
      var barHeight = Math.max(value > 0 ? 1 : 0, value * height)
      var x = i * (barWidth + gap)
      var y = height - barHeight

      if (variant === "barsoutline") {
        var outlineY = Math.max(0.5, y + 0.5)
        ctx.strokeStyle = spectrumColor(1 - outlineY / height)
        ctx.beginPath()
        ctx.moveTo(x, outlineY)
        ctx.lineTo(x + barWidth, outlineY)
        ctx.stroke()
      } else if (variant === "barsdot") {
        for (var dotY = height - 2; dotY >= y; dotY -= 3) {
          ctx.fillStyle = spectrumColor(1 - dotY / height)
          ctx.fillRect(x, dotY, Math.max(1, barWidth - 1), 1)
        }
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
    if (heartbeat) {
      ctx.fillStyle = lowColor
      ctx.globalAlpha = 0.35
      for (var dash = 0; dash < width; dash += 10)
        ctx.fillRect(dash, height * 0.55, 6, 1)
      ctx.globalAlpha = 1
    }
    ctx.lineWidth = heartbeat ? 1.6 : 1.4
    if (heartbeat) {
      ctx.strokeStyle = highColor
      ctx.beginPath()
    }
    var points = Math.max(24, Math.floor(width / 2))
    var previousX = 0
    var previousY = height * 0.5
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
      if (heartbeat) {
        if (i === 0)
          ctx.moveTo(x, y)
        else
          ctx.lineTo(x, y)
      } else if (i > 0) {
        ctx.strokeStyle = spectrumColor(1 - (previousY + y) / (2 * height))
        ctx.beginPath()
        ctx.moveTo(previousX, previousY)
        ctx.lineTo(x, y)
        ctx.stroke()
      }
      previousX = x
      previousY = y
    }
    if (heartbeat)
      ctx.stroke()
  }

  function paintScatter(ctx) {
    var step = 2
    for (var y = 0; y < height; y += step) {
      var gravity = 0.5 + 0.5 * y / Math.max(1, height - 1)
      for (var x = 0; x < width; x += step) {
        var local = bandAt(x / Math.max(1, width - 1))
        if (seeded(x + y * 113, frame >> 2) > local * local * gravity)
          continue
        ctx.fillStyle = spectrumColor(1 - y / height)
        ctx.globalAlpha = 0.35 + local * 0.65
        ctx.fillRect(x, y, 1.2, 1.2)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintRain(ctx) {
    var columns = Math.max(18, Math.floor(width / 4))
    var columnWidth = width / columns
    for (var i = 0; i < columns; i++) {
      var local = bandAt((i + 0.5) / columns)
      if (seeded(i, frame >> 4) > local + 0.18)
        continue
      var speed = 0.45 + seeded(i, 8) * 0.9
      var head = (seeded(i, 9) * height + frame * speed) % (height + 8) - 4
      var trail = 2 + local * 8
      var tailLength = Math.max(1, trail * 0.45)
      var bodyLength = Math.max(1, trail * 0.3)
      var headLength = Math.max(1, trail - tailLength - bodyLength)
      var dropX = i * columnWidth
      var dropWidth = Math.max(1, columnWidth - 1)
      ctx.globalAlpha = 0.58
      ctx.fillStyle = lowColor
      ctx.fillRect(dropX, head - trail, dropWidth, tailLength)
      ctx.globalAlpha = 0.82
      ctx.fillStyle = midColor
      ctx.fillRect(dropX, head - trail + tailLength, dropWidth, bodyLength)
      ctx.globalAlpha = 1
      ctx.fillStyle = highColor
      ctx.fillRect(dropX, head - headLength, dropWidth, headLength)
    }
    ctx.globalAlpha = 1
  }

  function paintMatrix(ctx) {
    var chars = "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ0123456789"
    var fontSize = Math.max(6, Math.floor(height / 5))
    var columns = Math.max(20, Math.floor(width / (fontSize * 0.78)))
    var rows = Math.max(4, Math.floor(height / fontSize))
    var cellWidth = width / columns
    ctx.font = fontSize + "px monospace"
    ctx.textAlign = "center"
    ctx.textBaseline = "top"
    for (var col = 0; col < columns; col++) {
      var local = bandAt((col + 0.5) / columns)
      if (seeded(col, frame >> 5) > local * 1.35 + 0.08)
        continue
      var speed = 2 + Math.floor(seeded(col, 12) * 3)
      var head = (Math.floor(frame / speed) + Math.floor(seeded(col, 13) * rows)) % (rows + 5)
      var trail = 2 + Math.floor(seeded(col, 14) * 3)
      for (var row = 0; row < rows; row++) {
        var distance = head - row
        if (distance < 0 || distance > trail)
          continue
        ctx.fillStyle = distance === 0 ? highColor : distance < 3 ? midColor : lowColor
        ctx.globalAlpha = 1 - distance / (trail + 1) * 0.55
        var charIndex = Math.floor(seeded(col + row * 97, frame >> 2) * chars.length)
        ctx.fillText(chars.charAt(charIndex), (col + 0.5) * cellWidth, row * fontSize)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintBinary(ctx) {
    var fontSize = Math.max(6, Math.floor(height / 5))
    var rows = Math.max(4, Math.floor(height / fontSize))
    var columns = Math.max(24, Math.floor(width / (fontSize * 0.72)))
    var cellWidth = width / columns
    ctx.font = fontSize + "px monospace"
    ctx.textAlign = "center"
    ctx.textBaseline = "top"
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        var local = bandAt((col + 0.5) / columns)
        var scroll = Math.floor(frame / Math.max(1, 4 - Math.floor(local * 3)))
        var one = seeded(col + (row + scroll) * 131, 17) < local * 0.6 + 0.15
        ctx.fillStyle = one && local > 0.4 ? highColor : one || local > 0.3 ? midColor : lowColor
        ctx.globalAlpha = one ? 1 : 0.48
        ctx.fillText(one ? "1" : "0", (col + 0.5) * cellWidth, row * fontSize)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintSakura(ctx) {
    var energy = average(0, 1)
    var count = 12 + Math.floor(energy * 16)
    for (var i = 0; i < count; i++) {
      var speed = seeded(i, 21) > 0.66 ? 0.32 : 0.18
      var wrap = height + 10
      var y = (seeded(i, 22) * wrap + frame * speed) % wrap - 5
      var sway = Math.sin(frame * 0.025 + seeded(i, 23) * Math.PI * 2) * 4
      var x = (seeded(i, 24) * width + sway + width) % width
      var size = 1.2 + seeded(i, 25) * 2.2
      ctx.fillStyle = spectrumColor(1 - y / height)
      ctx.globalAlpha = 0.45 + seeded(i, 26) * 0.55
      ctx.save()
      ctx.translate(x, y)
      ctx.rotate(frame * 0.015 + seeded(i, 27) * Math.PI)
      ctx.beginPath()
      ctx.moveTo(0, -size)
      ctx.quadraticCurveTo(size, -size * 0.1, 0, size)
      ctx.quadraticCurveTo(-size * 0.7, 0, 0, -size)
      ctx.fill()
      ctx.restore()
    }
    ctx.globalAlpha = 1
  }

  function paintTerrain(ctx) {
    var samples = Math.max(36, Math.floor(width / 2))
    ctx.beginPath()
    ctx.moveTo(0, height)
    for (var i = 0; i < samples; i++) {
      var historyIndex = terrainHistory.length - samples + i
      var level = historyIndex >= 0 ? terrainHistory[historyIndex] : 0
      ctx.lineTo(i * width / (samples - 1), height - level * height * 0.88)
    }
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
    for (var y = 0; y < height; y += 1.5) {
      var local = bandAt(y / Math.max(1, height - 1))
      var wobble = Math.sin(frame * 0.08 + y * 0.55) * 0.14
      var wing = Math.max(1, center * Math.max(0, local + wobble) * 0.88)
      ctx.fillStyle = spectrumColor(y / height)
      for (var x = 0; x < wing; x += 1.7) {
        var norm = x / wing
        var density = (1 - norm * norm) * local
        if (norm > 0.6)
          density *= 0.5 + 0.5 * Math.sin(frame * 0.1 + y * 0.5 + x * 0.3)
        if (seeded(Math.floor(x) + Math.floor(y) * 223, frame >> 2) >= density)
          continue
        ctx.fillRect(center + x, y, 1.3, 1.3)
        ctx.fillRect(center - x - 1.3, y, 1.3, 1.3)
      }
      if (local > 0.05)
        ctx.fillRect(center - 0.7, y, 1.4, 1.4)
    }
  }

  function paintScope(ctx) {
    var energy = average(0, 1)
    ctx.lineWidth = 1.2
    var previousX = width / 2
    var previousY = height / 2
    for (var i = 0; i <= 72; i++) {
      var angle = i / 72 * Math.PI * 2
      var x = width / 2 + Math.sin(angle * 2) * width * (0.18 + energy * 0.24)
      var y = height / 2 + Math.sin(angle * 3 + frame * 0.035) * height * (0.18 + energy * 0.3)
      if (i > 0) {
        ctx.strokeStyle = spectrumColor(1 - (previousY + y) / (2 * height))
        ctx.beginPath()
        ctx.moveTo(previousX, previousY)
        ctx.lineTo(x, y)
        ctx.stroke()
      }
      previousX = x
      previousY = y
    }
  }

  function paintRetro(ctx) {
    var horizon = height * 0.43
    var sunRadius = horizon * 0.8
    var sunCenterX = width / 2
    for (var sy = Math.max(0, horizon - sunRadius); sy < horizon; sy += 2) {
      var distance = horizon - sy
      if (distance < sunRadius * 0.5 && Math.floor(distance / 2) % 2)
        continue
      var halfWidth = Math.sqrt(Math.max(0, sunRadius * sunRadius - distance * distance)) * 2.2
      ctx.fillStyle = distance > sunRadius * 0.58 ? highColor : midColor
      ctx.fillRect(sunCenterX - halfWidth, sy, halfWidth * 2, 1.4)
    }

    ctx.strokeStyle = lowColor
    ctx.lineWidth = 0.8
    ctx.beginPath()
    ctx.moveTo(0, horizon)
    ctx.lineTo(width, horizon)
    ctx.stroke()
    for (var i = 0; i < 9; i++) {
      ctx.beginPath()
      ctx.moveTo(width / 2, horizon)
      ctx.lineTo(i * width / 8, height)
      ctx.stroke()
    }
    var scroll = (frame % 20) / 20
    for (var row = 0; row < 6; row++) {
      var depth = (row + scroll) / 6
      var y = horizon + 1 + (height - horizon - 1) * depth * depth
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(width, y)
      ctx.stroke()
    }

    ctx.strokeStyle = highColor
    ctx.lineWidth = 1.2
    ctx.beginPath()
    var points = Math.max(44, Math.floor(width / 2))
    for (var p = 0; p < points; p++) {
      var px = p * width / (points - 1)
      var level = Math.max(0.03, bandAt(p / (points - 1)))
      var py = horizon - level * horizon * 0.75
      if (p === 0)
        ctx.moveTo(px, py)
      else
        ctx.lineTo(px, py)
    }
    ctx.stroke()
  }

  function paintPulse(ctx) {
    var energy = average(0, 1)
    var steps = 96
    ctx.beginPath()
    for (var i = 0; i <= steps; i++) {
      var angle = i / steps * Math.PI * 2
      var local = bandAt((angle / (Math.PI * 2) + frame * 0.002) % 1)
      var blended = local * 0.62 + energy * 0.38
      var punch = blended * blended
      var radius = 0.24 + punch * 0.76 + Math.sin(frame * 0.05) * 0.02
      var x = width / 2 + Math.cos(angle) * width * 0.44 * radius
      var y = height / 2 + Math.sin(angle) * height * 0.46 * radius
      if (i === 0)
        ctx.moveTo(x, y)
      else
        ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.fillStyle = spectrumGradient(ctx)
    ctx.globalAlpha = 0.78
    ctx.fill()
    ctx.globalAlpha = 1
    ctx.strokeStyle = highColor
    ctx.lineWidth = 1
    ctx.stroke()

    var shock = (frame % 35) / 35
    if (energy > 0.2) {
      ctx.strokeStyle = midColor
      ctx.globalAlpha = energy * (1 - shock)
      drawEllipse(ctx, width / 2, height / 2, width * (0.12 + shock * 0.35), height * (0.12 + shock * 0.33))
      ctx.stroke()
      ctx.globalAlpha = 1
    }
  }

  function paintBubbles(ctx) {
    var energy = average(0, 1)
    var count = Math.max(12, Math.floor(width / 12))
    for (var i = 0; i < count; i++) {
      var radius = 1.5 + seeded(i, 31) * 3.2
      var wrap = height + radius * 2 + 8
      var speed = 0.16 + (4.8 - radius) * 0.035
      var y = height + radius - ((seeded(i, 32) * wrap + frame * speed) % wrap)
      var sway = Math.sin(frame * 0.035 + seeded(i, 33) * Math.PI * 2) * (1.5 + energy * 2.5)
      var x = (seeded(i, 34) * width + sway + width) % width
      ctx.strokeStyle = spectrumColor(1 - y / height)
      ctx.globalAlpha = 0.45 + seeded(i, 35) * 0.45
      drawEllipse(ctx, x, y, radius, radius * 0.78)
      ctx.stroke()
      ctx.fillStyle = foregroundColor
      ctx.fillRect(x - radius * 0.42, y - radius * 0.42, 1, 1)
    }
    ctx.globalAlpha = 1
  }

  function paintFirework(ctx) {
    var bursts = 5 + Math.floor(average(0, 1) * 4)
    for (var burst = 0; burst < bursts; burst++) {
      var cycle = 52
      var localFrame = (frame + burst * 11) % cycle
      var centerX = width * (0.08 + 0.84 * seeded(burst, Math.floor(frame / cycle) + 41))
      var centerY = height * (0.18 + 0.32 * seeded(burst, 42))
      var local = bandAt(seeded(burst, 43))
      if (localFrame < 9) {
        var progress = localFrame / 9
        var trailY = height - (height - centerY) * progress
        ctx.strokeStyle = midColor
        ctx.globalAlpha = 0.5 + progress * 0.5
        ctx.beginPath()
        ctx.moveTo(centerX, height)
        ctx.lineTo(centerX, trailY)
        ctx.stroke()
      } else {
        var burstTime = (localFrame - 9) / (cycle - 9)
        var radius = (3 + local * height * 0.32) * Math.min(1, burstTime * 3)
        var gravity = burstTime * burstTime * height * 0.18
        var particles = 12 + Math.floor(local * 12)
        ctx.globalAlpha = Math.max(0.12, 1 - burstTime * 1.2)
        for (var p = 0; p < particles; p++) {
          var angle = p / particles * Math.PI * 2
          var speed = 0.62 + seeded(p + burst * 71, 44) * 0.4
          var x = centerX + Math.cos(angle) * radius * speed
          var y = centerY + Math.sin(angle) * radius * speed + gravity
          ctx.fillStyle = p % 3 === 0 ? highColor : p % 2 === 0 ? midColor : lowColor
          ctx.fillRect(x, y, 1.3, 1.3)
        }
      }
    }
    ctx.globalAlpha = 1
  }

  function paintFlame(ctx) {
    var cell = 2
    for (var y = 0; y < height; y += cell) {
      var rise = y / height
      for (var x = 0; x < width; x += cell) {
        var sourceX = (x + Math.sin(frame * 0.09 + y * 0.55) * 5) / width
        var heat = 0.28 + bandAt(sourceX) * 0.78 - rise * 0.7
        heat += (seeded(x + y * 211, frame >> 2) - 0.5) * 0.22
        if (heat < 0.08)
          continue
        ctx.fillStyle = heat > 0.58 ? midColor : highColor
        ctx.globalAlpha = Math.min(1, 0.32 + heat)
        ctx.fillRect(x, height - y - cell, cell, cell)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintGeyser(ctx) {
    var bass = average(0, 0.34)
    var particles = 42 + Math.floor(bass * 40)
    for (var i = 0; i < particles; i++) {
      var life = (frame * (0.45 + seeded(i, 51) * 0.25) + seeded(i, 52) * 70) % 70
      var t = life / 70
      var velocity = 1.1 + bass * 1.4 + seeded(i, 53) * 0.8
      var spread = (seeded(i, 54) - 0.5) * width * 0.24
      var x = width / 2 + spread * t + Math.sin(t * 8 + i) * 1.5
      var y = height - velocity * height * t + height * 1.15 * t * t
      if (y < 0 || y > height)
        continue
      ctx.fillStyle = i % 3 === 0 ? highColor : i % 2 === 0 ? midColor : lowColor
      ctx.globalAlpha = Math.max(0.15, 1 - t)
      ctx.fillRect(x, y, 1.4, 1.4)
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

  function paintFirefly(ctx) {
    var bass = average(0, 0.34)
    var high = average(0.67, 1)
    var grassTop = height * 0.76
    ctx.fillStyle = lowColor
    ctx.globalAlpha = 0.72
    ctx.beginPath()
    ctx.moveTo(0, height)
    for (var x = 0; x <= width; x += 2) {
      var blade = 2 + 2.5 * Math.sin(x * 0.41) + 1.5 * Math.sin(x * 0.17 + 2.3)
      ctx.lineTo(x, grassTop - Math.max(0, blade))
    }
    ctx.lineTo(width, height)
    ctx.closePath()
    ctx.fill()

    var flies = Math.max(20, Math.floor(width / 7))
    for (var i = 0; i < flies; i++) {
      var phaseX = seeded(i, 61) * Math.PI * 2
      var phaseY = seeded(i, 62) * Math.PI * 2
      var fx = 0.012 + seeded(i, 63) * 0.005
      var fy = 0.018 + seeded(i, 64) * 0.006
      var px = width / 2 + Math.cos(frame * fx + phaseX) * width * 0.44
               + bass * 3 * Math.sin(frame * 0.02 + phaseX)
      var py = grassTop * 0.5 + Math.sin(frame * fy + phaseY) * grassTop * 0.38
      var lit = Math.sin(frame * 0.18 + i * 1.31) * 0.5 + 0.5 + high * 0.4 > 0.55
      ctx.fillStyle = lit ? highColor : midColor
      ctx.globalAlpha = lit ? 1 : 0.38
      ctx.fillRect(px, py, lit ? 1.8 : 1, lit ? 1.8 : 1)
      if (lit) {
        ctx.globalAlpha = 0.2
        ctx.fillRect(px - 1.5, py - 1.5, 4.8, 4.8)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintSand(ctx) {
    var energy = average(0, 1)
    var grains = Math.max(45, Math.floor(width / 2))
    var pileHeight = height * (0.12 + energy * 0.22)
    for (var i = 0; i < grains; i++) {
      var x = seeded(i, 71) * width
      var ground = height - pileHeight * (0.35 + 0.65 * Math.sin(x / width * Math.PI))
      var fall = (seeded(i, 72) * (height + 12) + frame * (0.28 + seeded(i, 73) * 0.35)) % (height + 12) - 6
      var settled = seeded(i, 74) < 0.48 + energy * 0.3
      var y = settled ? ground + seeded(i, 75) * Math.max(1, height - ground) : fall
      if (y > height)
        continue
      var band = x / width
      ctx.fillStyle = band < 0.34 ? highColor : band < 0.67 ? midColor : lowColor
      ctx.globalAlpha = settled ? 0.82 : 0.5 + bandAt(band) * 0.5
      ctx.fillRect(x, y, 1.5, 1.5)
    }
    ctx.globalAlpha = 1
  }

  function paintAscii(ctx) {
    var columns = Math.max(22, Math.floor(width / 5))
    var rows = Math.max(4, Math.floor(height / 6))
    var cellWidth = width / columns
    var cellHeight = height / rows
    for (var i = 0; i < columns; i++) {
      var value = bandAt((i + 0.5) / columns)
      for (var row = 0; row < rows; row++) {
        var bottom = (rows - 1 - row) / rows
        if (value <= bottom)
          continue
        var fraction = Math.min(1, (value - bottom) * rows)
        ctx.fillStyle = spectrumColor(bottom)
        ctx.globalAlpha = 0.25 + fraction * 0.75
        ctx.fillRect(i * cellWidth, row * cellHeight, Math.max(1, cellWidth - 1.2), Math.max(1, cellHeight - 1))
      }
    }
    ctx.globalAlpha = 1
  }

  function paintStereo(ctx) {
    var levels = [average(0, 0.5), average(0.5, 1)]
    var segments = Math.max(20, Math.floor((width - 10) / 4))
    var segmentWidth = (width - 10) / segments
    ctx.font = Math.max(6, height * 0.25) + "px monospace"
    ctx.textBaseline = "middle"
    for (var channel = 0; channel < 2; channel++) {
      var y = (channel + 0.5) * height / 2
      ctx.fillStyle = foregroundColor
      ctx.fillText(channel === 0 ? "L" : "R", 0, y)
      var lit = Math.round(levels[channel] * segments)
      var peak = Math.min(segments - 1, Math.max(lit, Math.round((peaks[channel] || levels[channel]) * segments)))
      for (var i = 0; i < segments; i++) {
        var ratio = i / Math.max(1, segments - 1)
        ctx.fillStyle = spectrumColor(ratio)
        ctx.globalAlpha = i < lit ? 1 : i === peak ? 0.95 : 0.16
        ctx.fillRect(9 + i * segmentWidth, y - 2.5, Math.max(1, segmentWidth - 1), 5)
      }
    }
    ctx.globalAlpha = 1
  }

  function paintLogo(ctx) {
    var glyphs = [
      ["01110", "10000", "10000", "10000", "10000", "10000", "01110"],
      ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
      ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
      ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
      ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
      ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
    ]
    var totalUnits = 40
    var scaleX = Math.max(1, Math.floor(width * 0.9 / totalUnits))
    var scaleY = Math.max(1, Math.floor(height * 0.78 / 7))
    var renderedWidth = totalUnits * scaleX
    var renderedHeight = 7 * scaleY
    var offsetX = (width - renderedWidth) / 2
    var offsetY = (height - renderedHeight) / 2
    var letterBands = [0.02, 0.2, 0.4, 0.58, 0.78, 0.98]
    for (var letter = 0; letter < glyphs.length; letter++) {
      var energy = bandAt(letterBands[letter])
      var bounce = Math.sin(frame * 0.06 + letter * 0.9) * 1.2 - energy * 1.2
      var letterX = offsetX + letter * 7 * scaleX
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          if (glyphs[letter][row].charAt(col) !== "1")
            continue
          var fill = energy * energy * 0.38 + 0.62
          var lit = seeded(letter * 97 + row * 11 + col, frame >> 2) <= fill
          ctx.fillStyle = spectrumColor(1 - row / 7)
          ctx.globalAlpha = lit ? 0.5 + energy * 0.5 : 0.3
          ctx.fillRect(letterX + col * scaleX, offsetY + row * scaleY + bounce,
                       Math.max(1, scaleX - 0.6), Math.max(1, scaleY - 0.6))
        }
      }
    }
    ctx.globalAlpha = 1
  }

  function updateTerrain() {
    if (mode !== "terrain")
      return
    var next = terrainHistory.slice(0)
    next.push(Math.min(1, average(0, 1) + seeded(frame, 81) * 0.12))
    var limit = Math.max(36, Math.floor(width / 2))
    if (next.length > limit)
      next = next.slice(next.length - limit)
    terrainHistory = next
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
      paintPulse(ctx)
    else if (mode === "bubbles")
      paintBubbles(ctx)
    else if (mode === "firework")
      paintFirework(ctx)
    else if (mode === "flame")
      paintFlame(ctx)
    else if (mode === "geyser")
      paintGeyser(ctx)
    else if (mode === "mosaic")
      paintMosaic(ctx)
    else if (mode === "ascii")
      paintAscii(ctx)
    else if (mode === "stereo")
      paintStereo(ctx)
    else if (mode === "logo")
      paintLogo(ctx)
    else if (mode === "scatter")
      paintScatter(ctx)
    else if (mode === "rain")
      paintRain(ctx)
    else if (mode === "matrix")
      paintMatrix(ctx)
    else if (mode === "binary")
      paintBinary(ctx)
    else if (mode === "sakura")
      paintSakura(ctx)
    else if (mode === "firefly")
      paintFirefly(ctx)
    else if (mode === "sand")
      paintSand(ctx)
    else
      paintScatter(ctx)
  }

  onBandsChanged: {
    updatePeaks()
    requestPaint()
  }
  onModeChanged: {
    peaks = []
    terrainHistory = []
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
      root.updateTerrain()
      root.requestPaint()
    }
  }
}
