(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VOTED (err u102))
(define-constant ERR_VOTING_ENDED (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u105))
(define-constant ERR_ALREADY_MEMBER (err u106))
(define-constant ERR_NOT_MEMBER (err u107))
(define-constant ERR_INVALID_AMOUNT (err u108))
(define-constant ERR_NOT_MEMBER_REP (err u200))
(define-constant ERR_INVALID_REPUTATION (err u201))

(define-constant ERR_MILESTONE_NOT_FOUND (err u300))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u301))
(define-constant ERR_MILESTONE_DEADLINE_PASSED (err u302))

(define-constant ERR_COLLABORATION_NOT_FOUND (err u400))
(define-constant ERR_NOT_TEAM_LEAD (err u401))
(define-constant ERR_INVALID_PERCENTAGE (err u402))
(define-constant ERR_ALREADY_COLLABORATOR (err u403))
(define-constant ERR_TEAM_FULL (err u404))

(define-data-var collaboration-counter uint u0)

(define-data-var milestone-counter uint u0)

(define-data-var proposal-counter uint u0)
(define-data-var member-counter uint u0)

(define-map members principal bool)
(define-map member-voting-power principal uint)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-amount: uint,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    status: (string-ascii 20),
    executed: bool
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map research-submissions
  uint
  {
    proposal-id: uint,
    researcher: principal,
    submission-hash: (string-ascii 64),
    peer-reviews: uint,
    approved-reviews: uint,
    submitted-at: uint
  }
)

(define-map peer-reviews
  { submission-id: uint, reviewer: principal }
  {
    score: uint,
    review-hash: (string-ascii 64),
    submitted-at: uint
  }
)

(define-public (join-dao (stake-amount uint))
  (let
    (
      (sender tx-sender)
      (is-member (default-to false (map-get? members sender)))
    )
    (asserts! (not is-member) ERR_ALREADY_MEMBER)
    (asserts! (> stake-amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? stake-amount sender (as-contract tx-sender)))
    (map-set members sender true)
    (map-set member-voting-power sender stake-amount)
    (var-set member-counter (+ (var-get member-counter) u1))
    (ok true)
  )
)

(define-public (submit-proposal (title (string-ascii 100)) (description (string-ascii 500)) (funding-amount uint))
  (let
    (
      (sender tx-sender)
      (proposal-id (+ (var-get proposal-counter) u1))
      (is-member (default-to false (map-get? members sender)))
      (voting-deadline (+ stacks-block-height u144))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (asserts! (> funding-amount u0) ERR_INVALID_AMOUNT)
    (map-set proposals proposal-id
      {
        proposer: sender,
        title: title,
        description: description,
        funding-amount: funding-amount,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: voting-deadline,
        status: "voting",
        executed: false
      }
    )
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let
    (
      (sender tx-sender)
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (is-member (default-to false (map-get? members sender)))
      (voting-power (default-to u0 (map-get? member-voting-power sender)))
      (has-voted (is-some (map-get? proposal-votes { proposal-id: proposal-id, voter: sender })))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (asserts! (not has-voted) ERR_ALREADY_VOTED)
    (asserts! (<= stacks-block-height (get voting-deadline proposal)) ERR_VOTING_ENDED)
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: sender }
      { vote: vote-for, voting-power: voting-power }
    )
    (if vote-for
      (map-set proposals proposal-id
        (merge proposal { votes-for: (+ (get votes-for proposal) voting-power) })
      )
      (map-set proposals proposal-id
        (merge proposal { votes-against: (+ (get votes-against proposal) voting-power) })
      )
    )
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (total-votes (+ votes-for votes-against))
    )
    (asserts! (> stacks-block-height (get voting-deadline proposal)) ERR_VOTING_ENDED)
    (if (and (> total-votes u0) (> votes-for votes-against))
      (begin
        (map-set proposals proposal-id
          (merge proposal { status: "approved" })
        )
        (ok "approved")
      )
      (begin
        (map-set proposals proposal-id
          (merge proposal { status: "rejected" })
        )
        (ok "rejected")
      )
    )
  )
)

