;; route-optimizer 
;; Smart contract for optimizing waste collection routes using AI data

;; Constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-ROUTE (err u402))
(define-constant ERR-ROUTE-FULL (err u403))
(define-constant ERR-INVALID-OWNER (err u404))
(define-constant ERR-INVALID-DISTANCE (err u405))
(define-constant ERR-INVALID-TIME (err u406))
(define-constant ERR-INVALID-VEHICLE (err u407))
(define-constant ERR-INVALID-METRICS (err u408))

(define-constant MAX-STOPS-PER-ROUTE u20)
(define-constant MAX-DISTANCE u100000)  ;; Maximum route distance in meters
(define-constant MAX-TIME u480)         ;; Maximum time in minutes (8 hours)
(define-constant MIN-FUEL u1)           ;; Minimum fuel consumption
(define-constant MAX-FUEL u1000)        ;; Maximum fuel consumption
(define-constant MAX-WASTE u10000)      ;; Maximum waste collection in kg

(define-constant VALID-VEHICLE-TYPES
    (list
        (some "truck")
        (some "van")
        (some "compact")
    )
)

;; Data variables
(define-data-var next-route-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Data structures
(define-map routes
    uint
    {
        stops: (list 20 principal),
        total-distance: uint,
        estimated-time: uint,
        last-optimized: uint,
        vehicle-type: (string-ascii 7)  ;; Updated to match the string length
    }
)

(define-map route-metrics
    uint
    {
        fuel-consumed: uint,
        time-taken: uint,
        waste-collected: uint,
        efficiency-score: uint
    }
)

;; Validation functions
(define-private (is-valid-owner (new-owner principal))
    ;; Prevent setting same owner and ensure new owner is not a zero address
    (and 
        (not (is-eq new-owner tx-sender))
        (not (is-eq new-owner (var-get contract-owner)))
    )
)

(define-private (is-valid-vehicle-type (vehicle-type (string-ascii 7)))  ;; Updated to match the string length
    (let ((vehicle-index (index-of VALID-VEHICLE-TYPES (some vehicle-type))))
        (is-some vehicle-index)
    )
)

(define-private (is-valid-distance (distance uint))
    (and (> distance u0) (<= distance MAX-DISTANCE))
)

(define-private (is-valid-time (time uint))
    (and (> time u0) (<= time MAX-TIME))
)

(define-private (is-valid-fuel (fuel uint))
    (and (>= fuel MIN-FUEL) (<= fuel MAX-FUEL))
)

(define-private (is-valid-waste (waste uint))
    (and (> waste u0) (<= waste MAX-WASTE))
)

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (is-valid-owner new-owner) ERR-INVALID-OWNER)
        (ok (var-set contract-owner new-owner))
    )
)

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (calculate-route-score 
    (distance uint) 
    (stops (list 20 principal)) 
    (time uint))
    (let
        ((num-stops (len stops)))
        (+ (* distance u2) 
           (* num-stops u100) 
           (* time u1))
    )
)

;; Public functions
(define-public (create-route 
    (stops (list 20 principal))
    (distance uint)
    (estimated-time uint)
    (vehicle-type (string-ascii 7)))  ;; Updated to match the string length
    (let
        ((route-id (var-get next-route-id))
         (score (calculate-route-score distance stops estimated-time)))
        (begin
            ;; Validate inputs
            (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
            (asserts! (> (len stops) u0) ERR-INVALID-ROUTE)
            (asserts! (<= (len stops) MAX-STOPS-PER-ROUTE) ERR-ROUTE-FULL)
            (asserts! (is-valid-distance distance) ERR-INVALID-DISTANCE)
            (asserts! (is-valid-time estimated-time) ERR-INVALID-TIME)
            (asserts! (is-valid-vehicle-type vehicle-type) ERR-INVALID-VEHICLE)
            
            ;; Create route
            (map-set routes route-id
                {
                    stops: stops,
                    total-distance: distance,
                    estimated-time: estimated-time,
                    last-optimized: block-height,
                    vehicle-type: vehicle-type
                })
            
            ;; Initialize metrics
            (map-set route-metrics route-id
                {
                    fuel-consumed: u0,
                    time-taken: u0,
                    waste-collected: u0,
                    efficiency-score: score
                })
            
            (var-set next-route-id (+ route-id u1))
            (ok route-id)
        )
    )
)

(define-public (update-route-metrics
    (route-id uint)
    (fuel uint)
    (time uint)
    (waste uint))
    (let
        ((existing-route (unwrap! (map-get? routes route-id) ERR-INVALID-ROUTE)))
        (begin
            ;; Validate inputs
            (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
            (asserts! (is-valid-fuel fuel) ERR-INVALID-METRICS)
            (asserts! (is-valid-time time) ERR-INVALID-TIME)
            (asserts! (is-valid-waste waste) ERR-INVALID-METRICS)
            
            (ok (map-set route-metrics route-id
                {
                    fuel-consumed: fuel,
                    time-taken: time,
                    waste-collected: waste,
                    efficiency-score: (calculate-route-score 
                        (get total-distance existing-route)
                        (get stops existing-route)
                        time)
                }))

        )
    )
)

;; Read-only functions
(define-read-only (get-route (route-id uint))
    (map-get? routes route-id)
)

(define-read-only (get-route-metrics (route-id uint))
    (map-get? route-metrics route-id)
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)
