(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SENSOR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DATA (err u102))
(define-constant ERR_ORACLE_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_ALREADY_EXISTS (err u105))
(define-constant ERR_NO_DATA_AVAILABLE (err u106))
(define-constant ERR_INVALID_WINDOW (err u107))

(define-constant ERR_QUALITY_CHECK_FAILED (err u108))

(define-constant ERR_ALERT_NOT_FOUND (err u109))
(define-constant ERR_INVALID_THRESHOLD (err u110))

(define-data-var next-listing-id uint u1)
(define-data-var next-pass-id uint u1)

(define-constant ERR_LISTING_NOT_FOUND (err u111))
(define-constant ERR_LISTING_INACTIVE (err u112))
(define-constant ERR_INVALID_DURATION (err u113))
(define-constant ERR_ACCESS_EXPIRED (err u114))

(define-data-var oracle-fee uint u1000000)
(define-data-var next-sensor-id uint u1)
(define-data-var next-oracle-id uint u1)

(define-map sensors
  { sensor-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    sensor-type: (string-ascii 50),
    active: bool,
    last-update: uint,
    created-at: uint
  }
)

(define-map sensor-data
  { sensor-id: uint, timestamp: uint }
  {
    temperature: int,
    humidity: uint,
    soil-moisture: uint,
    ph-level: uint,
    light-intensity: uint,
    rainfall: uint
  }
)

(define-map oracles
  { oracle-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    reputation: uint,
    total-updates: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map oracle-permissions
  { oracle-id: uint, sensor-id: uint }
  { authorized: bool }
)

(define-map sensor-subscriptions
  { subscriber: principal, sensor-id: uint }
  {
    active: bool,
    subscribed-at: uint,
    last-payment: uint
  }
)

(define-public (register-sensor (location (string-ascii 100)) (sensor-type (string-ascii 50)))
  (let
    (
      (sensor-id (var-get next-sensor-id))
    )
    (map-set sensors
      { sensor-id: sensor-id }
      {
        owner: tx-sender,
        location: location,
        sensor-type: sensor-type,
        active: true,
        last-update: u0,
        created-at: stacks-block-height
      }
    )
    (var-set next-sensor-id (+ sensor-id u1))
    (ok sensor-id)
  )
)

(define-public (register-oracle (name (string-ascii 50)))
  (let
    (
      (oracle-id (var-get next-oracle-id))
    )
    (map-set oracles
      { oracle-id: oracle-id }
      {
        address: tx-sender,
        name: name,
        reputation: u100,
        total-updates: u0,
        active: true,
        registered-at: stacks-block-height
      }
    )
    (var-set next-oracle-id (+ oracle-id u1))
    (ok oracle-id)
  )
)

(define-public (authorize-oracle (sensor-id uint) (oracle-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (oracle (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR_ORACLE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR_UNAUTHORIZED)
    (asserts! (get active oracle) ERR_ORACLE_NOT_FOUND)
    (map-set oracle-permissions
      { oracle-id: oracle-id, sensor-id: sensor-id }
      { authorized: true }
    )
    (ok true)
  )
)

(define-public (submit-sensor-data 
  (oracle-id uint)
  (sensor-id uint)
  (temperature int)
  (humidity uint)
  (soil-moisture uint)
  (ph-level uint)
  (light-intensity uint)
  (rainfall uint)
)
  (let
    (
      (oracle (unwrap! (map-get? oracles { oracle-id: oracle-id }) ERR_ORACLE_NOT_FOUND))
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (permission (unwrap! (map-get? oracle-permissions { oracle-id: oracle-id, sensor-id: sensor-id }) ERR_UNAUTHORIZED))
      (timestamp stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get address oracle)) ERR_UNAUTHORIZED)
    (asserts! (get authorized permission) ERR_UNAUTHORIZED)
    (asserts! (get active oracle) ERR_ORACLE_NOT_FOUND)
    (asserts! (get active sensor) ERR_SENSOR_NOT_FOUND)
    (asserts! (and (>= humidity u0) (<= humidity u100)) ERR_INVALID_DATA)
    (asserts! (and (>= soil-moisture u0) (<= soil-moisture u100)) ERR_INVALID_DATA)
    (asserts! (and (>= ph-level u0) (<= ph-level u1400)) ERR_INVALID_DATA)
    
    (map-set sensor-data
      { sensor-id: sensor-id, timestamp: timestamp }
      {
        temperature: temperature,
        humidity: humidity,
        soil-moisture: soil-moisture,
        ph-level: ph-level,
        light-intensity: light-intensity,
        rainfall: rainfall
      }
    )
    
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor { last-update: timestamp })
    )
    
    (map-set oracles
      { oracle-id: oracle-id }
      (merge oracle { 
        total-updates: (+ (get total-updates oracle) u1),
        reputation: (+ (get reputation oracle) u1)
      })
    )
    
    (ok timestamp)
  )
)

