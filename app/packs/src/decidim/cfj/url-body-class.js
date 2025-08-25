/**
 * add a class to body element
 *
 *   /processes/example -> body.participatory-process-example
 */
document.addEventListener('DOMContentLoaded', () => {
  const addUrlClassToBody = () => {
    const body = document.body;
    const pathname = window.location.pathname;

    // only pathes started with `/processes`
    if (pathname && pathname.startsWith('/processes/')) {
      // remove existing classes
      const existingClasses = Array.from(body.classList).filter(cls => cls.startsWith('participatory-process-'));
      existingClasses.forEach(cls => body.classList.remove(cls));

      // use only first segments of slugs
      const processPath = pathname.substring('/processes/'.length);
      const processSlug = processPath.split('/')[0];

      if (processSlug) {
        const processClass = processSlug.replace(/[^a-z0-9-]/gi, '').toLowerCase();

        if (processClass) {
          body.classList.add(`participatory-process-${processClass}`);
        }
      }
    }
  };

  addUrlClassToBody();
  document.addEventListener('turbo:load', addUrlClassToBody);
});
