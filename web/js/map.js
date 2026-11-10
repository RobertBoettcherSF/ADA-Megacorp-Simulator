"use strict";

// Drawing only. Tile ids, terrain, height, and flags come from the
// Ada export. The atlas geometry comes from assets/tiles.json.
const COLOUR = {
  ".": [112, 146, 104],
  "+": [72, 72, 78],
  "=": [186, 178, 164],
  "B": [154, 82, 60],
  "~": [46, 116, 166]
};

const CELL = 5;

let mapData = null;
let tileset = null;
let atlasPixels = null;
let atlasWidth = 0;
let view = "iso";
let tilePx = 6;
let isoScale = 1;

function shade(code, level) {
  const base = COLOUR[code] || [255, 0, 200];
  const scale = 0.48 + (level / 15) * 0.72;
  return base.map((channel) => {
    const value = Math.round(channel * scale);
    return Math.max(0, Math.min(255, value));
  });
}

function cellAt(data, x, y) {
  const row = data.rows[y - 1];
  const at = (x - 1) * CELL;
  const code = row.charAt(at);
  const level = parseInt(row.charAt(at + 1), 16);
  const flags = parseInt(row.charAt(at + 2), 16);
  const tileId = parseInt(row.slice(at + 3, at + 5), 16);
  const legend = data.legend || {};
  return {
    code,
    name: legend[code] || code,
    level,
    tileId,
    walk: (flags & 1) !== 0,
    drive: (flags & 2) !== 0
  };
}

function paintLegend(data) {
  const host = document.getElementById("legend");
  host.replaceChildren();
  [".", "+", "=", "B", "~"].forEach((code) => {
    if (!data.legend || !data.legend[code]) {
      return;
    }
    const item = document.createElement("span");
    item.className = "swatch";
    const chip = document.createElement("span");
    chip.className = "chip";
    const rgb = shade(code, 4);
    chip.style.background = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
    item.append(chip, document.createTextNode(data.legend[code]));
    host.append(item);
  });
}

function drawFlat(ctx) {
  const canvas = ctx.canvas;
  canvas.width = mapData.width * tilePx;
  canvas.height = mapData.height * tilePx;
  for (let y = 1; y <= mapData.height; y += 1) {
    const row = mapData.rows[y - 1];
    for (let x = 1; x <= mapData.width; x += 1) {
      const at = (x - 1) * CELL;
      const level = parseInt(row.charAt(at + 1), 16);
      const rgb = shade(row.charAt(at), level);
      ctx.fillStyle = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
      ctx.fillRect((x - 1) * tilePx, (y - 1) * tilePx, tilePx, tilePx);
    }
  }
  document.getElementById("zoom-label").textContent = `${tilePx} px`;
}

function anchor(x, y, scale) {
  const halfW = (tileset.tile_width * scale) / 2;
  const halfH = (tileset.diamond_height * scale) / 2;
  const cellH = tileset.cell_height * scale;
  const originX = mapData.height * halfW;
  const originY = cellH;
  const x0 = x - 1;
  const y0 = y - 1;
  return {
    sx: originX + (x0 - y0) * halfW,
    sy: originY + (x0 + y0) * halfH,
    halfW,
    cellH
  };
}

function canvasSize(scale) {
  const halfW = (tileset.tile_width * scale) / 2;
  const halfH = (tileset.diamond_height * scale) / 2;
  const cellH = tileset.cell_height * scale;
  return {
    width: (mapData.width + mapData.height) * halfW,
    height: cellH + (mapData.width + mapData.height - 2) * halfH
  };
}

function drawIso(ctx) {
  const scale = isoScale;
  const size = canvasSize(scale);
  const canvas = ctx.canvas;
  canvas.width = size.width;
  canvas.height = size.height;
  const tw = tileset.tile_width;
  const ch = tileset.cell_height;
  for (let y = 1; y <= mapData.height; y += 1) {
    for (let x = 1; x <= mapData.width; x += 1) {
      const cell = cellAt(mapData, x, y);
      const tile = tileset.byId[cell.tileId];
      const spot = anchor(x, y, scale);
      ctx.drawImage(
        tileset.image,
        tile.column * tw,
        tile.row * ch,
        tw,
        ch,
        spot.sx - spot.halfW,
        spot.sy - spot.cellH,
        tw * scale,
        ch * scale
      );
    }
  }
  document.getElementById("zoom-label").textContent = `${scale}×`;
}

function draw() {
  if (!mapData) {
    return;
  }
  const canvas = document.getElementById("map");
  const ctx = canvas.getContext("2d");
  if (view === "iso" && tileset) {
    drawIso(ctx);
  } else {
    drawFlat(ctx);
  }
}

function opaque(atlasX, atlasY) {
  if (atlasX < 0 || atlasY < 0 || atlasX >= atlasWidth) {
    return false;
  }
  const index = (atlasY * atlasWidth + atlasX) * 4 + 3;
  return atlasPixels[index] > 16;
}

