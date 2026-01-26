(function () {
  'use strict';

  const defaultStyle = { color: "#3388ff", weight: 2, fillColor: "#3388ff", fillOpacity: 0.2 };
  const selectedStyle = { color: "#2E7D32", weight: 3, fillColor: "#4CAF50", fillOpacity: 0.5 };

  // Track selected parcels per map
  const selectedParcels = {};

  // Helper function to find the Leaflet map instance
  function findLeafletMap(mapId) {
    const el = document.getElementById(mapId);
    if (!el) {
      console.warn('cadastre_select: element not found:', mapId);
      return null;
    }

    // Method 1: Try _leaflet_map (some versions)
    if (el._leaflet_map) {
      return el._leaflet_map;
    }

    // Method 2: Try HTMLWidgets.getInstance
    if (window.HTMLWidgets && HTMLWidgets.getInstance) {
      const instance = HTMLWidgets.getInstance(el);
      if (instance && instance.getMap) {
        return instance.getMap();
      }
    }

    // Method 3: Try to find via Leaflet's internal registry
    if (window.L && L.Map) {
      // Leaflet stores map instances with _leaflet_id
      const leafletId = el._leaflet_id;
      if (leafletId !== undefined) {
        // Iterate through all Leaflet maps
        for (let key in L.Map._instances) {
          if (L.Map._instances.hasOwnProperty(key)) {
            const map = L.Map._instances[key];
            if (map._container === el) {
              return map;
            }
          }
        }
      }
    }

    // Method 4: Search in child elements (leaflet container might be nested)
    const leafletContainer = el.querySelector('.leaflet-container');
    if (leafletContainer) {
      if (leafletContainer._leaflet_map) {
        return leafletContainer._leaflet_map;
      }
      // Try HTMLWidgets on the container
      if (window.HTMLWidgets && HTMLWidgets.getInstance) {
        const instance = HTMLWidgets.getInstance(leafletContainer);
        if (instance && instance.getMap) {
          return instance.getMap();
        }
      }
    }

    console.warn('cadastre_select: could not find Leaflet map for:', mapId);
    return null;
  }

  Shiny.addCustomMessageHandler("cadastre_select", function (msg) {
    const map = findLeafletMap(msg.mapId);
    if (!map) return;

    // Find layer by layerId
    let targetLayer = null;
    map.eachLayer(function (layer) {
      if (layer && layer.options && String(layer.options.layerId) === String(msg.id)) {
        targetLayer = layer;
      }
    });

    if (!targetLayer || !targetLayer.setStyle) {
      console.warn('cadastre_select: layer not found or no setStyle:', msg.id);
      return;
    }

    // Initialize state for this map
    if (!selectedParcels[msg.mapId]) {
      selectedParcels[msg.mapId] = new Set();
    }

    if (msg.selected) {
      // Select
      targetLayer.setStyle(selectedStyle);
      if (targetLayer.bringToFront) targetLayer.bringToFront();
      selectedParcels[msg.mapId].add(msg.id);
    } else {
      // Deselect
      targetLayer.setStyle(defaultStyle);
      selectedParcels[msg.mapId].delete(msg.id);
    }
  });

  // Handler to clear all selections
  Shiny.addCustomMessageHandler("cadastre_clear", function (msg) {
    const map = findLeafletMap(msg.mapId);
    if (!map) return;

    if (selectedParcels[msg.mapId]) {
      selectedParcels[msg.mapId].forEach(function(id) {
        map.eachLayer(function (layer) {
          if (layer && layer.options && String(layer.options.layerId) === String(id)) {
            if (layer.setStyle) layer.setStyle(defaultStyle);
          }
        });
      });
      selectedParcels[msg.mapId].clear();
    }
  });
})();
