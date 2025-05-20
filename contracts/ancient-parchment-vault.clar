;; Ancient Parchment Vault System
;; An immutable ledger for safeguarding ancient manuscripts and tracking their provenance

;; ===============================================
;; SYSTEM GOVERNANCE FUNDAMENTALS
;; ===============================================

(define-constant invalid-scroll-identifier-error (err u393))
(define-constant scroll-dimension-invalid-error (err u394))
(define-constant archival-privileges-error (err u395))
(define-constant scroll-authenticity-error (err u396))
(define-constant descriptor-format-error (err u397))
(define-constant scroll-archiver tx-sender)
(define-constant forbidden-access-error (err u390))
(define-constant nonexistent-scroll-error (err u391))
(define-constant scroll-already-cataloged-error (err u392))


;; ===============================================
;; PRIMARY DATA REPOSITORIES
;; ===============================================

(define-data-var parchment-counter uint u0)
(define-map examination-permissions
  { parchment-id: uint, scholar: principal }
  { examination-granted: bool }
)
(define-map scroll-repository
  { parchment-id: uint }
  {
    scroll-title: (string-ascii 64),
    scroll-keeper: principal,
    parchment-dimensions: uint,
    cataloging-epoch: uint,
    origin-narrative: (string-ascii 128),
    subject-descriptors: (list 10 (string-ascii 32))
  }
)

;; ===============================================
;; VERIFICATION UTILITY MECHANISMS
;; ===============================================


;; Validates descriptor nomenclature adheres to archival standards
(define-private (is-valid-descriptor (descriptor (string-ascii 32)))
  (and
    (> (len descriptor) u0)
    (< (len descriptor) u33)
  )
)

;; Ensures complete descriptor set conforms to cataloging requirements
(define-private (validate-descriptor-collection (descriptors (list 10 (string-ascii 32))))
  (and
    (> (len descriptors) u0)
    (<= (len descriptors) u10)
    (is-eq (len (filter is-valid-descriptor descriptors)) (len descriptors))
  )
)
;; Confirms presence in manuscript collection
(define-private (scroll-cataloged? (parchment-id uint))
  (is-some (map-get? scroll-repository { parchment-id: parchment-id }))
)

;; Validates stewardship claim over manuscript
(define-private (is-keeper-of (parchment-id uint) (claimant principal))
  (match (map-get? scroll-repository { parchment-id: parchment-id })
    scroll-data (is-eq (get scroll-keeper scroll-data) claimant)
    false
  )
)

;; Determines physical dimensions of manuscript
(define-private (get-parchment-dimensions (parchment-id uint))
  (default-to u0
    (get parchment-dimensions
      (map-get? scroll-repository { parchment-id: parchment-id })
    )
  )
)


;; ===============================================
;; MANUSCRIPT CURATION OPERATIONS
;; ===============================================

;; Introduces newly discovered manuscript to repository
(define-public (catalog-ancient-parchment 
  (scroll-name (string-ascii 64)) 
  (dimensions uint) 
  (provenance (string-ascii 128)) 
  (subject-areas (list 10 (string-ascii 32)))
)
  (let
    (
      (new-parchment-id (+ (var-get parchment-counter) u1))
    )
    ;; Archival standards enforcement
    (asserts! (> (len scroll-name) u0) invalid-scroll-identifier-error)
    (asserts! (< (len scroll-name) u65) invalid-scroll-identifier-error)
    (asserts! (> dimensions u0) scroll-dimension-invalid-error)
    (asserts! (< dimensions u1000000000) scroll-dimension-invalid-error)
    (asserts! (> (len provenance) u0) invalid-scroll-identifier-error)
    (asserts! (< (len provenance) u129) invalid-scroll-identifier-error)
    (asserts! (validate-descriptor-collection subject-areas) descriptor-format-error)

    ;; Create permanent archival record with comprehensive metadata
    (map-insert scroll-repository
      { parchment-id: new-parchment-id }
      {
        scroll-title: scroll-name,
        scroll-keeper: tx-sender,
        parchment-dimensions: dimensions,
        cataloging-epoch: block-height,
        origin-narrative: provenance,
        subject-descriptors: subject-areas
      }
    )

    ;; Grant initial examination rights to cataloger
    (map-insert examination-permissions
      { parchment-id: new-parchment-id, scholar: tx-sender }
      { examination-granted: true }
    )

    ;; Update repository metrics
    (var-set parchment-counter new-parchment-id)
    (ok new-parchment-id)
  )
)

;; Applies scholarly corrections to existing manuscript record
(define-public (revise-parchment-record 
  (parchment-id uint) 
  (amended-title (string-ascii 64)) 
  (amended-dimensions uint) 
  (amended-provenance (string-ascii 128)) 
  (amended-subject-areas (list 10 (string-ascii 32)))
)
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
    )
    ;; Validate manuscript existence and curatorial authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! (is-eq (get scroll-keeper scroll-data) tx-sender) archival-privileges-error)

    ;; Validate scholarly amendments meet archival standards
    (asserts! (> (len amended-title) u0) invalid-scroll-identifier-error)
    (asserts! (< (len amended-title) u65) invalid-scroll-identifier-error)
    (asserts! (> amended-dimensions u0) scroll-dimension-invalid-error)
    (asserts! (< amended-dimensions u1000000000) scroll-dimension-invalid-error)
    (asserts! (> (len amended-provenance) u0) invalid-scroll-identifier-error)
    (asserts! (< (len amended-provenance) u129) invalid-scroll-identifier-error)
    (asserts! (validate-descriptor-collection amended-subject-areas) descriptor-format-error)

    ;; Update archival record with revised scholarly assessment
    (map-set scroll-repository
      { parchment-id: parchment-id }
      (merge scroll-data { 
        scroll-title: amended-title, 
        parchment-dimensions: amended-dimensions, 
        origin-narrative: amended-provenance, 
        subject-descriptors: amended-subject-areas 
      })
    )
    (ok true)
  )
)

