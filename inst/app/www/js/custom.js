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
  // Parcel Style Updates via setStyle (no flash)
  // ============================================================

  /**
   * Store reference to map layers for quick access
   */
  var parcelLayers = {};

  /**
   * Register a parcel layer for style updates
   */
  Shiny.addCustomMessageHandler('registerParcelLayer', function(data) {
    // Not needed - we'll find layers dynamically
  });

  /**
   * Update polygon style using Leaflet's setStyle (no remove/re-add)
   */
  Shiny.addCustomMessageHandler('updateParcelStyle', function(data) {
    var mapId = data.mapId;
    var layerId = data.layerId;
    var style = data.style;

    // Find the map container element
    var mapEl = document.getElementById(mapId);
    if (!mapEl) {
      console.warn('Map element not found:', mapId);
      return;
    }

    // Access the Leaflet map instance via the element's _leaflet_id
    var map = null;

    // Try to get the map from the HTMLWidgets binding
    if (window.HTMLWidgets) {
      var widgets = HTMLWidgets.widgets || [];
      for (var i = 0; i < widgets.length; i++) {
        var w = widgets[i];
        if (w.el && w.el.id === mapId && w.bindings && w.bindings.leaflet) {
          map = w.bindings.leaflet.getMap();
          break;
        }
      }
    }

    // Alternative: look for _leaflet_map on the element
    if (!map && mapEl._leaflet_map) {
      map = mapEl._leaflet_map;
    }

    // Alternative: iterate through L.map instances if available
    if (!map && window.L && L.DomUtil) {
      // Check if the element has a leaflet ID
      var leafletId = mapEl._leaflet_id;
      if (leafletId && L.Map && L.Map._instances) {
        map = L.Map._instances[leafletId];
      }
    }

    if (!map) {
      // Last resort: find map in global scope via HTMLWidgets.find
      if (window.HTMLWidgets && HTMLWidgets.find) {
        var widget = HTMLWidgets.find('#' + mapId);
        if (widget) {
          map = widget.getMap ? widget.getMap() : null;
        }
      }
    }

    if (!map) {
      console.warn('Could not find Leaflet map for:', mapId);
      return;
    }

    // Find and update the layer
    var found = false;
    map.eachLayer(function(layer) {
      if (layer.options && layer.options.layerId === layerId) {
        layer.setStyle({
          color: style.color,
          weight: style.weight,
          fillColor: style.fillColor,
          fillOpacity: style.fillOpacity
        });
        if (style.bringToFront) {
          layer.bringToFront();
        }
        found = true;
      }
    });

    if (!found) {
      console.warn('Layer not found:', layerId);
    }
  });


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
   * Handle progress bar updates
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