(define-public (execute-funding (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (funding-amount (get funding-amount proposal))
      (proposer (get proposer proposal))
      (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (>= contract-balance funding-amount) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? funding-amount tx-sender proposer)))
    (map-set proposals proposal-id
      (merge proposal { executed: true })
    )
    (ok true)
  )
)

(define-public (submit-research (proposal-id uint) (submission-hash (string-ascii 64)))
  (let
    (
      (sender tx-sender)
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (submission-id (+ proposal-id u1000))
    )
    (asserts! (is-eq sender (get proposer proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (get executed proposal) ERR_PROPOSAL_NOT_APPROVED)
    (map-set research-submissions submission-id
      {
        proposal-id: proposal-id,
        researcher: sender,
        submission-hash: submission-hash,
        peer-reviews: u0,
        approved-reviews: u0,
        submitted-at: stacks-block-height
      }
    )
    (ok submission-id)
  )
)

(define-public (submit-peer-review (submission-id uint) (score uint) (review-hash (string-ascii 64)))
  (let
    (
      (sender tx-sender)
      (submission (unwrap! (map-get? research-submissions submission-id) ERR_PROPOSAL_NOT_FOUND))
      (is-member (default-to false (map-get? members sender)))
      (has-reviewed (is-some (map-get? peer-reviews { submission-id: submission-id, reviewer: sender })))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (asserts! (not has-reviewed) ERR_ALREADY_VOTED)
    (asserts! (<= score u10) ERR_INVALID_AMOUNT)
    (map-set peer-reviews
      { submission-id: submission-id, reviewer: sender }
      {
        score: score,
        review-hash: review-hash,
        submitted-at: stacks-block-height
      }
    )
    (let
      (
        (new-review-count (+ (get peer-reviews submission) u1))
        (new-approved-count (if (>= score u7) (+ (get approved-reviews submission) u1) (get approved-reviews submission)))
      )
      (map-set research-submissions submission-id
        (merge submission {
          peer-reviews: new-review-count,
          approved-reviews: new-approved-count
        })
      )
    )
    (ok true)
  )
)

(define-public (increase-stake (additional-amount uint))
  (let
    (
      (sender tx-sender)
      (is-member (default-to false (map-get? members sender)))
      (current-power (default-to u0 (map-get? member-voting-power sender)))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (asserts! (> additional-amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? additional-amount sender (as-contract tx-sender)))
    (map-set member-voting-power sender (+ current-power additional-amount))
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-member-info (member principal))
  {
    is-member: (default-to false (map-get? members member)),
    voting-power: (default-to u0 (map-get? member-voting-power member))
  }
)

(define-read-only (get-research-submission (submission-id uint))
  (map-get? research-submissions submission-id)
)

(define-read-only (get-peer-review (submission-id uint) (reviewer principal))
  (map-get? peer-reviews { submission-id: submission-id, reviewer: reviewer })
)

(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-dao-stats)
  {
    total-members: (var-get member-counter),
    total-proposals: (var-get proposal-counter),
    contract-balance: (stx-get-balance (as-contract tx-sender))
  }
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)



(define-map member-reputation principal uint)
(define-map reputation-history
  { member: principal, action-type: (string-ascii 20), timestamp: uint }
  { points: uint, details: (string-ascii 100) }
)

(define-data-var reputation-counter uint u0)

(define-private (award-reputation (member principal) (points uint) (action-type (string-ascii 20)) (details (string-ascii 100)))
  (let
    (
      (current-rep (default-to u0 (map-get? member-reputation member)))
      (counter (var-get reputation-counter))
    )
    (map-set member-reputation member (+ current-rep points))
    (map-set reputation-history
      { member: member, action-type: action-type, timestamp: stacks-block-height }
      { points: points, details: details }
    )
    (var-set reputation-counter (+ counter u1))
    (ok true)
  )
)

(define-public (award-proposal-reputation (member principal))
  (let
    (
      (is-member (default-to false (map-get? members member)))
    )
    (asserts! is-member ERR_NOT_MEMBER_REP)
    (award-reputation member u50 "proposal-approved" "Research proposal approved")
  )
)

(define-public (award-review-reputation (member principal) (review-score uint))
  (let
    (
      (is-member (default-to false (map-get? members member)))
      (rep-points (if (>= review-score u8) u20 u10))
    )
    (asserts! is-member ERR_NOT_MEMBER_REP)
    (asserts! (<= review-score u10) ERR_INVALID_REPUTATION)
    (award-reputation member rep-points "peer-review" "Quality peer review submitted")
  )
)

(define-public (award-participation-reputation (member principal))
  (let
    (
      (is-member (default-to false (map-get? members member)))
    )
    (asserts! is-member ERR_NOT_MEMBER_REP)
    (award-reputation member u5 "participation" "Active DAO participation")
  )
)

(define-read-only (get-member-reputation (member principal))
  (default-to u0 (map-get? member-reputation member))
)

(define-read-only (get-reputation-history (member principal) (action-type (string-ascii 20)) (timestamp uint))
  (map-get? reputation-history { member: member, action-type: action-type, timestamp: timestamp })
)

(define-read-only (get-reputation-tier (member principal))
  (let
    (
      (rep-score (get-member-reputation member))
    )
    (if (>= rep-score u500)
      "expert"
      (if (>= rep-score u200)
        "advanced"
        (if (>= rep-score u50)
          "intermediate"
          "beginner"
        )
      )
    )
  )
)

(define-read-only (get-reputation-stats)
  {
    total-reputation-entries: (var-get reputation-counter)
  }
)

(define-map research-milestones
  uint
  {
    proposal-id: uint,
    researcher: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    deadline: uint,
    funding-percentage: uint,
    completed: bool,
    completion-evidence: (string-ascii 64),
    completed-at: uint
  }
)

(define-map proposal-milestones
  uint
  { milestone-ids: (list 10 uint), total-milestones: uint }
)

(define-public (create-milestone (proposal-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (deadline uint) (funding-percentage uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (milestone-id (+ (var-get milestone-counter) u1))
      (current-milestones (default-to { milestone-ids: (list), total-milestones: u0 } (map-get? proposal-milestones proposal-id)))
    )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status proposal) "approved") ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (> deadline stacks-block-height) ERR_VOTING_ENDED)
    (asserts! (<= funding-percentage u100) ERR_INVALID_AMOUNT)
    (map-set research-milestones milestone-id
      {
        proposal-id: proposal-id,
        researcher: tx-sender,
        title: title,
        description: description,
        deadline: deadline,
        funding-percentage: funding-percentage,
        completed: false,
        completion-evidence: "",
        completed-at: u0
      }
    )
    (map-set proposal-milestones proposal-id
      {
        milestone-ids: (unwrap! (as-max-len? (append (get milestone-ids current-milestones) milestone-id) u10) ERR_INVALID_AMOUNT),
        total-milestones: (+ (get total-milestones current-milestones) u1)
      }
    )
    (var-set milestone-counter milestone-id)
    (ok milestone-id)
  )
)

(define-public (complete-milestone (milestone-id uint) (evidence-hash (string-ascii 64)))
  (let
    (
      (milestone (unwrap! (map-get? research-milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get researcher milestone)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get completed milestone)) ERR_MILESTONE_ALREADY_COMPLETED)
    (asserts! (<= stacks-block-height (get deadline milestone)) ERR_MILESTONE_DEADLINE_PASSED)
    (map-set research-milestones milestone-id
      (merge milestone {
        completed: true,
        completion-evidence: evidence-hash,
        completed-at: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? research-milestones milestone-id)
)

(define-read-only (get-proposal-milestones (proposal-id uint))
  (map-get? proposal-milestones proposal-id)
)

(define-read-only (get-milestone-stats (proposal-id uint))
  (let
    (
      (milestone-data (default-to { milestone-ids: (list), total-milestones: u0 } (map-get? proposal-milestones proposal-id)))
      (total-count (get total-milestones milestone-data))
    )
    {
      total-milestones: total-count,
      completion-rate: (if (> total-count u0) (/ (* u100 total-count) total-count) u0)
    }
  )
)


(define-map research-collaborations
  uint
  {
    lead-researcher: principal,
    proposal-id: uint,
    max-collaborators: uint,
    current-collaborators: uint,
    funding-distributed: bool
  }
)

(define-map collaboration-members
  { collab-id: uint, member: principal }
  {
    contribution-percentage: uint,
    expertise-area: (string-ascii 50),
    joined-at: uint
  }
)

(define-public (create-collaboration (proposal-id uint) (max-collaborators uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (collab-id (+ (var-get collaboration-counter) u1))
    )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (<= max-collaborators u5) ERR_INVALID_AMOUNT)
    (map-set research-collaborations collab-id
      {
        lead-researcher: tx-sender,
        proposal-id: proposal-id,
        max-collaborators: max-collaborators,
        current-collaborators: u0,
        funding-distributed: false
      }
    )
    (var-set collaboration-counter collab-id)
    (ok collab-id)
  )
)

(define-public (join-collaboration (collab-id uint) (contribution-percentage uint) (expertise-area (string-ascii 50)))
  (let
    (
      (collaboration (unwrap! (map-get? research-collaborations collab-id) ERR_COLLABORATION_NOT_FOUND))
      (is-member (default-to false (map-get? members tx-sender)))
      (already-joined (is-some (map-get? collaboration-members { collab-id: collab-id, member: tx-sender })))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (asserts! (not already-joined) ERR_ALREADY_COLLABORATOR)
    (asserts! (< (get current-collaborators collaboration) (get max-collaborators collaboration)) ERR_TEAM_FULL)
    (asserts! (and (> contribution-percentage u0) (<= contribution-percentage u100)) ERR_INVALID_PERCENTAGE)
    (map-set collaboration-members
      { collab-id: collab-id, member: tx-sender }
      {
        contribution-percentage: contribution-percentage,
        expertise-area: expertise-area,
        joined-at: stacks-block-height
      }
    )
    (map-set research-collaborations collab-id
      (merge collaboration { current-collaborators: (+ (get current-collaborators collaboration) u1) })
    )
    (ok true)
  )
)

(define-public (distribute-collaboration-funding (collab-id uint))
  (let
    (
      (collaboration (unwrap! (map-get? research-collaborations collab-id) ERR_COLLABORATION_NOT_FOUND))
      (proposal-id (get proposal-id collaboration))
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get lead-researcher collaboration)) ERR_NOT_TEAM_LEAD)
    (asserts! (get executed proposal) ERR_PROPOSAL_NOT_APPROVED)
    (asserts! (not (get funding-distributed collaboration)) ERR_PROPOSAL_NOT_APPROVED)
    (map-set research-collaborations collab-id
      (merge collaboration { funding-distributed: true })
    )
    (ok true)
  )
)

(define-read-only (get-collaboration (collab-id uint))
  (map-get? research-collaborations collab-id)
)

(define-read-only (get-collaboration-member (collab-id uint) (member principal))
  (map-get? collaboration-members { collab-id: collab-id, member: member })
)

(define-constant ERR_DISPUTE_NOT_FOUND (err u500))
(define-constant ERR_INVALID_DISPUTE_TYPE (err u501))
(define-constant ERR_DISPUTE_ALREADY_RESOLVED (err u502))
(define-constant ERR_ARBITRATION_ENDED (err u503))
(define-constant ERR_ALREADY_ARBITRATED (err u504))
(define-constant MIN_ARBITRATOR_REPUTATION u100)

(define-data-var dispute-counter uint u0)

(define-map disputes
  uint
  {
    initiator: principal,
    defendant: principal,
    dispute-type: (string-ascii 30),
    target-id: uint,
    evidence-hash: (string-ascii 64),
    votes-uphold: uint,
    votes-dismiss: uint,
    arbitration-deadline: uint,
    resolved: bool,
    resolution: (string-ascii 20)
  }
)

(define-map arbitrator-votes
  { dispute-id: uint, arbitrator: principal }
  { vote-uphold: bool, voting-power: uint }
)

(define-public (create-dispute (defendant principal) (dispute-type (string-ascii 30)) (target-id uint) (evidence-hash (string-ascii 64)))
  (let
    (
      (dispute-id (+ (var-get dispute-counter) u1))
      (is-member (default-to false (map-get? members tx-sender)))
      (arbitration-deadline (+ stacks-block-height u288))
    )
    (asserts! is-member ERR_NOT_MEMBER)
    (map-set disputes dispute-id
      {
        initiator: tx-sender,
        defendant: defendant,
        dispute-type: dispute-type,
        target-id: target-id,
        evidence-hash: evidence-hash,
        votes-uphold: u0,
        votes-dismiss: u0,
        arbitration-deadline: arbitration-deadline,
        resolved: false,
        resolution: "pending"
      }
    )
    (var-set dispute-counter dispute-id)
    (ok dispute-id)
  )
)

(define-public (vote-on-dispute (dispute-id uint) (vote-uphold bool))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (arbitrator-rep (get-member-reputation tx-sender))
      (has-voted (is-some (map-get? arbitrator-votes { dispute-id: dispute-id, arbitrator: tx-sender })))
      (voting-power (default-to u0 (map-get? member-voting-power tx-sender)))
    )
    (asserts! (>= arbitrator-rep MIN_ARBITRATOR_REPUTATION) ERR_NOT_MEMBER_REP)
    (asserts! (not has-voted) ERR_ALREADY_ARBITRATED)
    (asserts! (<= stacks-block-height (get arbitration-deadline dispute)) ERR_ARBITRATION_ENDED)
    (asserts! (not (get resolved dispute)) ERR_DISPUTE_ALREADY_RESOLVED)
    (map-set arbitrator-votes
      { dispute-id: dispute-id, arbitrator: tx-sender }
      { vote-uphold: vote-uphold, voting-power: voting-power }
    )
    (if vote-uphold
      (map-set disputes dispute-id
        (merge dispute { votes-uphold: (+ (get votes-uphold dispute) voting-power) })
      )
      (map-set disputes dispute-id
        (merge dispute { votes-dismiss: (+ (get votes-dismiss dispute) voting-power) })
      )
    )
    (ok true)
  )
)

(define-public (resolve-dispute (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
      (votes-uphold (get votes-uphold dispute))
      (votes-dismiss (get votes-dismiss dispute))
    )
    (asserts! (> stacks-block-height (get arbitration-deadline dispute)) ERR_ARBITRATION_ENDED)
    (asserts! (not (get resolved dispute)) ERR_DISPUTE_ALREADY_RESOLVED)
    (if (> votes-uphold votes-dismiss)
      (begin
        (map-set disputes dispute-id
          (merge dispute { resolved: true, resolution: "upheld" })
        )
        (ok "upheld")
      )
      (begin
        (map-set disputes dispute-id
          (merge dispute { resolved: true, resolution: "dismissed" })
        )
        (ok "dismissed")
      )
    )
  )
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id)
)

(define-read-only (get-arbitrator-vote (dispute-id uint) (arbitrator principal))
  (map-get? arbitrator-votes { dispute-id: dispute-id, arbitrator: arbitrator })
)

(define-read-only (get-total-disputes)
  (var-get dispute-counter)
)