const PETS = {
  orbit: {
    colors: ['transparent', '#2e94ff', '#0a1f3d', '#8ceaff', '#080d12'],
    rows: [
      [0, 0, 2, 2, 2, 0, 0],
      [0, 2, 1, 1, 1, 2, 0],
      [2, 1, 4, 1, 4, 1, 2],
      [2, 1, 1, 3, 1, 1, 2],
      [0, 2, 1, 1, 1, 2, 0],
      [0, 3, 2, 1, 2, 3, 0],
      [3, 0, 2, 0, 2, 0, 3],
    ],
  },
  stacky: {
    colors: ['transparent', '#ffad33', '#472b0a', '#ffed7a', '#080d12'],
    rows: [
      [0, 0, 2, 2, 2, 0, 0],
      [0, 2, 3, 3, 3, 2, 0],
      [2, 3, 4, 3, 4, 3, 2],
      [2, 1, 1, 1, 1, 1, 2],
      [2, 3, 3, 3, 3, 3, 2],
      [0, 2, 1, 1, 1, 2, 0],
      [3, 2, 0, 0, 0, 2, 3],
    ],
  },
  nullSignal: {
    colors: ['transparent', '#9e5cff', '#33145c', '#e6c7ff', '#ffffff'],
    rows: [
      [0, 0, 2, 2, 2, 0, 0],
      [0, 2, 1, 1, 1, 2, 0],
      [2, 1, 4, 1, 4, 1, 2],
      [2, 1, 1, 2, 1, 1, 2],
      [2, 1, 3, 3, 3, 1, 2],
      [0, 2, 1, 1, 1, 2, 0],
      [0, 0, 2, 0, 2, 0, 0],
    ],
  },
  luma: {
    colors: ['transparent', '#38dbae', '#0a3d38', '#c7ff6b', '#080d12'],
    rows: [
      [0, 0, 3, 3, 3, 0, 0],
      [0, 3, 1, 1, 1, 3, 0],
      [3, 1, 4, 1, 4, 1, 3],
      [2, 1, 1, 1, 1, 1, 2],
      [0, 3, 1, 2, 1, 3, 0],
      [0, 0, 3, 1, 3, 0, 0],
      [0, 3, 0, 0, 0, 3, 0],
    ],
  },
  flux: {
    colors: ['transparent', '#ff6157', '#5c140d', '#ffc738', '#ffffff'],
    rows: [
      [0, 0, 3, 1, 3, 0, 0],
      [0, 3, 1, 1, 1, 3, 0],
      [3, 1, 4, 1, 4, 1, 3],
      [2, 1, 1, 3, 1, 1, 2],
      [0, 3, 1, 1, 1, 3, 0],
      [0, 0, 2, 3, 2, 0, 0],
      [0, 2, 0, 0, 0, 2, 0],
    ],
  },
};

const namespace = 'http://www.w3.org/2000/svg';

document.querySelectorAll('[data-pet]').forEach(target => {
  const pet = PETS[target.dataset.pet];

  if (!pet || target.firstChild) {
    return;
  }

  const svg = document.createElementNS(namespace, 'svg');
  svg.setAttribute('viewBox', '0 0 7 7');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('focusable', 'false');

  pet.rows.forEach((row, y) => {
    row.forEach((value, x) => {
      if (!value) {
        return;
      }

      const rect = document.createElementNS(namespace, 'rect');
      rect.setAttribute('x', String(x));
      rect.setAttribute('y', String(y));
      rect.setAttribute('width', '1');
      rect.setAttribute('height', '1');
      rect.setAttribute('fill', pet.colors[value]);
      svg.appendChild(rect);
    });
  });

  target.appendChild(svg);
});

const navLinks = [...document.querySelectorAll('.site-nav a[href^="#"]')];
const navTargets = navLinks
  .map(link => ({
    link,
    section: document.querySelector(link.getAttribute('href')),
  }))
  .filter(item => item.section);

const setActiveNav = () => {
  let current = navTargets[0];

  navTargets.forEach(item => {
    if (item.section.getBoundingClientRect().top <= 180) {
      current = item;
    }
  });

  navTargets.forEach(item => {
    item.link.classList.toggle('active', item === current);
  });
};

setActiveNav();
window.addEventListener('scroll', setActiveNav, { passive: true });
window.addEventListener('hashchange', setActiveNav);
