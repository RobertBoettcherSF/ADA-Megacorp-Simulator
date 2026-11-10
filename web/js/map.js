"use strict";

// Drawing only. Terrain, height, and flags come from the Ada export.
const COLOUR = {
  ".": [112, 146, 104],
  "+": [72, 72, 78],
  "=": [186, 178, 164],
  "B": [154, 82, 60],
  "~": [46, 116, 166]
};

let mapData = null;
let tilePx = 6;

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
  const at = (x - 1) * 3;
  const code = row.charAt(at);
  const level = parseInt(row.charAt(at + 1), 16);
  const flags = parseInt(row.charAt(at + 2), 16);
  const legend = data.legend || {};
  return {
    code,
    name: legend[code] || code,
    level,
    walk: (flags & 1) !== 0,
    drive: (flags & 2) !== 0
  };
}

function paintLegend(data) {
  const host = document.getElementById("legend");
  host.replaceChildren();
  const order = [".", "+", "=", "B", "~"];
  order.forEach((code) => {
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

function draw() {
  if (!mapData) {
    return;
  }
  const canvas = document.getElementById("map");
  const ctx = canvas.getContext("2d");
  canvas.width = mapData.width * tilePx;
  canvas.height = mapData.height * tilePx;
  for (let y = 1; y <= mapData.height; y += 1) {
    const row = mapData.rows[y - 1];
    for (let x = 1; x <= mapData.width; x += 1) {
      const at = (x - 1) * 3;
      const level = parseInt(row.charAt(at + 1), 16);
      const rgb = shade(row.charAt(at), level);
      ctx.fillStyle = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
      ctx.fillRect((x - 1) * tilePx, (y - 1) * tilePx, tilePx, tilePx);
    }
  }
  document.getElementById("zoom-label").textContent = `${tilePx} px`;
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

function tileFromEvent(event) {
  const canvas = document.getElementById("map");
  const rect = canvas.getBoundingClientRect();
  const px = (event.clientX - rect.left) * (canvas.width / rect.width);
  const py = (event.clientY - rect.top) * (canvas.height / rect.height);
  return {
    x: Math.floor(px / tilePx) + 1,
    y: Math.floor(py / tilePx) + 1
  };
}

async function main() {
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
  document.getElementById("zoom-in").addEventListener("click", () => {
    tilePx = Math.min(16, tilePx + 2);
    draw();
  });
  document.getElementById("zoom-out").addEventListener("click", () => {
    tilePx = Math.max(2, tilePx - 2);
    draw();
  });
  const canvas = document.getElementById("map");
  canvas.addEventListener("mousemove", (event) => {
    if (!mapData) {
      return;
    }
    const tile = tileFromEvent(event);
    const info = document.getElementById("hover");
    if (tile.x < 1 || tile.y < 1
        || tile.x > mapData.width || tile.y > mapData.height) {
      info.textContent = "Hover a tile.";
      return;
    }
    const cell = cellAt(mapData, tile.x, tile.y);
    const walk = cell.walk ? "yes" : "no";
    const drive = cell.drive ? "yes" : "no";
    info.textContent =
      `x ${tile.x}  y ${tile.y}  ${cell.name}` +
      `  height ${cell.level}  walk ${walk}  drive ${drive}`;
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
