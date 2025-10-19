Proposal comments

Overview
Adds on-chain per-proposal comments to improve governance transparency without affecting existing voting/execution logic.

Technical Implementation
- New maps: proposal-comment-counters (next id per proposal), proposal-comments (author, message, created-at)
- Public function: add-comment(proposal-id, message)
- Read-only: get-comment-count(proposal-id), get-comment(proposal-id, comment-id)
- Clarity v3 types, error constants, no cross-contract calls

Testing & Validation
•  ✅ Contract passes clarinet check
•  ✅ All npm tests successful
•  ✅ CI/CD pipeline configured
•  ✅ Clarity v3 compliant with proper error handling