function pickIso(px, py) {
  const scale = isoScale;
  const tw = tileset.tile_width;
  const ch = tileset.cell_height;
  for (let y = mapData.height; y >= 1; y -= 1) {
    for (let x = mapData.width; x >= 1; x -= 1) {
      const spot = anchor(x, y, scale);
      const left = spot.sx - spot.halfW;
      const top = spot.sy - spot.cellH;
      if (px < left || py < top || px >= left + tw * scale
          || py >= top + ch * scale) {
        continue;
      }
      const cell = cellAt(mapData, x, y);
      const tile = tileset.byId[cell.tileId];
      const localX = Math.floor((px - left) / scale);
      const localY = Math.floor((py - top) / scale);
      if (opaque(tile.column * tw + localX, tile.row * ch + localY)) {
        return { x, y };
      }
    }
  }
  return null;
}

function pickFlat(px, py) {
  return {
    x: Math.floor(px / tilePx) + 1,
    y: Math.floor(py / tilePx) + 1
  };
}

function showCell(x, y) {
  const info = document.getElementById("hover");
  if (x < 1 || y < 1 || x > mapData.width || y > mapData.height) {
    info.textContent = "Hover a tile.";
    return;
  }
  const cell = cellAt(mapData, x, y);
  const walk = cell.walk ? "yes" : "no";
  const drive = cell.drive ? "yes" : "no";
  info.textContent =
    `x ${x}  y ${y}  ${cell.name}  height ${cell.level}` +
    `  tile ${cell.tileId}  walk ${walk}  drive ${drive}`;
}

async function loadTileset() {
  const response = await fetch("assets/tiles.json");
  if (!response.ok) {
    throw new Error(response.statusText);
  }
  const index = await response.json();
  const byId = [];
  index.tiles.forEach((tile) => {
    byId[tile.id] = tile;
  });
  const image = new Image();
  await new Promise((resolve, reject) => {
    image.onload = resolve;
    image.onerror = reject;
    image.src = index.atlas;
  });
  const scratch = document.createElement("canvas");
  scratch.width = image.width;
  scratch.height = image.height;
  const ctx = scratch.getContext("2d");
  ctx.drawImage(image, 0, 0);
  atlasPixels = ctx.getImageData(0, 0, image.width, image.height).data;
  atlasWidth = image.width;
  tileset = {
    tile_width: index.tile_width,
    diamond_height: index.diamond_height,
    cell_height: index.cell_height,
    byId,
    image
  };
}

async function loadFile(file) {
  const response = await fetch(`data/${file}`);
  if (!response.ok) {
    throw new Error(response.statusText);
  }
  mapData = await response.json();
  document.getElementById("version").textContent = mapData.version;
  document.getElementById("seed-label").textContent = String(mapData.seed);
  paintLegend(mapData);
  draw();
}

function canvasPoint(event) {
  const canvas = document.getElementById("map");
  const rect = canvas.getBoundingClientRect();
  return {
    x: (event.clientX - rect.left) * (canvas.width / rect.width),
    y: (event.clientY - rect.top) * (canvas.height / rect.height)
  };
}

async function main() {
  await loadTileset();
  const indexResponse = await fetch("data/index.json");
  if (!indexResponse.ok) {
    throw new Error(indexResponse.statusText);
  }
  const index = await indexResponse.json();
  document.getElementById("version").textContent = index.version;
  const select = document.getElementById("seed");
  let chosen = 0;
  index.maps.forEach((entry, i) => {
    const option = document.createElement("option");
    option.value = entry.file;
    option.textContent = String(entry.seed);
    if (entry.seed === 42) {
      chosen = i;
    }
    select.append(option);
  });
  select.selectedIndex = chosen;
  select.addEventListener("change", () => {
    const entry = index.maps[select.selectedIndex];
    loadFile(entry.file).catch(showError);
  });
  document.getElementById("view").addEventListener("click", () => {
    view = view === "iso" ? "flat" : "iso";
    document.getElementById("view").textContent =
      view === "iso" ? "Flat view" : "Isometric view";
    draw();
  });
  document.getElementById("zoom-in").addEventListener("click", () => {
    if (view === "iso") {
      isoScale = Math.min(3, isoScale + 1);
    } else {
      tilePx = Math.min(16, tilePx + 2);
    }
    draw();
  });
  document.getElementById("zoom-out").addEventListener("click", () => {
    if (view === "iso") {
      isoScale = Math.max(1, isoScale - 1);
    } else {
      tilePx = Math.max(2, tilePx - 2);
    }
    draw();
  });
  const canvas = document.getElementById("map");
  canvas.addEventListener("mousemove", (event) => {
    if (!mapData) {
      return;
    }
    const point = canvasPoint(event);
    if (view === "iso") {
      const tile = pickIso(point.x, point.y);
      if (!tile) {
        document.getElementById("hover").textContent = "Hover a tile.";
        return;
      }
      showCell(tile.x, tile.y);
      return;
    }
    const tile = pickFlat(point.x, point.y);
    showCell(tile.x, tile.y);
  });
  canvas.addEventListener("mouseleave", () => {
    document.getElementById("hover").textContent = "Hover a tile.";
  });
  await loadFile(index.maps[select.selectedIndex].file);
}

function showError(err) {
  document.getElementById("hover").textContent =
    `Could not load map data (${err}).`;
}

main().catch(showError);
