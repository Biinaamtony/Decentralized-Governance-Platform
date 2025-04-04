;; Decentralized Governance Platform
;; A governance system for DAOs with advanced voting mechanisms

;; Constants
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-PROPOSAL-NOT-FOUND u2)
(define-constant ERR-INVALID-STATE u3)
(define-constant ERR-INSUFFICIENT-BALANCE u4)
(define-constant ERR-ALREADY-VOTED u5)
(define-constant ERR-VOTING-CLOSED u6)
(define-constant ERR-VOTING-ACTIVE u7)
(define-constant ERR-NOT-EXECUTABLE-YET u8)
(define-constant ERR-EXECUTION-TIMELOCK-ACTIVE u9)
(define-constant ERR-PROPOSAL-EXPIRED u10)
(define-constant ERR-INSUFFICIENT-VOTING-POWER u11)
(define-constant ERR-INVALID-VOTE u12)
(define-constant ERR-DELEGATE-NOT-FOUND u13)
(define-constant ERR-CANNOT-DELEGATE-TO-SELF u14)
(define-constant ERR-DELEGATION-LOOP u15)
(define-constant ERR-INSUFFICIENT-VOTES u16)
(define-constant ERR-ALREADY-EXECUTED u17)
(define-constant ERR-TREASURY-OPERATION-FAILED u18)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Governance token contract principal
(define-data-var governance-token-contract principal tx-sender)

;; DAO configuration
(define-data-var dao-name (string-utf8 100) "Decentralized Autonomous Organization")
(define-data-var proposal-submission-threshold uint u100000000) ;; Minimum tokens to submit proposal
(define-data-var voting-period uint u144) ;; ~1 day in blocks
(define-data-var execution-timelock uint u1008) ;; ~1 week in blocks
(define-data-var proposal-expiration-period uint u10080) ;; ~10 weeks in blocks
(define-data-var proposal-approval-threshold uint u51) ;; Percentage needed to approve
(define-data-var quadratic-voting-enabled bool true)
(define-data-var max-options-per-proposal uint u10)
(define-data-var next-proposal-id uint u1)

;; Proposal status enumeration
(define-constant PROPOSAL-STATUS-PENDING u1)
(define-constant PROPOSAL-STATUS-ACTIVE u2)
(define-constant PROPOSAL-STATUS-APPROVED u3)
(define-constant PROPOSAL-STATUS-REJECTED u4)
(define-constant PROPOSAL-STATUS-EXECUTED u5)
(define-constant PROPOSAL-STATUS-EXPIRED u6)

;; Mapping for governance token balance checks
(define-read-only (get-token-balance (owner principal))
  (contract-call? (var-get governance-token-contract) get-balance owner)
)

;; Mapping for governance token votes
(define-map token-vote-power
  { owner: principal }
  { voting-power: uint }
)

;; Mapping for proposal data
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 1000),
    proposer: principal,
    status: uint,
    created-at-block: uint,
    voting-starts-at-block: uint,
    voting-ends-at-block: uint,
    execution-allowed-at-block: uint,
    expires-at-block: uint,
    payload-contract: principal,
    payload-function: (string-ascii 128),
    payload-args: (list 10 (string-utf8 100)),
    yes-votes: uint,
    no-votes: uint,
    abstain-votes: uint,
    executed-at-block: (optional uint),
    is-quadratic: bool,
    options-count: uint
  }
)

;; Mapping for proposal options when more than yes/no/abstain is needed
(define-map proposal-options
  { proposal-id: uint, option-id: uint }
  {
    option-name: (string-utf8 100),
    option-description: (string-utf8 500),
    votes: uint
  }
)

;; Mapping for votes
(define-map votes
  { proposal-id: uint, voter: principal }
  {
    option-id: uint,
    vote-power: uint,
    vote-amount: uint, ;; Original amount before quadratic calculation
    vote-time: uint
  }
)

;; Mapping for delegations
(define-map delegations
  { delegator: principal }
  { 
    delegate: principal,
    amount: uint
  }
)
;; Treasury balance
(define-data-var treasury-balance uint u0)

;; Read-only functions

