# Community-Governed Investment Fund DAO

A decentralized autonomous organization (DAO) smart contract that enables community members to pool funds and collectively make investment decisions through transparent voting mechanisms.

## Features

- **Membership System**: Join the DAO by depositing STX tokens
- **Proposal Creation**: Members can submit investment proposals with detailed descriptions
- **Democratic Voting**: Token-weighted voting system for all investment decisions  
- **Treasury Management**: Secure fund pooling and automated distribution
- **Transparent Governance**: All transactions and votes are publicly auditable
- **Flexible Configuration**: Adjustable voting periods, quorum requirements, and minimum deposits

## Contract Functions

### Public Functions

#### `join-dao`
Join the DAO by depositing STX tokens. Your deposit determines your voting power.

#### `add-funds (amount uint)`
Add additional STX tokens to increase your voting power and stake in the DAO.

#### `submit-proposal (title description amount recipient)`
Create a new investment proposal specifying:
- `title`: Brief proposal title (max 100 chars)
- `description`: Detailed proposal description (max 500 chars) 
- `amount`: STX amount to be invested
- `recipient`: Target address for the investment

#### `vote (proposal-id vote-for)`
Vote on an active proposal:
- `proposal-id`: ID of the proposal to vote on
- `vote-for`: true for yes, false for no

#### `execute-proposal (proposal-id)`
Execute an approved proposal after voting period ends. Transfers funds to the specified recipient.

#### `withdraw-membership`
Exit the DAO and withdraw your proportional share of the treasury.

### Read-Only Functions

#### `get-member-info (member)`
Returns membership details including deposit amount and voting power.

#### `get-proposal (proposal-id)`
Returns full proposal details including voting statistics.

#### `get-treasury-balance`
Returns current total STX balance in the DAO treasury.

#### `is-proposal-approved (proposal-id)`
Checks if a proposal has met quorum and majority approval requirements.

## Usage Examples

### Joining the DAO
```clarity
(contract-call? .DAO join-dao)
```

### Creating a Proposal
```clarity
(contract-call? .DAO submit-proposal
  "Fund DeFi Protocol"
  "Invest 10,000 STX in a promising new DeFi lending protocol"
  u10000000
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Voting on a Proposal
```clarity
(contract-call? .DAO vote u1 true)
```

### Executing an Approved Proposal
```clarity
(contract-call? .DAO execute-proposal u1)
```

## Governance Parameters

- **Minimum Deposit**: 1 STX (configurable)
- **Voting Period**: 144 blocks (~24 hours, configurable)
- **Quorum**: 30% of total voting power (configurable)
- **Voting Power**: 1 voting power per 1000 micro-STX deposited

## Development Setup

1. Install Clarinet: https://docs.hiro.so/stacks/clarinet
2. Clone this repository
3. Run contract checks: `clarinet check`
4. Run tests: `npm test`

## Security Features

- Owner-only governance parameter updates
- Prevention of double voting
- Automatic quorum validation
- Secure fund handling with built-in checks
- Protection against proposal replay attacks

## Error Codes

- `u100`: Owner-only function
- `u101`: Not a DAO member
- `u102`: Proposal not found
- `u103`: Voting period ended
- `u104`: Already voted on this proposal
- `u105`: Insufficient funds
- `u106`: Proposal not approved
- `u107`: Proposal already executed
- `u108`: Below minimum deposit requirement

## License

This project is open source and available under the MIT License.