(define-public (subscribe-to-sensor (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (fee (var-get oracle-fee))
    )
    (asserts! (get active sensor) ERR_SENSOR_NOT_FOUND)
    (try! (stx-transfer? fee tx-sender (get owner sensor)))
    
    (map-set sensor-subscriptions
      { subscriber: tx-sender, sensor-id: sensor-id }
      {
        active: true,
        subscribed-at: stacks-block-height,
        last-payment: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (deactivate-sensor (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR_UNAUTHORIZED)
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor { active: false })
    )
    (ok true)
  )
)

(define-public (update-oracle-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set oracle-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-sensor-info (sensor-id uint))
  (map-get? sensors { sensor-id: sensor-id })
)

(define-read-only (get-latest-sensor-data (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (last-update (get last-update sensor))
    )
    (ok (if (> last-update u0)
      (map-get? sensor-data { sensor-id: sensor-id, timestamp: last-update })
      none
    ))
  )
)

(define-read-only (get-sensor-data-at-time (sensor-id uint) (timestamp uint))
  (map-get? sensor-data { sensor-id: sensor-id, timestamp: timestamp })
)

(define-read-only (get-oracle-info (oracle-id uint))
  (map-get? oracles { oracle-id: oracle-id })
)

(define-read-only (is-oracle-authorized (oracle-id uint) (sensor-id uint))
  (default-to { authorized: false } 
    (map-get? oracle-permissions { oracle-id: oracle-id, sensor-id: sensor-id })
  )
)

(define-read-only (get-subscription-status (subscriber principal) (sensor-id uint))
  (map-get? sensor-subscriptions { subscriber: subscriber, sensor-id: sensor-id })
)

(define-read-only (get-oracle-fee)
  (var-get oracle-fee)
)

(define-read-only (get-next-sensor-id)
  (var-get next-sensor-id)
)

(define-read-only (get-next-oracle-id)
  (var-get next-oracle-id)
)


(define-map sensor-analytics
  { sensor-id: uint }
  {
    sample-count: uint,
    temp-min: int,
    temp-max: int,
    temp-sum: int,
    humidity-min: uint,
    humidity-max: uint,
    humidity-sum: uint,
    moisture-min: uint,
    moisture-max: uint,
    moisture-sum: uint,
    last-analysis: uint
  }
)

(define-private (update-sensor-analytics 
  (sensor-id uint)
  (temperature int)
  (humidity uint)
  (soil-moisture uint)
)
  (let
    (
      (current-stats (default-to {
        sample-count: u0,
        temp-min: temperature,
        temp-max: temperature,
        temp-sum: temperature,
        humidity-min: humidity,
        humidity-max: humidity,
        humidity-sum: humidity,
        moisture-min: soil-moisture,
        moisture-max: soil-moisture,
        moisture-sum: soil-moisture,
        last-analysis: u0
      } (map-get? sensor-analytics { sensor-id: sensor-id })))
    )
    (map-set sensor-analytics
      { sensor-id: sensor-id }
      {
        sample-count: (+ (get sample-count current-stats) u1),
        temp-min: (if (< temperature (get temp-min current-stats)) temperature (get temp-min current-stats)),
        temp-max: (if (> temperature (get temp-max current-stats)) temperature (get temp-max current-stats)),
        temp-sum: (+ (get temp-sum current-stats) temperature),
        humidity-min: (if (< humidity (get humidity-min current-stats)) humidity (get humidity-min current-stats)),
        humidity-max: (if (> humidity (get humidity-max current-stats)) humidity (get humidity-max current-stats)),
        humidity-sum: (+ (get humidity-sum current-stats) humidity),
        moisture-min: (if (< soil-moisture (get moisture-min current-stats)) soil-moisture (get moisture-min current-stats)),
        moisture-max: (if (> soil-moisture (get moisture-max current-stats)) soil-moisture (get moisture-max current-stats)),
        moisture-sum: (+ (get moisture-sum current-stats) soil-moisture),
        last-analysis: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-read-only (get-sensor-analytics (sensor-id uint))
  (map-get? sensor-analytics { sensor-id: sensor-id })
)

(define-read-only (get-sensor-averages (sensor-id uint))
  (let
    (
      (stats (unwrap! (map-get? sensor-analytics { sensor-id: sensor-id }) ERR_NO_DATA_AVAILABLE))
      (sample-count (get sample-count stats))
    )
    (asserts! (> sample-count u0) ERR_NO_DATA_AVAILABLE)
    (ok {
      temp-avg: (/ (get temp-sum stats) (to-int sample-count)),
      humidity-avg: (/ (get humidity-sum stats) sample-count),
      moisture-avg: (/ (get moisture-sum stats) sample-count),
      sample-count: sample-count
    })
  )
)


(define-map data-quality-scores
  { sensor-id: uint, timestamp: uint }
  {
    temperature-score: uint,
    humidity-score: uint,
    moisture-score: uint,
    ph-score: uint,
    overall-score: uint,
    validated: bool
  }
)

(define-map oracle-quality-metrics
  { oracle-id: uint }
  {
    total-submissions: uint,
    high-quality-submissions: uint,
    quality-ratio: uint,
    last-quality-update: uint
  }
)

(define-private (calculate-quality-score (value uint) (min-val uint) (max-val uint))
  (if (and (>= value min-val) (<= value max-val))
    u100
    (if (or (< value (- min-val u10)) (> value (+ max-val u10)))
      u0
      u50
    )
  )
)

(define-private (validate-data-quality 
  (sensor-id uint)
  (timestamp uint)
  (temperature int)
  (humidity uint)
  (soil-moisture uint)
  (ph-level uint)
)
  (let
    (
      (temp-score (if (and (>= temperature -40) (<= temperature 60)) u100 u0))
      (humidity-score (calculate-quality-score humidity u0 u100))
      (moisture-score (calculate-quality-score soil-moisture u0 u100))
      (ph-score (calculate-quality-score ph-level u0 u1400))
      (overall-score (/ (+ temp-score humidity-score moisture-score ph-score) u4))
    )
    (map-set data-quality-scores
      { sensor-id: sensor-id, timestamp: timestamp }
      {
        temperature-score: temp-score,
        humidity-score: humidity-score,
        moisture-score: moisture-score,
        ph-score: ph-score,
        overall-score: overall-score,
        validated: (>= overall-score u75)
      }
    )
    overall-score
  )
)

(define-private (update-oracle-quality (oracle-id uint) (quality-score uint))
  (let
    (
      (current-metrics (default-to {
        total-submissions: u0,
        high-quality-submissions: u0,
        quality-ratio: u100,
        last-quality-update: u0
      } (map-get? oracle-quality-metrics { oracle-id: oracle-id })))
      (new-total (+ (get total-submissions current-metrics) u1))
      (new-high-quality (if (>= quality-score u75) 
        (+ (get high-quality-submissions current-metrics) u1)
        (get high-quality-submissions current-metrics)))
      (new-ratio (/ (* new-high-quality u100) new-total))
    )
    (map-set oracle-quality-metrics
      { oracle-id: oracle-id }
      {
        total-submissions: new-total,
        high-quality-submissions: new-high-quality,
        quality-ratio: new-ratio,
        last-quality-update: stacks-block-height
      }
    )
    (ok new-ratio)
  )
)

(define-read-only (get-data-quality (sensor-id uint) (timestamp uint))
  (map-get? data-quality-scores { sensor-id: sensor-id, timestamp: timestamp })
)

(define-read-only (get-oracle-quality-metrics (oracle-id uint))
  (map-get? oracle-quality-metrics { oracle-id: oracle-id })
)


(define-data-var next-alert-id uint u1)

(define-map sensor-thresholds
  { sensor-id: uint }
  {
    temp-min: int,
    temp-max: int,
    humidity-min: uint,
    humidity-max: uint,
    moisture-min: uint,
    moisture-max: uint,
    ph-min: uint,
    ph-max: uint,
    active: bool,
    owner: principal,
    created-at: uint
  }
)

(define-map active-alerts
  { alert-id: uint }
  {
    sensor-id: uint,
    alert-type: (string-ascii 20),
    value: int,
    threshold: int,
    timestamp: uint,
    resolved: bool,
    severity: uint
  }
)

(define-public (set-sensor-thresholds 
  (sensor-id uint)
  (temp-min int) (temp-max int)
  (humidity-min uint) (humidity-max uint)
  (moisture-min uint) (moisture-max uint)
  (ph-min uint) (ph-max uint)
)
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR_UNAUTHORIZED)
    (asserts! (< temp-min temp-max) ERR_INVALID_THRESHOLD)
    (asserts! (< humidity-min humidity-max) ERR_INVALID_THRESHOLD)
    (asserts! (< moisture-min moisture-max) ERR_INVALID_THRESHOLD)
    (asserts! (< ph-min ph-max) ERR_INVALID_THRESHOLD)
    
    (map-set sensor-thresholds
      { sensor-id: sensor-id }
      {
        temp-min: temp-min, temp-max: temp-max,
        humidity-min: humidity-min, humidity-max: humidity-max,
        moisture-min: moisture-min, moisture-max: moisture-max,
        ph-min: ph-min, ph-max: ph-max,
        active: true,
        owner: tx-sender,
        created-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-private (check-and-create-alerts (sensor-id uint) (temperature int) (humidity uint) (soil-moisture uint) (ph-level uint))
  (let
    (
      (thresholds (map-get? sensor-thresholds { sensor-id: sensor-id }))
      (timestamp stacks-block-height)
    )
    (match thresholds
      threshold-data
      (begin
        (if (get active threshold-data)
          (begin
            (if (< temperature (get temp-min threshold-data))
              (create-alert sensor-id "temp-low" temperature (get temp-min threshold-data) timestamp)
              true)
            (if (> temperature (get temp-max threshold-data))
              (create-alert sensor-id "temp-high" temperature (get temp-max threshold-data) timestamp)
              true)
            (if (< humidity (get humidity-min threshold-data))
              (create-alert sensor-id "humidity-low" (to-int humidity) (to-int (get humidity-min threshold-data)) timestamp)
              true)
            (if (> humidity (get humidity-max threshold-data))
              (create-alert sensor-id "humidity-high" (to-int humidity) (to-int (get humidity-max threshold-data)) timestamp)
              true)
          )
          true
        )
        true
      )
      true
    )
  )
)

(define-private (create-alert (sensor-id uint) (alert-type (string-ascii 20)) (value int) (threshold int) (timestamp uint))
  (let
    (
      (alert-id (var-get next-alert-id))
      (diff (- value threshold))
      (severity (if (> (if (< diff 0) (- 0 diff) diff) 10) u3 u2))
    )
    (map-set active-alerts
      { alert-id: alert-id }
      {
        sensor-id: sensor-id,
        alert-type: alert-type,
        value: value,
        threshold: threshold,
        timestamp: timestamp,
        resolved: false,
        severity: severity
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    true
  )
)

(define-read-only (get-sensor-thresholds (sensor-id uint))
  (map-get? sensor-thresholds { sensor-id: sensor-id })
)

(define-read-only (get-alert (alert-id uint))
  (map-get? active-alerts { alert-id: alert-id })
)


(define-map marketplace-listings
  { listing-id: uint }
  {
    sensor-id: uint,
    seller: principal,
    price-per-block: uint,
    min-duration: uint,
    max-duration: uint,
    active: bool,
    created-at: uint,
    total-sales: uint
  }
)

(define-map sensor-to-listing
  { sensor-id: uint }
  { listing-id: uint }
)

(define-map access-passes
  { pass-id: uint }
  {
    listing-id: uint,
    buyer: principal,
    sensor-id: uint,
    purchased-at: uint,
    expires-at: uint,
    amount-paid: uint
  }
)

(define-map buyer-active-passes
  { buyer: principal, sensor-id: uint }
  { pass-id: uint, expires-at: uint }
)

(define-public (create-marketplace-listing 
  (sensor-id uint)
  (price-per-block uint)
  (min-duration uint)
  (max-duration uint)
)
  (let
    (
      (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (listing-id (var-get next-listing-id))
    )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR_UNAUTHORIZED)
    (asserts! (> price-per-block u0) ERR_INVALID_DATA)
    (asserts! (and (> min-duration u0) (>= max-duration min-duration)) ERR_INVALID_DURATION)
    
    (map-set marketplace-listings
      { listing-id: listing-id }
      {
        sensor-id: sensor-id,
        seller: tx-sender,
        price-per-block: price-per-block,
        min-duration: min-duration,
        max-duration: max-duration,
        active: true,
        created-at: stacks-block-height,
        total-sales: u0
      }
    )
    (map-set sensor-to-listing { sensor-id: sensor-id } { listing-id: listing-id })
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (purchase-access-pass (listing-id uint) (duration uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR_LISTING_NOT_FOUND))
      (total-cost (* (get price-per-block listing) duration))
      (pass-id (var-get next-pass-id))
      (expires-at (+ stacks-block-height duration))
    )
    (asserts! (get active listing) ERR_LISTING_INACTIVE)
    (asserts! (and (>= duration (get min-duration listing)) (<= duration (get max-duration listing))) ERR_INVALID_DURATION)
    
    (try! (stx-transfer? total-cost tx-sender (get seller listing)))
    
    (map-set access-passes
      { pass-id: pass-id }
      {
        listing-id: listing-id,
        buyer: tx-sender,
        sensor-id: (get sensor-id listing),
        purchased-at: stacks-block-height,
        expires-at: expires-at,
        amount-paid: total-cost
      }
    )
    (map-set buyer-active-passes
      { buyer: tx-sender, sensor-id: (get sensor-id listing) }
      { pass-id: pass-id, expires-at: expires-at }
    )
    (map-set marketplace-listings
      { listing-id: listing-id }
      (merge listing { total-sales: (+ (get total-sales listing) u1) })
    )
    (var-set next-pass-id (+ pass-id u1))
    (ok pass-id)
  )
)

(define-read-only (has-valid-access (buyer principal) (sensor-id uint))
  (match (map-get? buyer-active-passes { buyer: buyer, sensor-id: sensor-id })
    pass-data (< stacks-block-height (get expires-at pass-data))
    false
  )
)

(define-read-only (get-marketplace-listing (listing-id uint))
  (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-access-pass (pass-id uint))
  (map-get? access-passes { pass-id: pass-id })
)

(define-read-only (get-buyer-pass-info (buyer principal) (sensor-id uint))
  (map-get? buyer-active-passes { buyer: buyer, sensor-id: sensor-id })
)