(function () {
  'use strict';

  const defaultStyle = { color: "#3388ff", weight: 2, fillColor: "#3388ff", fillOpacity: 0.2 };
  const selectedStyle = { color: "#2E7D32", weight: 3, fillColor: "#4CAF50", fillOpacity: 0.5 };

  // Track selected parcels per map
  const selectedParcels = {};

  Shiny.addCustomMessageHandler("cadastre_select", function (msg) {
    const el = document.getElementById(msg.mapId);
    if (!el) {
      console.warn('cadastre_select: element not found:', msg.mapId);
      return;
    }

    const map = el._leaflet_map;
    if (!map) {
      console.warn('cadastre_select: no _leaflet_map on element');
      return;
    }

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

    const isCurrentlySelected = selectedParcels[msg.mapId].has(msg.id);

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
    const el = document.getElementById(msg.mapId);
    if (!el || !el._leaflet_map) return;

    const map = el._leaflet_map;

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
