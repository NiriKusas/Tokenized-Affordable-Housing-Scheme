(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-milestone-not-ready (err u106))
(define-constant err-unit-not-available (err u107))

(define-data-var next-unit-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var dao-fund uint u0)

(define-map housing-units
  { unit-id: uint }
  {
    owner: principal,
    total-tokens: uint,
    available-tokens: uint,
    rent-per-token: uint,
    construction-status: (string-ascii 20),
    monthly-rent: uint,
    is-available: bool
  }
)

(define-map token-ownership
  { unit-id: uint, owner: principal }
  { tokens: uint }
)

(define-map construction-milestones
  { milestone-id: uint }
  {
    unit-id: uint,
    description: (string-ascii 100),
    required-funds: uint,
    current-funds: uint,
    is-completed: bool,
    completion-date: uint
  }
)

(define-map rental-income
  { unit-id: uint, month: uint }
  {
    total-income: uint,
    distributed: bool,
    distribution-date: uint
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-public (create-housing-unit (total-tokens uint) (rent-per-token uint) (monthly-rent uint))
  (let ((unit-id (var-get next-unit-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> total-tokens u0) err-invalid-amount)
    (map-set housing-units
      { unit-id: unit-id }
      {
        owner: tx-sender,
        total-tokens: total-tokens,
        available-tokens: total-tokens,
        rent-per-token: rent-per-token,
        construction-status: "planning",
        monthly-rent: monthly-rent,
        is-available: true
      }
    )
    (var-set next-unit-id (+ unit-id u1))
    (ok unit-id)
  )
)

(define-public (buy-tokens (unit-id uint) (token-amount uint))
  (let (
    (unit (unwrap! (map-get? housing-units { unit-id: unit-id }) err-not-found))
    (cost (* token-amount (get rent-per-token unit)))
    (current-ownership (default-to { tokens: u0 } 
      (map-get? token-ownership { unit-id: unit-id, owner: tx-sender })))
  )
    (asserts! (get is-available unit) err-unit-not-available)
    (asserts! (>= (get available-tokens unit) token-amount) err-insufficient-funds)
    (asserts! (> token-amount u0) err-invalid-amount)
    
    (try! (stx-transfer? cost tx-sender (get owner unit)))
    
    (map-set housing-units
      { unit-id: unit-id }
      (merge unit { available-tokens: (- (get available-tokens unit) token-amount) })
    )
    
    (map-set token-ownership
      { unit-id: unit-id, owner: tx-sender }
      { tokens: (+ (get tokens current-ownership) token-amount) }
    )
    
    (ok token-amount)
  )
)

(define-public (create-milestone (unit-id uint) (description (string-ascii 100)) (required-funds uint))
  (let ((milestone-id (var-get next-milestone-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? housing-units { unit-id: unit-id })) err-not-found)
    (asserts! (> required-funds u0) err-invalid-amount)
    
    (map-set construction-milestones
      { milestone-id: milestone-id }
      {
        unit-id: unit-id,
        description: description,
        required-funds: required-funds,
        current-funds: u0,
        is-completed: false,
        completion-date: u0
      }
    )
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (fund-milestone (milestone-id uint) (amount uint))
  (let (
    (milestone (unwrap! (map-get? construction-milestones { milestone-id: milestone-id }) err-not-found))
    (user-balance (default-to { balance: u0 } (map-get? user-balances { user: tx-sender })))
  )
    (asserts! (>= (get balance user-balance) amount) err-insufficient-funds)
    (asserts! (not (get is-completed milestone)) err-milestone-not-ready)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set user-balances
      { user: tx-sender }
      { balance: (- (get balance user-balance) amount) }
    )
    
    (map-set construction-milestones
      { milestone-id: milestone-id }
      (merge milestone { current-funds: (+ (get current-funds milestone) amount) })
    )
    
    (var-set dao-fund (+ (var-get dao-fund) amount))
    (ok amount)
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let (
    (milestone (unwrap! (map-get? construction-milestones { milestone-id: milestone-id }) err-not-found))
    (unit-id (get unit-id milestone))
    (unit (unwrap! (map-get? housing-units { unit-id: unit-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= (get current-funds milestone) (get required-funds milestone)) err-insufficient-funds)
    (asserts! (not (get is-completed milestone)) err-milestone-not-ready)
    
    (map-set construction-milestones
      { milestone-id: milestone-id }
      (merge milestone { 
        is-completed: true,
        completion-date: stacks-block-height
      })
    )
    
    (map-set housing-units
      { unit-id: unit-id }
      (merge unit { construction-status: "in-progress" })
    )
    
    (ok true)
  )
)

(define-public (deposit-rental-income (unit-id uint) (month uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? housing-units { unit-id: unit-id })) err-not-found)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set rental-income
      { unit-id: unit-id, month: month }
      {
        total-income: amount,
        distributed: false,
        distribution-date: u0
      }
    )
    (ok amount)
  )
)

(define-public (distribute-rental-income (unit-id uint) (month uint) (token-holder principal))
  (let (
    (income (unwrap! (map-get? rental-income { unit-id: unit-id, month: month }) err-not-found))
    (unit (unwrap! (map-get? housing-units { unit-id: unit-id }) err-not-found))
    (ownership (unwrap! (map-get? token-ownership { unit-id: unit-id, owner: token-holder }) err-not-found))
    (share-percentage (/ (* (get tokens ownership) u100) (get total-tokens unit)))
    (payout (/ (* (get total-income income) share-percentage) u100))
    (current-balance (default-to { balance: u0 } (map-get? user-balances { user: token-holder })))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get distributed income)) err-unauthorized)
    (asserts! (> (get tokens ownership) u0) err-unauthorized)
    
    (map-set user-balances
      { user: token-holder }
      { balance: (+ (get balance current-balance) payout) }
    )
    
    (ok payout)
  )
)

