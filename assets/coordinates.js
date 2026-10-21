(function (root) {
  'use strict';
  function nearestGrid(value, scale) {
    return Math.floor(value * scale + 0.5) / scale;
  }
  function measure(world, camera, fit) {
    const screen = world - camera + 160;
    const draw = nearestGrid(screen, 1);
    return { world: world, camera: camera, screen: screen, draw: draw,
      error: draw - screen, fit: fit, displayExtent: fit, viewLeft: camera - 160 };
  }
  function describe(value) {
    const place = value.screen < 145 ? 'left of the window’s middle' :
      value.screen > 175 ? 'right of the window’s middle' : 'near the window’s middle';
    const alignment = Math.abs(value.error) < 0.000001 ?
      'Its ideal edge is already on a native grid boundary.' :
      'Its ideal edge falls between native grid boundaries; the drawing copy moves ' +
      (value.error > 0 ? 'right' : 'left') + ' onto the nearest boundary.';
    return 'The actor appears ' + place + '. ' + alignment +
      ' Alignment leaves its world position unchanged.';
  }
  root.CoordinateLesson = { measure: measure, nearestGrid: nearestGrid, describe: describe };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.CoordinateLesson;
  if (typeof document === 'undefined') return;
  const panel = document.querySelector('[data-coordinate-demo]');
  if (!panel) return;
  const world = panel.querySelector('[name=world]');
  const camera = panel.querySelector('[name=camera]');
  const fit = panel.querySelector('[name=fit]');
  const ns = 'http://www.w3.org/2000/svg';
  function node(name, attributes, text) {
    const element = document.createElementNS(ns, name);
    Object.keys(attributes).forEach(function (key) { element.setAttribute(key, attributes[key]); });
    if (text !== undefined) element.textContent = text;
    return element;
  }
  function line(svg, x, y, x2, y2, color, dashed) {
    const attributes = { x1: x, y1: y, x2: x2, y2: y2, stroke: color };
    if (dashed) attributes['stroke-dasharray'] = '5 4';
    svg.appendChild(node('line', attributes));
  }
  function text(svg, x, y, content, anchor) {
    svg.appendChild(node('text', { x: x, y: y, 'text-anchor': anchor || 'start' }, content));
  }
  const landmarks = [{ x: 280, name: 'Door' }, { x: 430, name: 'Pedestal' }, { x: 700, name: 'Lamp' }];
  function landmark(svg, x, y, name) {
    svg.appendChild(node('rect', { x: x - 5, y: y - 24, width: 10, height: 24,
      fill: '#c3cabf', stroke: '#59635e' }));
    text(svg, x, y + 20, name, 'middle');
  }
  function actor(svg, x, y) {
    svg.appendChild(node('rect', { x: x, y: y - 38, width: 12, height: 38, fill: '#12665c' }));
    text(svg, x > 650 ? x - 10 : x + 18, y - 18, 'Actor edge', x > 650 ? 'end' : 'start');
  }
  function update() {
    const value = measure(Number(world.value), Number(camera.value), Number(fit.value));
    const worldView = panel.querySelector('[data-world]');
    worldView.replaceChildren();
    const map = function (x) { return 40 + (x - 200) * 1.2; };
    line(worldView, 40, 140, 760, 140, '#59635e');
    landmarks.forEach(function (mark) { landmark(worldView, map(mark.x), 140, mark.name); });
    worldView.appendChild(node('rect', { x: map(value.viewLeft), y: 50, width: 320 * 1.2,
      height: 100, fill: 'none', stroke: '#376a8b', 'stroke-width': 3 }));
    text(worldView, map(value.viewLeft) + 8, 36, 'Camera window');
    actor(worldView, map(value.world), 110);
    text(worldView, 40, 190, 'World reference: the room landmarks stay fixed');

    const screenView = panel.querySelector('[data-screen]');
    screenView.replaceChildren();
    screenView.appendChild(node('rect', { x: 40, y: 20, width: 720, height: 100,
      fill: 'none', stroke: '#376a8b', 'stroke-width': 3 }));
    const projectScreen = function (x) { return 40 + x * 720 / 320; };
    line(screenView, 400, 25, 400, 115, '#b6c0b1', true);
    landmarks.forEach(function (mark) {
      const screen = mark.x - value.camera + 160;
      if (screen > 12 && screen < 308) landmark(screenView, projectScreen(screen), 84, mark.name);
    });
    actor(screenView, projectScreen(value.screen), 75);
    text(screenView, 40, 142, 'Window left');
    text(screenView, 400, 142, 'Middle', 'middle');
    text(screenView, 760, 142, 'Window right', 'end');

    const raster = panel.querySelector('[data-raster]');
    raster.replaceChildren();
    const start = Math.floor(value.screen) - 3;
    const project = function (x) { return 50 + (x - start) * 85; };
    for (let i = 0; i <= 8; i += 1) {
      const x = project(start + i);
      line(raster, x, 28, x, 140, '#b6c0b1');
    }
    raster.appendChild(node('rect', { x: project(value.screen), y: 38, width: 85, height: 38,
      fill: '#d6aa77', stroke: '#885221' }));
    raster.appendChild(node('rect', { x: project(value.draw), y: 94, width: 85, height: 38,
      fill: '#12665c' }));
    text(raster, 50, 21, 'Ideal placement after camera translation');
    text(raster, 50, 89, 'Final aligned drawing copy');
    text(raster, 50, 163, 'Vertical lines mark native cell boundaries');

    const display = panel.querySelector('[data-display]');
    display.replaceChildren();
    display.appendChild(node('rect', { x: 50, y: 25, width: value.fit * 60, height: 48, fill: '#d6aa77' }));
    for (let i = 0; i <= 10; i += 1) {
      const x = 50 + i * 60;
      line(display, x, 18, x, 80, '#59635e');
    }
    text(display, 50, 103, 'Display-cell boundaries');
    panel.querySelector('[data-spatial-description]').textContent = describe(value);
    world.setAttribute('aria-valuetext', value.world < value.camera ? 'Actor edge left of the camera center' :
      value.world > value.camera ? 'Actor edge right of the camera center' : 'Actor edge at the camera center');
    camera.setAttribute('aria-valuetext', value.camera < value.world ? 'Camera center left of the actor edge' :
      value.camera > value.world ? 'Camera center right of the actor edge' : 'Camera center at the actor edge');
    fit.setAttribute('aria-valuetext', value.fit < 3 ? 'Small enlargement' :
      value.fit < 6 ? 'Moderate enlargement' : 'Large enlargement');
  }
  panel.addEventListener('input', update);
  panel.querySelector('[data-follow]').addEventListener('click', function () {
    camera.value = world.value;
    update();
  });
  panel.querySelector('[data-between]').addEventListener('click', function () {
    world.value = String(Number(camera.value) + (Number(camera.value) < 570 ? 0.25 : -0.25));
    update();
  });
  panel.querySelector('[data-reset]').addEventListener('click', function () {
    world.value = '500.5'; camera.value = '500.25'; fit.value = '5.5'; update();
  });
  update();
}(typeof globalThis !== 'undefined' ? globalThis : this));
