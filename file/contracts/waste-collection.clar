;; waste-collection
;; Smart contract for managing waste collection operations

(define-data-var total-collections uint u0)

;; Constants for validation
(define-constant MIN-CAPACITY u100)
(define-constant MAX-CAPACITY u10000)
(define-constant VALID-WASTE-TYPES (list "organic" "recyclable" "hazardous" "electronic" "general"))

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-CAPACITY (err u402))
(define-constant ERR-INVALID-WASTE-TYPE (err u403))
(define-constant ERR-INVALID-COORDINATES (err u405))

;; Data structures
(define-map collection-points
    principal
    {
        location: (tuple (latitude int) (longitude int)),
        waste-type: (string-ascii 10),  ;; Changed from utf8 to ascii
        capacity: uint,
        last-collection: uint
    }
)

;; Helper functions
(define-private (is-valid-waste-type (waste-type (string-ascii 10)))  ;; Changed parameter type
    (is-some (index-of VALID-WASTE-TYPES waste-type))
)

(define-private (is-valid-coordinates (latitude int) (longitude int))
    (and
        (and (>= latitude -90) (<= latitude 90))
        (and (>= longitude -180) (<= longitude 180))
    )
)

;; Public functions
(define-public (register-collection-point 
    (latitude int) 
    (longitude int)
    (waste-type (string-ascii 10))  ;; Changed parameter type
    (capacity uint))
    (let
        ((caller tx-sender))
        (begin
            ;; Input validation
            (asserts! (is-valid-coordinates latitude longitude) 
                ERR-INVALID-COORDINATES)
            (asserts! (is-valid-waste-type waste-type) 
                ERR-INVALID-WASTE-TYPE)
            (asserts! (and (>= capacity MIN-CAPACITY) (<= capacity MAX-CAPACITY)) 
                ERR-INVALID-CAPACITY)
            ;; Check if point already registered
            (asserts! (is-none (map-get? collection-points caller))
                (err u1))
            ;; If all validations pass, register the point
            (ok (map-set collection-points 
                caller
                {
                    location: (tuple (latitude latitude) (longitude longitude)),
                    waste-type: waste-type,
                    capacity: capacity,
                    last-collection: block-height
                }
            ))
        )
    )
)

;; Read-only functions
(define-read-only (get-collection-point (owner principal))
    (map-get? collection-points owner)
)

(define-read-only (get-valid-waste-types)
    VALID-WASTE-TYPES
)

;; Constants
(define-constant COLLECTION-INTERVAL u10000) ;; Blocks between collections
