;; =========================================================
;; CarbonChain Protocol
;; Decentralized Carbon Credit Verification & Trading
;; Author: Nathaniel Matthew
;; License: MIT
;; =========================================================

(define-data-var admin principal tx-sender)
(define-data-var total-credits uint u0)

;; Project structure
(define-map projects
  { id: uint }
  { owner: principal, name: (string-ascii 64), verified: bool, credits: uint }
)

;; Carbon balances
(define-map balances
  { user: principal }
  { credits: uint }
)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID (err u102))
(define-constant ERR_INSUFFICIENT (err u103))

;; Project ID counter
(define-data-var project-counter uint u0)

;; ---------------------------------------------------------
;; Register new carbon reduction project
(define-public (register-project (name (string-ascii 64)))
  (let ((new-id (+ (var-get project-counter) u1)))
    (begin
      (map-set projects { id: new-id } 
        { owner: tx-sender, name: name, verified: false, credits: u0 })
      (var-set project-counter new-id)
      (ok new-id)
    )
  )
)

;; Verify a registered project (admin only)
(define-public (verify-project (project-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((project (map-get? projects { id: project-id })))
      ;; Fixed match syntax - removed 'none' binding, now uses 4 arguments
      (match project
        p
          (begin
            (map-set projects { id: project-id }
              { owner: (get owner p), name: (get name p), verified: true, credits: (get credits p) })
            (ok "Project verified")
          )
        ERR_NOT_FOUND)
    )
  )
)

;; Mint carbon credits for a verified project
(define-public (mint-carbon-credit (project-id uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((project (map-get? projects { id: project-id })))
      (match project
        p
          (begin
            (asserts! (get verified p) ERR_INVALID)
            (map-set balances { user: (get owner p) }
              { credits: (+ (get credits (default-to { credits: u0 } (map-get? balances { user: (get owner p) }))) amount) })
            (map-set projects { id: project-id }
              { owner: (get owner p), name: (get name p), verified: true, credits: (+ (get credits p) amount) })
            (var-set total-credits (+ (var-get total-credits) amount))
            (ok "Credits minted successfully")
          )
        ERR_NOT_FOUND)
    )
  )
)

;; Transfer carbon credits
(define-public (transfer-credit (to principal) (amount uint))
  (let ((sender (map-get? balances { user: tx-sender })))
    ;; Fixed match syntax - removed 'none' binding
    (match sender
      s
        (begin
          (asserts! (>= (get credits s) amount) ERR_INSUFFICIENT)
          (map-set balances { user: tx-sender } { credits: (- (get credits s) amount) })
          (map-set balances { user: to }
            { credits: (+ (get credits (default-to { credits: u0 } (map-get? balances { user: to }))) amount) })
          (ok "Transfer successful")
        )
      ERR_INVALID)
  )
)

;; Redeem carbon credits when offsets are used
(define-public (redeem-credit (amount uint))
  (let ((balance (map-get? balances { user: tx-sender })))
    (match balance
      b
        (begin
          (asserts! (>= (get credits b) amount) ERR_INSUFFICIENT)
          (map-set balances { user: tx-sender } { credits: (- (get credits b) amount) })
          (ok "Credits redeemed")
        )
      ERR_INVALID)
  )
)

;; ---------------------------------------------------------
;; READ-ONLY FUNCTIONS
;; ---------------------------------------------------------
(define-read-only (get-balance (user principal))
  ;; Fixed match syntax - removed 'none' binding
  (match (map-get? balances { user: user })
    b (ok (get credits b))
    (ok u0))
)

(define-read-only (get-project-info (id uint))
  (map-get? projects { id: id })
)

(define-read-only (get-total-credits)
  (ok (var-get total-credits))
)