;; Get governance token details
(define-read-only (get-governance-token)
  (var-get governance-token-contract)
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get proposal option
(define-read-only (get-proposal-option (proposal-id uint) (option-id uint))
  (map-get? proposal-options { proposal-id: proposal-id, option-id: option-id })
)

;; Get vote for a specific voter
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Get delegation details
(define-read-only (get-delegation (delegator principal))
  (map-get? delegations { delegator: delegator })
)

;; Calculate total voting power for a user
(define-read-only (get-total-voting-power (user principal))
  (let
    (
      (direct-power (default-to u0 (get-token-balance user)))
      (delegated-power (fold total-delegated-power-reducer (get-delegators user) u0))
    )
    (+ direct-power delegated-power)
  )
)

;; Helper to get all delegators to a specific delegate
(define-read-only (get-delegators (delegate principal))
  ;; This would require an off-chain indexer in practice
  ;; For demonstration, we return an empty list
  (list)
)

;; Fold reducer for calculating delegated power
(define-read-only (total-delegated-power-reducer (delegator principal) (total uint))
  (let
    (
      (delegation (get-delegation delegator))
    )
    (match delegation
      del (+ total (get amount del))
      total
    )
  )
)

;; Calculate quadratic vote power
(define-read-only (calculate-quadratic-vote-power (amount uint))
  ;; Square root approximation - in real contract would need more precision
  ;; For simplicity, this is a rough approximation
  (let
    (
      (sqrt-power (sqrti amount))
    )
    sqrt-power
  )
)

;; Integer square root approximation
(define-read-only (sqrti (n uint))
  (if (<= n u1)
    n
    (let
      (
        (x (/ n u2))
        (y (+ (/ n x) x))
        (z (/ y u2))
      )
      (if (< z x)
        (sqrti-iter z n)
        (sqrti-iter x n)
      )
    )
  )
)

(define-read-only (sqrti-iter (guess uint) (n uint))
  (let
    (
      (new-guess (/ (+ guess (/ n guess)) u2))
    )
    (if (or (<= (- guess new-guess) u1) (<= (- new-guess guess) u1))
      new-guess
      (sqrti-iter new-guess n)
    )
  )
)
;; Get proposal status text
(define-read-only (get-proposal-status-text (status uint))
  (match status
    PROPOSAL-STATUS-PENDING "Pending"
    PROPOSAL-STATUS-ACTIVE "Active"
    PROPOSAL-STATUS-APPROVED "Approved"
    PROPOSAL-STATUS-REJECTED "Rejected"
    PROPOSAL-STATUS-EXECUTED "Executed"
    PROPOSAL-STATUS-EXPIRED "Expired"
    "Unknown"
  )
)

;; Check if a proposal can be executed
(define-read-only (can-execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) false))
      (current-block block-height)
    )
    (and
      (is-eq (get status proposal) PROPOSAL-STATUS-APPROVED)
      (>= current-block (get execution-allowed-at-block proposal))
      (< current-block (get expires-at-block proposal))
      (is-none (get executed-at-block proposal))
    )
  )
)

;; Get treasury balance
(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

;; Public functions

;; Submit a new proposal
(define-public (submit-proposal
  (title (string-utf8 100)) 
  (description (string-utf8 1000))
  (payload-contract principal)
  (payload-function (string-ascii 128))
  (payload-args (list 10 (string-utf8 100)))
  (is-quadratic bool)
  (options-count uint)
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (user-balance (unwrap! (get-token-balance tx-sender) (err ERR-INSUFFICIENT-BALANCE)))
      (current-block block-height)
      (voting-starts-at-block (+ current-block u1))
      (voting-ends-at-block (+ voting-starts-at-block (var-get voting-period)))
      (execution-allowed-at-block (+ voting-ends-at-block (var-get execution-timelock)))
      (expires-at-block (+ execution-allowed-at-block (var-get proposal-expiration-period)))
    )
    
    ;; Check if user has enough tokens to submit proposal
    (asserts! (>= user-balance (var-get proposal-submission-threshold)) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Check if options count is valid
    (asserts! (<= options-count (var-get max-options-per-proposal)) (err ERR-INVALID-STATE))
    (asserts! (> options-count u0) (err ERR-INVALID-STATE))

     ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        status: PROPOSAL-STATUS-ACTIVE,
        created-at-block: current-block,
        voting-starts-at-block: voting-starts-at-block,
        voting-ends-at-block: voting-ends-at-block,
        execution-allowed-at-block: execution-allowed-at-block,
        expires-at-block: expires-at-block,
        payload-contract: payload-contract,
        payload-function: payload-function,
        payload-args: payload-args,
        yes-votes: u0,
        no-votes: u0,
        abstain-votes: u0,
        executed-at-block: none,
        is-quadratic: is-quadratic,
        options-count: options-count
      }
    )
    
    ;; Initialize options if more than standard yes/no/abstain
    (if (> options-count u3)
      (begin
        ;; Initialize standard options
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u1 } 
          { option-name: "Yes", option-description: "Approve the proposal", votes: u0 }
        )
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u2 } 
          { option-name: "No", option-description: "Reject the proposal", votes: u0 }
        )
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u3 } 
          { option-name: "Abstain", option-description: "Abstain from voting", votes: u0 }
        )
      )
      ;; For standard yes/no/abstain, we just rely on the counts in the proposal record
      true
    )
    
    ;; Increment proposal ID counter
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

