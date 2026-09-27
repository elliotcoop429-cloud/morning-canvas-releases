import * as THREE from 'three';

// Bundled into Resources/Loading/scene.js; no network or school data enters this scene.
try {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setClearColor(0, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1;
  document.body.appendChild(renderer.domElement);
  document.querySelector('#fallback').hidden = true;
  renderer.domElement.setAttribute('aria-label', 'Floating 3D school notebooks');
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 100);
  camera.position.set(0, 0, 12);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x667c9b, 1.3));
  const key = new THREE.DirectionalLight(0xffffff, 3);
  key.position.set(-3, 6, 8);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x98dfff, 2);
  rim.position.set(5, 2, -4);
  scene.add(rim);
  const group = new THREE.Group();
  scene.add(group);
  const pale = new THREE.MeshStandardMaterial({ color: 0xf4f8ff, roughness: 0.55 });
  const silver = new THREE.MeshStandardMaterial({ color: 0xcfe5f7, metalness: 0.8, roughness: 0.24 });
  function roundedBox(w, h, d, material) {
    const r = 0.09;
    const s = new THREE.Shape();
    s.moveTo(-w / 2 + r, -h / 2);
    s.lineTo(w / 2 - r, -h / 2);
    s.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r);
    s.lineTo(w / 2, h / 2 - r);
    s.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2);
    s.lineTo(-w / 2 + r, h / 2);
    s.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r);
    s.lineTo(-w / 2, -h / 2 + r);
    s.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
    const geometry = new THREE.ExtrudeGeometry(s, { depth: d, bevelEnabled: true, bevelSize: 0.025, bevelThickness: 0.025, bevelSegments: 3, steps: 1 });
    geometry.translate(0, 0, -d / 2);
    return new THREE.Mesh(geometry, material);
  }
  const books = [0x228bff, 0x20c7b8, 0xffb846].map((color, i) => {
    const book = new THREE.Group();
    const cover = new THREE.MeshPhysicalMaterial({ color, metalness: 0.25, roughness: 0.24, clearcoat: 1, clearcoatRoughness: 0.15 });
    const pages = roundedBox(1.22, 1.65, 0.18, pale);
    book.add(pages);
    for (const z of [-0.13, 0.13]) {
      const panel = roundedBox(1.36, 1.8, 0.065, cover);
      panel.position.z = z;
      book.add(panel);
    }
    for (let j = 0; j < 5; j++) {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.105, 0.025, 8, 24), silver);
      ring.position.set(-0.64, -0.58 + j * 0.29, 0);
      ring.rotation.y = Math.PI / 2;
      book.add(ring);
    }
    for (let j = 0; j < 3; j++) {
      const line = new THREE.Mesh(new THREE.BoxGeometry(j === 2 ? 0.4 : 0.68, 0.045, 0.02), pale);
      line.position.set(0.08, -0.16 - j * 0.17, 0.185);
      book.add(line);
    }
    const checkPath = new THREE.CurvePath();
    checkPath.add(new THREE.LineCurve3(new THREE.Vector3(-0.16, 0.4, 0.2), new THREE.Vector3(0, 0.24, 0.2)));
    checkPath.add(new THREE.LineCurve3(new THREE.Vector3(0, 0.24, 0.2), new THREE.Vector3(0.34, 0.59, 0.2)));
    book.add(new THREE.Mesh(new THREE.TubeGeometry(checkPath, 8, 0.038, 8, false), pale));
    book.position.x = (i - 1) * 1.45;
    group.add(book);
    return book;
  });
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let running = true;
  let frame = 0;
  let pointer = { x: 0, y: 0 };
  function resize() {
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 3));
    renderer.setSize(innerWidth, innerHeight);
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
    const visibleWidth = 2 * 12 * Math.tan(THREE.MathUtils.degToRad(17.5)) * camera.aspect;
    group.scale.setScalar(Math.min(1.05, visibleWidth / 6.2));
    // Keep the scene above the native title/status controls at every window size.
    group.position.y = 1.45;
    render(performance.now());
  }
  function render(now) {
    const t = motion.matches ? 0 : now / 1000;
    books.forEach((book, i) => {
      book.position.y = Math.sin(t * 1.15 + i * 1.4) * 0.2;
      book.position.z = Math.cos(t * 0.8 + i) * 0.2;
      book.rotation.set(-0.25 + Math.sin(t * 0.65 + i) * 0.2, (i - 1) * -0.45 + Math.sin(t * 0.75 + i * 0.4) * 0.65, (i - 1) * -0.1);
    });
    group.rotation.y = motion.matches ? 0 : pointer.x * 0.2;
    group.rotation.x = motion.matches ? 0 : pointer.y * 0.12;
    renderer.render(scene, camera);
  }
  function tick(now) {
    render(now);
    frame = running && !motion.matches ? requestAnimationFrame(tick) : 0;
  }
  window.setLoadingAnimation = (active) => {
    running = active;
    cancelAnimationFrame(frame);
    frame = 0;
    if (active) tick(performance.now());
  };
  motion.addEventListener('change', () => window.setLoadingAnimation(running));
  document.addEventListener('visibilitychange', () => window.setLoadingAnimation(!document.hidden));
  document.addEventListener('pointermove', e => {
    pointer = { x: e.clientX / innerWidth - 0.5, y: e.clientY / innerHeight - 0.5 };
  });
  window.addEventListener('resize', resize);
  resize();
  tick(performance.now());
} catch (error) {
  console.error('3D loading scene unavailable', error);
}
