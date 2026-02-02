/**
 * nemetonApp Custom JavaScript
 * Accessibility and UX enhancements
 */

(function() {
  'use strict';

  // ============================================================
  // Keyboard Navigation
  // ============================================================

  /**
   * Add keyboard navigation support for custom elements
   */
  function initKeyboardNavigation() {
    // Make map parcels keyboard accessible
    document.addEventListener('keydown', function(e) {
      // Enter or Space to select focused parcel
      if ((e.key === 'Enter' || e.key === ' ') && e.target.classList.contains('leaflet-interactive')) {
        e.preventDefault();
        e.target.click();
      }

      // Escape to close modals
      if (e.key === 'Escape') {
        const modal = document.querySelector('.modal.show');
        if (modal) {
          const closeBtn = modal.querySelector('[data-bs-dismiss="modal"]');
          if (closeBtn) closeBtn.click();
        }
      }
    });
  }


  // ============================================================
  // Focus Management
  // ============================================================

  /**
   * Trap focus within modals for accessibility
   */
  function initFocusTrap() {
    document.addEventListener('shown.bs.modal', function(e) {
      const modal = e.target;
      const focusableElements = modal.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );

      if (focusableElements.length === 0) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      // Focus first element
      firstElement.focus();

      // Trap focus
      modal.addEventListener('keydown', function(e) {
        if (e.key !== 'Tab') return;

        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
          }
        } else {
          if (document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
          }
        }
      });
    });
  }


  // ============================================================
  // Touch Support
  // ============================================================

  /**
   * Enhance touch interactions for tablet use
   */
  function initTouchSupport() {
    // Detect touch device
    const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

    if (isTouchDevice) {
      document.body.classList.add('touch-device');

      // Increase hit areas on touch devices
      document.querySelectorAll('.btn-sm').forEach(function(btn) {
        btn.style.minHeight = '44px';
        btn.style.minWidth = '44px';
      });
    }
  }


  // ============================================================
  // Form Validation
  // ============================================================

  /**
   * Real-time form validation feedback
   */
  function initFormValidation() {
    // Project name validation
    const projectNameInput = document.querySelector('[id$="-project_name"]');
    if (projectNameInput) {
      projectNameInput.addEventListener('input', function() {
        const value = this.value.trim();
        const isValid = value.length > 0 && value.length <= 100;

        this.classList.toggle('is-valid', isValid && value.length > 0);
        this.classList.toggle('is-invalid', !isValid && value.length > 0);
      });
    }
  }


  // ============================================================
  // Basemap Toggle
  // ============================================================

  /**
   * Handle basemap toggle button group (client-side click)
   */
  function initBasemapToggle() {
    document.addEventListener('click', function(e) {
      var btn = e.target.closest('.basemap-btn');
      if (btn) {
        var btnGroup = btn.closest('.btn-group');
        if (btnGroup) {
          btnGroup.querySelectorAll('.basemap-btn').forEach(function(b) {
            b.classList.remove('basemap-btn-active');
          });
          btn.classList.add('basemap-btn-active');
        }
      }
    });
  }

  /**
   * Server-driven basemap button toggle
   */
  Shiny.addCustomMessageHandler('toggleBasemapButtons', function(data) {
    var osmBtn = document.getElementById(data.osmId);
    var satBtn = document.getElementById(data.satId);
    if (!osmBtn || !satBtn) return;

    osmBtn.classList.remove('basemap-btn-active');
    satBtn.classList.remove('basemap-btn-active');

    if (data.active === 'osm') {
      osmBtn.classList.add('basemap-btn-active');
    } else {
      satBtn.classList.add('basemap-btn-active');
    }
  });


  // ============================================================
  // Announcements for Screen Readers
  // ============================================================

  /**
   * Create a live region for screen reader announcements
   */
  function initLiveRegion() {
    if (document.getElementById('sr-announcer')) return;

    const announcer = document.createElement('div');
    announcer.id = 'sr-announcer';
    announcer.setAttribute('role', 'status');
    announcer.setAttribute('aria-live', 'polite');
    announcer.setAttribute('aria-atomic', 'true');
    announcer.className = 'visually-hidden';
    document.body.appendChild(announcer);
  }

  /**
   * Announce a message to screen readers
   * @param {string} message - Message to announce
   */
  window.announceToScreenReader = function(message) {
    const announcer = document.getElementById('sr-announcer');
    if (announcer) {
      announcer.textContent = '';
      setTimeout(function() {
        announcer.textContent = message;
      }, 100);
    }
  };


  // ============================================================
  // Selection Counter
  // ============================================================

  /**
   * Update selection counter display
   */
  Shiny.addCustomMessageHandler('updateSelectionCount', function(data) {
    const count = data.count;
    const max = data.max;

    // Announce to screen readers
    window.announceToScreenReader(count + ' parcelles sélectionnées sur ' + max);
  });


  // ============================================================
  // Progress Updates
  // ============================================================

  /**
   * Handle progress bar updates (generic)
   */
  Shiny.addCustomMessageHandler('updateProgress', function(data) {
    const progress = data.progress;
    const message = data.message;

    // Update progress bar
    const progressBar = document.querySelector('.progress-bar');
    if (progressBar) {
      progressBar.style.width = progress + '%';
      progressBar.textContent = progress + '%';
      progressBar.setAttribute('aria-valuenow', progress);
    }

    // Announce significant progress to screen readers
    if (progress === 25 || progress === 50 || progress === 75 || progress === 100) {
      window.announceToScreenReader(message);
    }
  });

  /**
   * Handle progress bar updates with specific element IDs
   */
  Shiny.addCustomMessageHandler('updateProgressBar', function(data) {
    const barId = data.barId;
    const percentId = data.percentId;
    const percent = data.percent;

    // Update progress bar width
    const progressBar = document.getElementById(barId);
    if (progressBar) {
      progressBar.style.width = percent + '%';
      progressBar.setAttribute('aria-valuenow', percent);
    }

    // Update percentage text
    const percentEl = document.getElementById(percentId);
    if (percentEl) {
      percentEl.textContent = percent + '%';
    }

    // Announce significant progress to screen readers
    if (percent === 25 || percent === 50 || percent === 75 || percent === 100) {
      window.announceToScreenReader('Progression: ' + percent + '%');
    }
  });

  /**
   * Handle text updates for specific elements
   */
  /**
   * Client-side elapsed time timer.
   * Avoids server-side invalidateLater(1000) which causes reactive flush flicker.
   */
  var _elapsedTimer = null;
  Shiny.addCustomMessageHandler('startElapsedTimer', function(data) {
    if (_elapsedTimer) clearInterval(_elapsedTimer);
    var el = document.getElementById(data.id);
    if (!el) return;
    var label = data.label || '';
    var startTime = Date.now();
    function tick() {
      var secs = Math.floor((Date.now() - startTime) / 1000);
      var m = Math.floor(secs / 60);
      var s = secs % 60;
      el.textContent = label + (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }
    tick();
    _elapsedTimer = setInterval(tick, 1000);
  });
  Shiny.addCustomMessageHandler('stopElapsedTimer', function(data) {
    if (_elapsedTimer) { clearInterval(_elapsedTimer); _elapsedTimer = null; }
  });

  /**
   * Build an indicator status table in the completion card.
   * data.containerId: target div ID
   * data.indicators: array of {name, status} objects
   * data.labels: {completed, failed, pending, indicator, status}
   */
  Shiny.addCustomMessageHandler('updateIndicatorsTable', function(data) {
    var container = document.getElementById(data.containerId);
    if (!container) return;
    var indicators = data.indicators || [];
    if (indicators.length === 0) { container.innerHTML = ''; return; }
    var labels = data.labels || {};
    var statusCell = function(s) {
      if (s === 'completed') return '<span class="text-success" style="font-size:1.1rem;">&#10003;</span>';
      return '<span class="text-danger" style="font-size:1.1rem;">&#10007;</span>';
    };
    var html = '<table class="table table-sm table-striped mb-0" style="font-size:0.85rem;">';
    html += '<thead><tr><th>' + (labels.indicator || 'Indicateur') + '</th>';
    html += '<th class="text-center" style="width:60px;"></th></tr></thead><tbody>';
    for (var i = 0; i < indicators.length; i++) {
      var ind = indicators[i];
      html += '<tr><td>' + ind.name + '</td>';
      html += '<td class="text-center">' + statusCell(ind.status) + '</td></tr>';
    }
    html += '</tbody></table>';
    container.innerHTML = html;
  });

  Shiny.addCustomMessageHandler('updateText', function(data) {
    const id = data.id;
    const text = data.text;

    const el = document.getElementById(id);
    if (el) {
      el.textContent = text;
    }
  });

  /**
   * Handle HTML updates for specific elements
   */
  Shiny.addCustomMessageHandler('updateHTML', function(data) {
    const id = data.id;
    const html = data.html;

    const el = document.getElementById(id);
    if (el) {
      el.innerHTML = html;
    }
  });

  /**
   * Show/hide element by ID
   */
  Shiny.addCustomMessageHandler('showElement', function(data) {
    const id = data.id;
    const el = document.getElementById(id);
    if (el) {
      el.style.display = 'block';
      el.classList.remove('d-none');
    }
  });

  /**
   * Hide element by ID
   */
  Shiny.addCustomMessageHandler('hideElement', function(data) {
    const id = data.id;
    const el = document.getElementById(id);
    if (el) {
      el.style.display = 'none';
      el.classList.add('d-none');
    }
  });

  /**
   * Toggle computation mode on body (suppresses busy indicator flicker)
   */
  Shiny.addCustomMessageHandler('setComputingMode', function(data) {
    if (data.active) {
      document.body.classList.add('nemeton-computing');
    } else {
      document.body.classList.remove('nemeton-computing');
    }
  });

  /**
   * Collapse a Bootstrap collapse element by ID
   */
  Shiny.addCustomMessageHandler('collapseElement', function(data) {
    var el = document.getElementById(data.id);
    if (el && typeof bootstrap !== 'undefined') {
      var bsCollapse = bootstrap.Collapse.getOrCreateInstance(el, {toggle: false});
      bsCollapse.hide();
    }
  });

  /**
   * In-map loading overlay: semi-transparent white + spinner over the map.
   * The map stays visible beneath the overlay at all times — no full-page
   * cover, no body class, no opacity changes on the leaflet container.
   */
  window._mapLoadingTimer = null;
  Shiny.addCustomMessageHandler('showMapLoading', function(data) {
    var loadingId = data.loadingId;
    var show = data.show;
    var overlay = document.getElementById(loadingId);

    if (show) {
      // Cancel any pending hide timer
      if (window._mapLoadingTimer) {
        clearTimeout(window._mapLoadingTimer);
        window._mapLoadingTimer = null;
      }
      if (overlay) {
        overlay.classList.remove('d-none');
        overlay.style.display = 'flex';
      }
    } else {
      // Brief delay so the spinner is visible for at least a moment
      window._mapLoadingTimer = setTimeout(function() {
        window._mapLoadingTimer = null;
        if (overlay) {
          overlay.classList.add('d-none');
          overlay.style.display = 'none';
        }
      }, 300);
    }
  });


  // ============================================================
  // Task Toast (fixed position, no DOM churn)
  // ============================================================

  /**
   * Update fixed task toast without creating/destroying DOM elements
   */
  Shiny.addCustomMessageHandler('updateTaskToast', function(data) {
    var wrapper = document.getElementById(data.wrapperId);
    var inner = document.getElementById(data.innerId);
    var textEl = document.getElementById(data.textId);
    var iconEl = document.getElementById(data.iconId);

    if (!wrapper || !textEl) return;

    if (data.visible) {
      textEl.textContent = data.text || '';
      // Set toast style based on type
      if (inner) {
        inner.className = 'toast show align-items-center border-0 text-bg-' +
          (data.type === 'warning' ? 'warning' : data.type === 'error' ? 'danger' : 'info');
      }
      if (iconEl) {
        iconEl.textContent = data.type === 'warning' ? '\u26a0' : data.type === 'error' ? '\u2716' : '\u2139';
      }
      wrapper.style.display = 'block';

      // Auto-hide after duration
      if (data.duration && data.duration > 0) {
        if (wrapper._hideTimer) clearTimeout(wrapper._hideTimer);
        wrapper._hideTimer = setTimeout(function() {
          wrapper.style.display = 'none';
        }, data.duration);
      }
    } else {
      wrapper.style.display = 'none';
      if (wrapper._hideTimer) clearTimeout(wrapper._hideTimer);
    }
  });

  // ============================================================
  // Tour Persistence (localStorage)
  // ============================================================

  /**
   * Check if guided tour was already seen and inform Shiny
   */
  function initTourPersistence() {
    var tourSeen = localStorage.getItem('nemeton_tour_seen') === 'true';
    // Send to Shiny once connected (namespaced for home module)
    $(document).on('shiny:connected', function() {
      Shiny.setInputValue('home-tour_seen_browser', tourSeen, {priority: 'event'});
    });
  }

  /**
   * Mark tour as seen in localStorage
   */
  Shiny.addCustomMessageHandler('markTourSeen', function(data) {
    localStorage.setItem('nemeton_tour_seen', 'true');
  });

  /**
   * Reset tour flag (for manual restart)
   */
  Shiny.addCustomMessageHandler('resetTourSeen', function(data) {
    localStorage.removeItem('nemeton_tour_seen');
  });

  // ============================================================
  // White Screen Prevention (Nuclear Safety Net)
  // ============================================================

  /**
   * White screen diagnostic + prevention.
   *
   * Previous approach: scan for white-background elements.
   * Result: NOTHING found in console. Body is gray but screen is white.
   *
   * New approach: use document.elementFromPoint() at center of viewport
   * to find what's ACTUALLY visible. This catches everything: real
   * elements, pseudo-elements rendered as children, iframe overlays, etc.
   * Logs on every shiny:busy + on a 200ms interval during busy state.
   */
  function initWhiteScreenPrevention() {

    // What element is at the center of the screen right now?
    function logCenterElement(label) {
      var cx = Math.round(window.innerWidth / 2);
      var cy = Math.round(window.innerHeight / 2);
      var el = document.elementFromPoint(cx, cy);
      if (!el) {
        console.log('[nemeton]', label, 'elementFromPoint: NULL');
        return;
      }
      var cs = window.getComputedStyle(el);
      console.log('[nemeton]', label, 'CENTER:', el.tagName,
        'id=' + el.id,
        'class=' + (el.className || '').toString().substring(0, 120),
        'bg=' + cs.backgroundColor, 'pos=' + cs.position,
        'z=' + cs.zIndex, 'opacity=' + cs.opacity,
        'size=' + el.offsetWidth + 'x' + el.offsetHeight);
      // Log 5 parents
      var p = el.parentElement;
      for (var d = 0; d < 5 && p; d++) {
        var pcs = window.getComputedStyle(p);
        console.log('[nemeton]   parent' + d + ':', p.tagName,
          'id=' + p.id,
          'class=' + (p.className || '').toString().substring(0, 80),
          'bg=' + pcs.backgroundColor, 'pos=' + pcs.position);
        p = p.parentElement;
      }
    }

    // Track busy state for interval scanning
    var busyInterval = null;

    $(document).on('shiny:busy', function() {
      console.log('[nemeton] ======= SHINY:BUSY =======');
      logCenterElement('BUSY-NOW');
      // Keep scanning during entire busy period
      if (busyInterval) clearInterval(busyInterval);
      busyInterval = setInterval(function() {
        logCenterElement('BUSY-SCAN');
      }, 200);
    });

    $(document).on('shiny:idle', function() {
      console.log('[nemeton] ======= SHINY:IDLE =======');
      logCenterElement('IDLE-NOW');
      if (busyInterval) {
        clearInterval(busyInterval);
        busyInterval = null;
      }
    });

    // Force visibility on key containers
    function forceVisible() {
      var selectors = [
        '.bslib-page-fill', '.bslib-page-navbar', '.tab-content',
        '.tab-pane.active', '.html-fill-container', '.html-fill-item',
        '.bslib-sidebar-layout', '.bslib-sidebar-layout > .main',
        '.bslib-sidebar-layout > .sidebar'
      ];
      for (var i = 0; i < selectors.length; i++) {
        var els = document.querySelectorAll(selectors[i]);
        for (var j = 0; j < els.length; j++) {
          els[j].style.setProperty('opacity', '1', 'important');
          els[j].style.setProperty('visibility', 'visible', 'important');
        }
      }
    }

    $(document).on('shiny:busy', forceVisible);
    setInterval(forceVisible, 1000);
  }


  // ============================================================
  // Initialization
  // ============================================================

  /**
   * Initialize all custom functionality
   */
  function init() {
    initKeyboardNavigation();
    initFocusTrap();
    initTouchSupport();
    initFormValidation();
    initBasemapToggle();
    initLiveRegion();
    initTourPersistence();
    initWhiteScreenPrevention();
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Re-initialize after Shiny updates
  $(document).on('shiny:value', function() {
    initFormValidation();
  });

})();
