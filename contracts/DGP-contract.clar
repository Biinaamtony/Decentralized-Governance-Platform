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