(define-public (withdraw-balance (amount uint))
  (let (
    (user-balance (unwrap! (map-get? user-balances { user: tx-sender }) err-not-found))
  )
    (asserts! (>= (get balance user-balance) amount) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set user-balances
      { user: tx-sender }
      { balance: (- (get balance user-balance) amount) }
    )
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok amount)
  )
)

(define-public (transfer-tokens (unit-id uint) (recipient principal) (token-amount uint))
  (let (
    (sender-ownership (unwrap! (map-get? token-ownership { unit-id: unit-id, owner: tx-sender }) err-not-found))
    (recipient-ownership (default-to { tokens: u0 } 
      (map-get? token-ownership { unit-id: unit-id, owner: recipient })))
  )
    (asserts! (>= (get tokens sender-ownership) token-amount) err-insufficient-funds)
    (asserts! (> token-amount u0) err-invalid-amount)
    
    (map-set token-ownership
      { unit-id: unit-id, owner: tx-sender }
      { tokens: (- (get tokens sender-ownership) token-amount) }
    )
    
    (map-set token-ownership
      { unit-id: unit-id, owner: recipient }
      { tokens: (+ (get tokens recipient-ownership) token-amount) }
    )
    
    (ok token-amount)
  )
)

(define-public (dao-vote (proposal-id uint) (vote bool))
  (ok vote)
)

(define-read-only (get-housing-unit (unit-id uint))
  (map-get? housing-units { unit-id: unit-id })
)

(define-read-only (get-token-ownership (unit-id uint) (owner principal))
  (map-get? token-ownership { unit-id: unit-id, owner: owner })
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? construction-milestones { milestone-id: milestone-id })
)

(define-read-only (get-rental-income (unit-id uint) (month uint))
  (map-get? rental-income { unit-id: unit-id, month: month })
)

(define-read-only (get-user-balance (user principal))
  (map-get? user-balances { user: user })
)

(define-read-only (get-dao-fund)
  (var-get dao-fund)
)
