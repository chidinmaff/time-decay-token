;; Time Decay Token Factory Contract
;; Factory contract for creating and managing multiple time-decay tokens

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u200))
(define-constant ERR_TOKEN_NOT_FOUND (err u201))
(define-constant ERR_TOKEN_ALREADY_EXISTS (err u202))
(define-constant ERR_INVALID_PARAMETERS (err u203))
(define-constant ERR_UNAUTHORIZED (err u204))

;; Data variables
(define-data-var next-token-id uint u1)
(define-data-var factory-fee uint u1000000) ;; 1 STX fee for token creation

;; Token registry
(define-map token-registry
  { token-id: uint }
  {
    contract-address: principal,
    creator: principal,
    name: (string-ascii 32),
    symbol: (string-ascii 10),
    created-block: uint,
    decay-rate: uint,
    decay-start-block: uint
  })

(define-map creator-tokens
  { creator: principal }
  { token-ids: (list 100 uint) })

(define-map token-stats
  { token-id: uint }
  {
    total-minted: uint,
    total-burned: uint,
    total-transfers: uint,
    last-activity-block: uint
  })

;; Events data
(define-map token-events
  { token-id: uint, event-id: uint }
  {
    event-type: (string-ascii 20),
    principal: principal,
    amount: uint,
    block-height: uint,
    data: (optional (string-utf8 256))
  })

(define-map token-event-counters
  { token-id: uint }
  { event-count: uint })

;; Read-only functions
(define-read-only (get-token-info (token-id uint))
  (map-get? token-registry { token-id: token-id }))

(define-read-only (get-tokens-by-creator (creator principal))
  (default-to 
    { token-ids: (list) }
    (map-get? creator-tokens { creator: creator })))

(define-read-only (get-token-stats (token-id uint))
  (default-to
    { total-minted: u0, total-burned: u0, total-transfers: u0, last-activity-block: u0 }
    (map-get? token-stats { token-id: token-id })))

(define-read-only (get-factory-info)
  {
    next-token-id: (var-get next-token-id),
    factory-fee: (var-get factory-fee),
    contract-owner: CONTRACT_OWNER,
    current-block: block-height
  })

(define-read-only (get-token-event (token-id uint) (event-id uint))
  (map-get? token-events { token-id: token-id, event-id: event-id }))

(define-read-only (get-token-event-count (token-id uint))
  (default-to 
    { event-count: u0 }
    (map-get? token-event-counters { token-id: token-id })))

(define-read-only (calculate-decay-preview (initial-amount uint) (decay-rate uint) (blocks-elapsed uint))
  (if (is-eq blocks-elapsed u0)
    initial-amount
    (let ((decay-factor (pow u10000 blocks-elapsed))
          (remaining-factor (pow (- u10000 decay-rate) blocks-elapsed)))
      (/ (* initial-amount remaining-factor) decay-factor))))

;; Private functions
(define-private (update-token-stats (token-id uint) (event-type (string-ascii 20)) (amount uint))
  (let ((current-stats (get-token-stats token-id)))
    (map-set token-stats
      { token-id: token-id }
      (if (is-eq event-type "mint")
        { 
          total-minted: (+ (get total-minted current-stats) amount), 
          total-burned: (get total-burned current-stats),
          total-transfers: (get total-transfers current-stats),
          last-activity-block: block-height 
        }
        (if (is-eq event-type "burn")
          { 
            total-minted: (get total-minted current-stats),
            total-burned: (+ (get total-burned current-stats) amount), 
            total-transfers: (get total-transfers current-stats),
            last-activity-block: block-height 
          }
          (if (is-eq event-type "transfer")
            { 
              total-minted: (get total-minted current-stats),
              total-burned: (get total-burned current-stats),
              total-transfers: (+ (get total-transfers current-stats) u1), 
              last-activity-block: block-height 
            }
            { 
              total-minted: (get total-minted current-stats),
              total-burned: (get total-burned current-stats),
              total-transfers: (get total-transfers current-stats),
              last-activity-block: block-height 
            }))))))

