(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-proposal-not-approved (err u106))
(define-constant err-proposal-executed (err u107))
(define-constant err-min-deposit (err u108))

(define-data-var next-proposal-id uint u1)
(define-data-var min-member-deposit uint u1000000)
(define-data-var voting-period uint u144)
(define-data-var quorum-percentage uint u30)
(define-data-var total-members uint u0)
(define-data-var treasury-balance uint u0)

(define-map members principal {
  deposit: uint,
  voting-power: uint,
  joined-at: uint
})

(define-map proposals uint {
  proposer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  amount: uint,
  recipient: principal,
  created-at: uint,
  voting-ends-at: uint,
  votes-for: uint,
  votes-against: uint,
  executed: bool,
  total-voters: uint
})

(define-map proposal-votes {proposal-id: uint, voter: principal} {
  vote: bool,
  voting-power: uint
})

(define-public (join-dao)
  (let (
    (deposit (stx-get-balance tx-sender))
    (min-deposit (var-get min-member-deposit))
  )
  (asserts! (>= deposit min-deposit) err-min-deposit)
  (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
  (var-set treasury-balance (+ (var-get treasury-balance) deposit))
  (var-set total-members (+ (var-get total-members) u1))
  (map-set members tx-sender {
    deposit: deposit,
    voting-power: (/ deposit u1000),
    joined-at: stacks-block-height
  })
  (ok true)))

(define-public (add-funds (amount uint))
  (let (
    (member (unwrap! (map-get? members tx-sender) err-not-member))
    (current-deposit (get deposit member))
  )
  (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
  (var-set treasury-balance (+ (var-get treasury-balance) amount))
  (map-set members tx-sender {
    deposit: (+ current-deposit amount),
    voting-power: (+ (get voting-power member) (/ amount u1000)),
    joined-at: (get joined-at member)
  })
  (ok true)))

(define-public (submit-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (amount uint)
  (recipient principal))
  (let (
    (proposal-id (var-get next-proposal-id))
    (member (unwrap! (map-get? members tx-sender) err-not-member))
    (voting-ends (+ stacks-block-height (var-get voting-period)))
  )
  (asserts! (<= amount (var-get treasury-balance)) err-insufficient-funds)
  (map-set proposals proposal-id {
    proposer: tx-sender,
    title: title,
    description: description,
    amount: amount,
    recipient: recipient,
    created-at: stacks-block-height,
    voting-ends-at: voting-ends,
    votes-for: u0,
    votes-against: u0,
    executed: false,
    total-voters: u0
  })
  (var-set next-proposal-id (+ proposal-id u1))
  (ok proposal-id)))

(define-public (vote (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (member (unwrap! (map-get? members tx-sender) err-not-member))
    (voting-power (get voting-power member))
    (vote-key {proposal-id: proposal-id, voter: tx-sender})
  )
  (asserts! (<= stacks-block-height (get voting-ends-at proposal)) err-voting-ended)
  (asserts! (is-none (map-get? proposal-votes vote-key)) err-already-voted)
  
  (map-set proposal-votes vote-key {
    vote: vote-for,
    voting-power: voting-power
  })
  
  (if vote-for
    (map-set proposals proposal-id
      (merge proposal {
        votes-for: (+ (get votes-for proposal) voting-power),
        total-voters: (+ (get total-voters proposal) u1)
      }))
    (map-set proposals proposal-id
      (merge proposal {
        votes-against: (+ (get votes-against proposal) voting-power),
        total-voters: (+ (get total-voters proposal) u1)
      })))
  (ok true)))

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (votes-for (get votes-for proposal))
    (votes-against (get votes-against proposal))
    (total-votes (+ votes-for votes-against))
    (amount (get amount proposal))
    (recipient (get recipient proposal))
  )
  (asserts! (> stacks-block-height (get voting-ends-at proposal)) err-voting-ended)
  (asserts! (not (get executed proposal)) err-proposal-executed)
  (asserts! (is-proposal-approved proposal-id) err-proposal-not-approved)
  
  (try! (as-contract (stx-transfer? amount tx-sender recipient)))
  (var-set treasury-balance (- (var-get treasury-balance) amount))
  
  (map-set proposals proposal-id
    (merge proposal { executed: true }))
  (ok true)))

(define-public (withdraw-membership)
  (let (
    (member (unwrap! (map-get? members tx-sender) err-not-member))
    (deposit (get deposit member))
    (share-percentage (/ (* deposit u100) (var-get treasury-balance)))
    (withdrawal-amount (/ (* (var-get treasury-balance) share-percentage) u100))
  )
  (asserts! (> withdrawal-amount u0) err-insufficient-funds)
  (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
  (var-set treasury-balance (- (var-get treasury-balance) withdrawal-amount))
  (var-set total-members (- (var-get total-members) u1))
  (map-delete members tx-sender)
  (ok withdrawal-amount)))

(define-public (update-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set voting-period new-period)
    (ok true)))

(define-public (update-min-deposit (new-deposit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-member-deposit new-deposit)
    (ok true)))

(define-public (update-quorum (new-quorum uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-quorum u100) (err u999))
    (var-set quorum-percentage new-quorum)
    (ok true)))

(define-read-only (get-member-info (member principal))
  (map-get? members member))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes {proposal-id: proposal-id, voter: voter}))

(define-read-only (get-treasury-balance)
  (var-get treasury-balance))

(define-read-only (get-total-members)
  (var-get total-members))

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id))

(define-read-only (get-voting-period)
  (var-get voting-period))

(define-read-only (get-min-deposit)
  (var-get min-member-deposit))

(define-read-only (get-quorum-percentage)
  (var-get quorum-percentage))

(define-read-only (is-member (address principal))
  (is-some (map-get? members address)))

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})))

(define-read-only (is-voting-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (<= stacks-block-height (get voting-ends-at proposal))
    false))

(define-read-only (is-proposal-approved (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
      (let (
        (votes-for (get votes-for proposal))
        (votes-against (get votes-against proposal))
        (total-votes (+ votes-for votes-against))
        (required-quorum (/ (* (get-total-voting-power) (var-get quorum-percentage)) u100))
      )
      (and 
        (>= total-votes required-quorum)
        (> votes-for votes-against)))
    false))

(define-read-only (get-total-voting-power)
  u0)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
      (if (get executed proposal)
        "executed"
        (if (> stacks-block-height (get voting-ends-at proposal))
          (if (is-proposal-approved proposal-id)
            "approved"
            "rejected")
          "active"))
    "not-found"))

(define-read-only (calculate-voting-power (deposit uint))
  (/ deposit u1000))
