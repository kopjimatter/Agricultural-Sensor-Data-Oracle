(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SENSOR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DATA (err u102))
(define-constant ERR_ORACLE_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_ALREADY_EXISTS (err u105))

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