(define-private (log-token-event (token-id uint) (event-type (string-ascii 20)) (principal principal) (amount uint) (data (optional (string-utf8 256))))
  (let ((event-counter (get-token-event-count token-id))
        (event-id (get event-count event-counter)))
    (map-set token-events
      { token-id: token-id, event-id: event-id }
      {
        event-type: event-type,
        principal: principal,
        amount: amount,
        block-height: block-height,
        data: data
      })
    (map-set token-event-counters
      { token-id: token-id }
      { event-count: (+ event-id u1) })
    event-id))

(define-private (add-token-to-creator (creator principal) (token-id uint))
  (let ((current-tokens (get token-ids (get-tokens-by-creator creator))))
    (if (< (len current-tokens) u100)
      (map-set creator-tokens
        { creator: creator }
        { token-ids: (unwrap-panic (as-max-len? (append current-tokens token-id) u100)) })
      false)))

;; Public functions
(define-public (create-decay-token 
  (name (string-ascii 32))
  (symbol (string-ascii 10))
  (decay-rate uint)
  (decay-start-block uint))
  (let ((token-id (var-get next-token-id))
        (creator tx-sender))
    
    ;; Validate parameters
    (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len symbol) u0) ERR_INVALID_PARAMETERS)
    (asserts! (<= decay-rate u10000) ERR_INVALID_PARAMETERS) ;; Max 100% per block
    (asserts! (>= decay-start-block block-height) ERR_INVALID_PARAMETERS)
    
    ;; Collect factory fee (if applicable)
    (if (> (var-get factory-fee) u0)
      (try! (stx-transfer? (var-get factory-fee) creator CONTRACT_OWNER))
      true)
    
    ;; Register the token
    (map-set token-registry
      { token-id: token-id }
      {
        contract-address: (as-contract tx-sender), ;; This would be the deployed token contract
        creator: creator,
        name: name,
        symbol: symbol,
        created-block: block-height,
        decay-rate: decay-rate,
        decay-start-block: decay-start-block
      })
    
    ;; Add to creator's token list
    (add-token-to-creator creator token-id)
    
    ;; Initialize stats
    (map-set token-stats
      { token-id: token-id }
      { total-minted: u0, total-burned: u0, total-transfers: u0, last-activity-block: block-height })
    
    ;; Initialize event counter
    (map-set token-event-counters
      { token-id: token-id }
      { event-count: u0 })
    
    ;; Log creation event
    (log-token-event token-id "created" creator u0 none)
    
    ;; Increment next token ID
    (var-set next-token-id (+ token-id u1))
    
    (print {
      type: "token-created",
      token-id: token-id,
      creator: creator,
      name: name,
      symbol: symbol,
      decay-rate: decay-rate,
      decay-start-block: decay-start-block,
      block: block-height
    })
    
    (ok token-id)))

(define-public (register-token-activity (token-id uint) (event-type (string-ascii 20)) (amount uint) (principal principal))
  ;; This would typically be called by the token contract itself
  ;; For security, you might want to implement proper authorization
  (begin
    (asserts! (is-some (get-token-info token-id)) ERR_TOKEN_NOT_FOUND)
    
    (update-token-stats token-id event-type amount)
    (log-token-event token-id event-type principal amount none)
    
    (ok true)))

;; Admin functions
(define-public (set-factory-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set factory-fee new-fee)
    (ok true)))

(define-public (withdraw-fees)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (let ((contract-balance (stx-get-balance (as-contract tx-sender))))
      (if (> contract-balance u0)
        (as-contract (stx-transfer? contract-balance tx-sender CONTRACT_OWNER))
        (ok true)))))

;; Utility functions
(define-public (batch-get-tokens (token-ids (list 20 uint)))
  (ok (map get-token-info token-ids)))

(define-private (is-token-active-since (token-id uint))
  (let ((stats (get-token-stats token-id)))
    (> (get last-activity-block stats) u0))) ;; This would use the min-activity-block parameter in a real implementation