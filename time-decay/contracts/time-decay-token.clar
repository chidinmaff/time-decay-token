;; Time Decay Token Contract
;; A token that loses value over time based on configurable decay parameters

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_TOKEN_EXPIRED (err u104))
(define-constant ERR_INVALID_DECAY_RATE (err u105))

;; Token metadata
(define-fungible-token time-decay-token)

;; Data variables
(define-data-var token-name (string-ascii 32) "Time Decay Token")
(define-data-var token-symbol (string-ascii 10) "TDT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Decay parameters
(define-data-var decay-rate uint u1000) ;; Rate of decay per block (basis points, 1000 = 10%)
(define-data-var decay-start-block uint u0) ;; Block when decay starts
(define-data-var decay-enabled bool true) ;; Whether decay is enabled
(define-data-var min-balance uint u1000000) ;; Minimum balance after decay (1 token with 6 decimals)

;; Maps
(define-map token-balances-snapshot 
  { owner: principal } 
  { balance: uint, last-update-block: uint })

;; Private functions
(define-private (max-uint (a uint) (b uint))
  (if (> a b) a b))

(define-private (get-current-balance (owner principal))
  (let ((snapshot (default-to 
                    { balance: u0, last-update-block: u0 }
                    (map-get? token-balances-snapshot { owner: owner }))))
    (if (var-get decay-enabled)
      (calculate-decayed-balance 
        (get balance snapshot)
        (get last-update-block snapshot)
        block-height)
      (ft-get-balance time-decay-token owner))))

(define-private (calculate-decayed-balance (original-balance uint) (last-block uint) (current-block uint))
  (if (< current-block (var-get decay-start-block))
    original-balance
    (let ((blocks-elapsed (- current-block (max-uint last-block (var-get decay-start-block))))
          (decay-per-block (var-get decay-rate)))
      (if (is-eq blocks-elapsed u0)
        original-balance
        (let ((decay-factor (pow u10000 blocks-elapsed))
              (remaining-factor (pow (- u10000 decay-per-block) blocks-elapsed))
              (decayed-balance (/ (* original-balance remaining-factor) decay-factor)))
          (max-uint decayed-balance (var-get min-balance)))))))

(define-private (update-balance-snapshot (owner principal))
  (let ((current-balance (get-current-balance owner)))
    (map-set token-balances-snapshot 
      { owner: owner }
      { balance: current-balance, last-update-block: block-height })
    current-balance))

;; Read-only functions
(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-balance (who principal))
  (ok (get-current-balance who)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply time-decay-token)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-read-only (get-decay-info)
  (ok {
    decay-rate: (var-get decay-rate),
    decay-start-block: (var-get decay-start-block),
    decay-enabled: (var-get decay-enabled),
    min-balance: (var-get min-balance),
    current-block: block-height
  }))

(define-read-only (calculate-future-balance (owner principal) (future-block uint))
  (let ((snapshot (default-to 
                    { balance: u0, last-update-block: u0 }
                    (map-get? token-balances-snapshot { owner: owner }))))
    (ok (calculate-decayed-balance 
          (get balance snapshot)
          (get last-update-block snapshot)
          future-block))))

;; Public functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) ERR_NOT_TOKEN_OWNER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Update balances with decay
    (let ((from-balance (update-balance-snapshot from)))
      (asserts! (>= from-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Perform the transfer
      (try! (ft-transfer? time-decay-token amount from to))
      
      ;; Update snapshots for both parties
      (update-balance-snapshot from)
      (update-balance-snapshot to)
      
      (print {
        type: "transfer",
        from: from,
        to: to,
        amount: amount,
        block: block-height,
        memo: memo
      })
      
      (ok true))))

(define-public (mint (amount uint) (to principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (ft-mint? time-decay-token amount to))
    (update-balance-snapshot to)
    
    (print {
      type: "mint",
      to: to,
      amount: amount,
      block: block-height
    })
    
    (ok true)))

(define-public (burn (amount uint) (from principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let ((current-balance (update-balance-snapshot from)))
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      (try! (ft-burn? time-decay-token amount from))
      (update-balance-snapshot from)
      
      (print {
        type: "burn",
        from: from,
        amount: amount,
        block: block-height
      })
      
      (ok true))))

;; Admin functions
(define-public (set-decay-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (asserts! (<= new-rate u10000) ERR_INVALID_DECAY_RATE) ;; Max 100% decay per block
    (var-set decay-rate new-rate)
    (ok true)))

(define-public (set-decay-start-block (start-block uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set decay-start-block start-block)
    (ok true)))

(define-public (toggle-decay)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set decay-enabled (not (var-get decay-enabled)))
    (ok true)))

(define-public (set-min-balance (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set min-balance new-min)
    (ok true)))

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set token-uri new-uri)
    (ok true)))

;; Force balance update (useful for claiming actual decay)
(define-public (update-balance (owner principal))
  (ok (update-balance-snapshot owner)))