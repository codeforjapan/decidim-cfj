export default () => {
  const accordions = document.querySelectorAll('[data-component="accordion"]');

  accordions.forEach(accordion => {
    const button = accordion.querySelector('[data-controls]');

    if (button) {
      button.addEventListener('click', () => {
        const isExpanded = button.getAttribute('aria-expanded') === 'false';

        if (!isExpanded) {
          let accordionTop;
          if (accordion.parentElement) {
            accordionTop = accordion.parentElement.offsetTop;
          } else {
            accordionTop = accordion.offsetTop;
          }

          window.scrollTo({
            top: accordionTop,
            behavior: 'instant'
          });
        }
      });
    }
  });
};

