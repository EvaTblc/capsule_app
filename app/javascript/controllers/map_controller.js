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
      new mapboxgl.Marker({ element: this.#createEventMarker() })
        .setLngLat([marker.lng, marker.lat])
        .setPopup(new mapboxgl.Popup().setText(marker.label || ''))
        .addTo(this.map)
    })

    if (this.hasUserLatValue && this.hasUserLngValue && this.userLatValue !== 0 && this.userLngValue !== 0) {
      new mapboxgl.Marker({ element: this.#createHomeMarker() })
        .setLngLat([this.userLngValue, this.userLatValue])
        .setPopup(new mapboxgl.Popup().setText('Ma position'))
        .addTo(this.map)
    }
  }

  #createEventMarker() {
    const el = document.createElement('div')
    el.style.width = '40px'
    el.style.height = '56px'
    el.style.cursor = 'pointer'
    el.innerHTML = `
      <svg width="40" height="56" viewBox="0 0 80 112" xmlns="http://www.w3.org/2000/svg">
        <circle cx="40" cy="36" r="32" fill="#7c3aed"/>
        <polygon points="40,20 43,31 55,31 46,38 49,49 40,43 31,49 34,38 25,31 37,31" fill="white"/>
        <path d="M32,65 Q40,82 48,65" fill="#7c3aed"/>
      </svg>
    `
    return el
  }

  #createHomeMarker() {
    const el = document.createElement('div')
    el.style.width = '40px'
    el.style.height = '56px'
    el.style.cursor = 'pointer'
    el.innerHTML = `
      <svg width="40" height="56" viewBox="0 0 80 112" xmlns="http://www.w3.org/2000/svg">
        <circle cx="40" cy="36" r="32" fill="#f59e0b"/>
        <path d="M40 18 L56 30 L56 50 L47 50 L47 39 L33 39 L33 50 L24 50 L24 30 Z" fill="white"/>
        <rect x="33" y="39" width="14" height="11" rx="2" fill="#f59e0b"/>
        <path d="M32,65 Q40,82 48,65" fill="#f59e0b"/>
      </svg>
    `
    return el
  }

  #fitMapToMarkers() {
    console.log("markers:", this.markersValue)
    const bounds = new mapboxgl.LngLatBounds()
    this.markersValue.forEach(marker => bounds.extend([marker.lng, marker.lat]))
    if (this.hasUserLatValue && this.hasUserLngValue) {
      bounds.extend([this.userLngValue, this.userLatValue])
    }
    this.map.fitBounds(bounds, { padding: 70, maxZoom: 12, duration: 0 })
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
