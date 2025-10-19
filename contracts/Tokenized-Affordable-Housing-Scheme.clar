(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-milestone-not-ready (err u106))
(define-constant err-unit-not-available (err u107))
(define-constant err-voting-period-active (err u108))
(define-constant err-already-voted (err u109))
(define-constant err-request-not-approved (err u110))

(define-data-var next-unit-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var next-maintenance-request-id uint u1)
(define-data-var next-listing-id uint u1)
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

(define-map maintenance-funds
  { unit-id: uint }
  {
    total-fund: uint,
    monthly-allocation-percentage: uint
  }
)

(define-map maintenance-requests
  { request-id: uint }
  {
    unit-id: uint,
    requester: principal,
    description: (string-ascii 200),
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    is-approved: bool,
    is-executed: bool
  }
)

(define-map maintenance-votes
  { request-id: uint, voter: principal }
  { vote: bool }
)

(define-map token-listings
  { listing-id: uint }
  {
    unit-id: uint,
    seller: principal,
    tokens: uint,
    price-per-token: uint
  }
)

(define-map insurance-pools
  { unit-id: uint }
  { total-pool: uint }
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
    (map-set maintenance-funds
      { unit-id: unit-id }
      {
        total-fund: u0,
        monthly-allocation-percentage: u10
      }
    )
    (map-set insurance-pools
      { unit-id: unit-id }
      { total-pool: u0 }
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
  (let (
    (maintenance-fund (unwrap! (map-get? maintenance-funds { unit-id: unit-id }) err-not-found))
    (maintenance-allocation (/ (* amount (get monthly-allocation-percentage maintenance-fund)) u100))
    (remaining-income (- amount maintenance-allocation))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? housing-units { unit-id: unit-id })) err-not-found)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set maintenance-funds
      { unit-id: unit-id }
      (merge maintenance-fund { 
        total-fund: (+ (get total-fund maintenance-fund) maintenance-allocation) 
      })
    )
    
    (map-set rental-income
      { unit-id: unit-id, month: month }
      {
        total-income: remaining-income,
        distributed: false,
        distribution-date: u0
      }
    )
    (ok remaining-income)
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

(define-public (contribute-to-maintenance (unit-id uint) (amount uint))
  (let (
    (maintenance-fund (unwrap! (map-get? maintenance-funds { unit-id: unit-id }) err-not-found))
    (user-balance (default-to { balance: u0 } (map-get? user-balances { user: tx-sender })))
  )
    (asserts! (>= (get balance user-balance) amount) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set user-balances
      { user: tx-sender }
      { balance: (- (get balance user-balance) amount) }
    )
    
    (map-set maintenance-funds
      { unit-id: unit-id }
      (merge maintenance-fund { 
        total-fund: (+ (get total-fund maintenance-fund) amount) 
      })
    )
    
    (ok amount)
  )
)

(define-public (request-maintenance-funds (unit-id uint) (description (string-ascii 200)) (amount uint))
  (let ((request-id (var-get next-maintenance-request-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? housing-units { unit-id: unit-id })) err-not-found)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set maintenance-requests
      { request-id: request-id }
      {
        unit-id: unit-id,
        requester: tx-sender,
        description: description,
        amount: amount,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: (+ stacks-block-height u144),
        is-approved: false,
        is-executed: false
      }
    )
    (var-set next-maintenance-request-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (vote-on-maintenance (request-id uint) (vote bool))
  (let (
    (request (unwrap! (map-get? maintenance-requests { request-id: request-id }) err-not-found))
    (unit-id (get unit-id request))
    (ownership (unwrap! (map-get? token-ownership { unit-id: unit-id, owner: tx-sender }) err-not-found))
    (existing-vote (map-get? maintenance-votes { request-id: request-id, voter: tx-sender }))
  )
    (asserts! (> (get tokens ownership) u0) err-unauthorized)
    (asserts! (< stacks-block-height (get voting-deadline request)) err-voting-period-active)
    (asserts! (is-none existing-vote) err-already-voted)
    
    (map-set maintenance-votes
      { request-id: request-id, voter: tx-sender }
      { vote: vote }
    )
    
    (if vote
      (map-set maintenance-requests
        { request-id: request-id }
        (merge request { votes-for: (+ (get votes-for request) (get tokens ownership)) })
      )
      (map-set maintenance-requests
        { request-id: request-id }
        (merge request { votes-against: (+ (get votes-against request) (get tokens ownership)) })
      )
    )
    (ok vote)
  )
)

(define-public (execute-maintenance-request (request-id uint))
  (let (
    (request (unwrap! (map-get? maintenance-requests { request-id: request-id }) err-not-found))
    (unit-id (get unit-id request))
    (unit (unwrap! (map-get? housing-units { unit-id: unit-id }) err-not-found))
    (maintenance-fund (unwrap! (map-get? maintenance-funds { unit-id: unit-id }) err-not-found))
    (total-tokens (get total-tokens unit))
    (approval-threshold (/ (* total-tokens u51) u100))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get voting-deadline request)) err-voting-period-active)
    (asserts! (not (get is-executed request)) err-unauthorized)
    (asserts! (> (get votes-for request) approval-threshold) err-request-not-approved)
    (asserts! (>= (get total-fund maintenance-fund) (get amount request)) err-insufficient-funds)
    
    (map-set maintenance-funds
      { unit-id: unit-id }
      (merge maintenance-fund { 
        total-fund: (- (get total-fund maintenance-fund) (get amount request)) 
      })
    )
    
    (map-set maintenance-requests
      { request-id: request-id }
      (merge request { 
        is-approved: true,
        is-executed: true
      })
    )
    
    (ok (get amount request))
  )
)