;; Set option details when proposal has custom options
(define-public (set-proposal-option
  (proposal-id uint)
  (option-id uint)
  (option-name (string-utf8 100))
  (option-description (string-utf8 500))
)
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
    )
    
    ;; Check if caller is the proposer
    (asserts! (is-eq tx-sender (get proposer proposal)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if option id is valid
    (asserts! (<= option-id (get options-count proposal)) (err ERR-INVALID-STATE))
    (asserts! (> option-id u0) (err ERR-INVALID-STATE))
    
    ;; Check if proposal is still pending or just became active
    (asserts! (<= block-height (+ (get created-at-block proposal) u10)) (err ERR-INVALID-STATE))
    
    ;; Set option details
    (map-set proposal-options
      { proposal-id: proposal-id, option-id: option-id }
      {
        option-name: option-name,
        option-description: option-description,
        votes: u0
      }
    )
    
    (ok true)
  )
)

;; Vote on a proposal
(define-public (vote
  (proposal-id uint)
  (option-id uint)
  (vote-amount uint)
)
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
      (user-balance (unwrap! (get-token-balance tx-sender) (err ERR-INSUFFICIENT-BALANCE)))
      (voting-power (get-total-voting-power tx-sender))
      (current-block block-height)
    )
    
    ;; Check if proposal is active
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-ACTIVE) (err ERR-INVALID-STATE))
    
    ;; Check if voting period is active
    (asserts! (>= current-block (get voting-starts-at-block proposal)) (err ERR-VOTING-CLOSED))
    (asserts! (<= current-block (get voting-ends-at-block proposal)) (err ERR-VOTING-CLOSED))
    
    ;; Check if user has already voted
    (asserts! (is-none (get-vote proposal-id tx-sender)) (err ERR-ALREADY-VOTED))
    
    ;; Check if user has enough voting power
    (asserts! (>= voting-power vote-amount) (err ERR-INSUFFICIENT-VOTING-POWER))
    
    ;; Check if option is valid
    (asserts! (<= option-id (get options-count proposal)) (err ERR-INVALID-VOTE))
    (asserts! (> option-id u0) (err ERR-INVALID-VOTE))
    
    ;; Calculate vote power (quadratic or linear)
    (let
      (
        (effective-vote-power (if (get is-quadratic proposal)
                               (calculate-quadratic-vote-power vote-amount)
                               vote-amount))
      )
        ;; Record the vote
      (map-set votes
        { proposal-id: proposal-id, voter: tx-sender }
        {
          option-id: option-id,
          vote-power: effective-vote-power,
          vote-amount: vote-amount,
          vote-time: current-block
        }
      )
      
      ;; Update vote counts based on option
      (if (> (get options-count proposal) u3)
        (match (get-proposal-option proposal-id option-id)
          option 
          (map-set proposal-options
            { proposal-id: proposal-id, option-id: option-id }
            (merge option { votes: (+ (get votes option) effective-vote-power) })
          )
          (err ERR-INVALID-VOTE)
        )
        (if (is-eq option-id u1)
          ;; Yes vote
          (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { yes-votes: (+ (get yes-votes proposal) effective-vote-power) })
          )
          (if (is-eq option-id u2)
            ;; No vote
            (map-set proposals
              { proposal-id: proposal-id }
              (merge proposal { no-votes: (+ (get no-votes proposal) effective-vote-power) })
            )
            ;; Abstain vote
            (map-set proposals
              { proposal-id: proposal-id }
              (merge proposal { abstain-votes: (+ (get abstain-votes proposal) effective-vote-power) })
            )
          )
        )
      )
      
      (ok effective-vote-power)
    )
  )
)

;; Delegate voting power to another address
(define-public (delegate-to (delegate-to principal))
  (let
    (
      (user-balance (unwrap! (get-token-balance tx-sender) (err ERR-INSUFFICIENT-BALANCE)))
    )
    
    ;; Check not delegating to self
    (asserts! (not (is-eq tx-sender delegate-to)) (err ERR-CANNOT-DELEGATE-TO-SELF))
    
    ;; Check for delegation loops (simplified - a full implementation would need to check entire chains)
    (match (get-delegation delegate-to)
      del (asserts! (not (is-eq (get delegate del) tx-sender)) (err ERR-DELEGATION-LOOP))
      true
    )
    
    ;; Set delegation
    (map-set delegations
      { delegator: tx-sender }
      {
        delegate: delegate-to,
        amount: user-balance
      }
    )
    
    (ok true)
  )
)

