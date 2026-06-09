import { Controller } from "@hotwired/stimulus"
import mapboxgl from 'mapbox-gl'

export default class extends Controller {
  static values = {
    apiKey: String,
    markers: Array,
    userLat: Number,
    userLng: Number,
    directions: Boolean
  }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v10"
    })

    this.#addMarkersToMap()
    this.#fitMapToMarkers()

    if (this.directionsValue && this.hasUserLatValue && this.hasUserLngValue) {
      this.map.on('load', () => this.#addDirections())
    }
  }

  #addMarkersToMap() {
    this.markersValue.forEach((marker) => {
      new mapboxgl.Marker({ color: marker.color || '#7c3aed' })
        .setLngLat([marker.lng, marker.lat])
        .setPopup(new mapboxgl.Popup().setText(marker.label || ''))
        .addTo(this.map)
    })

    // Marker user
    if (this.hasUserLatValue && this.hasUserLngValue && this.userLatValue !== 0 && this.userLngValue !== 0) {
      new mapboxgl.Marker({ color: '#f59e0b' })
        .setLngLat([this.userLngValue, this.userLatValue])
        .setPopup(new mapboxgl.Popup().setText('Ma position'))
        .addTo(this.map)
    }
  }

  #fitMapToMarkers() {
    const bounds = new mapboxgl.LngLatBounds()
    this.markersValue.forEach(marker => bounds.extend([marker.lng, marker.lat]))
    if (this.hasUserLatValue && this.hasUserLngValue) {
      bounds.extend([this.userLngValue, this.userLatValue])
    }
    this.map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 0 })
  }

  #addDirections() {
    const userCoords = [this.userLngValue, this.userLatValue]
    const eventCoords = [this.markersValue[0].lng, this.markersValue[0].lat]

    fetch(`https://api.mapbox.com/directions/v5/mapbox/driving/${userCoords[0]},${userCoords[1]};${eventCoords[0]},${eventCoords[1]}?geometries=geojson&access_token=${mapboxgl.accessToken}`)
      .then(res => res.json())
      .then(data => {
        const route = data.routes[0]
        const duration = Math.round(route.duration / 60)
        const distance = (route.distance / 1000).toFixed(1)

        const infoEl = document.getElementById('route-info')
        if (infoEl) {
          infoEl.innerHTML = `<span>🚗 ${duration} min</span><span>•</span><span>${distance} km</span>`
        }

        if (this.map.getSource('route')) {
          this.map.getSource('route').setData({ type: 'Feature', geometry: route.geometry })
        } else {
          this.map.addSource('route', {
            type: 'geojson',
            data: { type: 'Feature', geometry: route.geometry }
          })
          this.map.addLayer({
            id: 'route',
            type: 'line',
            source: 'route',
            layout: { 'line-join': 'round', 'line-cap': 'round' },
            paint: { 'line-color': '#7c3aed', 'line-width': 4, 'line-opacity': 0.8 }
          })
        }

        const bounds = new mapboxgl.LngLatBounds()
          .extend(userCoords)
          .extend(eventCoords)
        this.map.fitBounds(bounds, { padding: 40 })
      })
  }
}