(define-read-only (get-dao-fund)
  (var-get dao-fund)
)

(define-read-only (get-maintenance-fund (unit-id uint))
  (map-get? maintenance-funds { unit-id: unit-id })
)

(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests { request-id: request-id })
)

(define-read-only (get-maintenance-vote (request-id uint) (voter principal))
  (map-get? maintenance-votes { request-id: request-id, voter: voter })
)

(define-public (list-tokens-for-sale (unit-id uint) (tokens uint) (price-per-token uint))
  (let (
    (listing-id (var-get next-listing-id))
    (ownership (unwrap! (map-get? token-ownership { unit-id: unit-id, owner: tx-sender }) err-not-found))
  )
    (asserts! (>= (get tokens ownership) tokens) err-insufficient-funds)
    (asserts! (> tokens u0) err-invalid-amount)
    (asserts! (> price-per-token u0) err-invalid-amount)
    (map-set token-listings
      { listing-id: listing-id }
      {
        unit-id: unit-id,
        seller: tx-sender,
        tokens: tokens,
        price-per-token: price-per-token
      }
    )
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (buy-listed-tokens (listing-id uint) (tokens-to-buy uint))
  (let (
    (listing (unwrap! (map-get? token-listings { listing-id: listing-id }) err-not-found))
    (unit-id (get unit-id listing))
    (seller (get seller listing))
    (total-price (* tokens-to-buy (get price-per-token listing)))
    (buyer-ownership (default-to { tokens: u0 } (map-get? token-ownership { unit-id: unit-id, owner: tx-sender })))
    (seller-ownership (unwrap! (map-get? token-ownership { unit-id: unit-id, owner: seller }) err-not-found))
  )
    (asserts! (>= (get tokens listing) tokens-to-buy) err-insufficient-funds)
    (asserts! (> tokens-to-buy u0) err-invalid-amount)
    (try! (stx-transfer? total-price tx-sender seller))
    (map-set token-ownership
      { unit-id: unit-id, owner: tx-sender }
      { tokens: (+ (get tokens buyer-ownership) tokens-to-buy) }
    )
    (map-set token-ownership
      { unit-id: unit-id, owner: seller }
      { tokens: (- (get tokens seller-ownership) tokens-to-buy) }
    )
    (if (is-eq (- (get tokens listing) tokens-to-buy) u0)
      (map-delete token-listings { listing-id: listing-id })
      (map-set token-listings
        { listing-id: listing-id }
        (merge listing { tokens: (- (get tokens listing) tokens-to-buy) })
      )
    )
    (ok tokens-to-buy)
  )
)

(define-public (cancel-token-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? token-listings { listing-id: listing-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (map-delete token-listings { listing-id: listing-id })
    (ok true)
  )
)

(define-read-only (get-token-listing (listing-id uint))
  (map-get? token-listings { listing-id: listing-id })
)

(define-public (contribute-to-insurance (unit-id uint) (amount uint))
  (let (
    (insurance-pool (unwrap! (map-get? insurance-pools { unit-id: unit-id }) err-not-found))
    (user-balance (default-to { balance: u0 } (map-get? user-balances { user: tx-sender })))
  )
    (asserts! (>= (get balance user-balance) amount) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    (map-set user-balances
      { user: tx-sender }
      { balance: (- (get balance user-balance) amount) }
    )
    (map-set insurance-pools
      { unit-id: unit-id }
      { total-pool: (+ (get total-pool insurance-pool) amount) }
    )
    (ok amount)
  )
)

(define-read-only (get-insurance-pool (unit-id uint))
  (map-get? insurance-pools { unit-id: unit-id })
)