;; Reassigns stewardship of manuscript to another curator
(define-public (reassign-parchment-stewardship (parchment-id uint) (new-keeper principal))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
    )
    ;; Validate manuscript exists and current keeper authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! (is-eq (get scroll-keeper scroll-data) tx-sender) archival-privileges-error)

    ;; Execute stewardship transition
    (map-set scroll-repository
      { parchment-id: parchment-id }
      (merge scroll-data { scroll-keeper: new-keeper })
    )
    (ok true)
  )
)

;; Removes manuscript from scholarly access
(define-public (withdraw-parchment-from-repository (parchment-id uint))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
    )
    ;; Validate manuscript exists and keeper authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! (is-eq (get scroll-keeper scroll-data) tx-sender) archival-privileges-error)

    ;; Remove manuscript from repository
    (map-delete scroll-repository { parchment-id: parchment-id })
    (ok true)
  )
)

;; ===============================================
;; ACCESS AND PERMISSIONS MANAGEMENT
;; ===============================================

;; Revokes scholarly access to a manuscript
(define-public (revoke-examination-privileges (parchment-id uint) (scholar principal))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
    )
    ;; Validate manuscript exists and keeper authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! (is-eq (get scroll-keeper scroll-data) tx-sender) archival-privileges-error)
    (asserts! (not (is-eq scholar tx-sender)) forbidden-access-error)

    ;; Remove examination permission
    (map-delete examination-permissions { parchment-id: parchment-id, scholar: scholar })
    (ok true)
  )
)

;; Enhances subject classification with additional scholarly perspectives
(define-public (augment-subject-classification (parchment-id uint) (supplementary-descriptors (list 10 (string-ascii 32))))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
      (existing-descriptors (get subject-descriptors scroll-data))
      (combined-descriptors (unwrap! (as-max-len? (concat existing-descriptors supplementary-descriptors) u10) descriptor-format-error))
    )
    ;; Validate manuscript exists and keeper authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! (is-eq (get scroll-keeper scroll-data) tx-sender) archival-privileges-error)

    ;; Validate supplementary descriptors meet archival standards
    (asserts! (validate-descriptor-collection supplementary-descriptors) descriptor-format-error)

    ;; Update manuscript with expanded classification
    (map-set scroll-repository
      { parchment-id: parchment-id }
      (merge scroll-data { subject-descriptors: combined-descriptors })
    )
    (ok combined-descriptors)
  )
)

;; Implements conservation restrictions to preserve fragile manuscripts
(define-public (enact-conservation-protocol (parchment-id uint))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
      (conservation-marker "CONSERVATION-PROTOCOL")
      (existing-descriptors (get subject-descriptors scroll-data))
    )
    ;; Validate manuscript exists and proper authorization
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! 
      (or 
        (is-eq tx-sender scroll-archiver)
        (is-eq (get scroll-keeper scroll-data) tx-sender)
      ) 
      forbidden-access-error
    )

    (ok true)
  )
)

;; ===============================================
;; SCHOLARLY VERIFICATION SERVICES
;; ===============================================

;; Performs comprehensive manuscript provenance verification
(define-public (verify-parchment-authenticity (parchment-id uint) (presumed-keeper principal))
  (let
    (
      (scroll-data (unwrap! (map-get? scroll-repository { parchment-id: parchment-id }) nonexistent-scroll-error))
      (current-keeper (get scroll-keeper scroll-data))
      (cataloging-height (get cataloging-epoch scroll-data))
      (has-examination-rights (default-to 
        false 
        (get examination-granted 
          (map-get? examination-permissions { parchment-id: parchment-id, scholar: tx-sender })
        )
      ))
    )
    ;; Validate manuscript exists and viewing authority
    (asserts! (scroll-cataloged? parchment-id) nonexistent-scroll-error)
    (asserts! 
      (or 
        (is-eq tx-sender current-keeper)
        has-examination-rights
        (is-eq tx-sender scroll-archiver)
      ) 
      forbidden-access-error
    )

    ;; Generate detailed authentication assessment
    (if (is-eq current-keeper presumed-keeper)
      ;; Return successful verification with provenance details
      (ok {
        authenticated: true,
        verification-block: block-height,
        repository-tenure: (- block-height cataloging-height),
        keeper-confirmation: true
      })
      ;; Return stewardship discrepancy report
      (ok {
        authenticated: false,
        verification-block: block-height,
        repository-tenure: (- block-height cataloging-height),
        keeper-confirmation: false
      })
    )
  )
)

