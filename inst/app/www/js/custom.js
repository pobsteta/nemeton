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
   * Handle basemap toggle button group
   */
  function initBasemapToggle() {
    document.addEventListener('click', function(e) {
      if (e.target.matches('[id$="-basemap_osm"], [id$="-basemap_satellite"]')) {
        const btnGroup = e.target.closest('.btn-group');
        if (btnGroup) {
          btnGroup.querySelectorAll('.btn').forEach(function(btn) {
            btn.classList.remove('active');
          });
          e.target.classList.add('active');
        }
      }
    });
  }


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
    console.log('showElement called with id:', id);
    const el = document.getElementById(id);
    if (el) {
      console.log('Element found, showing:', id);
      el.style.display = 'block';
      el.classList.remove('d-none');
    } else {
      console.warn('Element not found:', id);
    }
  });

  /**
   * Hide element by ID
   */
  Shiny.addCustomMessageHandler('hideElement', function(data) {
    const id = data.id;
    console.log('hideElement called with id:', id);
    const el = document.getElementById(id);
    if (el) {
      console.log('Element found, hiding:', id);
      el.style.display = 'none';
      el.classList.add('d-none');
    } else {
      console.warn('Element not found for hiding:', id);
    }
  });

  /**
   * Handle map loading overlay visibility
   */
  Shiny.addCustomMessageHandler('showMapLoading', function(data) {
    const loadingId = data.loadingId;
    const show = data.show;

    const overlay = document.getElementById(loadingId);
    if (overlay) {
      if (show) {
        overlay.classList.remove('d-none');
        overlay.style.display = 'flex';
      } else {
        overlay.classList.add('d-none');
        overlay.style.display = 'none';
      }
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
