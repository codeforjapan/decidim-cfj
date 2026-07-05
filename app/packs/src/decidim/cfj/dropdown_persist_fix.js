import { screens } from 'tailwindcss/defaultTheme'

// a11y-dropdown-component closes any dropdown on outside click regardless of
// data-open-md, and decidim-core's createDropdown() never reopens it (see
// app/packs/src/decidim/a11y.js in decidim-core) — this restores it on desktop.
const isDesktop = () => window.matchMedia(`(min-width: ${screens.md})`).matches

const keepOpenOnDesktop = trigger => {
  const target = document.getElementById(trigger.dataset.target)
  if (!target) return

  const reopenIfNeeded = () => {
    if (isDesktop() && target.getAttribute('aria-hidden') === 'true') {
      target.setAttribute('aria-hidden', 'false')
      trigger.setAttribute('aria-expanded', 'true')
    }
  }

  new MutationObserver(reopenIfNeeded).observe(target, { attributes: true, attributeFilter: ['aria-hidden'] })
  window.addEventListener('resize', reopenIfNeeded)
}

export default () => {
  document.querySelectorAll('[data-component="dropdown"][data-open-md="true"]').forEach(keepOpenOnDesktop)
}
