;; Protection Coordination Contract
;; Coordinates trade secret protection measures

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-INVALID-STATUS (err u302))
(define-constant ERR-ALREADY-PROTECTED (err u303))

;; Data Variables
(define-data-var next-protection-id uint u1)

;; Data Maps
(define-map protection-measures
  { protection-id: uint }
  {
    secret-id: uint,
    measure-type: (string-ascii 50),
    status: (string-ascii 20),
    implemented-at: uint,
    expires-at: uint,
    coordinator: principal
  }
)

(define-map secret-protections
  { secret-id: uint, measure-type: (string-ascii 50) }
  { protection-id: uint, active: bool }
)

(define-map compliance-records
  { protection-id: uint }
  {
    last-check: uint,
    compliance-status: (string-ascii 20),
    violations-count: uint,
    next-review: uint
  }
)

;; Public Functions

;; Implement protection measure
(define-public (implement-protection
  (secret-id uint)
  (measure-type (string-ascii 50))
  (duration uint)
)
  (let ((protection-id (var-get next-protection-id)))
    (asserts! (is-none (map-get? secret-protections { secret-id: secret-id, measure-type: measure-type })) ERR-ALREADY-PROTECTED)

    (map-set protection-measures
      { protection-id: protection-id }
      {
        secret-id: secret-id,
        measure-type: measure-type,
        status: "active",
        implemented-at: block-height,
        expires-at: (+ block-height duration),
        coordinator: tx-sender
      }
    )

    (map-set secret-protections
      { secret-id: secret-id, measure-type: measure-type }
      { protection-id: protection-id, active: true }
    )

    (map-set compliance-records
      { protection-id: protection-id }
      {
        last-check: block-height,
        compliance-status: "compliant",
        violations-count: u0,
        next-review: (+ block-height u144) ;; ~24 hours
      }
    )

    (var-set next-protection-id (+ protection-id u1))
    (ok protection-id)
  )
)

;; Update protection status
(define-public (update-protection-status (protection-id uint) (new-status (string-ascii 20)))
  (let ((protection-data (unwrap! (map-get? protection-measures { protection-id: protection-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get coordinator protection-data)) ERR-UNAUTHORIZED)

    (map-set protection-measures
      { protection-id: protection-id }
      (merge protection-data { status: new-status })
    )

    (ok true)
  )
)

;; Record compliance check
(define-public (record-compliance-check
  (protection-id uint)
  (compliance-status (string-ascii 20))
  (violations-found uint)
)
  (let ((compliance-data (unwrap! (map-get? compliance-records { protection-id: protection-id }) ERR-NOT-FOUND)))
    (map-set compliance-records
      { protection-id: protection-id }
      {
        last-check: block-height,
        compliance-status: compliance-status,
        violations-count: (+ (get violations-count compliance-data) violations-found),
        next-review: (+ block-height u144)
      }
    )

    (ok true)
  )
)

;; Extend protection duration
(define-public (extend-protection (protection-id uint) (additional-duration uint))
  (let ((protection-data (unwrap! (map-get? protection-measures { protection-id: protection-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get coordinator protection-data)) ERR-UNAUTHORIZED)

    (map-set protection-measures
      { protection-id: protection-id }
      (merge protection-data {
        expires-at: (+ (get expires-at protection-data) additional-duration)
      })
    )

    (ok true)
  )
)

;; Deactivate protection
(define-public (deactivate-protection (protection-id uint))
  (let ((protection-data (unwrap! (map-get? protection-measures { protection-id: protection-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get coordinator protection-data)) ERR-UNAUTHORIZED)

    (map-set protection-measures
      { protection-id: protection-id }
      (merge protection-data { status: "inactive" })
    )

    (map-set secret-protections
      { secret-id: (get secret-id protection-data), measure-type: (get measure-type protection-data) }
      { protection-id: protection-id, active: false }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get protection measure
(define-read-only (get-protection (protection-id uint))
  (map-get? protection-measures { protection-id: protection-id })
)

;; Get compliance record
(define-read-only (get-compliance-record (protection-id uint))
  (map-get? compliance-records { protection-id: protection-id })
)

;; Check if secret has protection
(define-read-only (has-protection (secret-id uint) (measure-type (string-ascii 50)))
  (default-to false
    (get active (map-get? secret-protections { secret-id: secret-id, measure-type: measure-type }))
  )
)

;; Check if protection is expired
(define-read-only (is-protection-expired (protection-id uint))
  (match (map-get? protection-measures { protection-id: protection-id })
    protection-data (>= block-height (get expires-at protection-data))
    true
  )
)
