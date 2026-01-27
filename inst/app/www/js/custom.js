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

  /**
   * Close map popup after delay
   */
  Shiny.addCustomMessageHandler('closeMapPopup', function(data) {
    const mapId = data.mapId;
    const delay = data.delay || 100;

    setTimeout(function() {
      // Get the Leaflet map instance
      const mapContainer = document.getElementById(mapId);
      if (mapContainer && mapContainer._leaflet_map) {
        mapContainer._leaflet_map.closePopup();
      } else if (window.HTMLWidgets && window.HTMLWidgets.widgets) {
        // Try to find the map through HTMLWidgets
        const widgets = window.HTMLWidgets.widgets;
        for (let i = 0; i < widgets.length; i++) {
          if (widgets[i].el && widgets[i].el.id === mapId) {
            const map = widgets[i].getMap();
            if (map) {
              map.closePopup();
            }
            break;
          }
        }
      }
    }, delay);
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
