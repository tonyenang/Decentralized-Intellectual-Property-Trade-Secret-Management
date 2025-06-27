;; Secret Identification Contract
;; Manages trade secret identification and registration

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-ALREADY-EXISTS (err u201))
(define-constant ERR-NOT-FOUND (err u202))
(define-constant ERR-INVALID-DATA (err u203))

;; Data Variables
(define-data-var next-secret-id uint u1)

;; Data Maps
(define-map trade-secrets
  { secret-id: uint }
  {
    owner: principal,
    title: (string-ascii 100),
    category: (string-ascii 50),
    classification: (string-ascii 30),
    registered-at: uint,
    status: (string-ascii 20),
    hash: (buff 32)
  }
)

(define-map secret-metadata
  { secret-id: uint }
  {
    description: (string-ascii 500),
    keywords: (string-ascii 200),
    industry: (string-ascii 50),
    value-estimate: uint
  }
)

(define-map owner-secrets
  { owner: principal, secret-id: uint }
  { active: bool }
)

;; Public Functions

;; Register a new trade secret
(define-public (register-secret
  (title (string-ascii 100))
  (category (string-ascii 50))
  (classification (string-ascii 30))
  (description (string-ascii 500))
  (keywords (string-ascii 200))
  (industry (string-ascii 50))
  (value-estimate uint)
  (content-hash (buff 32))
)
  (let ((secret-id (var-get next-secret-id)))
    (asserts! (> (len title) u0) ERR-INVALID-DATA)
    (asserts! (> (len category) u0) ERR-INVALID-DATA)

    (map-set trade-secrets
      { secret-id: secret-id }
      {
        owner: tx-sender,
        title: title,
        category: category,
        classification: classification,
        registered-at: block-height,
        status: "active",
        hash: content-hash
      }
    )

    (map-set secret-metadata
      { secret-id: secret-id }
      {
        description: description,
        keywords: keywords,
        industry: industry,
        value-estimate: value-estimate
      }
    )

    (map-set owner-secrets
      { owner: tx-sender, secret-id: secret-id }
      { active: true }
    )

    (var-set next-secret-id (+ secret-id u1))
    (ok secret-id)
  )
)

;; Update secret status
(define-public (update-secret-status (secret-id uint) (new-status (string-ascii 20)))
  (let ((secret-data (unwrap! (map-get? trade-secrets { secret-id: secret-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner secret-data)) ERR-UNAUTHORIZED)

    (map-set trade-secrets
      { secret-id: secret-id }
      (merge secret-data { status: new-status })
    )

    (ok true)
  )
)

;; Update secret metadata
(define-public (update-metadata
  (secret-id uint)
  (description (string-ascii 500))
  (keywords (string-ascii 200))
  (industry (string-ascii 50))
  (value-estimate uint)
)
  (let ((secret-data (unwrap! (map-get? trade-secrets { secret-id: secret-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner secret-data)) ERR-UNAUTHORIZED)

    (map-set secret-metadata
      { secret-id: secret-id }
      {
        description: description,
        keywords: keywords,
        industry: industry,
        value-estimate: value-estimate
      }
    )

    (ok true)
  )
)

;; Transfer secret ownership
(define-public (transfer-ownership (secret-id uint) (new-owner principal))
  (let ((secret-data (unwrap! (map-get? trade-secrets { secret-id: secret-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner secret-data)) ERR-UNAUTHORIZED)

    (map-set trade-secrets
      { secret-id: secret-id }
      (merge secret-data { owner: new-owner })
    )

    (map-set owner-secrets
      { owner: tx-sender, secret-id: secret-id }
      { active: false }
    )

    (map-set owner-secrets
      { owner: new-owner, secret-id: secret-id }
      { active: true }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get trade secret by ID
(define-read-only (get-secret (secret-id uint))
  (map-get? trade-secrets { secret-id: secret-id })
)

;; Get secret metadata
(define-read-only (get-metadata (secret-id uint))
  (map-get? secret-metadata { secret-id: secret-id })
)

;; Check if user owns secret
(define-read-only (owns-secret (owner principal) (secret-id uint))
  (default-to false
    (get active (map-get? owner-secrets { owner: owner, secret-id: secret-id }))
  )
)

;; Get secret hash for verification
(define-read-only (get-secret-hash (secret-id uint))
  (match (map-get? trade-secrets { secret-id: secret-id })
    secret-data (some (get hash secret-data))
    none
  )
)
