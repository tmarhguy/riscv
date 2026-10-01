(function () {
  'use strict';

  // Collapsible left TOC for Asciidoctor ':toc: left' output.
  // No dependencies. Degrades gracefully: without JS the TOC renders
  // fully expanded and all anchor links keep working.
  // Generic: storage key is derived from the page path, no project name.

  var TOC_ID = 'toc';
  var COLLAPSED_CLASS = 'toc-collapsed';
  var ACTIVE_CLASS = 'toc-active';
  var JS_CLASS = 'js-nav';
  var EXPANDED_GLYPH = '\u25BE'; // v
  var COLLAPSED_GLYPH = '\u25B8'; // >
  var STORAGE_KEY = 'asciidoc-toc-state:' + location.pathname;

  function loadState() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return {};
      var parsed = JSON.parse(raw);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch (e) {
      return {}; // private mode etc: simply don't persist
    }
  }

  function saveState(state) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      /* ignore */
    }
  }

  // Section key for an anchor href: the '#fragment' part.
  function keyOf(href) {
    var i = href.indexOf('#');
    return i >= 0 ? href.slice(i) : href;
  }

  function setCollapsed(li, button, collapsed, state, persist) {
    li.classList.toggle(COLLAPSED_CLASS, collapsed);
    button.textContent = collapsed ? COLLAPSED_GLYPH : EXPANDED_GLYPH;
    button.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
    var link = li.querySelector(':scope > a');
    if (link) {
      if (persist) {
        var k = keyOf(link.getAttribute('href') || link.textContent);
        if (collapsed) state[k] = true;
        else delete state[k];
      }
    }
  }

  function expandAncestors(link) {
    // Walk up nested <li> ancestors so the active section is visible.
    var el = link.parentElement;
    while (el) {
      if (el.tagName === 'LI') el.classList.remove(COLLAPSED_CLASS);
      if (el.id === TOC_ID) break;
      el = el.parentElement;
    }
    // Sync disclosure buttons after un-collapsing ancestors.
    el = link.parentElement;
    while (el) {
      if (el.tagName === 'LI') {
        var btn = el.querySelector(':scope > button.toc-disclosure');
        if (btn && !el.classList.contains(COLLAPSED_CLASS)) {
          btn.textContent = EXPANDED_GLYPH;
          btn.setAttribute('aria-expanded', 'true');
        }
      }
      if (el.id === TOC_ID) break;
      el = el.parentElement;
    }
  }

  function markActive(link) {
    var toc = document.getElementById(TOC_ID);
    toc.querySelectorAll('a.' + ACTIVE_CLASS).forEach(function (a) {
      a.classList.remove(ACTIVE_CLASS);
    });
    link.classList.add(ACTIVE_CLASS);
    expandAncestors(link);
  }

  function init() {
    var toc = document.getElementById(TOC_ID);
    if (!toc) return;
    document.documentElement.classList.add(JS_CLASS);

    var state = loadState();

    // Add a disclosure button to every item that owns a nested list.
    // The title <a> is left untouched so navigation never depends on JS.
    toc.querySelectorAll('li').forEach(function (li) {
      var childList = li.querySelector(':scope > ul');
      if (!childList) return;
      var link = li.querySelector(':scope > a');
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'toc-disclosure';
      btn.setAttribute('aria-label', 'Toggle subsection visibility');
      btn.textContent = EXPANDED_GLYPH;
      btn.setAttribute('aria-expanded', 'true');
      btn.addEventListener('click', function () {
        var collapsed = !li.classList.contains(COLLAPSED_CLASS);
        setCollapsed(li, btn, collapsed, state, true);
        saveState(state);
      });
      li.insertBefore(btn, link || childList);

      // Restore persisted state.
      if (link && state[keyOf(link.getAttribute('href') || '')]) {
        setCollapsed(li, btn, true, state, false);
      }
    });

    // Subtle Collapse all / Expand all controls at the top of the TOC.
    var controls = document.createElement('div');
    controls.className = 'toc-controls';
    var collapseAll = document.createElement('button');
    collapseAll.type = 'button';
    collapseAll.textContent = 'Collapse all';
    var expandAll = document.createElement('button');
    expandAll.type = 'button';
    expandAll.textContent = 'Expand all';
    collapseAll.addEventListener('click', function () {
      toc.querySelectorAll('li').forEach(function (li) {
        var btn = li.querySelector(':scope > button.toc-disclosure');
        if (btn && li.querySelector(':scope > ul')) {
          setCollapsed(li, btn, true, state, true);
        }
      });
      saveState(state);
    });
    expandAll.addEventListener('click', function () {
      toc.querySelectorAll('li').forEach(function (li) {
        var btn = li.querySelector(':scope > button.toc-disclosure');
        if (btn && li.querySelector(':scope > ul')) {
          setCollapsed(li, btn, false, state, true);
        }
      });
      saveState(state);
    });
    controls.appendChild(collapseAll);
    controls.appendChild(expandAll);
    toc.insertBefore(controls, toc.firstChild);

    // Highlight the current section and auto-expand its ancestors.
    function linkForFragment(frag) {
      return frag && toc.querySelector('a[href="' + frag + '"]');
    }
    function activateFromHash() {
      var link = linkForFragment(location.hash);
      if (link) markActive(link);
    }
    window.addEventListener('hashchange', activateFromHash);
    activateFromHash();

    // Scrollspy: mark the section currently at the top of the viewport.
    if ('IntersectionObserver' in window) {
      var links = Array.prototype.slice.call(toc.querySelectorAll('a[href^="#"]'));
      var byFrag = {};
      links.forEach(function (a) {
        byFrag[a.getAttribute('href')] = a;
      });
      var observer = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              var link = byFrag['#' + entry.target.id];
              if (link) markActive(link);
            }
          });
        },
        { rootMargin: '-20% 0px -70% 0px' }
      );
      document
        .querySelectorAll('#content h2[id], #content h3[id], #content h4[id]')
        .forEach(function (h) {
          observer.observe(h);
        });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
