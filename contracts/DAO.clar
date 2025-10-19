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
(define-constant err-delegation-loop (err u109))
(define-constant err-insufficient-delegation (err u110))
(define-constant err-self-delegation (err u111))
(define-constant err-empty-comment (err u112))

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

(define-map delegations principal principal)

(define-map delegated-amounts principal uint)

(define-map received-delegations principal uint)

(define-map proposal-comment-counters uint uint)

(define-map proposal-comments {proposal-id: uint, comment-id: uint} {
  author: principal,
  message: (string-ascii 280),
  created-at: uint
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
    (effective-power (get-effective-voting-power tx-sender))
    (vote-key {proposal-id: proposal-id, voter: tx-sender})
  )
  (asserts! (<= stacks-block-height (get voting-ends-at proposal)) err-voting-ended)
  (asserts! (is-none (map-get? proposal-votes vote-key)) err-already-voted)
  (asserts! (> effective-power u0) err-insufficient-funds)
  
  (map-set proposal-votes vote-key {
    vote: vote-for,
    voting-power: effective-power
  })
  
  (if vote-for
    (map-set proposals proposal-id
      (merge proposal {
        votes-for: (+ (get votes-for proposal) effective-power),
        total-voters: (+ (get total-voters proposal) u1)
      }))
    (map-set proposals proposal-id
      (merge proposal {
        votes-against: (+ (get votes-against proposal) effective-power),
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

(define-public (delegate-votes (delegatee principal) (amount uint))
  (let (
    (member (unwrap! (map-get? members tx-sender) err-not-member))
    (current-delegated (default-to u0 (map-get? delegated-amounts tx-sender)))
    (voting-power (get voting-power member))
    (available-power (- voting-power current-delegated))
    (current-received (default-to u0 (map-get? received-delegations delegatee)))
    (delegatee-has-delegation (is-some (map-get? delegations delegatee)))
  )
  (asserts! (not (is-eq tx-sender delegatee)) err-self-delegation)
  (asserts! (<= amount available-power) err-insufficient-delegation)
  (asserts! (> amount u0) err-insufficient-delegation)
  (asserts! (is-member delegatee) err-not-member)
  (asserts! (not delegatee-has-delegation) err-delegation-loop)
  
  (map-set delegations tx-sender delegatee)
  (map-set delegated-amounts tx-sender (+ current-delegated amount))
  (map-set received-delegations delegatee (+ current-received amount))
  (ok true)))

(define-public (undelegate-votes (amount uint))
  (let (
    (current-delegated (default-to u0 (map-get? delegated-amounts tx-sender)))
    (delegatee (unwrap! (map-get? delegations tx-sender) err-not-member))
    (current-received (default-to u0 (map-get? received-delegations delegatee)))
  )
  (asserts! (<= amount current-delegated) err-insufficient-delegation)
  (asserts! (> amount u0) err-insufficient-delegation)
  
  (let (
    (new-delegated (- current-delegated amount))
    (new-received (- current-received amount))
  )
  (if (is-eq new-delegated u0)
    (map-delete delegations tx-sender)
    true)
  (map-set delegated-amounts tx-sender new-delegated)
  (map-set received-delegations delegatee new-received)
  (ok true))))

(define-public (revoke-delegation)
  (let (
    (current-delegated (default-to u0 (map-get? delegated-amounts tx-sender)))
    (delegatee (unwrap! (map-get? delegations tx-sender) err-not-member))
    (current-received (default-to u0 (map-get? received-delegations delegatee)))
  )
  (map-delete delegations tx-sender)
  (map-delete delegated-amounts tx-sender)
  (map-set received-delegations delegatee (- current-received current-delegated))
  (ok true)))

(define-public (add-comment (proposal-id uint) (message (string-ascii 280)))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (msg-len (len message))
    (next-id (default-to u1 (map-get? proposal-comment-counters proposal-id)))
  )
    (asserts! (> msg-len u0) err-empty-comment)
    (map-set proposal-comments {proposal-id: proposal-id, comment-id: next-id} {
      author: tx-sender,
      message: message,
      created-at: stacks-block-height
    })
    (map-set proposal-comment-counters proposal-id (+ next-id u1))
    (ok next-id)
  )
)

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
  (/ (var-get treasury-balance) u1000))

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

(define-read-only (get-delegatee (member principal))
  (map-get? delegations member))

(define-read-only (get-delegated-amount (member principal))
  (default-to u0 (map-get? delegated-amounts member)))

(define-read-only (get-received-delegation-power (delegate principal))
  (default-to u0 (map-get? received-delegations delegate)))

(define-read-only (get-effective-voting-power (member principal))
  (match (map-get? members member)
    member-data
      (let (
        (base-power (get voting-power member-data))
        (delegated-out (default-to u0 (map-get? delegated-amounts member)))
        (delegated-in (default-to u0 (map-get? received-delegations member)))
      )
      (+ (- base-power delegated-out) delegated-in))
    u0))

(define-read-only (get-comment-count (proposal-id uint))
  (let ((next-id (default-to u0 (map-get? proposal-comment-counters proposal-id))))
    (if (is-eq next-id u0) u0 (- next-id u1))
  )
)

(define-read-only (get-comment (proposal-id uint) (comment-id uint))
  (map-get? proposal-comments {proposal-id: proposal-id, comment-id: comment-id})
)