;; Remove delegation
(define-public (remove-delegation)
  (map-delete delegations { delegator: tx-sender })
  (ok true)
)

;; Close voting on a proposal and determine the outcome
(define-public (close-voting (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
      (current-block block-height)
    )
    
    ;; Check if proposal is active
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-ACTIVE) (err ERR-INVALID-STATE))
    
    ;; Check if voting period has ended
    (asserts! (> current-block (get voting-ends-at-block proposal)) (err ERR-VOTING-ACTIVE))
    
    ;; Calculate outcome
    (let
      (
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (yes-percentage (if (> total-votes u0)
                         (/ (* (get yes-votes proposal) u100) total-votes)
                         u0))
        (new-status (if (>= yes-percentage (var-get proposal-approval-threshold))
                     PROPOSAL-STATUS-APPROVED
                     PROPOSAL-STATUS-REJECTED))
      )
      
      ;; Check minimum votes requirement (could add a separate threshold)
      (asserts! (> total-votes u0) (err ERR-INSUFFICIENT-VOTES))
      
      ;; Update proposal status
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { status: new-status })
      )
      
      (ok new-status)
    )
  )
)

;; Execute an approved proposal
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
      (current-block block-height)
    )
    
    ;; Check if proposal is approved
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-APPROVED) (err ERR-INVALID-STATE))
    
    ;; Check if timelock has passed
    (asserts! (>= current-block (get execution-allowed-at-block proposal)) (err ERR-EXECUTION-TIMELOCK-ACTIVE))
    
    ;; Check if proposal hasn't expired
    (asserts! (< current-block (get expires-at-block proposal)) (err ERR-PROPOSAL-EXPIRED))
    
    ;; Check if proposal hasn't already been executed
    (asserts! (is-none (get executed-at-block proposal)) (err ERR-ALREADY-EXECUTED))
    
    ;; Execute proposal by calling the specified contract function
    ;; Note: In an actual implementation, this would use dynamic contract calls
    ;; For this example, we're just registering that execution was attempted
    
    ;; Update proposal as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        status: PROPOSAL-STATUS-EXECUTED,
        executed-at-block: (some current-block)
      })
    )
    
    (ok true)
  )
)

;; Treasury functions

;; Deposit tokens to the treasury
(define-public (deposit-to-treasury (amount uint))
  (let
    (
      (current-balance (var-get treasury-balance))
    )
    
    ;; Transfer tokens from sender to contract
    (try! (contract-call? (var-get governance-token-contract) transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update treasury balance
    (var-set treasury-balance (+ current-balance amount))
    
    (ok true)
  )
)

;; Withdraw tokens from treasury (only via successful proposal)
(define-public (withdraw-from-treasury (amount uint) (recipient principal) (proposal-id uint))
  (let
    (
      (current-balance (var-get treasury-balance))
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
    )
    
    ;; Only contract itself can call this (from a proposal execution)
    (asserts! (is-eq tx-sender (as-contract tx-sender)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if proposal is executed
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-EXECUTED) (err ERR-INVALID-STATE))
    
    ;; Check if treasury has enough balance
    (asserts! (>= current-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Transfer tokens from contract to recipient
    (try! (as-contract (contract-call? (var-get governance-token-contract) transfer amount tx-sender recipient none)))
    
    ;; Update treasury balance
    (var-set treasury-balance (- current-balance amount))
    
    (ok true)
  )
)

;; Administrative functions

;; Update governance token contract (only owner)
(define-public (update-governance-token (new-token-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set governance-token-contract new-token-contract)
    (ok true)
  )
)

;; Update DAO parameters (only owner)
(define-public (update-dao-parameters
  (new-dao-name (string-utf8 100))
  (new-proposal-submission-threshold uint)
  (new-voting-period uint)
  (new-execution-timelock uint)
  (new-proposal-expiration-period uint)
  (new-proposal-approval-threshold uint)
  (new-quadratic-voting-enabled bool)
  (new-max-options-per-proposal uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    (var-set dao-name new-dao-name)
    (var-set proposal-submission-threshold new-proposal-submission-threshold)
    (var-set voting-period new-voting-period)
    (var-set execution-timelock new-execution-timelock)
    (var-set proposal-expiration-period new-proposal-expiration-period)
    (var-set proposal-approval-threshold new-proposal-approval-threshold)
    (var-set quadratic-voting-enabled new-quadratic-voting-enabled)
    (var-set max-options-per-proposal new-max-options-per-proposal)
    
    (ok true)
  )
)

;; Transfer ownership (only owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)