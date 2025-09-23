# 🗳️ Delegation System

## Overview

The Delegation System enables DAO members to delegate their voting power to trusted representatives, creating a flexible governance structure that improves participation and decision-making efficiency.

## Key Features

### 🎯 **Partial Delegation**
- Delegate any amount of your voting power (not required to delegate all)
- Maintain control over remaining voting power for direct participation

### 🔄 **Flexible Management**
- **Delegate**: Assign voting power to trusted representatives
- **Undelegate**: Reclaim specific amounts of delegated power
- **Revoke**: Instantly revoke all delegations

### 🛡️ **Security Safeguards**
- **Loop Prevention**: Prevents circular delegation chains that could break voting
- **Self-Delegation Block**: Cannot delegate to yourself
- **Balance Validation**: Cannot delegate more power than you possess

## API Reference

### Public Functions

#### `delegate-votes (delegatee principal) (amount uint)`
Delegate voting power to another DAO member.

**Parameters:**
- `delegatee`: Principal address to receive delegation
- `amount`: Voting power amount to delegate

**Requirements:**
- Must be a DAO member
- Delegatee must be a DAO member
- Cannot delegate to yourself
- Must have sufficient available voting power
- Delegatee cannot already be delegating to someone else (prevents loops)

#### `undelegate-votes (amount uint)`
Reclaim a specific amount of previously delegated voting power.

**Parameters:**
- `amount`: Voting power amount to reclaim

**Requirements:**
- Must have active delegation
- Amount must not exceed currently delegated power

#### `revoke-delegation ()`
Instantly revoke all delegated voting power.

**Requirements:**
- Must have an active delegation

### Read-Only Functions

#### `get-delegatee (member principal)`
Returns the principal that the member has delegated to (if any).

#### `get-delegated-amount (member principal)`
Returns the amount of voting power the member has delegated out.

#### `get-received-delegation-power (delegate principal)`
Returns the total voting power that has been delegated to this delegate.

#### `get-effective-voting-power (member principal)`
Returns the member's effective voting power (own power - delegated out + delegated in).

## Usage Examples

### Basic Delegation
```clarity
;; Alice delegates 50 voting power to Bob
(contract-call? .DAO delegate-votes 'ST1ALICE... u50)
```

### Partial Undelegation
```clarity
;; Alice reclaims 20 voting power from her delegation
(contract-call? .DAO undelegate-votes u20)
```

### Complete Revocation
```clarity
;; Alice revokes all delegated power
(contract-call? .DAO revoke-delegation)
```

### Checking Delegation Status
```clarity
;; Check who Alice delegated to
(contract-call? .DAO get-delegatee 'ST1ALICE...)

;; Check Alice's effective voting power
(contract-call? .DAO get-effective-voting-power 'ST1ALICE...)
```

## Governance Impact

### Enhanced Participation
- **Lower Barrier**: Members can participate through delegation without monitoring every proposal
- **Expert Representation**: Specialized delegates can make informed decisions in their areas of expertise
- **Scalable Governance**: Reduces the burden on individual members while maintaining democratic principles

### Voting Power Calculation
```
Effective Voting Power = Base Power - Delegated Out + Received Delegations
```

**Example:**
- Alice deposits 100 STX → 100 base voting power
- Alice delegates 60 power to Bob → Alice has 40 effective power
- Carol delegates 30 power to Alice → Alice has 70 effective power

## Security Considerations

### Loop Prevention
The system prevents delegation loops using a simplified approach:
- A member who has delegated to someone cannot receive delegations
- This prevents complex circular chains while maintaining simplicity

### State Consistency
- All delegation operations are atomic
- Voting power calculations are performed on-demand
- No double-spending of voting power is possible

## Error Codes

- `u109` (`err-delegation-loop`): Attempted delegation would create a loop
- `u110` (`err-insufficient-delegation`): Insufficient delegated power for operation
- `u111` (`err-self-delegation`): Attempted to delegate to yourself

## Best Practices

### For Delegates
1. **Transparency**: Clearly communicate your voting philosophy and expertise areas
2. **Engagement**: Actively participate in proposal discussions
3. **Responsibility**: Vote in the best interests of those who delegated to you

### For Delegators
1. **Research**: Choose delegates based on their track record and alignment with your values
2. **Monitor**: Keep track of how your delegates vote
3. **Flexibility**: Don't hesitate to redelegate or reclaim power when needed

## Integration Notes

The delegation system is fully backward-compatible with existing DAO functionality:
- Existing members' voting power remains unchanged
- Non-delegating members operate exactly as before
- All existing functions continue to work without modification